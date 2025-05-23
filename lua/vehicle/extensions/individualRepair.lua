local M = {}

--- Gets the parent path by finding the last "/"
-- @param path (string) The full path to split
-- @return (string) The parent path, or "/" if no parent found
local function getParentPath(path)
  local lastSlash = path:find("/[^/]*$")
  if lastSlash then
    return path:sub(1, lastSlash)
  end
  return "/"
end

--- Checks if a part path should be repaired
-- @param partPath (string) The path to check
-- @param pathsTable (table) Table of paths to match against
-- @return (boolean) True if the part should be repaired
local function shouldProcessPart(partPath, pathsTable)
  if not partPath or not pathsTable then return false end
  
  for checkPath, _ in pairs(pathsTable) do
    if partPath:find(checkPath, 1, true) then
      return true
    end
  end
  return false
end

--- Rotates a point around a center using a quaternion
-- @param point Vec3 point to rotate
-- @param center Vec3 center to rotate around
-- @param rotation Quat rotation to apply
-- @return Vec3 rotated point
local function rotatePointAround(point, center, rotation)
  -- 1. Translate point to origin relative to center
  local relativePos = point - center
  
  -- 2. Apply rotation (BeamNG's quaternions can multiply vectors directly)
  local rotatedPos = rotation * relativePos
  
  -- 3. Translate back to original coordinate system
  return rotatedPos + center
end

--- Custom load function for vehicle states with selective part repair.
-- @param filename (string) The path to the standard beamstate save file.
-- @param partsToRepair (table) A list of partPath strings whose beams should be reset to undamaged state.
-- @param partsToRemove (table) A list of partPath strings to ignore completely.
function M.loadVehicleStateSelectiveRepair(filename, partsToRepair, partsToRemove)
  if filename == nil then
    log("E", "individualRepair.load", "No filename provided")
    return
  end

  if (not partsToRepair or #partsToRepair == 0) and (not partsToRemove or #partsToRemove == 0) then
    log("W", "individualRepair.load", "No parts to repair specified, loading normal save state")
    beamstate.load(filename)
    return
  end

  local save = jsonReadFile(filename)

  dump(save)

  -- Safety checks
  if not save then
    log("E", "individualRepair.load", "Save file not found or invalid: " .. filename)
    return
  end

  -- Check if we're dealing with the same vehicle type - only this check is critical
  if save.vehicleDirectory ~= v.data.vehicleDirectory then
    log("E", "individualRepair.load", "Unable to load vehicle: Wrong vehicle. File: " .. filename)
    return
  end
  
  -- Compare structure sizes but don't abort - just log a warning
  if save.nodeCount ~= tableSizeC(v.data.nodes) or save.beamCount ~= tableSizeC(v.data.beams) then
    log("W", "individualRepair.load", "Structure mismatch detected - likely due to part replacements. Proceeding with caution.")
  end

  -- Ensure beamstate.onBeamDeformed is available
  if not beamstate or not beamstate.onBeamDeformed then
    log("E", "individualRepair.load", "beamstate.onBeamDeformed is not available. Cannot reliably load beam deformation states.")
    return
  end

  -- Create a set of part paths to repair for faster lookup
  local partsToRepairSet = {}
  for _, path in ipairs(partsToRepair) do
    partsToRepairSet[path] = true
  end
  
  -- Create a set of part paths to remove
  local partsToRemoveSet = {}
  if partsToRemove then
    for _, path in ipairs(partsToRemove) do
      partsToRemoveSet[path] = true
    end
  end

  importPersistentData(save.luaState)

  -- Create a mapping of parts to their nodes
  local partNodes = {}
  for cid = 0, tableSizeC(v.data.nodes) - 1 do
    local node = v.data.nodes[cid]
    local nodePath = node.partPath or v.config.partsTree.partPath
    
    if shouldProcessPart(nodePath, partsToRepairSet) then
      if not partNodes[nodePath] then
        partNodes[nodePath] = {}
      end
      table.insert(partNodes[nodePath], {cid = cid, pos = node.pos})
    end
  end
  
  -- Get vehicle's current transform
  local refNodeID = v.data.refNodes[0].ref
  local currentRefPos = obj:getNodePosition(refNodeID)
  local vehRot = obj:getRotation() -- Use direct rotation instead of constructing from vectors
  
  -- Get original reference node position from jbeam definition
  local origRefNodePos = v.data.nodes[refNodeID].pos
  
  if hydros and hydros.hydros and save.hydros then
    for k, h_state in pairs(save.hydros) do
      local hydroPath = hydros.hydros[k].partPath
      if hydros.hydros[k] and not shouldProcessPart(hydroPath, partsToRepairSet) and not shouldProcessPart(hydroPath, partsToRemoveSet) then
        hydros.hydros[k].state = h_state
      end
    end
  end

  -- Load node positions - first handle nodes we're not repairing
  for cid_plus_1, node_data in pairs(save.nodes) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.nodes[cid] then
      local nodePath = v.data.nodes[cid].partPath or v.config.partsTree.partPath
      if not shouldProcessPart(nodePath, partsToRepairSet) and not shouldProcessPart(nodePath, partsToRemoveSet) then
        -- Not a part to repair, use saved position
        obj:setNodePosition(cid, vec3(node_data[1]))
        if #node_data > 1 then
          obj:setNodeMass(cid, node_data[2])
        end
      end
    end
    -- If node doesn't exist, we silently skip it (this is now OK with mismatched structures)
  end
  
  -- Now position the parts to repair, treating each part as a unit
  for partPath, nodes in pairs(partNodes) do
    for _, nodeData in ipairs(nodes) do
      local cid = nodeData.cid      
      obj:setNodePosition(cid, obj:getNodePosition(cid))
      
      -- Set mass from saved data if available, only if this specific node exists in the save
      if save.nodes[tostring(cid + 1)] and #save.nodes[tostring(cid + 1)] > 1 then
        obj:setNodeMass(cid, save.nodes[tostring(cid + 1)][2])
      end
    end
  end

  -- Load beam states, with selective repair - safely handling missing beams
  for cid_plus_1, beam_data in pairs(save.beams) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.beams[cid] then  -- Only process beams that exist in current vehicle
      local beamPath = v.data.beams[cid].partPath or v.config.partsTree.partPath
      if shouldProcessPart(beamPath, partsToRepairSet) then
        -- For beams we want to repair, reset them to original state
        local beamData = v.data.beams[cid]
        if beamData.beamLength then
          obj:setBeamLength(cid, beamData.beamLength)
        end
        if beamData.beamSpring then
          obj:setBeamSpringDamp(cid, beamData.beamSpring, beamData.beamDamp, beamData.beamShortBound or -1, beamData.beamLongBound or -1)
        end
        if beamData.beamDeformed then
          beamstate.onBeamDeformed(cid, 0)
        end
      elseif not shouldProcessPart(beamPath, partsToRemoveSet) then
        -- For other beams, load their saved state
        obj:setBeamLength(cid, beam_data[1])
        if beam_data[2] == true then
          obj:breakBeam(cid)
        end
        beamstate.onBeamDeformed(cid, beam_data[3])
      end
    end
    -- If beam doesn't exist in current structure, we silently skip it
  end

  -- Process beams that exist in the current structure but not in the save data
  -- These are likely from new or replacement parts
  local currentBeamCount = tableSizeC(v.data.beams)
  for cid = 0, currentBeamCount - 1 do
    -- If this beam doesn't have data in the save file, it's from a new/replaced part
    if not save.beams[tostring(cid + 1)] then
      local beamPath = v.data.beams[cid].partPath or v.config.partsTree.partPath
      
      -- For new beams in parts we're not explicitly repairing, set to default state
      if not shouldProcessPart(beamPath, partsToRepairSet) and not shouldProcessPart(beamPath, partsToRemoveSet) then
        local beamData = v.data.beams[cid]
        if beamData.beamLength then
          obj:setBeamLength(cid, beamData.beamLength)
        end
        if beamData.beamSpring then
          obj:setBeamSpringDamp(cid, beamData.beamSpring, beamData.beamDamp, beamData.beamShortBound or -1, beamData.beamLongBound or -1)
        end
        if beamData.beamDeformed then
          beamstate.onBeamDeformed(cid, 0)
        end
      end
    end
  end

  obj:commitLoad()
  log('I', 'individualRepair.load', 'Vehicle state loaded with selective repair from: ' .. filename)
end

return M