-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career', "career_modules_log", "render_renderViews", "util_screenshotCreator"}

local parking = require('gameplay/parking')
local freeroam_facilities = require('freeroam/facilities')

local minimumVersion = 42
local defaultVehicle = {model = "covet", config = "DXi_M"}

local xVec, yVec, zVec = vec3(1,0,0), vec3(0,1,0), vec3(0,0,1)

local saveAnyVehiclePosDEBUG = true

local slotAmount = 5

local vehicles = {}
local dirtiedVehicles = {}
local vehIdToInventoryId = {}
local inventoryIdToVehId = {}
local currentVehicle
local lastVehicle
local favoriteVehicle
local sellAllVehicles

local carConfigToLoad
local carModelToLoad
local loadedVehiclesLocations
local unicycleSavedPosition

local vehicleToEnterId
local vehiclesMovedToStorage
local loanedVehicleReturned

local function getClosestGarage(pos, levelName)
  levelName = levelName or getCurrentLevelIdentifier()
  local facilities = freeroam_facilities.getFacilities(levelName)
  local playerPos = pos or getPlayerVehicle(0):getPosition()
  local closestGarage
  local minDist = math.huge
  for _, garage in ipairs(facilities.garages) do
    local zones = freeroam_facilities.getZonesForFacility(garage)
    if zones and not tableIsEmpty(zones) then
      local dist = zones[1].center:distance(playerPos)
      if dist < minDist then
        closestGarage = garage
        minDist = dist
      end
    end
  end
  return closestGarage
end



local function getClosestOwnedGarage(pos, levelName)
  levelName = levelName or getCurrentLevelIdentifier()
  local facilities = freeroam_facilities.getFacilities(levelName)
  local playerPos = pos or getPlayerVehicle(0):getPosition()
  local closestGarage
  local minDist = math.huge
  for _, garage in ipairs(facilities.garages) do
    if not career_modules_garageManager.isPurchasedGarage(garage.id) then
      goto continue
    end
    local zones = freeroam_facilities.getZonesForFacility(garage)
    if not zones or tableIsEmpty(zones) then
      goto continue
    end
    local dist = zones[1].center:distance(playerPos)
    if dist < minDist then
      closestGarage = garage
      minDist = dist
    end
    ::continue::
  end
  return closestGarage
end

local function getClosestGarageAndSpot(pos, levelName)
  levelName = levelName or getCurrentLevelIdentifier()
  local facilities = freeroam_facilities.getFacilities(levelName)
  local closestGarage
  local closestSpot
  local minDist = math.huge

  -- Check each garage
  for _, garage in ipairs(facilities.garages) do
    local parkingSpots = freeroam_facilities.getParkingSpotsForFacility(garage)
    for _, spot in ipairs(parkingSpots) do
      if not spot.vehicle and not spot:hasAnyVehicles() then
        local dist = spot.pos:distance(pos)
        if dist < minDist then
          minDist = dist
          closestGarage = garage
          closestSpot = spot
        end
      end
    end
  end
  return closestGarage, closestSpot, minDist
end

-- Function to parse ISO 8601 date-time string
local function parse_iso8601(datetime)
  local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z"
  local year, month, day, hour, min, sec = datetime:match(pattern)

  -- Convert to Unix timestamp
  return os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec),
    isdst = false
  })
end

-- Function to calculate time difference
local function time_since(datetime)
  local past = parse_iso8601(datetime)
  local now = os.time(os.date("!*t"))
  local diff = os.difftime(now, past)
  return diff
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end

  -- load from saveslot
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot or not savePath then return end

  table.clear(vehicles)

  local saveInfo = jsonReadFile(savePath .. "/info.json")
  if not saveInfo or saveInfo.version < minimumVersion then return end

  -- load the vehicles
  local files = FS:findFiles(savePath .. "/career/vehicles/", '*.json', 0, false, false)
  for i = 1, tableSize(files) do
    local vehicleData = jsonReadFile(files[i])
    vehicleData.partConditions = deserialize(vehicleData.partConditions)
    if vehicleData.timeToAccess then
      vehicleData.timeToAccess = vehicleData.timeToAccess - time_since(saveInfo.date)
      if vehicleData.timeToAccess <= 0 then
        vehicleData.timeToAccess = nil
        vehicleData.delayReason = nil
      end
    end

    vehicles[vehicleData.id] = vehicleData
    if tableIsEmpty(core_vehicles.getModel(vehicleData.model)) or not FS:fileExists(vehicleData.config.partConfigFilename) then
      vehicleData.missingFile = true
    end
  end

  local inventoryData = jsonReadFile(savePath .. "/career/inventory.json")

  local levelName = getCurrentLevelIdentifier()

  if not levelName then
    local generalSaveInfo = jsonReadFile(savePath .. "/career/general.json")
    if generalSaveInfo and generalSaveInfo.level then
      levelName = tostring(generalSaveInfo.level)
    end
  end

  -- Sell all vehicles when the save version is not the newest one
  if saveInfo.version < career_saveSystem.getSaveSystemVersion() then
    sellAllVehicles = true
    if inventoryData then
      inventoryData.currentVehicle = nil
      inventoryData.lastVehicle = nil
      inventoryData.spawnedPlayerVehicles = nil
    end
  end

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
        -- change pos and rot to closest parking spot
        local psList = parking.findParkingSpots(vec3(transform.pos))
        local closestGarage, closestGarageSpot, garageDistance = getClosestGarageAndSpot(transform.pos, levelName)
        
        local closestParkingSpot
        local closestParkingDist = math.huge

        -- Find closest regular parking spot
        if psList and #psList > 0 then
          for _, psData in ipairs(psList) do
            local spot = psData.ps
            if not spot.vehicle and not spot:hasAnyVehicles() then
              local dist = spot.pos:distance(transform.pos)
              if dist < closestParkingDist then
                closestParkingDist = dist
                closestParkingSpot = spot
              end
            end
          end
        end

        -- Compare distances and place vehicle accordingly
        if closestGarageSpot and garageDistance < closestParkingDist then
          transform.pos = closestGarageSpot.pos
          transform.rot = quat(closestGarageSpot.rot)
          closestGarageSpot.vehicle = true
          transform.inGarage = true
          transform.garageId = closestGarage.id
        elseif closestParkingSpot then
          transform.pos = closestParkingSpot.pos
          transform.rot = quat(closestParkingSpot.rot)
          closestParkingSpot.vehicle = true
          transform.inGarage = false
        end

        loadedVehiclesLocations[inventoryId] = transform
      end
    else
      loadedVehiclesLocations = nil -- will force spawning at garage
    end

    -- if the last currentVehicle is not spawned, then dont enter it
    if not (loadedVehiclesLocations and loadedVehiclesLocations[vehicleToEnterId]) then
      vehicleToEnterId = nil
    end

    unicycleSavedPosition = inventoryData.unicyclePos
  end
end

local function updateVehicleThumbnail(inventoryId, filename, callback)
  local vehId = M.getVehicleIdFromInventoryId(inventoryId)
  if not vehId then return end
  local vehObj = getObjectByID(vehId)
  local bb = vehObj:getSpawnWorldOOBB()
  local bbCenter = bb:getCenter()

  local resolution = vec3(500, 281, 0)
  local fov = 50
  local nearPlane = 0.1
  local camPos = util_screenshotCreator.frameVehicle(vehObj, fov, nearPlane, resolution.x / resolution.y)

  local options = {
    pos = camPos,
    rot = quatFromDir(bbCenter - camPos),
    filename = filename,
    renderViewName = "careerVehicleRenderView" .. inventoryId,
    resolution = resolution,
    fov = fov,
    nearPlane = nearPlane,
    screenshotDelay = 0.5
  }
  render_renderViews.takeScreenshot(options, callback)
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
local function inventorySaveFinished(currentSavePath, oldSaveDate)
  -- if there are more async saving steps waiting for the vehicle save to finish, we need to call registerAsyncSaveExtension inside their onVehicleSaveFinished function first
  extensions.hook("onVehicleSaveFinished", currentSavePath, oldSaveDate)
  career_saveSystem.asyncSaveExtensionFinished(extensionName)
  guihooks.trigger("saveFinished")
end

local function onSaveCurrentSaveSlotAsyncStart()
  career_saveSystem.registerAsyncSaveExtension(extensionName)
end

local finishedSaveTasks = {}
local function checkSaveFinished(currentSavePath, oldSaveDate)
  for _, fin in pairs(finishedSaveTasks) do
    if not fin then
      return --not finished
    end
  end
  inventorySaveFinished(currentSavePath, oldSaveDate)
end

local function saveVehiclesData(currentSavePath, oldSaveDate, vehiclesThumbnailUpdate)
  local vehiclesCopy = deepcopy(vehicles)
  local currentDate = os.date("!%Y-%m-%dT%XZ")

  for id, vehicle in pairs(vehiclesCopy) do
    if dirtiedVehicles[id] or not vehicle.dirtyDate then
      vehicles[id].dirtyDate = currentDate
      vehicle.dirtyDate = currentDate
      dirtiedVehicles[id] = nil
    end
    if (vehicle.dirtyDate > oldSaveDate) then
      vehicle.partConditions = serialize(vehicle.partConditions)

      local thumbnailFilename = currentSavePath .. "/career/vehicles/" .. id .. ".png"
      if vehiclesThumbnailUpdate and tableContains(vehiclesThumbnailUpdate, id) and inventoryIdToVehId[id] then
        finishedSaveTasks["thumbnail" .. id] = false
        updateVehicleThumbnail(id, thumbnailFilename, function()
          finishedSaveTasks["thumbnail" .. id] = true
          checkSaveFinished(currentSavePath, oldSaveDate)
        end)
        vehicle.defaultThumbnail = nil
        vehicles[id].defaultThumbnail = nil

      elseif not vehicle.defaultThumbnail then
        local _, oldSavePath = career_saveSystem.getCurrentSaveSlot()
        FS:copyFile(oldSavePath .. "/career/vehicles/" .. id .. ".png", thumbnailFilename)
      end

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
      FS:removeFile(dir .. inventoryId .. ".png")
    end
  end
end

-- TODO update a vehicles part conditions in the table when you exit a vehicle
local function onSaveCurrentSaveSlot(currentSavePath, oldSaveDate, vehiclesThumbnailUpdate)
  local data = {}
  data.currentVehicle = currentVehicle
  data.lastVehicle = lastVehicle
  data.favoriteVehicle = favoriteVehicle

  data.spawnedPlayerVehicles = {}
  for inventoryId, vehId in pairs(inventoryIdToVehId) do
    local veh = getObjectByID(vehId)
    if veh then
      data.spawnedPlayerVehicles[inventoryId] = {pos = veh:getPosition(), rot = quat(0,0,1,0) * quat(veh:getRefNodeRotation())}
    end
  end

  if gameplay_walk.isWalking() then
    local playerVeh = getPlayerVehicle(0)
    data.unicyclePos = playerVeh:getPosition()
  end

  table.clear(finishedSaveTasks)

  finishedSaveTasks.updatePartConditions = false
  updatePartConditionsOfSpawnedVehicles(function()
    saveVehiclesData(currentSavePath, oldSaveDate, vehiclesThumbnailUpdate)
    finishedSaveTasks.updatePartConditions = true
    checkSaveFinished(currentSavePath, oldSaveDate)
  end)

  career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/inventory.json", data, true)
end

local function assignInventoryIdToVehId(inventoryId, vehId)
  if vehIdToInventoryId[vehId] then
    inventoryIdToVehId[vehIdToInventoryId[vehId]] = nil
  end
  vehIdToInventoryId[vehId] = inventoryId
  inventoryIdToVehId[inventoryId] = vehId
end

local getNumberOfFreeSlots = function() 
  return career_modules_garageManager.getFreeSlots()
end

local function hasFreeSlot()
  return getNumberOfFreeSlots() > 0
end

local inventoryIdAfterUpdatingPartConditions
local function addVehicle(vehId, inventoryId, options)
  options = options or {}
  if options.owned == nil then options.owned = true end
  if options.owned and (not hasFreeSlot() and not options.starter) then return end

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
    vehicles[inventoryId].config.licenseName = core_vehicles.getVehicleLicenseText(vehicle)
    vehicles[inventoryId].owned = options.owned
    vehicles[inventoryId].defaultThumbnail = true

    if vehicle.JBeam and vehicleData.config and vehicleData.config.partConfigFilename then
      local dir, configName, ext = path.splitWithoutExt(vehicleData.config.partConfigFilename)
      local baseConfig = core_vehicles.getConfig(vehicle.JBeam, configName)
      vehicles[inventoryId].configBaseValue = baseConfig.Value
      vehicles[inventoryId].takesNoInventorySpace = baseConfig.takesNoInventorySpace
    else
      log("D", "", "Couldnt find base value for added vehicle, so using default value")
      vehicles[inventoryId].configBaseValue = 1000
    end

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
local function removeVehicleObject(inventoryId, skipPartConditions)
  if currentVehicle == inventoryId then
    skipPartConditionsBeforeWalking = true
    gameplay_walk.setWalkingMode(true, nil, nil, true)
  end
  extensions.hook("onInventoryPreRemoveVehicleObject", inventoryId, M.getVehicleIdFromInventoryId(inventoryId))
  -- TODO save part conditions
  local vehId = inventoryIdToVehId[inventoryId]
  if vehId then
    local obj = getObjectByID(vehId)
    if obj then
      obj:delete()
    end
    vehIdToInventoryId[vehId] = nil
  end
  inventoryIdToVehId[inventoryId] = nil
end


local function removeVehicle(inventoryId)
  removeVehicleObject(inventoryId)
  vehicles[inventoryId] = nil
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
    veh = getObjectByID(vehId)
  else
    veh = getObjectByID(inventoryIdToVehId[inventoryId])
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
  core_vehicleBridge.executeAction(veh, 'initPartConditions', vehicles[inventoryId].partConditions)
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

    core_vehicle_manager.queueAdditionalVehicleData({spawnWithEngineRunning = false})
    if replaceOption == 1 then
      vehObj = core_vehicles.replaceVehicle(carModelToLoad, vehicleData)
    elseif replaceOption == 2 then
      -- check if the vehicle object with the same inventoryId exists and then replace it specifically
      local oldVehId = inventoryIdToVehId[inventoryId]
      local oldVehObj
      if oldVehId then
        oldVehObj = getObjectByID(oldVehId)
      end
      vehObj = core_vehicles.replaceVehicle(carModelToLoad, vehicleData, oldVehObj)
    else
      vehicleData.autoEnterVehicle = false
      vehObj = core_vehicles.spawnNewVehicle(carModelToLoad, vehicleData)
    end

    assignInventoryIdToVehId(inventoryId, vehObj:getID())
    local numberOfBrokenParts = career_modules_valueCalculator.getNumberOfBrokenParts(vehInfo.partConditions)
    if numberOfBrokenParts > 0 and numberOfBrokenParts < career_modules_valueCalculator.getBrokenPartsThreshold() then
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

    gameplay_walk.removeVehicleFromBlacklist(vehObj:getId())

    if inventoryId then
      vehObj:queueLuaCommand('electrics.setIgnitionLevel(0)')

      M.setMileage(inventoryId)

      vehObj:queueLuaCommand(string.format(
        'local cert = extensions.vehicleCertifications.getCertifications() obj:queueGameEngineLua("career_modules_inventory.setCertifications(%s, " .. serialize(cert) .. ")")',
        vehObj:getID()))
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
    gameplay_walk.setWalkingMode(false, nil, nil, true)
    be:enterVehicle(0, getObjectByID(inventoryIdToVehId[id]))
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
local function setupInventory(levelPath)
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    local data = jsonReadFile(savePath .. "/info.json")
    local generalData = jsonReadFile(savePath .. "/career/general.json")
    local levelName = generalData and generalData.level or getCurrentLevelIdentifier()
    local justSwitched = generalData and generalData.justSwitched or false

  if justSwitched and not career_modules_hardcore.isHardcoreMode() then
    career_modules_garageManager.purchaseDefaultGarage()
  end

    if career_modules_linearTutorial.getLinearStep() == -1 then
        if loadedVehiclesLocations then
            local vehiclesToTeleportToGarage = {}
            for inventoryId, location in pairs(loadedVehiclesLocations) do
                local vehInfo = vehicles[inventoryId]
                if vehInfo.loanType == "work" then
                    career_modules_loanerVehicles.returnVehicle(inventoryId)
                    loanedVehicleReturned = true
                else
                    if career_modules_insurance.inventoryVehNeedsRepair(inventoryId) then
                        vehiclesMovedToStorage = true
                    else
                        local veh = nil
                        if not justSwitched or vehicleToEnterId == inventoryId then
                            veh = spawnVehicle(inventoryId)
                        end
                        if veh then
                            local levelGate
                            if justSwitched then
                                levelGate = scenetree.findObject("Level Gate")
                                if levelGate then
                                    location.pos = levelGate:getPosition()
                                    location.rot = levelGate:getRotation()
                                end
                            end
                            if not levelGate and location.option == "garage" then
                                location.vehId = veh:getID()
                                vehiclesToTeleportToGarage[inventoryId] = location
                            end
                            spawn.safeTeleport(veh, location.pos, location.rot)
                        end
                    end
                end
            end
            loadedVehiclesLocations = nil

            -- The teleport to garage needs to happen with one frame delay because that's when the OOBBs get updated
            extensions.core_jobsystem.create(function(job)
                for inventoryId, location in pairs(vehiclesToTeleportToGarage) do
                    local veh = getObjectByID(location.vehId)
                    local garage = getClosestGarage(location.pos)
                    freeroam_facilities.teleportToGarage(garage.id, veh)
                    job.sleep(0.1)
                end
            end)
        end

        if vehicleToEnterId and inventoryIdToVehId[vehicleToEnterId] then
            enterVehicle(vehicleToEnterId)
        else
            gameplay_walk.setWalkingMode(true)
        end
        extensions.hook("onSetupInventoryFinished")
    end

    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    local data = jsonReadFile(savePath .. "/info.json")
    if not data then
        -- this means this is a new career save
        saveCareer = 0
        if career_career.hardcoreMode then
            local eligibleVehicles = util_configListGenerator.getEligibleVehicles(false, false)
            local hardcoreFilter = {
                whiteList = {
                    ["Config Type"] = {"Hardcore"}
                }
            }
            local hardcoreVehicleInfos = util_configListGenerator.getRandomVehicleInfos({
                filter = hardcoreFilter
            }, 6, eligibleVehicles, "Population")
            local randomVehicleInfo = hardcoreVehicleInfos[math.random(#hardcoreVehicleInfos)]
            local model = randomVehicleInfo.model_key
            local config = '/vehicles/' .. model .. '/configurations/' .. randomVehicleInfo.key .. '.pc'
            local pos, rot = vec3(-24.026, 609.157, 75.112), quatFromDir(vec3(1, 0, 0))
            local options = {
                config = config,
                licenseText = "Hardcore",
                vehicleName = "First Car",
                pos = pos,
                rot = rot
            }
            local spawningOptions = sanitizeVehicleSpawnOptions(model, options)
            spawningOptions.autoEnterVehicle = false
            local veh = core_vehicles.spawnNewVehicle(model, spawningOptions)
            core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0)
            core_vehicles.setPlateText("Uncle's", veh:getID())

            gameplay_walk.setWalkingMode(true)
            -- move walking character into position
            spawn.safeTeleport(getPlayerVehicle(0), vec3(-20.746, 598.736, 75.112))
            gameplay_walk.setRot(vec3(0, 1, 0), vec3(0, 0, 1))
            local mileage = 900000 * 1609.344
            veh:queueLuaCommand(string.format("partCondition.initConditions(nil, %d, nil, %f)", mileage, 0.5))
            M.addVehicle(veh:getID(), nil, {
                starter = true
            })
        elseif career_modules_linearTutorial.getLinearStep() == -1 then
            -- default placement is in front of the dealership, facing it
            -- spawn.safeTeleport(getPlayerVehicle(0), vec3(838.51,-522.42,165.75))
            -- gameplay_walk.setRot(vec3(-1,-1,0), vec3(0,0,1))
            if levelName == "west_coast_usa" then
                freeroam_facilities.teleportToGarage("chinatownGarage", getPlayerVehicle(0))
            elseif levelName == "italy" then
                freeroam_facilities.teleportToGarage("uncleGarage", getPlayerVehicle(0))
            end
            career_modules_garageManager.purchaseDefaultGarage()
        else
            -- spawn the tutorial vehicle
            local model, config = "covet", "vehicles/covet/covet_tutorial.pc"
            local pos, rot = vec3(-24.026, 609.157, 75.112), quatFromDir(vec3(1, 0, 0))
            local options = {
                config = config,
                licenseText = "TUTORIAL",
                vehicleName = "TutorialVehicle",
                pos = pos,
                rot = rot
            }
            local spawningOptions = sanitizeVehicleSpawnOptions(model, options)
            spawningOptions.autoEnterVehicle = false
            local veh = core_vehicles.spawnNewVehicle(model, spawningOptions)
            core_vehicleBridge.executeAction(veh, 'setIgnitionLevel', 0)

            gameplay_walk.setWalkingMode(true)
            -- move walking character into position
            spawn.safeTeleport(getPlayerVehicle(0), vec3(-20.746, 598.736, 75.112))
            gameplay_walk.setRot(vec3(0, 1, 0), vec3(0, 0, 1))
            career_modules_garageManager.purchaseDefaultGarage()
        end
    else
        if gameplay_walk.isWalking() then
            if unicycleSavedPosition and not justSwitched then

                spawn.safeTeleport(getPlayerVehicle(0), unicycleSavedPosition)
            else
                if levelName == "west_coast_usa" then
                    freeroam_facilities.teleportToGarage("chinatownGarage", getPlayerVehicle(0))
                elseif levelName == "italy" then
                    freeroam_facilities.teleportToGarage("uncleGarage", getPlayerVehicle(0))
                end
            end
        end
        extensions.hook("onEnterVehicleFinished", currentVehicle)
    end

    commands.setGameCamera()
end


local function onCareerModulesActivated(alreadyInLevel)
  if sellAllVehicles then
    for inventoryId, vehicle in pairs(vehicles) do
      if vehicle.owned then
        M.sellVehicle(inventoryId)
      elseif vehicle.loanType == "work" then
        career_modules_loanerVehicles.returnVehicle(inventoryId)
        loanedVehicleReturned = true
      else
        M.removeVehicle(inventoryId)
      end
    end
    sellAllVehicles = nil
  end
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
    spawnedVehicles[inventoryId] = getObjectByID(vehId)
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
      local vehInfo = vehicles[otherInventoryId]
      if vehInfo.owned then
        M.removeVehicleObject(otherInventoryId)
        M.switchGarageSpots(otherInventoryId, inventoryId)
      end
    end
  end
end

local function getDefaultVehicleThumb(vehInfo)
  local model = core_vehicles.getModel(vehInfo.model)
  if not model then return nil end
  local _, configKey = path.splitWithoutExt(vehInfo.config.partConfigFilename)
  local config = model.configs[configKey]
  if not config then return nil end
  return config.preview
end

local function getVehicleThumbnail(inventoryId)
  if not inventoryId then return end
  local vehicle = vehicles[inventoryId]
  if not vehicle then return end
  local _, savePath = career_saveSystem.getCurrentSaveSlot()
  local thumbnailPath = savePath .. "/career/vehicles/" .. inventoryId .. ".png"
  if not vehicle.defaultThumbnail and FS:fileExists(thumbnailPath) then
    return thumbnailPath
  else
    return getDefaultVehicleThumb(vehicle)
  end
end

local originComputerId
local menuIsOpen
local buttonsActive = {}
local chooseButtonsData = {}
local menuHeader

local function isVehicleOnSite(inventoryId, garage)
  local vehicle = vehicles[inventoryId]
  if not vehicle or not vehicle.location then
    return
  end
  return vehicle.location == garage.id
end

local function processPerformanceData(performanceData)
  if not performanceData then return end

  career_modules_vehiclePerformance.addScoresToPerformanceData(performanceData)

  -- Process drivetrain information
  if performanceData.powertrainLayout then
    local frontWheelDrive = performanceData.powertrainLayout.poweredWheelsFront > 0
    local rearWheelDrive = performanceData.powertrainLayout.poweredWheelsRear > 0
    performanceData.drivetrain = frontWheelDrive and rearWheelDrive and "AWD" or frontWheelDrive and "FWD" or rearWheelDrive and "RWD" or "Unknown"
  end

  -- Process fuel type information
  if performanceData.fuelTypes then
    if performanceData.fuelTypes["fuelTank:gasoline"] then
      performanceData.fuelType = "Gasoline"
    elseif performanceData.fuelTypes["fuelTank:diesel"] then
      performanceData.fuelType = "Diesel"
    elseif performanceData.fuelTypes["fuelTank:electric"] then
      performanceData.fuelType = "Electric"
    elseif next(performanceData.fuelTypes) then
      performanceData.fuelType = next(performanceData.fuelTypes)
    else
      performanceData.fuelType = "Unknown"
    end
  end

  -- Process induction type information
  if performanceData.inductionTypes then
    if performanceData.inductionTypes.naturalAspiration then
      performanceData.inductionType = "NA"
    elseif performanceData.inductionTypes.turbocharger then
      performanceData.inductionType = "Turbocharger"
    elseif next(performanceData.inductionTypes) then
      performanceData.inductionType = next(performanceData.inductionTypes)
    else
      performanceData.inductionType = "Unknown"
    end
  end

  if performanceData.power and performanceData.weight then
    performanceData.powerPerTon = performanceData.power * 1000 / performanceData.weight
  end
end

local function getVehicleUiData(inventoryId, inventoryIdsInGarage)
  local vehicleData = deepcopy(vehicles[inventoryId])
  if not vehicleData then return end
  if not inventoryIdsInGarage then
    inventoryIdsInGarage = getVehiclesInGarage(getClosestGarage())
  end

  vehicleData.value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
  vehicleData.valueRepaired = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId, true)
  vehicleData.quickRepairExtraPrice = career_modules_insurance.getQuickRepairExtraPrice()
  vehicleData.initialRepairTime = career_modules_insurance.getRepairTime(inventoryId)

  if inventoryIdToVehId[inventoryId] then
    local vehObj = getObjectByID(inventoryIdToVehId[inventoryId])
    if vehObj then
      vehicleData.distance = vehObj:getPosition():distance(getPlayerVehicle(0):getPosition())
      vehicleData.inGarage = inventoryIdsInGarage[inventoryId]
    end
    vehicleData.inStorage = false
  else
    vehicleData.inStorage = true
  end

  for otherInventoryId, _ in pairs(inventoryIdsInGarage) do
    if otherInventoryId ~= inventoryId then
      vehicleData.otherVehicleInGarage = true
      break
    end
  end

  vehicleData.needsRepair = career_modules_insurance.inventoryVehNeedsRepair(vehicleData.id)
  if inventoryId == favoriteVehicle then
    vehicleData.favorite = true
  end

  local vehPolicyInfo = career_modules_insurance.getVehPolicyInfo(inventoryId)
  vehicleData.policyInfo = vehPolicyInfo.policyInfo
  vehicleData.ownsRequiredInsurance = vehPolicyInfo.policyOwned

  vehicleData.thumbnail = getVehicleThumbnail(inventoryId)

  vehicleData.repairPermission = career_modules_permissions.getStatusForTag("vehicleRepair", {inventoryId = inventoryId})
  vehicleData.sellPermission = career_modules_permissions.getStatusForTag("vehicleSelling", {inventoryId = inventoryId})
  vehicleData.favoritePermission = career_modules_permissions.getStatusForTag("vehicleFavorite", {inventoryId = inventoryId})
  vehicleData.storePermission = career_modules_permissions.getStatusForTag("vehicleStoring", {inventoryId = inventoryId})
  vehicleData.licensePlateChangePermission = career_modules_permissions.getStatusForTag({"vehicleLicensePlate", "vehicleModification"}, {inventoryId = inventoryId})
  vehicleData.returnLoanerPermission = career_modules_permissions.getStatusForTag("returnLoanedVehicle", {inventoryId = inventoryId})

  for _, performanceData in ipairs(vehicleData.performanceHistory or {}) do
    processPerformanceData(performanceData)
  end

  if vehicleData.certificationData then
    processPerformanceData(vehicleData.certificationData)
  end

  return vehicleData
end

local function sendDataToUi()
  menuIsOpen = true
  local data = {vehicles = {}}
  data.menuHeader = menuHeader
  data.chooseButtonsData = chooseButtonsData
  data.buttonsActive = buttonsActive
  local vehiclesCopy = deepcopy(vehicles)

  local garage = getClosestGarage()
  local inventoryIdsInGarage = getVehiclesInGarage(garage)

  local playerPolicyData = career_modules_insurance.getPlayerPolicyData()

  for inventoryId, vehicle in pairs(vehiclesCopy) do
    vehicle.value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
    vehicle.valueRepaired = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId, true)
    vehicle.quickRepairExtraPrice = career_modules_insurance.getQuickRepairExtraPrice()
    vehicle.initialRepairTime = career_modules_insurance.getRepairTime(inventoryId)

    if vehicle.certifications then
      vehicle.power = string.format("%d", vehicle.certifications.power)
      vehicle.weight = string.format("%d", vehicle.certifications.weight)
      vehicle.torque = string.format("%d", vehicle.certifications.torque)
      vehicle.powerPerWeight = string.format("%0.3f", vehicle.certifications.power / vehicle.certifications.weight)
    else
      vehicle.power = "N/A"
      vehicle.weight = "N/A"
      vehicle.torque = "N/A"
      vehicle.powerPerWeight = "N/A"
    end

    vehicle.mileage = M.setMileage(inventoryId)

    if inventoryIdToVehId[inventoryId] then
      local vehObj = be:getObjectByID(inventoryIdToVehId[inventoryId])
      if vehObj then
        vehicle.distance = vehObj:getPosition():distance(getPlayerVehicle(0):getPosition())
        vehicle.inGarage = inventoryIdsInGarage[inventoryId]
      end
    end

    for otherInventoryId, _ in pairs(inventoryIdsInGarage) do
      if otherInventoryId ~= inventoryId then
        vehicle.otherVehicleInGarage = true
        break
      end
    end

    vehicle.needsRepair = career_modules_insurance.inventoryVehNeedsRepair(vehicle.id)
    vehicle.onSite = isVehicleOnSite(inventoryId, garage)
    if inventoryId == favoriteVehicle then
      vehicle.favorite = true
    end

    local vehPolicyInfo = career_modules_insurance.getVehPolicyInfo(inventoryId)
    vehicle.policyInfo = vehPolicyInfo.policyInfo
    vehicle.ownsRequiredInsurance = vehPolicyInfo.policyOwned

    vehicle.thumbnail = getVehicleThumbnail(inventoryId)

    vehicle.repairPermission = career_modules_permissions.getStatusForTag("vehicleRepair", {inventoryId = inventoryId})
    vehicle.sellPermission = career_modules_permissions.getStatusForTag("vehicleSelling", {inventoryId = inventoryId})
    vehicle.favoritePermission = career_modules_permissions.getStatusForTag("vehicleFavorite", {inventoryId = inventoryId})
    vehicle.storePermission = career_modules_permissions.getStatusForTag("vehicleStoring", {inventoryId = inventoryId})
    vehicle.storePermission.allow = vehicle.storePermission.allow and (career_modules_garageManager.isGarageSpace(garage.id)[1] or M.getVehicleLocation(inventoryId) == garage.id)
    vehicle.deliverPermission = { allow = (career_modules_garageManager.isGarageSpace(garage.id)[1] and vehicle.location ~= garage.id)}
    vehicle.licensePlateChangePermission = career_modules_permissions.getStatusForTag({"vehicleLicensePlate", "vehicleModification"}, {inventoryId = inventoryId})
    vehicle.returnLoanerPermission = career_modules_permissions.getStatusForTag("returnLoanedVehicle", {inventoryId = inventoryId})
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
    guihooks.trigger("toastrMsg", {type="warning", label = "vehStored", title="Vehicle stored", msg="One or more of your vehicles were damaged at the end of your last session. They have been moved to your storage and have to be repaired."})
    vehiclesMovedToStorage = nil
  end

  if loanedVehicleReturned then
    guihooks.trigger("toastrMsg", {type="warning", label = "loanReturned", title="Loaner returned", msg="Your loaned vehicles have been returned to their respective owners."})
    loanedVehicleReturned = nil
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
        elseif vehInfo.delayReason == "rented" then
          ui_message(string.format("Your %s has been returned from the Movie Rental.", vehInfo.niceName), nil, "vehicleInventory")
        elseif vehInfo.delayReason == "certification" then
          ui_message(string.format("Your %s has been certified and returned to your vehicle storage.", vehInfo.niceName), nil, "vehicleInventory")
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

  if getPlayerVehicle(0) then
    local playerPos = getPlayerVehicle(0):getPosition()
    table.sort(inventoryIdsList, function(id1, id2)
      local veh1 = getObjectByID(inventoryIdToVehId[id1])
      local veh2 = getObjectByID(inventoryIdToVehId[id2])
      return veh1:getPosition():distance(playerPos) < veh2:getPosition():distance(playerPos)
    end)
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
  if buttonsActive.returnLoanerEnabled == nil then buttonsActive.returnLoanerEnabled = true end
  menuHeader = header or "Vehicle Inventory"

  chooseButtonsData = _chooseButtonsData or {{}}
  for _, buttonData in ipairs(chooseButtonsData) do
    buttonData.buttonText = buttonData.buttonText or "Choose Vehicle"
    if buttonData.repairRequired == nil then buttonData.repairRequired = true end
    if buttonData.insuranceRequired == nil then buttonData.insuranceRequired = false end
    if buttonData.ownedRequired == nil then buttonData.ownedRequired = false end
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

local function spawnVehicleAndTeleportToGarage(enterAfterSpawn, inventoryId, replaceOthers)
  if inventoryId == currentVehicle then return end
  spawnVehicleAfterFade(enterAfterSpawn, inventoryId,
  function()
    if replaceOthers then
      removeVehiclesFromGarageExcept(inventoryId)
    end
    local vehObj = getObjectByID(inventoryIdToVehId[inventoryId])
    setPartConditionResetSnapshot(vehObj,
      function()
        local closestGarage = getClosestGarage()
        freeroam_facilities.teleportToGarage(closestGarage.id, vehObj, false)
        career_modules_fuel.minimumRefuelingCheck(vehObj:getId())
        setVehicleDirty(inventoryId)
        ui_fadeScreen.stop(0.5)

        local pos, _ = freeroam_facilities.getGaragePosRot(closestGarage, vehObj)
        career_modules_playerDriving.showPosition(pos)

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
      },
      {
        callback = function(inventoryId)
          career_modules_vehiclePerformance.openMenu({inventoryId = inventoryId, computerId = originComputerId})
        end,
        buttonText = "Performance Index",
        repairRequired = false
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
    local vehObj = getObjectByID(inventoryIdToVehId[currentVehicle])
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

local function getVehicleTimeToAccess(inventoryId)
  return vehicles[inventoryId].timeToAccess
end

local function sellVehicle(inventoryId)
  local vehicle = vehicles[inventoryId]
  if not vehicle then return end

  local value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId) * (career_modules_hardcore.isHardcoreMode() and 0.33 or 0.66)
  career_modules_playerAttributes.addAttributes({money=value}, {tags={"vehicleSold","selling"},label="Sold a vehicle: "..(vehicle.niceName or "(Unnamed Vehicle)")}, true)
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

local function returnLoanedVehicleFromInventory(inventoryId)
  career_modules_loanerVehicles.returnVehicle(inventoryId, function()
    career_saveSystem.saveCurrent()
    sendDataToUi()
  end)
end

local function expediteRepairFromInventory(inventoryId, price)
  career_modules_insurance.expediteRepair(inventoryId, price)
  career_saveSystem.saveCurrent()
  sendDataToUi()
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
    order = 1
  }
  if menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive then
    computerFunctionData.disabled = true
    computerFunctionData.reason = career_modules_computer.reasons.tutorialActive
  end
  computerFunctions.general[computerFunctionData.id] = computerFunctionData
end

local function setLicensePlateText(inventoryId, text)
  local vehId = getVehicleIdFromInventoryId(inventoryId)
  if inventoryId then
    core_vehicles.setPlateText(text, vehId)
  end
  vehicles[inventoryId].config.licenseName = text
end

local function getLicensePlateText(vehId)
  local inventoryId = getInventoryIdFromVehicleId(vehId)
  return inventoryId and vehicles[inventoryId] and vehicles[inventoryId].config.licenseName or nil
end

local function purchaseLicensePlateText(inventoryId, text, money)
  local price = {money = {amount = money}}
  if not career_modules_payment.canPay(price) then return end
  career_modules_payment.pay(price, {label = string.format("Change the license plate text"), tags = {"licensePlate", "buying"}})
  setLicensePlateText(inventoryId, text)
  Engine.Audio.playOnce('AudioGui','event:>UI>Career>Buy_01')
  setVehicleDirty(inventoryId)
end

local permissionTags = {
  notOwned = {
    vehicleSelling = "forbidden", --selling a vehicle
    vehicleRepair = "forbidden",
    interactMission = "forbidden", --use the mission POI to start a mission
    painting = "forbidden",
    partBuying = "forbidden",
    vehicleLicensePlate = "forbidden",
    tuning = "forbidden",
    vehicleStoring = "forbidden",
    partSwapping = "forbidden",
    recoveryTowToGarage = "forbidden",
    returnLoanedVehicle = "allowed",
    vehicleFavorite = "forbidden"
  }
}

local function onCheckPermission(tags, permissions, additionalData)
  if not additionalData or not additionalData.inventoryId then return end
  local vehData = vehicles[additionalData.inventoryId]
  if not vehData then return end

  for _, tag in ipairs(tags) do
    if not vehData.owned then
      if permissionTags.notOwned[tag] then
        table.insert(permissions, {permission = permissionTags.notOwned[tag]})
      end
    elseif tag == "returnLoanedVehicle" then
      table.insert(permissions, {permission = "hidden"})
    end

    if tag == "vehicleRepair" and (vehData.timeToAccess or vehData.missingFile) then
      table.insert(permissions, {permission = "forbidden"})
    end
    if tag == "vehicleSelling" and vehData.timeToAccess then
      table.insert(permissions, {permission = "forbidden"})
    end
    if tag == "vehicleFavorite" and (vehData.favorite or vehData.missingFile) then
      table.insert(permissions, {permission = "forbidden"})
    end
    if tag == "vehicleStoring" and not inventoryIdToVehId[additionalData.inventoryId] then
      table.insert(permissions, {permission = "forbidden"})
    end
  end
end

local function onGetRawPoiListForLevel(levelIdentifier, elements)
  if next(inventoryIdToVehId) then
    for invId, vehId in pairs(inventoryIdToVehId) do
      if be:getPlayerVehicleID(0) ~= vehId then -- don't display the current player's vehicle
        if map.objects[vehId] then
          local desc = "Player's vehicle"
          if vehicles[invId].loanType then
            desc = "Loaned vehicle"
          end

          local id = "plVeh"..vehId
          local dist, distUnit = translateDistance(map.objects[vehId].pos:distance(getPlayerVehicle(0):getPosition()), true)
          local plate = vehicles[invId].config.licenseName
          local odometer, odoUnit = translateDistance(career_modules_valueCalculator.getVehicleMileageById(invId), true)

          desc = string.format("%s | Distance: %0.2f %s | Licence plate: %s | Odometer: %i %s", desc, dist, distUnit, plate, odometer, odoUnit)
          table.insert(elements, {
            id = id,
            data = {type = "playerVehicle", id = id},
            markerInfo = {
              bigmapMarker = {
                pos = map.objects[vehId].pos,
                icon = "vehicle_marker_outlined",
                name = vehicles[invId].niceName,
                description = desc,
                thumbnail = getVehicleThumbnail(invId),
                previews = getVehicleThumbnail(invId),
                cluster = false
              }
            }
          })
        end
      end
    end
  end
end

local function getDirtiedVehicles()
  return dirtiedVehicles
end

local function isEmpty()
  return tableIsEmpty(vehicles)
end

local function getVehicle(inventoryId)
  return vehicles[inventoryId]
end

-- RLS Extra Vehicle Stats

local function setVehicleRole(inventoryId, role)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].role = role
end

local function getVehicleRole(inventoryId)
  return vehicles[inventoryId] and vehicles[inventoryId].role or nil
end

local function addMeetReputation(inventoryId, amount)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].meetReputation = (vehicles[inventoryId].meetReputation or 0) + amount
end

local function getMeetReputation(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].meetReputation or 0
end

local function addAccident(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].accidents = (vehicles[inventoryId].accidents or 0) + 1
end

local function getAccidents(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].accidents or 0
end

local function addArrest(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].arrests = (vehicles[inventoryId].arrests or 0) + 1
end

local function getArrests(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].arrests or 0
end

local function addTicket(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].tickets = (vehicles[inventoryId].tickets or 0) + 1
end

local function getTickets(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].tickets or 0
end

local function addEvade(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].evades = (vehicles[inventoryId].evades or 0) + 1
end

local function getEvades(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].evades or 0
end

local function addTaxiDropoff(inventoryId, passengers)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].taxiDropoffs = (vehicles[inventoryId].taxiDropoffs or 0) + passengers
end

local function getTaxiDropoffs(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].taxiDropoffs or 0
end

local function addRepossession(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].repos = (vehicles[inventoryId].repos or 0) + 1
end

local function getRepossessions(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].repos or 0
end

local function addMovieRental(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].movieRentals = (vehicles[inventoryId].movieRentals or 0) + 1
end

local function getMovieRentals(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].movieRentals or 0
end

function M.setCertifications(vehId, certifications)
  local invId = getInventoryIdFromVehicleId(vehId)
  if not invId then return end
  vehicles[invId].certifications = certifications
end

M.getCertifications = function()
  local invId = getInventoryIdFromVehicleId(be:getPlayerVehicleID(0))
  local veh = vehicles[invId]
  if not veh then return {} end
  return veh.certifications
end

function M.addDeliveredItems(inventoryId, amount)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].deliveredItems = vehicles[inventoryId].deliveredItems or 0
  vehicles[inventoryId].deliveredItems = vehicles[inventoryId].deliveredItems + amount
end

function M.getDeliveredItems(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].deliveredItems or 0
end

function M.addSuspectCaught(inventoryId)
  if not vehicles[inventoryId] then return end
  vehicles[inventoryId].suspectsCaught = (vehicles[inventoryId].suspectsCaught or 0) + 1
end

function M.getSuspectsCaught(inventoryId)
  if not vehicles[inventoryId] then return 0 end
  return vehicles[inventoryId].suspectsCaught or 0
end

-- RLS Reload function

local function onWorldReadyState(state)
  if state == 2 and career_career.isActive() then
    setupInventory()
  end
end

-- RLS Taxi Functions

local function specificCapcityCases(partName)
  if partName:find("capsule") and partName:find("seats") then
    if partName:find("sd12m") then return 58
    elseif partName:find("sd18m") then return 44
    elseif partName:find("sd105") then return 25
    elseif partName:find("sd_seats") then return 33
    elseif partName:find("dd105") then return 58
    elseif partName:find("sd195") then return 42
    elseif partName:find("lh_seats") then return 70
    elseif partName:find("artic") then return 107 end
  end
  return nil
end

local function cyclePartsTree(partData, seatingCapacity)
  for first, part in pairs(partData) do
    local partName = part.chosenPartName
    if partName:find("seat") and not partName:find("cargo") and not partName:find("captains") then
      local seatSize = nil
      if partName:find("seats") then
        seatSize = 3
      elseif partName:find("ext") then
        seatSize = 2
      else
        if partName:match("(%d+)R") then
          seatSize = 2
        else
          seatSize = 1
        end
      end
      if partName:find("citybus_seats") then seatSize = 44
      elseif partName:find("skin") then seatSize = 0 end
      if specificCapcityCases(partName) then seatSize = specificCapcityCases(partName) end
      seatingCapacity = seatingCapacity + seatSize
    end
    if part.children then
      seatingCapacity = cyclePartsTree(part.children, seatingCapacity)
    end
    if partName == "pickup" then
      seatingCapacity = math.max(seatingCapacity, 7)
    end
  end
  return seatingCapacity
end

local function calculateSeatingCapacity(inventoryId)
  if not inventoryId then inventoryId = currentVehicle end
  local veh = vehicles[inventoryId]
  if not veh then return 0 end
  local partData = veh.config.partsTree

  return cyclePartsTree({partData}, 0)
end

-- RLS Marketplace Functions

function M.loadMarketplaceData(savePath)
  local marketplaceData = jsonReadFile(savePath .. "/career/rls_career/marketplace.json")

  if marketplaceData then
    for inventoryId, vehicle in pairs(vehicles) do
      if marketplaceData[inventoryId] ~= nil then

        vehicle.forSale = true
      end
    end
    return marketplaceData
  end
  return {}
end

function M.removeVehicleFromSale(inventoryId, price)
  inventoryId = tonumber(inventoryId)
  local vehicle = vehicles[inventoryId]
  if vehicle and vehicle.forSale then
    vehicle.forSale = nil
  end
  extensions.hook("onVehicleListingUpdate", {inventoryId = inventoryId, forSale = false})
  if price then
    career_modules_playerAttributes.addAttributes({money=price}, {tags={"vehicleSold","selling"},label="Sold a "..(vehicle.niceName or "(Unnamed Vehicle)")}, true)
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Buy_01')
    career_modules_log.addLog(string.format("Sold vehicle %d for %f", inventoryId, price), "inventory")
    removeVehicle(inventoryId)
  end
end

function M.listVehicleForSale(inventoryId)
  local vehicle = vehicles[tonumber(inventoryId)]
  if not vehicle then return end
  vehicle.forSale = true
  extensions.hook("onVehicleListingUpdate", {inventoryId = inventoryId, forSale = true})
end

function M.setMileage(inventoryId)
  if not inventoryId then inventoryId = currentVehicle end
  local vehicle = vehicles[inventoryId]
  if not vehicle or not vehicle.partConditions then
    return 0 -- Or nil, or handle the case where there are no part conditions
  end

  local maxOdometer = 0
  local partConditions = vehicle.partConditions

  for partName, conditionData in pairs(partConditions) do
    if conditionData.odometer then
      maxOdometer = math.max(maxOdometer, conditionData.odometer)
    end
  end
  vehicle.mileage = maxOdometer
  return maxOdometer
end

function M.requestListedVehicles()
  local listedVehicles = {}
  for _, vehicle in pairs(vehicles) do
    listedVehicles[tostring(vehicle.id)] = false
    if vehicle.forSale then
      listedVehicles[tostring(vehicle.id)] = true
    end
  end
  print("requestListedVehicles LUA")
  dump(listedVehicles)
  guihooks.trigger("listedVehiclesUpdate", listedVehicles)
end

-- RLS FRE Functions

local lastRaceName = nil
local lastRaceTime = nil
local currentSession = 0

local function saveFRETimeToVehicle(raceName, inventoryId, time, driftScore)
  print("saveFRETimeToVehicle" .. tostring(raceName) .. " " .. tostring(inventoryId) .. " " .. tostring(time) .. " " .. tostring(driftScore))
  local veh = vehicles[inventoryId]
  if not veh then return end
  veh.FRETimes = veh.FRETimes or {}
  veh.FRECompletions = veh.FRECompletions or {}
  if veh.FRETimes[raceName] then
    if driftScore and driftScore ~= 0 then
      veh.FRETimes[raceName] = math.max(veh.FRETimes[raceName], driftScore)
    else
      veh.FRETimes[raceName] = math.min(veh.FRETimes[raceName], time)
    end
  else
    if driftScore and driftScore ~= 0 then
      veh.FRETimes[raceName] = driftScore
    else
      veh.FRETimes[raceName] = time
    end
  end
  veh.FRECompletions[raceName] = veh.FRECompletions[raceName] or {}
  veh.FRECompletions[raceName].total = (veh.FRECompletions[raceName].total or 0) + 1
  if lastRaceName == raceName then
    local pausedTime = career_modules_pauseTime.getTotalPauseTime()
    local totalTime = time + pausedTime
    if lastRaceTime and os.time() - lastRaceTime < totalTime + 10 then
      print("Adding session to " .. raceName)
      currentSession = currentSession + 1
      if not veh.FRECompletions[raceName].consecutive or veh.FRECompletions[raceName].consecutive < currentSession then
        veh.FRECompletions[raceName].consecutive = currentSession
      end
    end
    lastRaceTime = os.time()
  else
    lastRaceName = raceName
    lastRaceTime = os.time()
    currentSession = 1
    if not veh.FRECompletions[raceName].consecutive then
      veh.FRECompletions[raceName].consecutive = 1
    end
  end
  career_modules_pauseTime.resetPauseTime()
end

local function getFRETimeToVehicle(raceName, inventoryId)
  local veh = vehicles[inventoryId]
  if not veh then return nil end
  return veh.FRETimes and veh.FRETimes[raceName] or nil
end

local function getFRECompletions(raceName, inventoryId)
  local veh = vehicles[inventoryId]
  if not veh then return nil end
  return veh.FRECompletions and veh.FRECompletions[raceName] or nil
end

M.getAllFRETimes = function()
  local invId = career_modules_inventory.getInventoryIdFromVehicleId(be:getPlayerVehicleID(0))
  if not invId then return {} end
  return vehicles[invId].FRETimes
end

M.getAllFRECompletions = function()
  local invId = career_modules_inventory.getInventoryIdFromVehicleId(be:getPlayerVehicleID(0))
  if not invId then return {} end
  return vehicles[invId].FRECompletions
end

-- Garage Localization

M.moveVehicleToGarage = function(id, garage)
  if not garage or not career_modules_garageManager.isGarageSpace(garage) then
    garage = career_modules_garageManager.getNextAvailableSpace()
  end
  if vehicles[id] then 
    vehicles[id].location = garage
    vehicles[id].niceLocation = career_modules_garageManager.garageIdToName(garage)
  end
end

M.deliverVehicle = function(id, money)
  local price = {money = {amount = money, canBeNegative = true}}
  career_modules_payment.pay(price, {label = string.format("Delivering vehicle to garage"), tags = {"delivery"}})
  delayVehicleAccess(id, 120, "delivery")
  M.storeVehicle(id)
end

M.storeVehicle = function(id)
  local garage = getClosestOwnedGarage()
  if vehicles[id] then
    vehicles[id].location = garage.id
    vehicles[id].niceLocation = career_modules_garageManager.garageIdToName(garage.id)
  end
end

M.switchGarageSpots = function(first, second)
  local spot1 = vehicles[first].location
  local spot2 = vehicles[second].location
  if not spot1 or not spot2 then return nil end
  vehicles[first].location = spot2
  vehicles[first].niceLocation = career_modules_garageManager.garageIdToName(spot2)
  vehicles[second].location = spot1
  vehicles[second].niceLocation = career_modules_garageManager.garageIdToName(spot1)
  return true
end

M.getVehicleLocation = function(id)
  if not vehicles[id] then return nil end
  return vehicles[id].location
end

M.saveFRETimeToVehicle = saveFRETimeToVehicle
M.getFRETimeToVehicle = getFRETimeToVehicle
M.getFRECompletions = getFRECompletions
M.calculateSeatingCapacity = calculateSeatingCapacity
M.onWorldReadyState = onWorldReadyState

M.addVehicle = addVehicle
M.removeVehicle = removeVehicle
M.enterVehicle = enterVehicle
M.sellVehicle = sellVehicle
M.sellVehicleFromInventory = sellVehicleFromInventory
M.returnLoanedVehicleFromInventory = returnLoanedVehicleFromInventory
M.expediteRepairFromInventory = expediteRepairFromInventory
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
M.setVehicleRole = setVehicleRole
M.getVehicleRole = getVehicleRole
M.setLicensePlateText = setLicensePlateText
M.getLicensePlateText = getLicensePlateText
M.purchaseLicensePlateText = purchaseLicensePlateText
M.getVehicleThumbnail = getVehicleThumbnail

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
M.onCheckPermission = onCheckPermission
M.onGetRawPoiListForLevel = onGetRawPoiListForLevel

M.getPartConditionsCallback = getPartConditionsCallback
M.applyPartConditions = applyPartConditions
M.teleportedFromBigmap = teleportedFromBigmap
M.setVehicleDirty = setVehicleDirty
M.getDirtiedVehicles = getDirtiedVehicles
M.getVehicles = getVehicles
M.getVehicle = getVehicle
M.isEmpty = isEmpty
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

M.getVehicleUiData = getVehicleUiData

-- RLS
M.getVehicleTimeToAccess = getVehicleTimeToAccess
M.addMeetReputation = addMeetReputation
M.getMeetReputation = getMeetReputation
M.addAccident = addAccident
M.getAccidents = getAccidents
M.addArrest = addArrest
M.addTicket = addTicket
M.getArrests = getArrests
M.getTickets = getTickets
M.addEvade = addEvade
M.getEvades = getEvades
M.addTaxiDropoff = addTaxiDropoff
M.getTaxiDropoffs = getTaxiDropoffs
M.addRepossession = addRepossession
M.getRepossessions = getRepossessions
M.addMovieRental = addMovieRental
M.getMovieRentals = getMovieRentals
M.getClosestOwnedGarage = getClosestOwnedGarage
return M
