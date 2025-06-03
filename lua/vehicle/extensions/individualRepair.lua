local M = {}

local damagedParts = {}
local damageData = {}

local nodeIDconvert = {}
local beamIDconvert = {}
local hydrosIDconvert = {}
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
  if not partPath or not pathsTable then
    return false
  end

  for checkPath, _ in pairs(pathsTable) do
    if partPath == checkPath then
      return true
    end
  end
  return false
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
    log("W", "individualRepair.load",
      "Structure mismatch detected - likely due to part replacements. Proceeding with caution.")
  end

  -- Ensure beamstate.onBeamDeformed is available
  if not beamstate or not beamstate.onBeamDeformed then
    log("E", "individualRepair.load",
      "beamstate.onBeamDeformed is not available. Cannot reliably load beam deformation states.")
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
      table.insert(partNodes[nodePath], {
        cid = cid,
        pos = node.pos
      })
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
      if hydros.hydros[k] and not shouldProcessPart(hydroPath, partsToRepairSet) and
        not shouldProcessPart(hydroPath, partsToRemoveSet) then
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
    if v.data.beams[cid] then -- Only process beams that exist in current vehicle
      local beamPath = v.data.beams[cid].partPath or v.config.partsTree.partPath
      if shouldProcessPart(beamPath, partsToRepairSet) then
        -- For beams we want to repair, reset them to original state
        local beamData = v.data.beams[cid]
        if beamData.beamLength then
          obj:setBeamLength(cid, beamData.beamLength)
        end
        if beamData.beamSpring then
          obj:setBeamSpringDamp(cid, beamData.beamSpring, beamData.beamDamp, beamData.beamShortBound or -1,
            beamData.beamLongBound or -1)
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
          obj:setBeamSpringDamp(cid, beamData.beamSpring, beamData.beamDamp, beamData.beamShortBound or -1,
            beamData.beamLongBound or -1)
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

local function onBeamDeformed(cid)
  local b = v.data.beams[cid]
  if b then
    if b.partPath then
      damagedParts[b.partPath] = true
    end
  end
end

local function onBeamBroke(cid)
  local b = v.data.beams[cid]
  if b then
    if b.partPath then
      damagedParts[b.partPath] = true
    end
  end
end

function M.getDamagedParts()
  return damagedParts
end

local function seperateByPart(inputTable)
  local outputTable = {}
  for _, state in ipairs(inputTable) do
    if not state.partPath then
      print("No part path found for: " .. tostring(state.cid))
      goto continue
    end
    local parentPath = getParentPath(state.partPath)
    if not outputTable[parentPath] then
      outputTable[parentPath] = {}
    end
    table.insert(outputTable[parentPath], state)
    ::continue::
  end
  return outputTable
end

local function getWheelNodes()
  local wheelNodes = {}
  for i, wheel in pairs(v.data.wheels) do
    if wheel.nodes then
      for index, node in ipairs(wheel.nodes) do
        table.insert(wheelNodes, node, "wheel" .. i .. "_node" .. index)
      end
    end
    if wheel.treadNodes then
      for index, node in ipairs(wheel.treadNodes) do
        table.insert(wheelNodes, node, "wheel" .. i .. "_treadNode" .. index)
      end
    end
  end
  return wheelNodes
end

local function saveDamageData(filename)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.rls_save.json"
  end

  local wheelNodes = getWheelNodes()

  local save = {}
  save.format = "rls_v1"
  save.model = v.data.model
  save.luaState = serialize(serializePackages("save"))
  save.rotation = quat(obj:getRotation()):toTable()

  save.partStates = {}

  --
  for _, node in pairs(v.data.nodes) do
    local parentPath
    if not node.partPath then
      print("No part path found for: " .. tostring(node.cid))
    else
      parentPath = getParentPath(node.partPath)
    end
    if not save.partStates[parentPath] then
      save.partStates[parentPath] = {}
    end
    if not save.partStates[parentPath].nodes then
      save.partStates[parentPath].nodes = {}
    end
    if not node.name then
      if wheelNodes[node.cid] then
        node.name = wheelNodes[node.cid]
      else
        print("No name found for: " .. tostring(node.cid) .. " " .. tostring(node.partPath))
      end
    end
    table.insert(save.partStates[parentPath].nodes, node.cid, {
      pos = obj:getNodePosition(node.cid):toTable(),
      name = node.name,
      mass = math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 and obj:getNodeMass(node.cid) or
        nil
    })
  end

  for _, beam in pairs(v.data.beams) do
    local parentPath
    if not beam.partPath then
      print("No part path found for: " .. tostring(beam.cid))
    else
      parentPath = getParentPath(beam.partPath)
    end
    if not save.partStates[parentPath] then
      save.partStates[parentPath] = {}
    end
    if not save.partStates[parentPath].beams then
      save.partStates[parentPath].beams = {}
    end
    table.insert(save.partStates[parentPath].beams, beam.cid, {
      length = obj:getBeamRestLength(beam.cid),
      broken = obj:beamIsBroken(beam.cid) and true or nil,
      deformed = obj:getBeamDeformation(beam.cid) ~= 0 and obj:getBeamDeformation(beam.cid) or nil,
      idents = {beam.id1, beam.id2, beam.beamType}
    })
  end

  for _, hydros in pairs(hydros.hydros) do
    local parentPath
    if not hydros.partPath then
      print("No part path found for: " .. tostring(hydros.cid))
    else
      parentPath = getParentPath(hydros.partPath)
    end
    if not save.partStates[parentPath] then
      save.partStates[parentPath] = {}
    end
    if not save.partStates[parentPath].hydros then
      save.partStates[parentPath].hydros = {}
    end
    table.insert(save.partStates[parentPath].hydros, hydros.cid, {
      idents = {hydros.id1, hydros.id2, hydros.beamType},
      state = hydros.state
    })
  end
  -- ]]

  --[[

  local vehNodes = seperateByPart(v.data.nodes)
  local vehBeams = seperateByPart(v.data.beams)
  local vehHydros = seperateByPart(hydros.hydros)

  for partPath, state in pairs(damagedParts) do
    save.partStates[partPath] = {}
    if not vehNodes[partPath] then
      goto beams
    end
    save.partStates[partPath].nodes = {}
    for _, node in pairs(vehNodes[partPath]) do
      save.partStates[partPath].nodes[node.cid] = {
          pos = obj:getNodePosition(node.cid):toTable(),
          name = node.name,
          mass = math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 and obj:getNodeMass(node.cid) or nil
      }
    end
    ::beams::
    if not vehBeams[partPath] then
      goto hydros
    end
    save.partStates[partPath].beams = {}
    for _, beam in pairs(vehBeams[partPath]) do
      save.partStates[partPath].beams[beam.cid] = {
          length = obj:getBeamRestLength(beam.cid) or 0,
          broken = obj:beamIsBroken(beam.cid) and true or nil,
          deformed = obj:getBeamDeformation(beam.cid) ~= 0 and obj:getBeamDeformation(beam.cid) or nil,
          idents = {beam.id1, beam.id2, beam.beamType},
      }
    end
    ::hydros::
    if not vehHydros[partPath] then
      goto nextPart
    end
    save.partStates[partPath].hydros = {}
    for _, hydros in pairs(vehHydros[partPath]) do
      save.partStates[partPath].hydros[hydros.cid] = {
        idents = {hydros.id1, hydros.id2, hydros.beamType},
        state = hydros.state,
      }
    end
    ::nextPart::
  end
  --]]

  local savedParts = 0
  for partPath, state in pairs(save.partStates) do
    savedParts = savedParts + 1
  end
  print("Saved " .. savedParts .. " parts")

  jsonWriteFile(filename, save, true)
  return save
end

local function loadNodeIDconvert(separateOldNodes)
  local separateNewNodes = seperateByPart(v.data.nodes)
  local nodeConvert = {}

  local wheelNodes = getWheelNodes()

  local partCount = 0
  -- Count the actual number of entries in the table
  local totalParts = 0
  for _ in pairs(separateOldNodes) do
    totalParts = totalParts + 1
  end

  print("Total parts to process: " .. totalParts)

  for partPath, state in pairs(separateOldNodes) do
    partCount = partCount + 1
    local nodes = state.nodes
    if not nodes then
      print("No nodes found for part: " .. partPath)
      goto continue -- Using goto instead of break to continue the loop
    end
    for cid, oldNode in pairs(nodes) do
      if oldNode.name then
        for _, newNode in ipairs(v.data.nodes) do
          if not newNode.name then
            if wheelNodes[newNode.cid] then
              newNode.name = wheelNodes[newNode.cid]
            else
              print("No name found for: " .. tostring(newNode.cid) .. " " .. tostring(newNode.partPath))
            end
          end
          if newNode.name == oldNode.name then
            if tostring(cid) ~= tostring(newNode.cid) then
              nodeConvert[cid] = newNode.cid
            end
            break
          end
        end
      end
    end
    ::continue::
  end
  print("Checked " .. partCount .. " parts")
  return nodeConvert
end

local function loadBeamIDconvert(separateOldBeams, hydros)
  if not separateOldBeams or separateOldBeams == {} then
    return
  end

  local separateNewBeams
  if hydros then
    separateNewBeams = seperateByPart(v.data.hydros)
  else
    separateNewBeams = seperateByPart(v.data.beams)
  end

  -- Process each part's beams
  for partPath, states in pairs(separateOldBeams) do
    -- Skip if this part doesn't exist in the new vehicle
    if not separateNewBeams[partPath] then
      goto continue
    end
    local beams = {}
    if hydros then
      beams = states.hydros
    else
      beams = states.beams
    end
    if not beams then
      goto continue
    end

    -- For each old beam in this part
    for oldCID, oldBeam in pairs(beams) do
      -- Get the nodes this beam connects
      local oldNode1 = oldBeam.idents[1]
      local oldNode2 = oldBeam.idents[2]
      local oldBeamType = oldBeam.idents[3]

      -- Convert old node IDs to new node IDs using nodeIDconvert
      local newNode1 = nodeIDconvert[tostring(oldNode1)] or oldNode1
      local newNode2 = nodeIDconvert[tostring(oldNode2)] or oldNode2

      -- Skip if either node conversion failed
      if not newNode1 or not newNode2 then
        goto nextBeam
      end

      -- Find matching beam in the new vehicle
      for _, newBeam in ipairs(separateNewBeams[partPath]) do
        -- Check if this beam connects the same nodes (in either order)
        if (newBeam.id1 == newNode1 and newBeam.id2 == newNode2 and newBeam.beamType == oldBeamType) or
          (newBeam.id1 == newNode2 and newBeam.id2 == newNode1 and newBeam.beamType == oldBeamType) then
          -- Found a match - map old beam CID to new beam CID
          if hydros then
            if oldCID ~= newBeam.cid then
              hydrosIDconvert[oldCID] = newBeam.cid
            end
          else
            if oldCID ~= newBeam.cid then
              beamIDconvert[oldCID] = newBeam.cid
            end
          end
          break
        end
      end

      ::nextBeam::
    end

    ::continue::
  end

  return beamIDconvert
end

local function getBeamsToChange(partStates, partsToChange)
  if not partsToChange then
    return {}
  end
  local changedNodes = {}
  for partPath, state in pairs(partStates) do
    if partsToChange and shouldProcessPart(partPath, partsToChange) then
      if state.nodes then
        for cid, node in pairs(state.nodes) do
          if node.name then
            table.insert(changedNodes, cid, partPath)
          end
        end
      end
    end
  end
  local beamsToChange = {}
  for partPath, state in pairs(partStates) do
    if state.beams then
      for cid, beam in pairs(state.beams) do
        if beam.idents[1] and beam.idents[2] then
          if changedNodes[beam.idents[1]] and changedNodes[beam.idents[2]] then
            goto nextBeam
          elseif changedNodes[beam.idents[1]] then
            local node = partStates[changedNodes[beam.idents[1]]].nodes[tostring(beam.idents[1])]
            if node then
              table.insert(beamsToChange, cid, {
                node = beam.idents[1],
                pos = vec3(node.pos)
              })
            end
          elseif changedNodes[beam.idents[2]] then
            local node = partStates[changedNodes[beam.idents[2]]].nodes[tostring(beam.idents[2])]
            if node then
              table.insert(beamsToChange, cid, {
                node = beam.idents[2],
                pos = vec3(node.pos)
              })
            end
          end
        end
        ::nextBeam::
      end
    end
  end
  return beamsToChange
end

local function loadDamageData(filename, partsToRepair, partsToRemove)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.rls_save.json"
  end

  local save = jsonReadFile(filename)
  if not save then
    log("E", "individualRepair.load", "Invalid save file: " .. filename)
    return
  end

  if save.format ~= "rls_v1" then
    log("E", "individualRepair.load", "Invalid save format: " .. save.format)
    return
  end

  if save.model ~= v.data.model then
    log("E", "individualRepair.load", "Invalid model: " .. save.model)
    return
  end

  -- Calculate rotation difference between saved and current orientation
  local currentRotation = quat(obj:getRotation())
  local saveRotation = quat(save.rotation)

  -- Calculate the rotation needed to go from saved rotation to current rotation
  local rotationDifference = currentRotation * saveRotation:inversed()

  -- Adjust beam lengths
  local beamsToAdjust = getBeamsToChange(save.partStates, partsToRepair)
  local beamsToRemove = getBeamsToChange(save.partStates, partsToRemove)
  
  for partPath, state in pairs(save.partStates) do
    if partsToRemove and shouldProcessPart(partPath, partsToRemove) then
      print("Skipping part: " .. partPath .. " because it is in the partsToRemove list")
      save.partStates[partPath] = nil
    end
    if partsToRepair and shouldProcessPart(partPath, partsToRepair) then
      print("Skipping part: " .. partPath .. " because it is in the partsToRepair list")
      save.partStates[partPath] = nil
    end
  end

  importPersistentData(save.luaState)
  nodeIDconvert = loadNodeIDconvert(save.partStates)
  beamIDconvert = loadBeamIDconvert(save.partStates)
  hydrosIDconvert = loadBeamIDconvert(save.partStates, true)

  dump(beamIDconvert)

  for partPath, state in pairs(save.partStates) do
    if save.partStates[partPath].nodes then
      for cid, node in pairs(state.nodes) do
        local newCID = nodeIDconvert[tostring(cid)] or cid
        if newCID then
          -- Apply rotation difference to the node position
          local nodePos = vec3(node.pos)
          local rotatedPos = rotationDifference * nodePos

          -- Set the rotated position
          obj:setNodePosition(newCID, rotatedPos)

          if node.mass then
            obj:setNodeMass(newCID, node.mass)
          end
        end
      end
    end
    if save.partStates[partPath].beams then
      for cid, beam in pairs(state.beams) do
        if beamsToAdjust[tonumber(cid)] or beamsToRemove[tonumber(cid)] then
          print("Skipping beam: " .. tostring(cid) .. " because it is in the beamsToAdjust or beamsToRemove list")
          goto nextBeam
        end
        if beam.length > 0 then
          obj:setBeamLength(beamIDconvert[cid] or cid, beam.length)
        end
        if beam.broken then
          obj:breakBeam(beamIDconvert[cid] or cid)
        end
        if beam.deformed then
          onBeamDeformed(beamIDconvert[cid] or cid, beam.deformed)
          beamstate.onBeamDeformed(beamIDconvert[cid] or cid, beam.deformed)
        end
        ::nextBeam::
      end
    end
    if save.partStates[partPath].hydros then
      if state.hydros then
        for cid, hydro in pairs(state.hydros) do
          for k, h in pairs(hydros.hydros) do
            if h.cid == (hydrosIDconvert[cid] or cid) then
              h.state = hydro.state
              break
            end
          end
        end
      end
    end
  end

  obj:commitLoad()
end

M.getNodeIDconvert = function()
  return nodeIDconvert
end

M.getBeamIDconvert = function()
  return beamIDconvert
end

M.getHydrosIDconvert = function()
  return hydrosIDconvert
end

M.saveDamageData = saveDamageData
M.loadDamageData = loadDamageData

M.onBeamDeformed = onBeamDeformed
M.onBeamBroke = onBeamBroke

M.saveData = damageData

-- Test reset function
M.reset = function()
  damagedParts = {}
  damageData = {}
  nodeIDconvert = {}
  beamIDconvert = {}
end

return M
