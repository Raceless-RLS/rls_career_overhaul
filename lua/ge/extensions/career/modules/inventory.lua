-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career', "career_modules_log"}

local defaultVehicle = {model = "covet", config = "DXi_M"}

local xVec, yVec, zVec = vec3(1,0,0), vec3(0,1,0), vec3(0,0,1)

local saveAnyVehiclePosDEBUG = false

local slotAmount = 15

local vehicles = {}
local dirtiedVehicles = {}
local vehIdToInventoryId = {}
local inventoryIdToVehId = {}
local currentVehicle
local lastVehicle
local favoriteVehicle

local carConfigToLoad
local carModelToLoad
local loadedVehiclesLocations
local unicycleSavedPosition

local vehicleToEnterId
local vehiclesMovedToStorage

local function getClosestGarage(pos)
  local facilities = freeroam_facilities.getFacilities(getCurrentLevelIdentifier())
  local playerPos = pos or getPlayerVehicle(0):getPosition()
  local closestGarage
  local minDist = math.huge
  for _, garage in ipairs(facilities.garages) do
    local zones = freeroam_facilities.getZonesForFacility(garage)
    local dist = zones[1].center:distance(playerPos)
    if dist < minDist then
      closestGarage = garage
      minDist = dist
    end
  end
  return closestGarage
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end

  -- load from saveslot
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot or not savePath then return end

  -- load the vehicles
  table.clear(vehicles)
  local files = FS:findFiles(savePath .. "/career/vehicles/", '*.json', 0, false, false)
  for i = 1, tableSize(files) do
    local vehicleData = jsonReadFile(files[i])
    vehicleData.partConditions = lpack.decode(vehicleData.partConditions)
    vehicles[vehicleData.id] = vehicleData
    if tableIsEmpty(core_vehicles.getModel(vehicleData.model)) or not FS:fileExists(vehicleData.config.partConfigFilename) then
      vehicleData.missingFile = true
    end
  end

  local inventoryData = jsonReadFile(savePath .. "/career/inventory.json")
  if inventoryData then
    vehicleToEnterId = tonumber(inventoryData.currentVehicle)
    lastVehicle = tonumber(inventoryData.lastVehicle)
    favoriteVehicle = tonumber(inventoryData.favoriteVehicle)

    if inventoryData.spawnedPlayerVehicles then
      loadedVehiclesLocations = {}

      for inventoryId, transform in pairs(inventoryData.spawnedPlayerVehicles) do
        inventoryId = tonumber(inventoryId)
        if not saveAnyVehiclePosDEBUG then
          transform.option = "garage"
        end
        loadedVehiclesLocations[inventoryId] = transform
      end
    else
      loadedVehiclesLocations = nil -- will force spawning at garage
    end

    -- if the last currentVehicle is not spawned, then dont enter it
    if not loadedVehiclesLocations[vehicleToEnterId] then
      vehicleToEnterId = nil
    end

    unicycleSavedPosition = inventoryData.unicyclePos
  end
end

local function saveVehiclesData(currentSavePath, oldSaveDate)
  local vehiclesCopy = deepcopy(vehicles)
  local currentDate = os.date("!%Y-%m-%dT%XZ")
  for id, vehicle in pairs(vehiclesCopy) do
    if dirtiedVehicles[id] or not vehicle.dirtyDate then
      vehicles[id].dirtyDate = currentDate
      vehicle.dirtyDate = currentDate
      dirtiedVehicles[id] = nil
    end
    if (vehicle.dirtyDate > oldSaveDate) then
      vehicle.partConditions = lpack.encode(vehicle.partConditions)
      career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/vehicles/" .. id .. ".json", vehicle, true)
    end
  end

  if currentVehicle then
    dirtiedVehicles[currentVehicle] = true
  end

  -- Remove vehicle files for vehicles that have been deleted
  local files = FS:findFiles(currentSavePath .. "/career/vehicles/", '*.json', 0, false, false)
  for i = 1, tableSize(files) do
    local dir, filename, ext = path.split(files[i])
    local fileNameNoExt = string.sub(filename, 1, -6)
    local inventoryId = tonumber(fileNameNoExt)
    if not vehicles[inventoryId] then
      FS:removeFile(dir .. filename)
    end
  end
end

local function setVehicleDirty(inventoryId)
  dirtiedVehicles[inventoryId] = true
end

local function updatePartConditionsOfSpawnedVehicles(callback)
  local callbackCounter = 0
  for vehId, inventoryId in pairs(vehIdToInventoryId) do
    setVehicleDirty(inventoryId)

    -- update part conditions and call the callback when all vehicles have been processed
    M.updatePartConditions(vehId, inventoryId, callback and
    function()
      callbackCounter = callbackCounter + 1
      if callbackCounter >= tableSize(vehIdToInventoryId) then
        callback()
      end
    end)
  end
  if callback and tableIsEmpty(vehIdToInventoryId) then
    callback()
  end
end

local extensionName = "inventory"
local function saveFinished(currentSavePath, oldSaveDate, forceSyncSave)
  extensions.hook("onVehicleSaveFinished", currentSavePath, oldSaveDate, forceSyncSave)
  career_saveSystem.asyncSaveExtensionFinished(extensionName)
  guihooks.trigger("saveFinished")
end

local function onSaveCurrentSaveSlotAsyncStart()
  career_saveSystem.registerAsyncSaveExtension(extensionName)
end

local function saveVehiclesCallback(currentSavePath, oldSaveDate)
  saveVehiclesData(currentSavePath, oldSaveDate)
  saveFinished(currentSavePath, oldSaveDate)
end

local function isVehicleInGarage(veh, garage)
  local zones = freeroam_facilities.getZonesForFacility(garage)
  for _, zone in ipairs(zones) do
    if zone:containsVehicle(veh) then
      return true
    end
  end
  return false
end

-- TODO update a vehicles part conditions in the table when you exit a vehicle
local function onSaveCurrentSaveSlot(currentSavePath, oldSaveDate, forceSyncSave)
  local data = {}
  data.currentVehicle = currentVehicle
  data.lastVehicle = lastVehicle
  data.favoriteVehicle = favoriteVehicle

  data.spawnedPlayerVehicles = {}
  for inventoryId, vehId in pairs(inventoryIdToVehId) do
    local veh = be:getObjectByID(vehId)
    if veh then
      data.spawnedPlayerVehicles[inventoryId] = {pos = veh:getPosition(), rot = quat(0,0,1,0) * quat(veh:getRefNodeRotation())}
    end
  end

  local useSaveVehiclesCallback = true
  if gameplay_walk.isWalking() then
    local playerVeh = getPlayerVehicle(0)
    data.unicyclePos = playerVeh:getPosition()
  end

  -- when forceSyncSave is not active, then saveVehiclesData gets called in the callback
  if not forceSyncSave then
    updatePartConditionsOfSpawnedVehicles(function() saveVehiclesCallback(currentSavePath, oldSaveDate) end)
    useSaveVehiclesCallback = false
  end

  if useSaveVehiclesCallback then
    saveVehiclesData(currentSavePath, oldSaveDate)
  end

  career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/inventory.json", data, true)

  if useSaveVehiclesCallback then
    saveFinished(currentSavePath, oldSaveDate, forceSyncSave)
  end
end

local function assignInventoryIdToVehId(inventoryId, vehId)
  if vehIdToInventoryId[vehId] then
    inventoryIdToVehId[vehIdToInventoryId[vehId]] = nil
  end
  vehIdToInventoryId[vehId] = inventoryId
  inventoryIdToVehId[inventoryId] = vehId
end

local function hasFreeSlot()
  return tableSize(vehicles) < slotAmount
end

local function getNumberOfFreeSlots()
  return slotAmount - tableSize(vehicles)
end

local inventoryIdAfterUpdatingPartConditions
local function addVehicle(vehId, inventoryId)
  if not hasFreeSlot() then return end
  local vehicle = scenetree.findObjectById(vehId)
  local vehicleData = core_vehicle_manager.getVehicleData(vehId)

  if vehicle and vehicleData then
    if not inventoryId then
      inventoryId = 1
      while vehicles[inventoryId] do
        inventoryId = inventoryId + 1
      end
    end
    local niceName
    if vehicleData.vdata and vehicleData.vdata.information then
      niceName = vehicleData.vdata.information.name
    end

    vehicles[inventoryId] = vehicles[inventoryId] or {}
    vehicles[inventoryId].model = vehicle.JBeam or ""
    vehicles[inventoryId].config = vehicleData.config
    vehicles[inventoryId].id = inventoryId
    vehicles[inventoryId].niceName = niceName

    assignInventoryIdToVehId(inventoryId, vehId)

    inventoryIdAfterUpdatingPartConditions = inventoryId
    vehicle:queueLuaCommand(string.format("if not partCondition.getConditions() then partCondition.initConditions() end obj:queueGameEngineLua('career_modules_inventory.updatePartConditions(%d, %d)')", vehId, inventoryId))

    if tableSize(vehicles) == 1 then
      M.setFavoriteVehicle(inventoryId)
    end
    return inventoryId
  end
end

local skipPartConditionsBeforeWalking
local function removeVehicleObject(inventoryId)
  if currentVehicle == inventoryId then
    skipPartConditionsBeforeWalking = true
    gameplay_walk.setWalkingMode(true)
  end
  extensions.hook("onInventoryPreRemoveVehicleObject", inventoryId, M.getVehicleIdFromInventoryId(inventoryId))
  -- TODO save part conditions
  local vehId = inventoryIdToVehId[inventoryId]
  if vehId then
    local obj = be:getObjectByID(vehId)
    if obj then
      obj:delete()
    end
    vehIdToInventoryId[vehId] = nil
  end
  inventoryIdToVehId[inventoryId] = nil
end


local function removeVehicle(inventoryId)
  vehicles[inventoryId] = nil
  removeVehicleObject(inventoryId)
  extensions.hook("onVehicleRemoved", inventoryId)

  if favoriteVehicle == inventoryId then
    M.setFavoriteVehicle(next(vehicles))
  end
end

local function onPartConditionsUpdateFinished()
  if inventoryIdAfterUpdatingPartConditions then
    extensions.hook("onVehicleAdded", inventoryIdAfterUpdatingPartConditions)
    inventoryIdAfterUpdatingPartConditions = nil
  end
end

local function getPartConditionsCallback(partConditions, inventoryId)
  vehicles[inventoryId].partConditions = partConditions
  onPartConditionsUpdateFinished()
  career_modules_partInventory.updatePartConditionsInInventory()
end

local function updatePartConditions(vehId, inventoryId, callback)
  local veh
  if vehId then
    veh = be:getObjectByID(vehId)
  else
    veh = be:getObjectByID(inventoryIdToVehId[inventoryId])
  end
  if not veh then
    log("E", "", "Couldnt find vehicle object to get part conditions")
    return
  end

  core_vehicleBridge.requestValue(
    veh,
    function(res)
      getPartConditionsCallback(res.result, inventoryId)
      if callback then callback() end
    end,
    'getPartConditions'
  )
end

local function applyPartConditions(inventoryId, vehId)
  local veh = scenetree.findObjectById(vehId or inventoryIdToVehId[inventoryId])
  if not veh then return end
  veh:queueLuaCommand("partCondition.initConditions(" .. serialize(vehicles[inventoryId].partConditions) .. ")")
end

-- replaceOption 1: replace the current vehicle object
-- replaceOption 2: replace the vehicle object with the same inventoryId
local function spawnVehicle(inventoryId, replaceOption, callback)
  local vehInfo = vehicles[inventoryId]

  local carConfigToLoad = vehInfo.config
  local carModelToLoad = vehInfo.model

  if carConfigToLoad then
    -- if the vehicle doesnt exist (deleted mod) then dont spawn
    if tableIsEmpty(core_vehicles.getModel(carModelToLoad)) or not FS:fileExists(vehInfo.config.partConfigFilename) then
      return
    end

    local vehObj
    local vehicleData = {}
    vehicleData.config = carConfigToLoad
    vehicleData.keepOtherVehRotation = true

    if replaceOption == 1 then
      vehObj = core_vehicles.replaceVehicle(carModelToLoad, vehicleData)
    elseif replaceOption == 2 then
      -- check if the vehicle object with the same inventoryId exists and then replace it specifically
      local oldVehId = inventoryIdToVehId[inventoryId]
      local oldVehObj
      if oldVehId then
        oldVehObj = be:getObjectByID(oldVehId)
      end
      vehObj = core_vehicles.replaceVehicle(carModelToLoad, vehicleData, oldVehObj)
    else
      vehicleData.autoEnterVehicle = false
      vehObj = core_vehicles.spawnNewVehicle(carModelToLoad, vehicleData)
    end

    assignInventoryIdToVehId(inventoryId, vehObj:getID())
    local numberOfBrokenParts = career_modules_insurance.getNumberOfBrokenParts(vehInfo.partConditions)
    if numberOfBrokenParts > 0 and numberOfBrokenParts < career_modules_insurance.getBrokenPartsThreshold() then
      career_modules_insurance.repairPartConditions({partConditions = vehInfo.partConditions})
    end

    if vehInfo.partConditions then
      core_vehicleBridge.executeAction(vehObj, 'initPartConditions', vehInfo.partConditions, 0, 1, 1)
      if callback then
        core_vehicleBridge.requestValue(vehObj, callback, 'ping')
      end
    else
      core_vehicleBridge.executeAction(vehObj, 'initPartConditions', {}, 0, 1, 1)
      core_vehicleBridge.requestValue(vehObj, function(res) career_modules_inventory.updatePartConditions(nil, inventoryId, callback) end, 'ping')
    end

    local vehDetails = core_vehicles.getVehicleDetails(vehObj:getId())
    if vehDetails.configs.aggregates.Type.Trailer then
      gameplay_walk.addVehicleToBlacklist(vehObj:getId())
    else
      gameplay_walk.removeVehicleFromBlacklist(vehObj:getId())
    end
    return vehObj
  end
end

-- loadOption 1: dont reload the vehicle
-- loadOption 2: force reload the vehicle
local enterCallbackFunction
local function enterVehicleActual(id, loadOption)
  if not id or loadOption == 1 then
    currentVehicle = id
  elseif inventoryIdToVehId[id] and loadOption ~= 2 then
    -- vehicle is already spawned. enter it
    gameplay_walk.setWalkingMode(false)
    be:enterVehicle(0, be:getObjectByID(inventoryIdToVehId[id]))
    currentVehicle = id
  else
    if spawnVehicle(id, 1, enterCallbackFunction) then
      currentVehicle = id
    end
    enterCallbackFunction = nil
  end
  if currentVehicle then
    dirtiedVehicles[currentVehicle] = true
  end
  extensions.hook("onEnterVehicleFinished", currentVehicle)

  if enterCallbackFunction then enterCallbackFunction() end
end

-- loadOption 1: dont reload the vehicle
-- loadOption 2: force reload the vehicle
local function enterVehicle(newInventoryId, loadOption, callback)
  local vehInfo = vehicles[newInventoryId]
  if vehInfo and vehInfo.timeToAccess then return end
  career_modules_log.addLog(string.format("Enter vehicle %s", newInventoryId or "no vehicle"), "inventory")

  enterCallbackFunction = callback
  if loadOption == 1 then
    enterVehicleActual(newInventoryId, loadOption)
    return
  end
  if currentVehicle then
    updatePartConditionsOfSpawnedVehicles(function() enterVehicleActual(newInventoryId, loadOption) end)
  else
    enterVehicleActual(newInventoryId, loadOption)
  end
end

local saveCareer
local function setupInventory()
  if career_modules_linearTutorial.getLinearStep() == -1 then
    if loadedVehiclesLocations then
      for inventoryId, location in pairs(loadedVehiclesLocations) do
        if not career_modules_insurance.inventoryVehNeedsRepair(inventoryId) then
          local veh = spawnVehicle(inventoryId)
          if veh then
            if location.option == "garage" then
              local garage = getClosestGarage(location.pos)
              freeroam_facilities.teleportToGarage(garage.id, veh)
            else
              spawn.safeTeleport(veh, location.pos, location.rot)
            end
          end
        else
          vehiclesMovedToStorage = true
        end
      end
      loadedVehiclesLocations = nil
    end

    if vehicleToEnterId and inventoryIdToVehId[vehicleToEnterId] then
      enterVehicle(vehicleToEnterId)
    else
      gameplay_walk.setWalkingMode(true)
    end
  end

  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  local data = jsonReadFile(savePath .. "/info.json")
  if not data then
    -- this means this is a new career save
    saveCareer = 0

    if career_modules_linearTutorial.getLinearStep() == -1 then
      -- default placement is in front of the dealership, facing it
      spawn.safeTeleport(getPlayerVehicle(0), vec3(838.51,-522.42,165.75))
      gameplay_walk.setRot(vec3(-1,-1,0), vec3(0,0,1))
    else
      -- spawn the tutorial vehicle
      local model, config = "covet","vehicles/covet/covet_tutorial.pc"
      local pos, rot = vec3(-24.026,609.157,75.112), quatFromDir(vec3(1,0,0))
      local options = {config = config, licenseText = "TUTORIAL", vehicleName = "TutorialVehicle", pos = pos, rot = rot}
      local spawningOptions = sanitizeVehicleSpawnOptions(model, options)
      spawningOptions.autoEnterVehicle = false
      local veh = core_vehicles.spawnNewVehicle(model, spawningOptions)
      core_vehicleBridge.executeAction(veh,'setIgnitionLevel', 0)

      gameplay_walk.setWalkingMode(true)
      -- move walking character into position
      spawn.safeTeleport(getPlayerVehicle(0), vec3(-20.746, 598.736, 75.112))
      gameplay_walk.setRot(vec3(0,1,0), vec3(0,0,1))
    end
  else
    if gameplay_walk.isWalking() then
      if unicycleSavedPosition then
        spawn.safeTeleport(getPlayerVehicle(0), unicycleSavedPosition)
      else
        freeroam_facilities.teleportToGarage("servicestationGarage", getPlayerVehicle(0))
      end
    end
  end

  commands.setGameCamera()
end

local function onCareerModulesActivated(alreadyInLevel)
  if alreadyInLevel then
    setupInventory()
  end
end

local function onClientStartMission(levelPath)
  setupInventory()
end

local function setPartConditionResetSnapshot(veh, callback)
  core_vehicleBridge.executeAction(veh, 'createPartConditionSnapshot', "beforeReset")
  core_vehicleBridge.executeAction(veh, 'setPartConditionResetSnapshotKey', "beforeReset")
  if callback then
    core_vehicleBridge.requestValue(veh, callback, "ping")
  end
end

local function onBigMapActivated()
  if currentVehicle then
    setPartConditionResetSnapshot(getPlayerVehicle(0))
  end
end

local function teleportedFromBigmap()
  if currentVehicle and career_career.isAutosaveEnabled() then
    career_saveSystem.saveCurrent()
  end
end

local function getCurrentVehicle()
  return currentVehicle
end

local function getLastVehicle()
  return lastVehicle
end

local function getVehicleIdFromInventoryId(inventoryId)
  if inventoryId then
    return inventoryIdToVehId[inventoryId]
  end
end

local function getInventoryIdFromVehicleId(vehId)
  if vehId then
    return vehIdToInventoryId[vehId]
  end
end

local function getMapInventoryIdToVehId()
  return inventoryIdToVehId
end

local function getCurrentVehicleId()
  return getVehicleIdFromInventoryId(currentVehicle)
end

local function isSeatedInsideOwnedVehicle()
  return currentVehicle and true or false
end

local function getVehiclesInGarage(garage, intersecting)
  local zones = freeroam_facilities.getZonesForFacility(garage)
  local spawnedVehicles = {}
  local res = {}
  for inventoryId, vehId in pairs(inventoryIdToVehId) do
    spawnedVehicles[inventoryId] = be:getObjectByID(vehId)
  end
  for _, zone in ipairs(zones) do
    for inventoryId, veh in pairs(spawnedVehicles) do
      if intersecting then
        local vehBB = veh:getWorldBox()
        local vehBBExtents = vehBB:getExtents() * 0.5
        local vehPos = veh:getPosition()
        local zoneExtents = vec3(zone.aabb.xMax - zone.aabb.xMin, zone.aabb.yMax - zone.aabb.yMin, zone.aabb.zMax - zone.aabb.zMin)
        zoneExtents.z = math.min(zoneExtents.z, 10000)
        if overlapsOBB_OBB(vehBB:getCenter(), xVec * vehBBExtents.x, yVec * vehBBExtents.y, zVec * vehBBExtents.z,
                           zone.center, xVec * zoneExtents.x/2, yVec * zoneExtents.y/2, zVec * zoneExtents.z/2) then
          for nodeId = 0, veh:getNodeCount() - 1 do
            if zone:containsPoint2D(veh:getNodePosition(nodeId) + vehPos) then
              res[inventoryId] = true
              break
            end
          end
        end
      elseif zone:containsVehicle(veh) then
        res[inventoryId] = true
      end
    end
  end
  return res
end

local function removeVehiclesFromGarageExcept(inventoryId)
  local garage = getClosestGarage()
  local inventoryIdsInGarage = getVehiclesInGarage(garage, true)
  for otherInventoryId, _ in pairs(inventoryIdsInGarage) do
    if otherInventoryId ~= inventoryId then
      M.removeVehicleObject(otherInventoryId)
    end
  end
end

local originComputerId
local menuIsOpen
local buttonsActive = {}
local chooseButtonsData = {}
local menuHeader

local function sendDataToUi()
  menuIsOpen = true
  local data = {vehicles = {}}
  data.menuHeader = menuHeader
  data.repairEnabled = buttonsActive.repairEnabled
  data.sellEnabled = buttonsActive.sellEnabled
  data.favoriteEnabled = buttonsActive.favoriteEnabled
  data.storingEnabled = buttonsActive.storingEnabled
  data.chooseButtonsData = chooseButtonsData
  local vehiclesCopy = deepcopy(vehicles)

  local garage = getClosestGarage()
  local inventoryIdsInGarage = getVehiclesInGarage(garage)

  local playerPolicyData = career_modules_insurance.getPlayerPolicyData()

  for inventoryId, vehicle in pairs(vehiclesCopy) do
    vehicle.value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
    vehicle.repairCost = career_modules_insurance.getPolicyDeductible(inventoryId)

    if inventoryIdToVehId[inventoryId] then
      local vehObj = be:getObjectByID(inventoryIdToVehId[inventoryId])
      if vehObj then
        vehicle.distance = vehObj:getPosition():distance(getPlayerVehicle(0):getPosition())
        vehicle.inGarage = inventoryIdsInGarage[inventoryId]
      end
    else
      vehicle.inStorage = true
    end

    for otherInventoryId, _ in pairs(inventoryIdsInGarage) do
      if otherInventoryId ~= inventoryId then
        vehicle.otherVehicleInGarage = true
        break
      end
    end

    vehicle.needsRepair = career_modules_insurance.inventoryVehNeedsRepair(vehicle.id)
    vehicle.policyInfo = career_modules_insurance.getVehPolicyInfo(inventoryId)
    if inventoryId == favoriteVehicle then
      vehicle.favorite = true
    end

    local playerInsuranceData = playerPolicyData[vehicle.policyInfo.id]
    if playerInsuranceData then
      vehicle.ownsRequiredInsurance = playerInsuranceData.owned
    else
      vehicle.ownsRequiredInsurance = false
    end
  end

  -- convert the keys to strings, so this table wont be converted to an array on js side
  for inventoryId, vehicle in pairs(vehiclesCopy) do
    data.vehicles[tostring(inventoryId)] = vehicle
  end
  data.numberOfFreeSlots = getNumberOfFreeSlots()
  data.originComputerId = originComputerId

  if not career_modules_linearTutorial.getTutorialFlag("purchasedFirstCar") then
    data.tutorialActive = true
  end

  data.playerMoney = career_modules_playerAttributes.getAttributeValue("money")
  guihooks.trigger("vehicleInventoryData", data)
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if saveCareer then
    -- we delay the save here so that the part condition initialization is definitely finished beforehand
    if saveCareer >= 10 then
      career_saveSystem.saveCurrent() -- this is the save just after starting a new career
      saveCareer = nil
    else
      saveCareer = saveCareer + 1
    end
  end

  if vehiclesMovedToStorage then
    guihooks.trigger("toastrMsg", {type="warning", title="Vehicle stored", msg="One or more of your vehicles were damaged at the end of your last session. They have been moved to your storage and have to be repaired."})
    vehiclesMovedToStorage = nil
  end

  for inventoryId, vehInfo in pairs(vehicles) do
    if vehInfo.timeToAccess then
      vehInfo.timeToAccess = vehInfo.timeToAccess - dtReal
      setVehicleDirty(inventoryId)
      if vehInfo.timeToAccess < 0 then
        if vehInfo.delayReason == "bought" then
          ui_message(string.format("The %s has been delivered to your vehicle storage.", vehInfo.niceName), nil, "vehicleInventory")
        elseif vehInfo.delayReason == "repair" then
          ui_message(string.format("Your %s has been repaired and returned to your vehicle storage.", vehInfo.niceName), nil, "vehicleInventory")
        end
        vehInfo.timeToAccess = nil
        vehInfo.delayReason = nil
        if menuIsOpen then
          sendDataToUi()
        end
      end
    end
  end
end

local function onBeforeWalkingModeToggled(enabled, vehicleInFrontVehId)
  if enabled then
    enterVehicle(nil, skipPartConditionsBeforeWalking and 1 or nil)
  elseif vehIdToInventoryId[vehicleInFrontVehId] then
    enterVehicle(vehIdToInventoryId[vehicleInFrontVehId], 1)
  end
  skipPartConditionsBeforeWalking = nil
end

local function getInventoryIdsInClosestGarage(onlyFirst)
  -- get closest garage
  local closestGarage = getClosestGarage()

  -- check if a vehicle is in the zone of the closest garage
  local inventoryIdsInGarage = getVehiclesInGarage(closestGarage, true)
  local inventoryIdsList = {}
  for inventoryId, _ in pairs(inventoryIdsInGarage) do
    table.insert(inventoryIdsList, inventoryId)
  end
  if onlyFirst then
    return next(inventoryIdsInGarage)
  else
    return inventoryIdsList
  end
end

local callbackAfterFade
local function onScreenFadeState(state)
  if callbackAfterFade and state == 1 then
    career_modules_vehicleDeletionService.deleteFlaggedVehicles()
    callbackAfterFade()
    callbackAfterFade = nil
  end
end

local closeMenuCallback
local function openMenu(_chooseButtonsData, header, _buttonsActive, _closeMenuCallback)
  buttonsActive = _buttonsActive or {}
  if buttonsActive.repairEnabled == nil then buttonsActive.repairEnabled = true end
  if buttonsActive.sellEnabled == nil then buttonsActive.sellEnabled = true end
  if buttonsActive.favoriteEnabled == nil then buttonsActive.favoriteEnabled = true end
  if buttonsActive.storingEnabled == nil then buttonsActive.storingEnabled = true end
  menuHeader = header or "Vehicle Inventory"

  chooseButtonsData = _chooseButtonsData or {{}}
  for _, buttonData in ipairs(chooseButtonsData) do
    buttonData.buttonText = buttonData.buttonText or "Choose Vehicle"
    if buttonData.repairRequired == nil then buttonData.repairRequired = true end
    if buttonData.insuranceRequired == nil then buttonData.insuranceRequired = false end
    buttonData.callback = buttonData.callback or function() end
  end

  closeMenuCallback = _closeMenuCallback
  guihooks.trigger('ChangeState', {state = 'vehicleInventory'})
  updatePartConditionsOfSpawnedVehicles()
end

local function closeMenu()
  if closeMenuCallback then
    closeMenuCallback()
  else
    career_career.closeAllMenus()
  end
end

local function spawnVehicleAfterFade(enterAfterSpawn, inventoryId, callback)
  ui_fadeScreen.start(0.5)
  callbackAfterFade = function()
    if enterAfterSpawn then
      enterVehicle(inventoryId, nil, callback)
    else
      -- if the vehicle is already spawned, call the callback directly
      if inventoryIdToVehId[inventoryId] then
        callback()
      else
        spawnVehicle(inventoryId, nil, callback)
      end
    end
  end
end

local function buildCamPath(targetPos, endDir)
  local camMode = core_camera.getGlobalCameras().bigMap

  local path = { looped = false, manualFov = false}
  local startPos = core_camera.getPosition() + vec3(0,0,30)

  local m1 = { fov = 30, movingEnd = false, movingStart = false, positionSmooth = 0.5, pos = startPos, rot = quatFromDir(targetPos - startPos), time = 0, trackPosition = false  }
  local m2 = { fov = 30, movingEnd = false, movingStart = false, positionSmooth = 0.5, pos = startPos, rot = quatFromDir(targetPos - startPos), time = 0.5, trackPosition = false  }
  local m3 = { fov = core_camera.getFovDeg(), movingEnd = false, movingStart = false, positionSmooth = 0.5, pos = core_camera.getPosition(), rot = endDir and quatFromDir(endDir) or core_camera.getQuat(), time = 5.5, trackPosition = false }
  path.markers = {m1, m2, m3}

  return path
end

local function spawnVehicleAndTeleportToGarage(enterAfterSpawn, inventoryId, replaceOthers)
  if inventoryId == currentVehicle then return end
  spawnVehicleAfterFade(enterAfterSpawn, inventoryId,
  function()
    if replaceOthers then
      removeVehiclesFromGarageExcept(inventoryId)
    end
    local vehObj = be:getObjectByID(inventoryIdToVehId[inventoryId])
    setPartConditionResetSnapshot(vehObj,
      function()
        local closestGarage = getClosestGarage()
        freeroam_facilities.teleportToGarage(closestGarage.id, vehObj, false)
        setVehicleDirty(inventoryId)
        ui_fadeScreen.stop(0.5)

        local pos, _ = freeroam_facilities.getGaragePosRot(closestGarage, vehObj)
        local camDir
        if gameplay_walk.isWalking() then
          camDir = pos - getPlayerVehicle(0):getPosition()
          gameplay_walk.setRot(camDir)
        end

        local camDirLength = camDir:length()
        local rayDist = castRayStatic(getPlayerVehicle(0):getPosition(), camDir, camDirLength)

        if rayDist < camDirLength then
          -- Play cam path to show where the vehicle spawned
          local camPath = buildCamPath(pos, camDir)
          local initData = {}
          initData.finishedPath = function(this)
            core_camera.setVehicleCameraByIndexOffset(0, 1)
          end
          core_paths.playPath(camPath, 0, initData)
        end

        career_modules_log.addLog(string.format("Spawned vehicle %d in garage %s. replaceOthers == %s", inventoryId, closestGarage.id, replaceOthers), "inventory")
      end)
  end)
end

local teleportVehicleForGarage
local function setupAndStartGarageMode(teleportVehicle)
  -- remove the other vehicles
  removeVehiclesFromGarageExcept(currentVehicle)

  -- this messes with the fade screen, so it's commented out.
  -- but that means that the fade screen must stay because it closes the vehicle inventory
  --guihooks.trigger('ChangeState', {state = 'play', params = {}})

  if teleportVehicle then
    teleportVehicleForGarage = true
  end
  gameplay_garageMode.start(true, true)
end

local function openMenuFromComputer(_originComputerId)
  originComputerId = _originComputerId
  openMenu(
    {
      {
        callback = function(inventoryId) spawnVehicleAndTeleportToGarage(false, inventoryId) end,
        buttonText = "Retrieve",
        insuranceRequired = true,
        requiredVehicleNotInGarage = true
      },
      {
        callback = function(inventoryId) spawnVehicleAndTeleportToGarage(false, inventoryId, true) end,
        buttonText = "Replace current vehicle",
        insuranceRequired = true,
        requiredOtherVehicleInGarage = true
      }
    },
    "Spawn Vehicle", nil,
    function()
      local computer = freeroam_facilities.getFacility("computer", originComputerId)
      career_modules_computer.openMenu(computer)
    end
  )
  career_modules_log.addLog(string.format("Opened vehicle inventory from computer %s", originComputerId), "inventory")
end

local function garageModeStartStep()
  if teleportVehicleForGarage then
    local vehObj = be:getObjectByID(inventoryIdToVehId[currentVehicle])
    setPartConditionResetSnapshot(vehObj,
    function()
      freeroam_facilities.teleportToGarage(getClosestGarage().id, vehObj, false)
      gameplay_garageMode.initStepFinished()
      ui_fadeScreen.stop(0.5)
    end)
    teleportVehicleForGarage = nil
  else
    gameplay_garageMode.initStepFinished()
    ui_fadeScreen.stop(0.5)
  end
end

local function chooseVehicleFromMenu(inventoryId, buttonIndex, repairPrevVeh)
  chooseButtonsData[buttonIndex].callback(inventoryId, repairPrevVeh)
end

local function onExitVehicleInventory()
  menuIsOpen = false
  chooseButtonsData = {}
  originComputerId = nil
  menuHeader = nil
  if gameplay_garageMode.isActive() and gameplay_walk.isWalking() then
    gameplay_garageMode.stop()
  end
end

local function onEnterVehicleFinished(inventoryId)
  if inventoryId then
    lastVehicle = inventoryId
  end
end

local function getVehicles()
  return vehicles
end

local function sellVehicle(inventoryId)
  local vehicle = vehicles[inventoryId]
  if not vehicle then return end

  local value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
  career_modules_playerAttributes.addAttributes({money=value}, {tags={"vehicleSold","selling"},label="Sold a vehicle: "..(vehicle.niceName or "(Unnamed Vehicle)")})
  removeVehicle(inventoryId)
  Engine.Audio.playOnce('AudioGui','event:>UI>Career>Buy_01')

  career_modules_log.addLog(string.format("Sold vehicle %d for %f", inventoryId, value), "inventory")
  return true
end

local function sellVehicleFromInventory(inventoryId)
  if sellVehicle(inventoryId) then
    career_saveSystem.saveCurrent()
    sendDataToUi()
  end
end

local function delayVehicleAccess(inventoryId, delay, reason)
  local vehInfo = vehicles[inventoryId]
  if not vehInfo or delay <= 0 then return end
  vehInfo.timeToAccess = delay
  vehInfo.delayReason = reason
end

local function onAvailableMissionsSentToUi()
  if not currentVehicle then return end
  updatePartConditions(inventoryIdToVehId[currentVehicle], currentVehicle,
  function()
    guihooks.trigger('gameContextPlayerVehicleDamageInfo', {needsRepair = career_modules_insurance.inventoryVehNeedsRepair(currentVehicle)})
  end)
end

local function setFavoriteVehicle(inventoryId)
  if vehicles[inventoryId] then
    favoriteVehicle = inventoryId
  end
end

local function getFavoriteVehicle()
  return favoriteVehicle
end

local function onComputerAddFunctions(menuData, computerFunctions)
  if not menuData.computerFacility.functions["vehicleInventory"] then return end

  local computerFunctionData = {
    id = "vehicleInventory",
    label = "My Vehicles",
    callback = function() openMenuFromComputer(menuData.computerFacility.id) end,
    disabled = menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive
  }
  computerFunctions.general[computerFunctionData.id] = computerFunctionData
end

M.addVehicle = addVehicle
M.removeVehicle = removeVehicle
M.enterVehicle = enterVehicle
M.sellVehicle = sellVehicle
M.sellVehicleFromInventory = sellVehicleFromInventory
M.updatePartConditions = updatePartConditions
M.updatePartConditionsOfSpawnedVehicles = updatePartConditionsOfSpawnedVehicles
M.removeVehicleObject = removeVehicleObject
M.openMenu = openMenu
M.closeMenu = closeMenu
M.openMenuFromComputer = openMenuFromComputer
M.chooseVehicleFromMenu = chooseVehicleFromMenu
M.garageModeStartStep = garageModeStartStep
M.delayVehicleAccess = delayVehicleAccess
M.hasFreeSlot = hasFreeSlot
M.getNumberOfFreeSlots = getNumberOfFreeSlots
M.setFavoriteVehicle = setFavoriteVehicle
M.getFavoriteVehicle = getFavoriteVehicle
M.sendDataToUi = sendDataToUi

M.onExtensionLoaded = onExtensionLoaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onClientStartMission = onClientStartMission
M.onBigMapActivated = onBigMapActivated
M.onUpdate = onUpdate
M.onBeforeWalkingModeToggled = onBeforeWalkingModeToggled
M.onCareerModulesActivated = onCareerModulesActivated
M.onEnterVehicleFinished = onEnterVehicleFinished
M.onExitVehicleInventory = onExitVehicleInventory
M.onScreenFadeState = onScreenFadeState
M.onAvailableMissionsSentToUi = onAvailableMissionsSentToUi
M.onComputerAddFunctions = onComputerAddFunctions
M.onSaveCurrentSaveSlotAsyncStart = onSaveCurrentSaveSlotAsyncStart

M.getPartConditionsCallback = getPartConditionsCallback
M.applyTuningCallback = applyTuningCallback
M.applyPartConditions = applyPartConditions
M.teleportedFromBigmap = teleportedFromBigmap
M.setVehicleDirty = setVehicleDirty
M.getVehicles = getVehicles
M.spawnVehicle = spawnVehicle
M.getInventoryIdsInClosestGarage = getInventoryIdsInClosestGarage
M.getClosestGarage = getClosestGarage
M.isSeatedInsideOwnedVehicle = isSeatedInsideOwnedVehicle

-- Debug
M.getCurrentVehicle = getCurrentVehicle
M.getCurrentVehicleId = getCurrentVehicleId
M.getLastVehicle = getLastVehicle
M.getVehicleIdFromInventoryId = getVehicleIdFromInventoryId
M.getInventoryIdFromVehicleId = getInventoryIdFromVehicleId
M.getMapInventoryIdToVehId = getMapInventoryIdToVehId

return M
