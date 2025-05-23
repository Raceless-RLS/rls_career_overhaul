-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')
local jbeamSlotSystem = require('jbeam/slotSystem')

local salesTax = 0.07

local shoppingSessionActive = false
local initialVehicle
local previewVehicle
local shoppingCart

local partsInShop = {}
local currentVehicle
local partShopId = 0
local slotToPartIdMap
local slotsNiceName = {}
local partsNiceName = {}
local engineRunning
local previewVehicleSlotData = {}

local tutorialPartNames = {cargo_load_box_M_seat_load_R = true}

local tether -- tether object for aborting shopping when walking too far away

-- TODO it needs to be decided, which parts come with their own subparts when you buy them and which parts you can use the existing subparts of the vehicle for
-- for now, i will assume that parts come with default subparts, except when a fitting part is already in the vehicle

local function openUIState()
  -- TODO we send all data every time a part changes. we should send only smaller updates
  guihooks.trigger('ChangeState', {state = 'partShopping', params = {}})
end

local function flattenPartsTree(tree)
  local result = {}

  if tree.chosenPartName then
    result[tree.path] = tree.chosenPartName
  end

  if tree.children then
    for slotName, childNode in pairs(tree.children) do
      tableMerge(result, flattenPartsTree(childNode))
    end
  end

  return result
end

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

local function getCurrentVehicleVehId()
  if not currentVehicle then return end
  local vehId = career_modules_inventory.getVehicleIdFromInventoryId(currentVehicle)
  return vehId
end

local function getCurrentVehicleObj()
  if not currentVehicle then return end
  return getObjectByID(getCurrentVehicleVehId())
end

local function generatePart(partName, currentVehicleData, availableParts, path, slot, vehicleObj)
  local jbeamData = jbeamIO.getPart(currentVehicleData.ioCtx, partName)
  if not jbeamData then return end

  local part = {}
  part.name = partName
  part.value = jbeamData.information.value or 100
  part.partCondition = {integrityValue = 1, odometer = 0, visualValue = 1}
  part.description = availableParts[partName] or "no description found"
  part.tags = {}
  part.containingSlot = path
  part.partPath = path .. partName
  part.slot = slot
  --part.slotType = jbeamData.slotType
  part.vehicleModel = vehicleObj:getJBeamFilename()
  part.year = 2023
  part.partShopId = partShopId
  partShopId = partShopId + 1

  part.finalValue = math.max(roundNear(career_modules_valueCalculator.getPartValue(part), 5) - 0.01, 0)
  return part
end

local function getPartSlotFromPartIdInShoppingCart(partId)
  for _, part in pairs(shoppingCart.partsIn) do
    if part.partId == partId then
      return part.containingSlot
    end
  end
end

local function generatePartFromTree(treeNode, slotName, slotInfo, currentVehicleData, availableParts, vehicleObj)
  if not treeNode then return end

  local partInfo = availableParts[treeNode.chosenPartName]
  previewVehicleSlotData[treeNode.path] = slotInfo

  treeNode.chosenPartNiceName = partInfo and partInfo.description
  treeNode.slotNiceName = slotsNiceName[slotName]
  treeNode.slotName = slotName

  partsNiceName[treeNode.chosenPartName] = treeNode.chosenPartNiceName

  if treeNode.suitablePartNames then
    for _, suitablePartName in ipairs(treeNode.suitablePartNames) do
      local part = generatePart(suitablePartName, currentVehicleData, availableParts, treeNode.path, slotName, vehicleObj)
      if part.containingSlot ~= "main" and not part.description.isAuxiliary then
        table.insert(partsInShop, part)

        -- Add matching parts from inventory
        for partId, inventoryPart in pairs(career_modules_partInventory.getInventory()) do
          local partSlotOfThisPartInShoppingCart = getPartSlotFromPartIdInShoppingCart(partId)
          if inventoryPart.name == suitablePartName and inventoryPart.location == 0 and inventoryPart.vehicleModel == part.vehicleModel and (not partSlotOfThisPartInShoppingCart or partSlotOfThisPartInShoppingCart == part.containingSlot) then
            local shopPart = deepcopy(inventoryPart)
            shopPart.containingSlot = part.containingSlot
            shopPart.partPath = part.partPath
            shopPart.slot = slotName
            shopPart.vehicleModel = part.vehicleModel
            shopPart.partId = partId
            shopPart.partShopId = partShopId
            partShopId = partShopId + 1
            shopPart.finalValue = 0
            table.insert(partsInShop, shopPart)
          end
        end
      end
    end
  end

  if slotInfo and not slotInfo.coreSlot and initialVehicle.partList[treeNode.path] and initialVehicle.partList[treeNode.path] ~= "" then
    local emptyPart = {}
    emptyPart.name = "empty"
    emptyPart.description = {}
    emptyPart.description.description = "Remove " .. partsNiceName[initialVehicle.partList[treeNode.path]]
    emptyPart.emptyPlaceholder = true
    emptyPart.containingSlot = treeNode.path
    emptyPart.partPath = treeNode.path .. "empty"
    emptyPart.slot = slotName
    emptyPart.slotNiceName = slotsNiceName[slotName]
    emptyPart.partShopId = partShopId
    emptyPart.finalValue = 0
    partShopId = partShopId + 1
    table.insert(partsInShop, emptyPart)
  end

  -- Recursively process child slots
  if treeNode.children then
    for childSlot, childNode in pairs(treeNode.children) do
      generatePartFromTree(childNode, childSlot, partInfo.slotInfoUi[childSlot], currentVehicleData, availableParts, vehicleObj)
    end
  end
end

local function generatePartShop()
  local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())
  local availableParts = jbeamIO.getAvailableParts(currentVehicleData.ioCtx)
  local vehicleObj = getCurrentVehicleObj()
  previewVehicleSlotData = {}

  for partName, partInfo in pairs(availableParts) do
    if partInfo.slotInfoUi then
      for slotName, slotInfo in pairs(partInfo.slotInfoUi) do
        slotsNiceName[slotName] = slotInfo.description
      end
    end
  end

  partsInShop = {}
  local chosenPartsTree = deepcopy(currentVehicleData.config.partsTree)
  generatePartFromTree(chosenPartsTree, "", nil, currentVehicleData, availableParts, vehicleObj)

  return chosenPartsTree
end

local function buildSearchSlotList(partTree)
  local searchSlotDict = {}

  -- Helper function to traverse the part tree
  local function traverseTree(node, slotName)
    if not node then return end

    if slotName then
      -- Build nice path by walking up the tree
      local pathSegments = {}
      local currentPath = node.path

      -- Split path into segments and process each one
      for segment in currentPath:gmatch("([^/]+)/") do
        table.insert(pathSegments, slotsNiceName[segment] or segment)
      end

      -- Add slot data for current node
      local slotData = {
        slotName = slotName,
        slotNiceName = slotsNiceName[slotName],
        path = node.path,
        nicePath = table.concat(pathSegments, " > "),
        partNiceName = partsNiceName[node.chosenPartName]
      }
      searchSlotDict[node.path] = slotData
    end

    -- Recursively process children
    if node.children then
      for childSlot, childNode in pairs(node.children) do
        traverseTree(childNode, childSlot)
      end
    end
  end

  -- Start traversal from root
  traverseTree(partTree)

  -- Convert dict to sorted list
  local searchSlotList = {}
  for path, slotInfo in pairs(searchSlotDict) do
    table.insert(searchSlotList, slotInfo)
  end
  table.sort(searchSlotList, function(a,b) return a.slotNiceName < b.slotNiceName end)
  return searchSlotList
end

local function updateShoppingCart()
  shoppingCart.total = 0
  shoppingCart.partsInList = {}
  shoppingCart.partsOutList = {}
  shoppingCart.partsOut = {}
  shoppingCart.slotList = {}

  for path, part in pairs(shoppingCart.partsIn) do
    shoppingCart.partsOut[path] = career_modules_partInventory.getInventory()[slotToPartIdMap[currentVehicle][path]]
  end
  for path, partName in pairs(initialVehicle.partList) do
    if partName ~= "" and (not previewVehicle.partList[path] or previewVehicle.partList[path] == "") then
      shoppingCart.partsOut[path] = career_modules_partInventory.getInventory()[slotToPartIdMap[currentVehicle][path]]
    end
  end

  local partPaths = {}

  for partId, part in pairs(shoppingCart.partsIn) do
    table.insert(partPaths, part.partPath)
  end

  -- Convert the partsIn/partsOut tables to lists
  local slotsAdded = {}
  local counter = 1
  for slot, part in pairs(shoppingCart.partsIn) do
    shoppingCart.slotList[counter] = slot
    shoppingCart.partsInList[counter] = part
    shoppingCart.partsOutList[counter] = shoppingCart.partsOut[part.containingSlot]
    slotsAdded[part.containingSlot] = true
    counter = counter + 1
  end

  for slot, part in pairs(shoppingCart.partsOut) do
    if not slotsAdded[part.containingSlot] then
      shoppingCart.slotList[counter] = slot
      shoppingCart.partsOutList[counter] = part
      slotsAdded[part.containingSlot] = true
      counter = counter + 1
    end
  end

  -- Calculate the total price of the whole shopping cart
  local total = 0
  for slot, part in pairs(shoppingCart.partsIn) do
    total = total + part.finalValue
  end

  shoppingCart.taxes = total * salesTax
  shoppingCart.total = total + shoppingCart.taxes
end

local function sendShoppingDataToUI()
  local partTree = generatePartShop()
  local shoppingData = {}
  shoppingData.partsInShop = partsInShop
  shoppingData.partTree = partTree
  shoppingData.shoppingCart = shoppingCart
  shoppingData.slotsNiceName = slotsNiceName
  shoppingData.searchSlotList = buildSearchSlotList(partTree)
  shoppingData.vehicleSlotToPartMap = {}
  for partId, part in pairs(career_modules_partInventory.getInventory()) do
    if part.location == currentVehicle then
      shoppingData.vehicleSlotToPartMap[part.containingSlot] = part
    end
  end
  if not career_modules_linearTutorial.getTutorialFlag("partShoppingComplete") then
    shoppingData.tutorialPartNames = tutorialPartNames
  end

  shoppingData.playerMoney = career_modules_playerAttributes.getAttributeValue("money")
  guihooks.trigger("partShoppingData", shoppingData)
end

local function updatePreviewVehicle(currentPartConditions)
  -- get the data
  local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())
  if not currentVehicleData then
    log('E', 'inventory', 'unable to get vehicle data')
    return false
  end
  if not currentVehicle then return end

  previewVehicle.config.partsTree = deepcopy(currentVehicleData.config.partsTree)
  previewVehicle.partList = flattenPartsTree(previewVehicle.config.partsTree)
  if currentPartConditions then
    previewVehicle.partConditions = currentPartConditions
  end
  updateShoppingCart()
  sendShoppingDataToUI()
  core_vehicleBridge.executeAction(getObjectByID(career_modules_inventory.getVehicleIdFromInventoryId(previewVehicle.id)),'setFreeze', true)
end

local originComputerId
local function startShoppingActual(_originComputerId)
  local vehicles = career_modules_inventory.getVehicles()
  shoppingCart = {partsIn = {}, partsOut = {}, total = 0, partsInList = {}, partsOutList = {}, slotList = {}}
  partsNiceName = {}
  shoppingSessionActive = true
  slotToPartIdMap = deepcopy(career_modules_partInventory.getSlotToPartIdMap())

  initialVehicle = deepcopy(vehicles[currentVehicle])
  initialVehicle.partList = flattenPartsTree(initialVehicle.config.partsTree)

  -- Fill partsNiceName with initial vehicle parts
  local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())
  local availableParts = jbeamIO.getAvailableParts(currentVehicleData.ioCtx)
  for _, partName in pairs(initialVehicle.partList) do
    if partName and partName ~= "" then
      local partInfo = availableParts[partName]
      if partInfo then
        partsNiceName[partName] = partInfo.description
      end
    end
  end

  previewVehicle = deepcopy(initialVehicle)

  partShopId = 0
  generatePartShop()
  originComputerId = _originComputerId

  M.setupTether()

  openUIState()

  if gameplay_walk.isWalking() then
    gameplay_walk.setRot(getCurrentVehicleObj():getPosition() - getPlayerVehicle(0):getPosition())
  end

  core_vehicleBridge.requestValue(getCurrentVehicleObj(), function(data) engineRunning = data.result > 1 end, 'electricsValue', 'ignitionLevel')

  core_vehicleBridge.executeAction(getObjectByID(career_modules_inventory.getVehicleIdFromInventoryId(previewVehicle.id)),'setFreeze', true)
  extensions.hook("onPartShoppingStarted")
end

local function setupTether()
    -- calculate the size of the vehicle to use for tethering
  local oobb = getCurrentVehicleObj():getSpawnWorldOOBB()
  local vehCenter = oobb:getCenter()
  local vehRadius = (oobb:getPoint(0) - oobb:getPoint(6)):length()
  -- calculate computer position
  local computerPos = freeroam_facilities.getAverageDoorPositionForFacility(freeroam_facilities.getFacility("computer",originComputerId))

  local distBetweenVehicleAndComputer = (computerPos-vehCenter):length()
  -- this smoothly scales the radius from 100% for 4m or less distance to 150% for 12m or more radius
  local radiusMultipler = ((clamp(distBetweenVehicleAndComputer,4,12)-4)/16 + 1)
  -- these radii are tuned for the wcusa garage!
  tether = career_modules_tether.startCapsuleTetherBetweenStatics(computerPos, 10*radiusMultipler, vehCenter, vehRadius + (9*radiusMultipler), M.cancelShopping)
end

local function startShopping(inventoryId, _originComputerId)
  currentVehicle = inventoryId or career_modules_inventory.getCurrentVehicle()
  if not currentVehicle then
    currentVehicle = career_modules_inventory.getInventoryIdsInClosestGarage(true)
  end
  if not currentVehicle then return end

  local numberOfBrokenParts = career_modules_valueCalculator.getNumberOfBrokenParts(career_modules_inventory.getVehicles()[currentVehicle].partConditions)
  if numberOfBrokenParts > 0 and numberOfBrokenParts < career_modules_valueCalculator.getBrokenPartsThreshold() then
    career_modules_insurance.startRepair(currentVehicle, nil, function() startShoppingActual(_originComputerId) end)
  elseif numberOfBrokenParts > 0 then
    core_jobsystem.create(function(job)
      career_modules_damageManager.saveDamageState(currentVehicle)
      startShoppingActual(_originComputerId)
    end, 2)
  else
    startShoppingActual(_originComputerId)
  end
end

local function getDefaultPartName(jbeamData, slotName)
  for _, slot in ipairs(jbeamData.slots2) do
    if slot.name == slotName and slot.default and slot.default ~= "" then return slot.default end
  end
end

-- TODO unfinished
local function getFittingPartFromInventory(parentPart, slotName)
  -- Add matching parts from inventory
  for partId, inventoryPart in pairs(career_modules_partInventory.getInventory()) do
    local partSlotOfThisPartInShoppingCart = getPartSlotFromPartIdInShoppingCart(partId)
    if inventoryPart.location == 0 and inventoryPart.vehicleModel == parentPart.vehicleModel and (not partSlotOfThisPartInShoppingCart or partSlotOfThisPartInShoppingCart == parentPart.containingSlot) then
      local shopPart = deepcopy(inventoryPart)
      shopPart.containingSlot = parentPart.containingSlot
      shopPart.partPath = parentPart.partPath
      shopPart.slot = slotName
      shopPart.vehicleModel = parentPart.vehicleModel
      shopPart.partId = partId
      shopPart.partShopId = partShopId
      partShopId = partShopId + 1
      shopPart.finalValue = 0
      return shopPart
    end
  end
end

local function getNeededAdditionalParts(parts, inventoryId)
  local vehId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
  local vehicleObj = getObjectByID(vehId)
  local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())
  local availableParts = jbeamIO.getAvailableParts(currentVehicleData.ioCtx)

  -- Make a map from slot to its part for the parts which were already in the vehicle and the parts which we want to add
  local combinedSlotToPartMap = {}
  for containingSlot, partId in pairs(slotToPartIdMap[inventoryId]) do
    combinedSlotToPartMap[containingSlot] = deepcopy(career_modules_partInventory.getInventory()[partId])
  end
  for _, part in pairs(parts) do
    combinedSlotToPartMap[part.containingSlot] = deepcopy(part)
  end

  for path, part in pairs(combinedSlotToPartMap) do
    local jbeamData = jbeamIO.getPart(currentVehicleData.ioCtx, part.name)
    part.slotType = jbeamData.slotType
  end

  -- add the default part if the slot is empty and they have a default part
  local addedParts = false
  local resultParts = deepcopy(parts)
  for _, part in pairs(parts) do
    if part.description.slotInfoUi then
      for slotName, slotInfo in pairs(part.description.slotInfoUi) do
        local path = part.containingSlot .. slotName .. "/"
        if not combinedSlotToPartMap[path] or not jbeamSlotSystem.partFitsSlot(combinedSlotToPartMap[path], slotInfo) then -- found an empty slot
          local jbeamData = jbeamIO.getPart(currentVehicleData.ioCtx, part.name)

          -- look for a fitting part from the inventory
          --getFittingPartFromInventory(part, slotName)

          local partNameToGenerate = getDefaultPartName(jbeamData, slotName)

          if partNameToGenerate then -- found a default part name
            local newGeneratedPart = generatePart(partNameToGenerate, currentVehicleData, availableParts, path, slotName, vehicleObj)

            if newGeneratedPart then -- the default part exists in the jbeam
              resultParts[newGeneratedPart.containingSlot] = newGeneratedPart
              addedParts = true
              if not slotInfo.coreSlot then
                newGeneratedPart.sourcePart = true
              end
            end
          end
        end
      end
    end
  end
  return resultParts, addedParts
end

-- TODO refactor for new parts system
local function findIncompatiblePartsInShoppingCartRec(partName, availableParts, node, vehicleParts, ioCtx)
  if not node or not node.children then return end

  -- Traverse through the vehicle parts tree
  for slotName, childNode in pairs(node.children) do
    local subPartName = childNode.chosenPartName

    if vehicleParts[childNode.path] then
      local description = availableParts[partName]
      local slotInfo = description and description.slotInfoUi and description.slotInfoUi[slotName]
      local subPart = jbeamIO.getPart(ioCtx, subPartName)

      if (shoppingCart.partsIn[childNode.path] and shoppingCart.partsIn[childNode.path].emptyPlaceholder) then
        -- This is an intentionally empty slot, so all child parts are incompatible
        vehicleParts[childNode.path] = nil
      elseif subPartName and subPartName ~= "" and (slotInfo and (jbeamSlotSystem.partFitsSlot(subPart, slotInfo))) then
        vehicleParts[childNode.path] = nil
        findIncompatiblePartsInShoppingCartRec(subPartName, availableParts, childNode, vehicleParts, ioCtx)
      end
    end
  end
end

-- TODO this returns "main"
local function findIncompatiblePartsInShoppingCart()
  local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())
  local availableParts = jbeamIO.getAvailableParts(currentVehicleData.ioCtx)

  local mainPartName = jbeamIO.getMainPartName(currentVehicleData.ioCtx)
  local vehiclePartsTree = deepcopy(previewVehicle.config.partsTree)
  local vehicleParts = flattenPartsTree(vehiclePartsTree)

  for path, part in pairs(vehicleParts) do
    -- Remove the root part
    if (path == "/") then
      vehicleParts[path] = nil
    end
  end

  -- Remove all parts of the "vehicleParts" list that are in the vehicle correctly. Then only the incorrect ones will remain
  findIncompatiblePartsInShoppingCartRec(mainPartName, availableParts, vehiclePartsTree, vehicleParts, currentVehicleData.ioCtx)
  return vehicleParts
end

-- fill the preview vehicle with the initial parts
local function fillWithInitialParts(containingSlot, currentVehicleData)
  local node = getNodeFromSlotPath(previewVehicle.config.partsTree, containingSlot)
  local initialVehicleNode = getNodeFromSlotPath(initialVehicle.config.partsTree, containingSlot)
  if initialVehicleNode and initialVehicleNode.chosenPartName and initialVehicleNode.chosenPartName ~= "" then
    node.chosenPartName = initialVehicleNode.chosenPartName
    previewVehicle.partConditions[initialVehicleNode.partPath] = initialVehicle.partConditions[initialVehicleNode.partPath]
    for _, slot in ipairs(initialVehicleNode.children or {}) do
      fillWithInitialParts(slot.path, currentVehicleData)
    end
  else
    node.chosenPartName = ""
  end
end

local function fillEmptySlotsWithInitialParts(initialNode, previewNode)
  if not initialNode or not previewNode then return end

  -- Fill current node if empty
  if previewNode.chosenPartName == "" and initialNode.chosenPartName and initialNode.chosenPartName ~= "" and not previewNode.emptyPlaceholder then
    previewNode.chosenPartName = initialNode.chosenPartName
    previewVehicle.partConditions[initialNode.partPath] = initialVehicle.partConditions[initialNode.partPath]
  end

  -- Recursively process children
  if initialNode.children then
    for slotName, initialChildNode in pairs(initialNode.children) do
      -- Create preview child node if it doesn't exist
      if not previewNode.children then previewNode.children = {} end
      if not previewNode.children[slotName] then
        previewNode.children[slotName] = {
          chosenPartName = "",
          children = {},
          suitablePartNames = {initialChildNode.chosenPartName},
          unsuitablePartNames = {},
          decisionMethod = "user"
        }
      end

      -- Recurse into child nodes
      fillEmptySlotsWithInitialParts(
        initialChildNode,
        previewNode.children[slotName]
      )
    end
  end
end

local function updateInstalledParts(addedParts, removedParts)
  if not shoppingSessionActive then return end


  if addedParts then
    local firstPart = next(addedParts)
    if firstPart and not addedParts[firstPart].emptyPlaceholder then
      local werePartsAdded
      repeat
        addedParts, werePartsAdded = getNeededAdditionalParts(addedParts, currentVehicle)
        for path, part in pairs(addedParts) do
          local node = getNodeFromSlotPath(previewVehicle.config.partsTree, part.containingSlot)
          if node then
            node.chosenPartName = part.name
          else
            -- Get the parent path by removing everything after the second-to-last "/"
            local parentPath = part.containingSlot:match("(.+)/[^/]+/$") or "/"
            local parentNode = getNodeFromSlotPath(previewVehicle.config.partsTree, parentPath)
            if parentNode then
              parentNode.children = parentNode.children or {}
              parentNode.children[part.slot] = {chosenPartName = part.name, path = parentNode.path .. part.slot .. "/", children = {}, suitablePartNames = {part.name}, unsuitablePartNames = {}, decisionMethod = "user"}
            end
          end
        end
      until not werePartsAdded
    end
    tableMerge(shoppingCart.partsIn, addedParts)
  end

  if removedParts then
    local currentVehicleData = extensions.core_vehicle_manager.getVehicleData(getCurrentVehicleVehId())

    for containingSlot, part in pairs(removedParts) do
      -- If there was another part in the slot before, put the initial part back in, otherwise leave the slot empty
      local initialPartName = initialVehicle.partList[containingSlot]
      local initialPart = jbeamIO.getPart(currentVehicleData.ioCtx, initialPartName)

      if initialPartName and initialPartName ~= "" and jbeamSlotSystem.partFitsSlot(initialPart, previewVehicleSlotData[containingSlot]) then
        fillWithInitialParts(containingSlot, currentVehicleData)
      else
        local node = getNodeFromSlotPath(previewVehicle.config.partsTree, containingSlot)
        if node then node.chosenPartName = "" end
      end
      shoppingCart.partsIn[containingSlot] = nil
    end
  end

  -- Add new parts to preview vehicle data
  for _, part in pairs(shoppingCart.partsIn) do
    local node = getNodeFromSlotPath(previewVehicle.config.partsTree, part.containingSlot)
    if node then
      if part.emptyPlaceholder then
        -- this means the slot is intentionally empty
        node.chosenPartName = ""
        node.emptyPlaceholder = true
      else
        node.chosenPartName = part.name
      end
    end
  end

  local partPaths = {}
  local partsToRemove = {}

  for path, part in pairs(shoppingCart.partsIn) do
    if part.emptyPlaceholder then
      table.insert(partsToRemove, path)
    else
      table.insert(partPaths, path)
    end
  end

  -- Find and remove parts from the shopping cart that are not compatible anymore after the installed parts have changed
  local incompatibleParts = findIncompatiblePartsInShoppingCart()
  for slot, partName in pairs(incompatibleParts) do
    print('incompatible part: ' .. slot .. ' ' .. partName)
    shoppingCart.partsIn[slot] = nil
    local node = getNodeFromSlotPath(previewVehicle.config.partsTree, slot)
    if node then node.chosenPartName = "" end
  end

  -- Fill the empty slots with initial vehicle parts using both methods
  fillEmptySlotsWithInitialParts(initialVehicle.config.partsTree, previewVehicle.config.partsTree)

  -- Add the partCondition of the new parts to the previewVehicle
  for _, part in pairs(shoppingCart.partsIn) do
    previewVehicle.partConditions[part.partPath] = part.partCondition
  end

  if not engineRunning then
    local additionalVehicleData = {spawnWithEngineRunning = false}
    core_vehicle_manager.queueAdditionalVehicleData(additionalVehicleData, getCurrentVehicleObj():getID())
  end

  local spawnOptions = {}
  spawnOptions.config = previewVehicle.config
  spawnOptions.keepOtherVehRotation = true


  core_vehicles.replaceVehicle(previewVehicle.model, spawnOptions, getCurrentVehicleObj())
  core_vehicleBridge.executeAction(getCurrentVehicleObj(), 'initPartConditions', previewVehicle.partConditions, nil, nil, nil, career_modules_painting.getPrimerColor())

  dump(partPaths)
  dump(partsToRemove)

  career_modules_damageManager.repairPartsAndReloadState(currentVehicle, partPaths, partsToRemove)

  -- Doing the callback immediately will result in wrong values for some parts, so we do it one frame later
  core_vehicleBridge.requestValue(getCurrentVehicleObj(),
  function()
    queueCallbackInVehicle(getCurrentVehicleObj(), "career_modules_partShopping.updatePreviewVehicle", "partCondition.getConditions()")
  end
  , 'ping')
end

local function removePart(part)
  if not shoppingSessionActive then return end
  local removedParts = {}
  removedParts[part.containingSlot] = part
  updateInstalledParts(nil, removedParts)
end

local function installPart(part)
  if not shoppingSessionActive then return end

  -- only make this a sourcePart if it is not in a core slot or if the initial vehicle has a part in that slot
  -- this way we make sure that a core slot can never be empty
  if not previewVehicleSlotData[part.containingSlot].coreSlot or initialVehicle.partList[part.containingSlot] and initialVehicle.partList[part.containingSlot] ~= "" then
    part.sourcePart = true
  end
  local newParts = {}
  newParts[part.containingSlot] = part
  updateInstalledParts(newParts)

  extensions.hook("onPartShoppingPartInstalled", {part = part})
end

local function installPartByPartShopId(partShopId)
  for _, part in ipairs(partsInShop) do
    if part.partShopId == partShopId then
      installPart(part)
      return
    end
  end
end

local function removePartBySlot(slot)
  for _, part in pairs(shoppingCart.partsIn) do
    if part.containingSlot == slot then
      removePart(part)
      return
    end
  end
end

local closeMenuAfterSaving
local function closeMenu()
  if originComputerId then
    local computer = freeroam_facilities.getFacility("computer", originComputerId)
    career_modules_computer.openMenu(computer)
  else
    career_career.closeAllMenus()
  end
  if tether then
    tether.remove = true
    tether = nil
  end
end

local function endShopping(_closeMenuAfterSaving)
  closeMenuAfterSaving = career_career.isAutosaveEnabled() and _closeMenuAfterSaving
  shoppingSessionActive = false
  if not closeMenuAfterSaving then
    closeMenu()
  end
end

local function cancelShopping()
  if shoppingSessionActive then
    career_modules_inventory.spawnVehicle(currentVehicle, 2)
    endShopping()
  end
end

local function onVehicleSaveFinished()
  if closeMenuAfterSaving then
    closeMenu()
    closeMenuAfterSaving = nil
  end
end

local function updateInventory()
  local vehicle = career_modules_inventory.getVehicles()[currentVehicle]
  for slot, part in pairs(shoppingCart.partsOut) do
    part.location = 0
    vehicle.changedSlots[slot] = true
  end

  vehicle.partList = nil

  for slot, part in pairs(shoppingCart.partsIn) do
    if part.emptyPlaceholder then
      goto continue
    end
    local partId = part.partId
    local partComesFromInventory = part.partId ~= nil
    part.location = currentVehicle
    part.partShopId = nil
    part.sourcePart = nil
    part.finalValue = nil
    part.partId = nil
    vehicle.changedSlots[slot] = true
    if partComesFromInventory then
      career_modules_partInventory.getInventory()[partId] = part
    else
      career_modules_partInventory.addPartToInventory(part)
    end
    ::continue::
  end
end

local function getBuyingLabel()
  local text = "Bought new parts: "
  for i=1,tableSize(shoppingCart.partsInList) - 1 do
    local part = shoppingCart.partsInList[i]
    text = text .. part.description.description .. ", "
  end
  local part = shoppingCart.partsInList[tableSize(shoppingCart.partsInList)]
  text = text .. part.description.description
  return text
end

local function applyShopping()
  if career_modules_playerAttributes.getAttributeValue("money") < shoppingCart.total then return end

  local vehicles = career_modules_inventory.getVehicles()
  vehicles[currentVehicle] = previewVehicle
  career_modules_vehiclePerformance.invalidateCertification(currentVehicle)
  updateInventory()
  endShopping(true)
  local buyingLabel = getBuyingLabel()
  career_modules_playerAttributes.addAttributes({money=-shoppingCart.total}, {tags={"partsBought", "buying"},label=buyingLabel})
  if career_career.isAutosaveEnabled() then
    career_saveSystem.saveCurrent({currentVehicle})
  else
    career_modules_inventory.updatePartConditions(nil, currentVehicle)
  end

  if not career_modules_linearTutorial.getTutorialFlag("partShoppingComplete") then
    career_career.closeAllMenus()
  end

  Engine.Audio.playOnce('AudioGui','event:>UI>Career>Buy_01')
  core_vehicleBridge.executeAction(getObjectByID(career_modules_inventory.getVehicleIdFromInventoryId(previewVehicle.id)),'setFreeze', false)
  extensions.hook("onPartShoppingTransactionComplete")
end

local function isShoppingSessionActive()
  return shoppingSessionActive
end

local function getPartsInShop()
  return partsInShop
end

local function getShoppingCart()
  return shoppingCart
end

local function onComputerAddFunctions(menuData, computerFunctions)
  if not menuData.computerFacility.functions["partShop"] then return end

  for _, vehicleData in ipairs(menuData.vehiclesInGarage) do
    local inventoryId = vehicleData.inventoryId
    local computerFunctionData = {
      id = "partShop",
      label = "Part Customization",
      callback = function() startShopping(inventoryId, menuData.computerFacility.id) end,
      order = 1
    }
    -- vehicle broken
    if vehicleData.needsRepair then
      computerFunctionData.label = "Part Customization (Experimental)"
    end
    -- tutorial active
    if menuData.tutorialTuningActive then
      computerFunctionData.disabled = true
      computerFunctionData.reason = career_modules_computer.reasons.tutorialActive
    end

    -- generic gameplay reason
    local reason = career_modules_permissions.getStatusForTag({"partBuying", "vehicleModification"}, {inventoryId = inventoryId})
    if not reason.allow then
      computerFunctionData.disabled = true
    end
    if reason.permission ~= "allowed" then
      computerFunctionData.reason = reason
    end

    computerFunctions.vehicleSpecific[inventoryId][computerFunctionData.id] = computerFunctionData
  end
end

M.startShopping = startShopping
M.installPart = installPart
M.installPartByPartShopId = installPartByPartShopId
M.removePartBySlot = removePartBySlot
M.updatePreviewVehicle = updatePreviewVehicle
M.cancelShopping = cancelShopping
M.applyShopping = applyShopping
M.sendShoppingDataToUI = sendShoppingDataToUI

M.getPartsInShop = getPartsInShop
M.getShoppingCart = getShoppingCart
M.isShoppingSessionActive = isShoppingSessionActive

M.setupTether = setupTether
M.onComputerAddFunctions = onComputerAddFunctions
M.onVehicleSaveFinished = onVehicleSaveFinished

return M