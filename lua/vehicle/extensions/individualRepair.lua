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

--- Custom load function for vehicle states with selective part repair.
-- @param filename (string) The path to the standard beamstate save file.
-- @param partsToRepair (table) A list of partPath strings whose beams should be reset to undamaged state.
function M.loadVehicleStateSelectiveRepair(filename, partsToRepair)
  if filename == nil then
    log("E", "individualRepair.load", "No filename provided")
    return
  end

  if not partsToRepair or #partsToRepair == 0 then
    log("W", "individualRepair.load", "No parts to repair specified, loading normal save state")
    beamstate.load(filename)
    return
  end

  local save = jsonReadFile(filename)

  -- Safety checks
  if not save then
    log("E", "individualRepair.load", "Save file not found or invalid: " .. filename)
    return
  end

  if save.nodeCount ~= tableSizeC(v.data.nodes) or save.beamCount ~= tableSizeC(v.data.beams) or save.vehicleDirectory ~= v.data.vehicleDirectory then
    log("E", "individualRepair.load", "Unable to load vehicle: Structural mismatch or wrong vehicle. File: " .. filename)
    return
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

  importPersistentData(save.luaState)

  if hydros and hydros.hydros and save.hydros then
    for k, h_state in pairs(save.hydros) do
      local parentPath = getParentPath(hydros.hydros[k].partPath)
      if hydros.hydros[k] and not partsToRepairSet[parentPath] then
        hydros.hydros[k].state = h_state
      end
    end
  end

  -- Load node positions
  for cid_plus_1, node_data in pairs(save.nodes) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.nodes[cid] then
      local parentPath = getParentPath(v.data.nodes[cid].partPath)
      if partsToRepairSet[parentPath] then
        obj:setNodePosition(cid, v.data.nodes[cid].pos)
        if #node_data > 1 then
          obj:setNodeMass(cid, node_data[2])
        end
      else
        obj:setNodePosition(cid, vec3(node_data[1]))
        if #node_data > 1 then
          obj:setNodeMass(cid, node_data[2])
        end
      end
    else
      log('W', 'individualRepair.load', 'Node CID ' .. cid .. ' from save file not found in current vehicle.')
    end
  end
  --]]

  -- Load beam states, with selective repair
  for cid_plus_1, beam_data in pairs(save.beams) do
    local cid = tonumber(cid_plus_1) - 1
    if v.data.beams[cid] then
      local parentPath = getParentPath(v.data.beams[cid].partPath)
      if partsToRepairSet[parentPath] then
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
      else
        -- For other beams, load their saved state
        obj:setBeamLength(cid, beam_data[1])
        if beam_data[2] == true then
          obj:breakBeam(cid)
        end
        beamstate.onBeamDeformed(cid, beam_data[3])
      end
    else
      log('W', 'individualRepair.load', 'Beam CID ' .. cid .. ' from save file not found in current vehicle.')
    end
  end
  --]]

  obj:commitLoad()
  log('I', 'individualRepair.load', 'Vehicle state loaded with selective repair from: ' .. filename)
end

return M 