local M = {}

--- Repairs/resets a specific beam by its ID.
-- This function attempts to restore the beam's physical properties (spring, damp, length)
-- and resets its damage state in Lua (beamstate.lua).
--
-- @param beamId (number) The numeric ID (cid) of the beam to repair.
-- @return (boolean) True if the beam was found and repair was attempted, false otherwise.
function M.repairBeamById(beamId)
  if not beamId then
    log('E', 'individualRepair.repairBeamById', 'No beamId provided.')
    return false
  end

  if not v or not v.data or not v.data.beams or not v.data.beams[beamId] then
    log('W', 'individualRepair.repairBeamById', 'Beam data not found for ID: ' .. tostring(beamId))
    return false
  end

  local beamData = v.data.beams[beamId] -- This should contain the original design specs

  -- 1. Reset Lua-side damage tracking (via beamstate if available)
  if beamstate and beamstate.onBeamDeformed then
    beamstate.onBeamDeformed(beamId, 0) -- Sets deformation ratio to 0
  else
    log('W', 'individualRepair.repairBeamById', 'beamstate.onBeamDeformed not available. Lua damage state might not be fully reset.')
    -- As a fallback, you might try to directly manipulate beamstate.deformedBeams if accessible and understood:
    -- if beamstate and beamstate.deformedBeams then beamstate.deformedBeams[beamId] = 0 end
    -- if beamstate then beamstate.beamDamageTrackerDirty = true end
  end

  -- 2. Restore physical properties in the engine
  local originalSpring = beamData.beamSpring
  local originalDamp = beamData.beamDamp
  -- Use original short/long bounds if they exist in beamData, otherwise -1 (common for 'use default/no change')
  local originalShortBound = beamData.beamShortBound or -1
  local originalLongBound = beamData.beamLongBound or -1
  local originalRestLength = beamData.beamLength -- Assuming this is the design rest length

  if type(originalSpring) ~= 'number' or type(originalDamp) ~= 'number' or type(originalRestLength) ~= 'number' then
    log('E', 'individualRepair.repairBeamById', 'Original beam properties (spring, damp, length) are invalid for beam ID: ' .. tostring(beamId))
    return false
  end

  obj:setBeamSpringDamp(beamId, originalSpring, originalDamp, originalShortBound, originalLongBound)
  obj:setBeamLength(beamId, originalRestLength)

  -- Note: The physics engine's internal 'isBroken' flag status after obj:breakBeam() was called
  -- is not directly 'unbroken' by a specific function. Restoring spring/damp *should*
  -- make it behave like an intact beam again if breaking merely zeroed these properties.

  log('D', 'individualRepair.repairBeamById', 'Attempted to repair beam: ' .. tostring(beamId))
  return true
end

--- Collects all beam IDs for a given list of part paths.
-- @param partPaths (table) A list of part path strings.
-- @return (table) A table where keys are beam IDs (numbers) belonging to any of the specified partPaths, and value is true.
local function getBeamIdsForParts(partPaths)
  local targetedBeamIds = {}
  if not v or not v.data or not v.data.beams or not partPaths or #partPaths == 0 then
    return targetedBeamIds
  end

  local partPathsSet = {}
  for _, path in ipairs(partPaths) do
    partPathsSet[path] = true
  end

  for beamId, beamData in pairs(v.data.beams) do
    if beamData and beamData.partPath and partPathsSet[beamData.partPath] then
      targetedBeamIds[beamId] = true
    end
  end
  return targetedBeamIds
end

M.getBeamIdsForParts = getBeamIdsForParts -- Expose if needed elsewhere

--- Custom save function that saves beams for specified parts as if they were repaired.
-- @param filename (string) The path to the save file.
-- @param partsToRepair (table) A list of partPath strings whose beams should be saved as undamaged.
function M.saveVehicleStateSelectiveRepair(filename, partsToRepair)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.selective_repair.save.json" -- Custom filename
  end
  if partsToRepair == nil then
    partsToRepair = {}
  end

  local save = {}
  save.format = "v2_selective_repair" -- Custom format identifier
  save.model = v.data.model
  save.parts = v.userPartConfig
  save.vars = v.userVars
  save.vehicleDirectory = v.data.vehicleDirectory
  save.nodeCount = tableSizeC(v.data.nodes)
  save.beamCount = tableSizeC(v.data.beams)
  save.luaState = serialize(serializePackages("save"))
  save.hydros = {}
  if hydros and hydros.hydros then
    for _, h in pairs(hydros.hydros) do
      table.insert(save.hydros, h.state)
    end
  end

  save.nodes = {}
  for nodeId, nodeData in pairs(v.data.nodes) do
    local d = {obj:getNodePosition(nodeData.cid):toTable()}
    if math.abs(obj:getOriginalNodeMass(nodeData.cid) - obj:getNodeMass(nodeData.cid)) > 0.1 then
      table.insert(d, obj:getNodeMass(nodeData.cid))
    end
    save.nodes[nodeData.cid + 1] = d -- Consistent with beamstate.lua (1-indexed)
  end

  local repairedBeamIds = getBeamIdsForParts(partsToRepair)
  save.beams = {}
  for beamId, beamDefData in pairs(v.data.beams) do -- beamId here is the numeric CID
    local beamOriginalData = v.data.beams[beamId] -- Contains original design specs
    local d
    if repairedBeamIds[beamId] then
      -- Save this beam as repaired/undamaged
      d = {
        beamOriginalData.beamLength, -- Original rest length
        false,                     -- Not broken
        0                          -- Zero deformation
      }
    else
      -- Save actual current state
      d = {
        obj:getBeamRestLength(beamId),
        obj:beamIsBroken(beamId),
        obj:getBeamDeformation(beamId)
      }
    end
    save.beams[beamId + 1] = d -- Consistent with beamstate.lua (1-indexed)
  end

  jsonWriteFile(filename, save, true)
  log('I', 'individualRepair.save', 'Vehicle state with selective repair saved to: ' .. filename)
end

--- Custom load function for vehicle states saved with selective repair.
-- @param filename (string) The path to the save file.
function M.loadVehicleStateSelectiveRepair(filename)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.selective_repair.save.json" -- Default custom filename
  end

  local save = jsonReadFile(filename)

  -- Safety checks
  if not save then
    log("E", "individualRepair.load", "Save file not found or invalid: " .. filename)
    return
  end
  
  if save.format ~= "v2_selective_repair" then
     log("E", "individualRepair.load", "Save file format mismatch. Expected 'v2_selective_repair', got: " .. tostring(save.format or "nil"))
    return
  end

  if save.nodeCount ~= tableSizeC(v.data.nodes) or save.beamCount ~= tableSizeC(v.data.beams) or save.vehicleDirectory ~= v.data.vehicleDirectory then
    log("E", "individualRepair.load", "Unable to load vehicle: Structural mismatch or wrong vehicle. File: " .. filename)
    return
  end

  -- Ensure beamstate.onBeamDeformed is available, as it's crucial for resetting deformation state
  if not beamstate or not beamstate.onBeamDeformed then
    log("E", "individualRepair.load", "beamstate.onBeamDeformed is not available. Cannot reliably load beam deformation states.")
    -- Depending on requirements, you might allow loading to continue with a warning, or abort.
    -- For now, we'll abort to prevent inconsistent states.
    return
  end

  importPersistentData(save.luaState)

  if hydros and hydros.hydros and save.hydros then
    for k, h_state in pairs(save.hydros) do
      if hydros.hydros[k] then
        hydros.hydros[k].state = h_state
      end
    end
  end

  for cid_plus_1, node_data in pairs(save.nodes) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.nodes[cid] then -- Check if node cid actually exists in current vehicle
      obj:setNodePosition(cid, vec3(node_data[1]))
      if #node_data > 1 then
        obj:setNodeMass(cid, node_data[2])
      end
    else
      log('W', 'individualRepair.load', 'Node CID ' .. cid .. ' from save file not found in current vehicle.')
    end
  end

  for cid_plus_1, beam_data in pairs(save.beams) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.beams[cid] then -- Check if beam cid actually exists
      obj:setBeamLength(cid, beam_data[1]) -- Sets rest length. For repaired beams, this is originalLength.
      if beam_data[2] == true then
        obj:breakBeam(cid) -- For non-repaired beams that were broken.
      end
      -- For repaired beams, beam_data[3] will be 0.
      -- For non-repaired, it's their actual deformation.
      -- beamstate.onBeamDeformed will correctly update the Lua-side tracking.
      beamstate.onBeamDeformed(cid, beam_data[3]) 
    else
      log('W', 'individualRepair.load', 'Beam CID ' .. cid .. ' from save file not found in current vehicle.')
    end
  end

  obj:commitLoad()
  log('I', 'individualRepair.load', 'Vehicle state with selective repair loaded from: ' .. filename)
  
  -- It might be necessary to trigger a full reset of beamstate's internal caches
  -- if just calling onBeamDeformed isn't enough for all derived states.
  -- For instance, breakgroup caches or part damage aggregations might need recalculation.
  -- beamstate.init() could be too broad, but something to consider if issues arise.
  -- For now, we rely on onBeamDeformed and the physics engine taking the new states.
end

return M 