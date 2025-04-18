-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local jbeamIO = require('jbeam/io')

local imgui = ui_imgui

local minimumVersion = 42

local partInventory = {}

local coreSlots = {}
local partsBefore = {}
local partsAfter
local slotToPartIdMap = {}
local partInventoryOpen = false
local closeMenuAfterSaving

local currentVehicleInventoryIdForMenu

local function getNodeFromSlotPath(tree, path)
  if not tree or not path then return nil end

  -- Handle empty path case
  if path == "/" then return tree end

  -- Split the path into segments
  local segments = {}
  for segment in string.gmatch(path, "[^/]+") do
    table.insert(segments, segment)
  end

  -- Navigate through the tree
  local currentNode = tree
  for _, segment in ipairs(segments) do
    if currentNode.children and currentNode.children[segment] then
      currentNode = currentNode.children[segment]
    else
      return nil -- Path not found
    end
  end

  return currentNode
end

local function getDisconnectedParts(initialRemovedNode, vehicle)
  local disconnectedParts = {}

  -- Helper function to recursively traverse the tree
  local function traverseTree(node)
    if not node then return end

    -- If this node has a part, add it to disconnectedParts
    if node.chosenPartName and node.chosenPartName ~= "" then
      for partId, inventoryPart in pairs(partInventory) do
        if inventoryPart.containingSlot == node.path and inventoryPart.location == vehicle.id then
          disconnectedParts[partId] = inventoryPart
          break
        end
      end
    end

    -- Recursively process all children
    if node.children then
      for _, childNode in pairs(node.children) do
        traverseTree(childNode)
      end
    end
  end

  -- Start traversal from the parent node
  traverseTree(initialRemovedNode)

  return disconnectedParts
end

local function removeDisconnectedParts(vehicle, removedPartId)
  local initialRemovedPart = partInventory[removedPartId]
  local initialRemovedNode = getNodeFromSlotPath(vehicle.config.partsTree, initialRemovedPart.containingSlot)

  local disconnectedParts = getDisconnectedParts(initialRemovedNode, vehicle)
  initialRemovedNode.chosenPartName = ""
  initialRemovedNode.children = {}
  for partId, part in pairs(disconnectedParts) do
    -- remove the part
    vehicle.partConditions[part.partPath] = nil
    partsAfter[partId] = nil
  end
end

local function getPartsThatMoved(partsBefore, partsAfter)
  -- Compare old parts with new parts to see what has changed
  local movedOut = {}
  for partId, _ in pairs(partsBefore) do
    if not partsAfter[partId] then
      movedOut[partId] = true
    end
  end
  return {movedOut = movedOut}
end

local function initConditionsCallback(_, inventoryId)
  local vehObjId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
  local vehicleObj = getObjectByID(vehObjId)
  queueCallbackInVehicle(vehicleObj, "career_modules_partInventory.changedPartsCallback", "partCondition.getConditions()", inventoryId)
end

local function getPartIdsFromVehicle(inventoryId)
  local result = {}
  for partId, part in pairs(partInventory) do
    if part.location == inventoryId then
      result[partId] = true
    end
  end
  return result
end

local function sellParts(partIds)
  local total = 0
  for _, partId in ipairs(partIds) do
    local part = partInventory[partId]
    if not part or part.location ~= 0 then return end
    total = total + career_modules_valueCalculator.getPartValue(part)
  end

  career_modules_playerAttributes.addAttributes({money=total}, {tags={"partsSold","selling"}, label = "Sold " .. #partIds .. " Parts."})
  Engine.Audio.playOnce('AudioGui','event:>UI>Career>Buy_01')
  for _, partId in ipairs(partIds) do
    partInventory[partId] = nil
  end

  if partInventoryOpen then
    M.sendUIData()
  end
end

local function removePart(partId, inventoryId)
  local vehicle = career_modules_inventory.getVehicles()[inventoryId]
  local carModelToLoad = vehicle.model
  local vehicleData = {}
  vehicleData.config = vehicle.config
  vehicleData.keepOtherVehRotation = true
  partsAfter = getPartIdsFromVehicle(inventoryId)
  partsAfter[partId] = nil
  removeDisconnectedParts(vehicle, partId)

  local partConditions = vehicle.partConditions

  local numberOfBrokenParts = career_modules_valueCalculator.getNumberOfBrokenParts(partConditions)
  if numberOfBrokenParts > 0 and numberOfBrokenParts < career_modules_valueCalculator.getBrokenPartsThreshold() then
    career_modules_insurance.repairPartConditions({partConditions = partConditions})
  end

  local vehObjId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
  if vehObjId then
    local vehicleObj = getObjectByID(vehObjId)
    core_vehicle_manager.queueAdditionalVehicleData({spawnWithEngineRunning = false}, vehObjId)
    core_vehicles.replaceVehicle(carModelToLoad, vehicleData, vehicleObj)
    queueCallbackInVehicle(vehicleObj, "career_modules_partInventory.initConditionsCallback", "partCondition.initConditions(" .. serialize(partConditions) .. ")", inventoryId)
  else
    M.changedPartsCallback(partConditions, inventoryId)
  end
  career_modules_inventory.setVehicleDirty(inventoryId)
end

local function addPartFromTree(result, tree, vehicleData, availableParts, vehObj, inventoryId, partConditions)
  if tree.chosenPartName and tree.chosenPartName ~= "" and tree.id ~= "main" then
    local part = {}
    part.name = tree.chosenPartName
    part.value = vehicleData.vdata.activePartsData[vehicleData.vdata.activeParts[tree.partPath]].information.value or 100
    part.description = availableParts[tree.chosenPartName] or "no description found"
    part.partCondition = partConditions[tree.partPath]
    part.tags = {}
    part.vehicleModel = vehObj:getJBeamFilename()
    part.location = inventoryId
    part.containingSlot = tree.path
    part.partPath = part.containingSlot .. part.name

    table.insert(result, part)
  end

  -- Recursively process children if they exist
  if tree.children then
    for childSlot, childInfo in pairs(tree.children) do
      addPartFromTree(result, childInfo, vehicleData, availableParts, vehObj, inventoryId, partConditions)
    end
  end
end

local function generateAndGetPartsFromVehicle(inventoryId)
  local vehicle = career_modules_inventory.getVehicles()[inventoryId]
  local vehObjId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
  local vehObj = getObjectByID(vehObjId)
  local vehicleData = extensions.core_vehicle_manager.getVehicleData(vehObjId)
  local partConditions = vehicle.partConditions
  if not partConditions then return {} end
  local availableParts = jbeamIO.getAvailableParts(vehicleData.ioCtx)

  local result = {}

  -- Start with the root part (usually "main")
  addPartFromTree(result, vehicleData.config.partsTree, vehicleData, availableParts, vehObj, inventoryId, partConditions)

  return result
end

-- TODO maybe also save for each part taken off the subparts that are attached to it
-- option 2: when detaching a part, put all the subparts seperately into the inventory and whenever you attach a part, all it's slots will be made empty

local function movePart(to, partId)
  local part = partInventory[partId]
  if not part then return end

  local from = part.location
  if from == to then return end

  -- we cant change parts of inaccessible vehicles
  local vehicles = career_modules_inventory.getVehicles()
  if vehicles[from] and vehicles[from].timeToAccess then return end

  if from >= 1 then
    if coreSlots[from][part.containingSlot] then return end
  end

  if to >= 1 then return end

  if from >= 1 then
    partsBefore = getPartIdsFromVehicle(from)
    removePart(partId, from)
    career_modules_vehiclePerformance.invalidateCertification(from)
  end

  career_modules_log.addLog(string.format("Moved part %d from %d to %d", partId, from, to), "partInventory")
end

local function updateVehicleMaps()
  -- Build a map of core slots
  table.clear(coreSlots)
  for partId, part in pairs(partInventory) do
    coreSlots[part.location] = coreSlots[part.location] or {}
    if part.description.slotInfoUi then
      for slotName, slotInfo in pairs(part.description.slotInfoUi) do
        if slotInfo.coreSlot then
          coreSlots[part.location][part.containingSlot .. slotName .. "/"] = slotInfo.coreSlot
        end
      end
    end
  end

  -- TODO does this need to be cached?
  -- Make a map from slot to its part
  table.clear(slotToPartIdMap)
  for partId, part in pairs(partInventory) do
    slotToPartIdMap[part.location] = slotToPartIdMap[part.location] or {}
    slotToPartIdMap[part.location][part.containingSlot] = partId
  end
end

-- TODO could even update once every time before removing a part
local function updatePartConditionsInInventory()
  for partId, part in pairs(partInventory) do
    if part.location > 0 and career_modules_inventory.getVehicles()[part.location].partConditions[part.partPath] then
      part.partCondition = career_modules_inventory.getVehicles()[part.location].partConditions[part.partPath]
    end
  end
end

local function addPartToInventory(part)
  local idCounter = 1
  while partInventory[idCounter] do
    idCounter = idCounter + 1
  end
  partInventory[idCounter] = part
end


local function changedPartsCallback(partConditions, inventoryId)
  career_modules_inventory.getPartConditionsCallback(partConditions, inventoryId)
  local partsThatMoved = getPartsThatMoved(partsBefore, partsAfter)
  partsAfter = nil
  local vehicle = career_modules_inventory.getVehicles()[inventoryId]
  for partId, _ in pairs(partsThatMoved.movedOut) do
    local part = partInventory[partId]
    part.location = 0
    vehicle.changedSlots[part.containingSlot] = true
  end
  updateVehicleMaps()
  if partInventoryOpen then
    M.sendUIData()
  end
end

local function addNewPartsToInventory(inventoryId)
  local newParts = generateAndGetPartsFromVehicle(inventoryId)
  for _, part in ipairs(newParts) do
    addPartToInventory(part)
  end
  career_modules_log.addLog(string.format("Added new vehicles' parts to inventory %d", inventoryId), "partInventory")
  return newParts
end

local function debugMenu()
  imgui.SetNextWindowSize(imgui.ImVec2(300, 300), imgui.Cond_FirstUseEver)
  local partInventoryOpenPtr = imgui.BoolPtr(true)
  imgui.Begin("Part Inventory", partInventoryOpenPtr)
  if not partInventoryOpenPtr[0] then
    partInventoryOpen = false
  end
  imgui.BeginChild1("vehiclePartsOuter", imgui.ImVec2(220, 0), imgui.WindowFlags_ChildWindow)
  imgui.Text("Parts in current vehicle")
  imgui.BeginChild1("partsInVehicle", imgui.ImVec2(200, 0), imgui.WindowFlags_ChildWindow)
    for partId, part in pairs(partInventory) do
      if part.location == currentVehicleInventoryIdForMenu then
        local disabled
        if coreSlots[part.location][part.slotType] then
          imgui.BeginDisabled()
          disabled = true
        end
        if part.description.description then
          if imgui.Button(part.description.description .. "##inVehicle") then
            movePart(0, partId)
          end
        end
        if disabled then imgui.EndDisabled() end
      end
    end
  imgui.EndChild()
  imgui.EndChild()
  imgui.SameLine()
  imgui.BeginChild1("inventoryPartsOuter", imgui.ImVec2(0, 0), imgui.WindowFlags_ChildWindow)
  imgui.Text("Parts in inventory")

  if imgui.BeginTable('', 8) then
    imgui.TableSetupScrollFreeze(0,1)
    imgui.TableSetupColumn("Id",nil,5)
    imgui.TableSetupColumn("Name",nil,20)
    imgui.TableSetupColumn("Vehicle Model",nil,10)
    imgui.TableSetupColumn("Description",nil,20)
    imgui.TableSetupColumn("Distance Driven",nil,10)
    imgui.TableSetupColumn("Value",nil,5)
    imgui.TableSetupColumn("Location",nil,5)
    imgui.TableSetupColumn("Put into current vehicle",nil,20)
    imgui.TableHeadersRow()
    imgui.TableNextColumn()
    for partId, part in pairs(partInventory) do
      imgui.Text("" .. partId)
      imgui.TableNextColumn()
      imgui.Text(part.name)
      imgui.TableNextColumn()
      imgui.Text(part.vehicleModel)
      imgui.TableNextColumn()
      imgui.Text(part.description.description or "missing")
      imgui.TableNextColumn()
      imgui.Text("" .. part.partCondition["odometer"])
      imgui.TableNextColumn()
      imgui.Text("" .. part.value)
      imgui.TableNextColumn()
      imgui.Text("" .. part.location)
      imgui.TableNextColumn()
      imgui.TableNextColumn()
    end

    imgui.EndTable()
  end
  imgui.EndChild()
  imgui.End()
end

local updateVehicleParts
local addNewVehiclePartsInventoryId
local function onUpdate()
  -- Add a new vehicles' parts to the inventory
  if addNewVehiclePartsInventoryId and career_modules_inventory.getVehicleIdFromInventoryId(addNewVehiclePartsInventoryId) and career_modules_inventory.getVehicles()[addNewVehiclePartsInventoryId].partConditions then
    local newParts = addNewPartsToInventory(addNewVehiclePartsInventoryId)
    extensions.hook("onAddedVehiclePartsToInventory", addNewVehiclePartsInventoryId, newParts)
    updateVehicleMaps()
    addNewVehiclePartsInventoryId = nil
  end

  -- Update cached maps for the current vehicle
  -- TODO why does this need to be async?
  if updateVehicleParts and (career_modules_inventory.getCurrentVehicle() and career_modules_inventory.getVehicles()[career_modules_inventory.getCurrentVehicle()].partConditions) then
    updateVehicleMaps()
    updateVehicleParts = nil
  end

  if not shipping_build and partInventoryOpen then
    --debugMenu()
  end
end

local function sendUIData()
  local data = {}
  local partList = {}
  local vehicles = career_modules_inventory.getVehicles()
  local vehiclesUiData = {}

  data.brokenVehicleInventoryIds = {}
  for inventoryId, vehicle in pairs(vehicles) do
    data.brokenVehicleInventoryIds[tostring(inventoryId)] = career_modules_insurance.inventoryVehNeedsRepair(inventoryId)

    local vehicleUiData = deepcopy(vehicle)
    vehicleUiData.thumbnail = career_modules_inventory.getVehicleThumbnail(inventoryId) .. "?" .. (vehicleUiData.dirtyDate or "")
    vehiclesUiData[tostring(inventoryId)] = vehicleUiData
  end

  for partId, part in pairs(partInventory) do
    -- TODO find another way to filter out the main part
    --if part.slotType ~= "main" then
      local newPart = deepcopy(part)
      if newPart.location ~= 0 and coreSlots[newPart.location][newPart.containingSlot] then
        newPart.isInCoreSlot = true
      end
      newPart.id = partId
      newPart.finalValue = career_modules_valueCalculator.getPartValue(newPart)
      newPart.accessible = not (vehicles[newPart.location] and
          (vehicles[newPart.location].timeToAccess or
          data.brokenVehicleInventoryIds[newPart.location] or
          not career_modules_permissions.getStatusForTag("partSwapping", {inventoryId = newPart.location}).allow)
        )
      table.insert(partList, newPart)
    --end
  end
  data.partList = partList
  data.currentVehicle = currentVehicleInventoryIdForMenu
  data.vehicles = vehiclesUiData

  guihooks.trigger('partInventoryData', data)
end

local function onVehicleSaveFinished(currentSavePath, oldSaveDate)
  -- TODO use the oldSaveDate
  -- TODO we could split this into multiple files, so that we dont have to rewrite the whole file for each autosave
  -- maybe one file per vehicle
  -- also the vehicle files themselves have some duplicated info like the part condition. we could replace that with references to parts from here

  local partInventoryCopy = deepcopy(partInventory)
  for partId, part in pairs(partInventoryCopy) do
    part.description = nil
  end
  jsonWriteFile(currentSavePath .. "/career/partInventory.json", {serialize(partInventoryCopy)}, true)
end

local function updatePartDescriptionsWithJBeamInfo()
  local jBeamPartInfos = {}
  local vehicleModels = {}

  for partId, part in pairs(partInventory) do
    vehicleModels[part.vehicleModel] = true
  end

  -- TODO if we need this data more often, we can put it in a local table in this file
  for vehicleModel, _ in pairs(vehicleModels) do
    local vehicleDir = string.format("/vehicles/%s/", vehicleModel)
    if FS:directoryExists(vehicleDir) then
      local vehicleFolders = {vehicleDir, "/vehicles/common/"}
      local ioCtx = jbeamIO.startLoading(vehicleFolders)
      jBeamPartInfos[vehicleModel] = jbeamIO.getAvailableParts(ioCtx)
    end
  end

  for partId, part in pairs(partInventory) do
    local partInfosVehicleModel = jBeamPartInfos[part.vehicleModel]
    if not partInfosVehicleModel then
      part.description = {}
      part.missingFile = true
    elseif partInfosVehicleModel[part.name] then
      part.description = partInfosVehicleModel[part.name]
    else
      part.description = {}
      part.missingFile = true
    end
  end
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  local saveInfo = savePath and jsonReadFile(savePath .. "/info.json")
  local outdated = not saveInfo or saveInfo.version < minimumVersion

  local jsonData = savePath and jsonReadFile(savePath .. "/career/partInventory.json")
  if jsonData and not outdated then
    partInventory = deserialize(jsonData[1])

    -- Not needed right now, because we sell all parts anyway
    --[[ if saveInfo.version < 43 then
      -- Update older versions to use "slotType" instead of "slot"
      for partId, part in pairs(partInventory) do
        part.slotType = part.slot
        part.slot = nil
      end
    end ]]

    if saveInfo.version < career_saveSystem.getSaveSystemVersion() then
      -- Sell all parts that are not in a vehicle
      local partsToSell = {}
      for partId, part in pairs(partInventory) do
        if part.location == 0 then
          table.insert(partsToSell, partId)
        end
      end
      sellParts(partsToSell)
    end
  else
    partInventory = {}
  end
  updatePartDescriptionsWithJBeamInfo()
  updateVehicleMaps()
end

local function onEnterVehicleFinished(currentVehicle)
  if not currentVehicle then return end

  -- Update the cached vehicle maps when entering a new vehicle
  updateVehicleParts = true
end

local function onPartShoppingTransactionComplete()
  updateVehicleMaps()
end

local function onVehicleAdded(inventoryId)
  addNewVehiclePartsInventoryId = inventoryId
end

local function onVehicleRemoved(inventoryId)
  local partsToRemove = {}
  for partId, part in pairs(partInventory) do
    if part.location == inventoryId then
      partsToRemove[partId] = true
    end
  end

  for partId, _ in pairs(partsToRemove) do
    partInventory[partId] = nil
  end
end

local function getPart(inventoryId, path)
  for partId, part in pairs(partInventory) do
    if part.location == inventoryId and part.containingSlot == path then
      return part
    end
  end
end

local function removePartWithSlot(inventoryId, slot)
  for partId, part in pairs(partInventory) do
    if part.location == inventoryId and part.containingSlot == slot then
      partInventory[partId] = nil
      return part
    end
  end
end

local originComputerId
local function openMenu(_originComputerId)
  partInventoryOpen = true
  currentVehicleInventoryIdForMenu = career_modules_inventory.getCurrentVehicle()
  if not currentVehicleInventoryIdForMenu then
    currentVehicleInventoryIdForMenu = career_modules_inventory.getInventoryIdsInClosestGarage(true)
  end

  originComputerId = _originComputerId

  if currentVehicleInventoryIdForMenu then
    career_modules_inventory.updatePartConditions(nil, currentVehicleInventoryIdForMenu, function() guihooks.trigger('ChangeState', {state = 'partInventory', params = {}}) end)
  else
    guihooks.trigger('ChangeState', {state = 'partInventory', params = {}})
  end
end

local function closeMenuActual()
  if originComputerId then
    local computer = freeroam_facilities.getFacility("computer", originComputerId)
    career_modules_computer.openMenu(computer)
  else
    career_career.closeAllMenus()
  end
end

local function closeMenu()
  local dirtyVehicles = career_modules_inventory.getDirtiedVehicles()
  if career_career.isAutosaveEnabled() and dirtyVehicles and next(dirtyVehicles) then
    local dirtyVehiclesList = {}
    for invId, _ in pairs(dirtyVehicles) do
      table.insert(dirtyVehiclesList, invId)
    end
    closeMenuAfterSaving = true
    career_saveSystem.saveCurrent(dirtyVehiclesList)
    return
  end

  closeMenuActual()
end

local function onSaveFinished()
  if closeMenuAfterSaving then
    closeMenuActual()
    closeMenuAfterSaving = nil
  end
end

local function partInventoryClosed()
  partInventoryOpen = false
end

local function getSlotToPartIdMap()
  return slotToPartIdMap
end

local function getInventory()
  return partInventory
end

local function onComputerAddFunctions(menuData, computerFunctions)
  if not menuData.computerFacility.functions["partInventory"] then return end

  local computerFunctionData = {
    id = "partInventory",
    label = "My Parts",
    callback = function() openMenu(menuData.computerFacility.id) end,
    order = 5
  }
  if menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive then
    computerFunctionData.disabled = true
    computerFunctionData.reason = career_modules_computer.reasons.tutorialActive
  end
  computerFunctions.general[computerFunctionData.id] = computerFunctionData
end

M.generateAndGetPartsFromVehicle = generateAndGetPartsFromVehicle
M.movePart = movePart
M.changedPartsCallback = changedPartsCallback
M.initConditionsCallback = initConditionsCallback
M.sendUIData = sendUIData
M.openMenu = openMenu
M.closeMenu = closeMenu
M.partInventoryClosed = partInventoryClosed
M.getSlotToPartIdMap = getSlotToPartIdMap
M.getInventory = getInventory
M.addPartToInventory = addPartToInventory
M.getPart = getPart
M.updatePartConditionsInInventory = updatePartConditionsInInventory
M.sellParts = sellParts
M.removePartWithSlot = removePartWithSlot

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onVehicleSaveFinished = onVehicleSaveFinished
M.onSaveFinished = onSaveFinished
M.onEnterVehicleFinished = onEnterVehicleFinished
M.onVehicleAdded = onVehicleAdded
M.onVehicleRemoved = onVehicleRemoved
M.onComputerAddFunctions = onComputerAddFunctions
M.onPartShoppingTransactionComplete = onPartShoppingTransactionComplete

return M