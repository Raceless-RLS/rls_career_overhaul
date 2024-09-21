-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local playerData = {trafficActive = 0} -- traffic data, parking data, etc.
local testTrafficAmounts = {traffic = 1, police = 0, parkedCars = 1, active = 1} -- amounts to use if restrict mode is true

M.ensureTraffic = false
M.preStart = true
M.debugMode = not shipping_build

local function getPlayerData()
  return playerData
end

local function setPlayerData(newId, oldId)
  -- oldId is optional and is used if the vehicle was switched
  playerData.isParked = gameplay_parking.getCurrentParkingSpot(newId) and true or false

  if oldId then
    gameplay_parking.disableTracking(oldId)
  end
  if not gameplay_walk.isWalking() then
    gameplay_parking.enableTracking(newId)
  end

  playerData.traffic = gameplay_traffic.getTrafficData()[newId]
  playerData.parking = gameplay_parking.getTrackingData()[newId]
end

local function setTrafficVars()
  -- temporary police adjustment
  gameplay_traffic.setTrafficVars({enableRandomEvents = false})
  gameplay_police.setPursuitVars({arrestRadius = 15, evadeLimit = 30})
  gameplay_parking.setParkingVars({precision = 0.2}) -- allows for relaxed parking detection
end

local function setupTraffic(forceSetup)
  if forceSetup or (gameplay_traffic.getState() == "off" and not gameplay_traffic.getTrafficList(true)[1] and playerData.trafficActive == 0) then
    log("I", "career", "Now spawning traffic for career mode")
    local restrict = settings.getValue('trafficRestrictForCareer')

    -- traffic amount
    local amount = settings.getValue('trafficAmount')
    if amount == 0 then -- auto amount
      amount = gameplay_traffic.getIdealSpawnAmount()
    end
    if not getAllVehiclesByType()[1] then -- if player vehicle does not exist yet
      amount = amount - 1
    end
    if not M.debugMode then
      amount = clamp(amount, 2, 50) -- at least 2 vehicles should get spawned
    end

    -- parked cars amount
    local parkedAmount = settings.getValue('trafficParkedAmount')
    if parkedAmount == 0 then -- auto amount
      parkedAmount = clamp(gameplay_traffic.getIdealSpawnAmount(nil, true), 4, 20)
    end
    if not M.debugMode then
      parkedAmount = clamp(parkedAmount, 2, 50) -- at least 2 vehicles should get spawned
    end

    -- police amount and vehicle pooling
    local policeAmount = M.debugMode and testTrafficAmounts.police or 0 -- temporarily disabled by default
    local extraAmount = policeAmount -- enables traffic pooling
    playerData.trafficActive = restrict and testTrafficAmounts.active or amount -- store the amount here for future usage
    if playerData.trafficActive == 0 then playerData.trafficActive = math.huge end

    --gameplay_traffic.queueTeleport = true -- forces traffic vehicles to teleport away

    -- TEMP: this is a temporary measure; it spawns vehicles far away, but skips the step of force teleporting them
    -- hopefully, this cures the vehicle instability issue
    -- we need to rework the initial loading logic so that the player / camera is already ready, then this hack won't be needed
    local trafficPos, trafficRot, parkingPos
    local trafficSpawnPoint = scenetree.findObject("spawns_refinery")
    local parkingSpawnPoint = scenetree.findObject("spawns_servicestation") -- TODO: replace this with the intended player position (player veh not ready yet)
    if trafficSpawnPoint then
      trafficPos, trafficRot = trafficSpawnPoint:getPosition(), quat(trafficSpawnPoint:getRotation()) * quat(0, 0, 1, 0)
    end
    if parkingSpawnPoint then
      parkingPos = parkingSpawnPoint:getPosition()
    end

    gameplay_parking.setupVehicles(restrict and testTrafficAmounts.parkedCars or parkedAmount, {pos = parkingPos})
    gameplay_traffic.setupTraffic(restrict and testTrafficAmounts.traffic + extraAmount or amount + extraAmount, 0, {policeAmount = policeAmount, simpleVehs = true, autoLoadFromFile = true, pos = trafficPos, rot = trafficRot})
    setTrafficVars()

    M.ensureTraffic = false
  else
    if playerData.trafficActive == 0 then
      playerData.trafficActive = gameplay_traffic.getTrafficVars().activeAmount
    end
    if not career_career.tutorialEnabled then
      setPlayerData(be:getPlayerVehicleID(0))
    end
  end
end

local function playerPursuitActive()
  return playerData.traffic and playerData.traffic.pursuit and playerData.traffic.pursuit.mode ~= 0
end

local function resetPlayerState()
  setPlayerData(be:getPlayerVehicleID(0))
  if playerData.traffic then playerData.traffic:resetAll() end

  setTrafficVars()
end

local function retrieveFavoriteVehicle()
  local inventory = career_modules_inventory
  local favoriteVehicleInventoryId = inventory.getFavoriteVehicle()
  if not favoriteVehicleInventoryId then return end
  local vehInfo = inventory.getVehicles()[favoriteVehicleInventoryId]
  if not vehInfo then return end

  local vehId = inventory.getVehicleIdFromInventoryId(favoriteVehicleInventoryId)
  if vehId then
    local playerVehObj = getPlayerVehicle(0)
    spawn.safeTeleport(be:getObjectByID(vehId), playerVehObj:getPosition(), quatFromDir(playerVehObj:getDirectionVector()), nil, nil, nil, nil, false)
    core_vehicleBridge.executeAction(be:getObjectByID(vehId),'setIgnitionLevel', 0)
  elseif not vehInfo.timeToAccess and not career_modules_insurance.inventoryVehNeedsRepair(favoriteVehicleInventoryId) then
    inventory.spawnVehicle(favoriteVehicleInventoryId, nil,
    function()
      local playerVehObj = getPlayerVehicle(0)
      local vehId = inventory.getVehicleIdFromInventoryId(favoriteVehicleInventoryId)
      spawn.safeTeleport(be:getObjectByID(vehId), playerVehObj:getPosition(), quatFromDir(playerVehObj:getDirectionVector()), nil, nil, nil, nil, false)
    end)
  end
end

local function deleteTrailers(veh)
  local trailerData = core_trailerRespawn.getTrailerData()
  local trailerDataThisVeh = trailerData[veh:getId()]

  if trailerDataThisVeh then
    local trailer = be:getObjectByID(trailerDataThisVeh.trailerId)
    deleteTrailers(trailer)
    career_modules_inventory.removeVehicleObject(career_modules_inventory.getInventoryIdFromVehicleId(trailerDataThisVeh.trailerId))
  end
end

local teleportTrailerJob = function(job)
  local args = job.args[1]
  local vehicle = be:getObjectByID(args.vehicleId)
  local trailer = be:getObjectByID(args.trailerId)
  local vehRot = quat(0,0,1,0) * quat(vehicle:getRefNodeRotation())
  local vehBB = vehicle:getSpawnWorldOOBB()
  local vehBBCenter = vehBB:getCenter()

  local trailerBB = vehicle:getSpawnWorldOOBB()

  spawn.safeTeleport(trailer, vehBBCenter - vehicle:getDirectionVector() * (vehBB:getHalfExtents().y + trailerBB:getHalfExtents().y), vehRot, nil, nil, nil, true, args.resetVeh)

  core_trailerRespawn.getTrailerData()[args.vehicleId] = nil
end

local function teleportToGarage(garageId, veh, resetVeh)
  freeroam_facilities.teleportToGarage(garageId, veh, resetVeh)
  freeroam_bigMapMode.navigateToMission(nil)
  core_vehicleBridge.executeAction(veh,'setIgnitionLevel', 0)

  local trailerData = core_trailerRespawn.getTrailerData()
  local primaryTrailerData = trailerData[veh:getId()]
  if primaryTrailerData then
    local teleportArgs = {
      trailerId = primaryTrailerData.trailerId,
      vehicleId = veh:getId(),
      resetVeh = resetVeh
    }
    -- need to do this with one frame delay, otherwise the safeTeleport gets confused with two vehicles
    core_jobsystem.create(teleportTrailerJob, 0.1, teleportArgs)

    career_modules_inventory.updatePartConditionsOfSpawnedVehicles(
      function()
        local trailer = be:getObjectByID(primaryTrailerData.trailerId)
        deleteTrailers(trailer)
        career_modules_fuel.minimumRefuelingCheck(veh:getId())
      end
    )
  else
    career_modules_fuel.minimumRefuelingCheck(veh:getId())
  end
end

local function onVehicleParkingStatus(vehId, data)
  if not gameplay_missions_missionManager.getForegroundMissionId() and not career_modules_linearTutorial.isLinearTutorialActive() and vehId == be:getPlayerVehicleID(0) then
    if data.event == "valid" then -- this refers to fully stopping while aligned in a parking spot
      if not playerData.isParked then
        playerData.isParked = true
      end
    elseif data.event == "exit" then
      playerData.isParked = false
    end
  end
end

local function onTrafficStarted()
  if not career_career.tutorialEnabled and not gameplay_missions_missionManager.getForegroundMissionId() then
    gameplay_traffic.insertTraffic(be:getPlayerVehicleID(0), true) -- assumes that player vehicle is ready
    setPlayerData(be:getPlayerVehicleID(0))
    gameplay_traffic.setActiveAmount(playerData.trafficActive)

    for k, v in pairs(gameplay_traffic.getTrafficData()) do
      if v.role.name == "police" then
        v.activeProbability = 0.15 -- this should be based on career progression as well as zones
      end
    end
  end
end

local function onTrafficStopped()
  if playerData.traffic then table.clear(playerData.traffic) end

  if M.ensureTraffic then -- temp solution to reset traffic
    setupTraffic(true)
  end
end

local function onPursuitAction(vehId, data)
  if not gameplay_missions_missionManager.getForegroundMissionId() and vehId == be:getPlayerVehicleID(0) then
    if data.type == "start" then -- pursuit started
      gameplay_parking.disableTracking(vehId)
      --core_recoveryPrompt.deactivateAllButtons()
      log("I", "career", "Police pursuing player, now deactivating recovery prompt buttons")
    elseif data.type == "reset" or data.type == "evade" then -- pursuit ended, return to normal
      if not gameplay_walk.isWalking() then
        gameplay_parking.enableTracking(vehId)
      end
      --core_recoveryPrompt.setDefaultsForCareer()
      log("I", "career", "Pursuit ended, now activating recovery prompt buttons")
    elseif data.type == "arrest" then -- pursuit arrest, make the player pay a fine
      local fine = data.mode * data.uniqueOffensesCount * 100 -- fine value is WIP
      --fine = math.min(fine, career_modules_playerAttributes.getAttributeValue("money"))
      career_modules_payment.pay({money = {amount = fine}}, {label = "Fine for being arrested by the police"})
      ui_message(translateLanguage("ui.traffic.policeFine", "You got fined by the police: ")..fine, 5, "careerPursuit")
    end
  end
end

local function onPlayerCameraReady()
  setupTraffic() -- spawns traffic while the loading screen did not fade out yet
end

local function onVehicleSwitched(oldId, newId)
  if not career_career.tutorialEnabled and not gameplay_missions_missionManager.getForegroundMissionId() then
    setPlayerData(newId, oldId)
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if M.preStart and freeroam_specialTriggers and playerData.traffic then -- this cycles all lights triggers, to eliminate lag spikes (move this code later)
    if not playerData.preStartTicks then playerData.preStartTicks = 6 end
    playerData.preStartTicks = playerData.preStartTicks - 1
    for k, v in pairs(freeroam_specialTriggers.getTriggers()) do
      if not v.vehIds[be:getPlayerVehicleID(0)] then
        if playerData.preStartTicks == 3 then
          freeroam_specialTriggers.setTriggerActive(k, true, true)
        elseif playerData.preStartTicks == 0 then
          freeroam_specialTriggers.setTriggerActive(k, false, true)
          M.preStart = false
        end
      end
    end
    if playerData.preStartTicks == 0 then playerData.preStartTicks = nil end
  end

  if not playerPursuitActive() then return end

  -- for now, prevent pursuit softlock by making the police give up
  if not playerData.pursuitStuckTimer then playerData.pursuitStuckTimer = 0 end
  if (playerData.traffic.speed < 3 and playerData.traffic.pursuit.timers.arrest == 0 and playerData.traffic.pursuit.timers.evade == 0)
  or not gameplay_police.getNearestPoliceVehicle(be:getPlayerVehicleID(0), false, true) then
    playerData.pursuitStuckTimer = playerData.pursuitStuckTimer + dtSim
    if playerData.pursuitStuckTimer >= 10 then
      log("I", "career", "Ending pursuit early due to conditions")
      gameplay_police.evadeVehicle(be:getPlayerVehicleID(0), true)
      playerData.pursuitStuckTimer = 0
    end
  else
    playerData.pursuitStuckTimer = 0
  end
end

local function onCareerModulesActivated(alreadyInLevel)
  if alreadyInLevel then
    setupTraffic()
  end
end

local function onClientStartMission()
  setupTraffic()
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

local function showPosition(pos)
  local camDir = pos - getPlayerVehicle(0):getPosition()
  if gameplay_walk.isWalking() then
    gameplay_walk.setRot(camDir)
  end

  local camDirLength = camDir:length()
  local rayDist = castRayStatic(getPlayerVehicle(0):getPosition(), camDir, camDirLength)

  if rayDist < camDirLength then
    -- Play cam path to show where the position is
    local camPath = buildCamPath(pos, camDir)
    local initData = {}
    initData.finishedPath = function(this)
      core_camera.setVehicleCameraByIndexOffset(0, 1)
    end
    core_paths.playPath(camPath, 0, initData)
  end
end

M.getPlayerData = getPlayerData
M.retrieveFavoriteVehicle = retrieveFavoriteVehicle
M.playerPursuitActive = playerPursuitActive
M.resetPlayerState = resetPlayerState
M.teleportToGarage = teleportToGarage
M.showPosition = showPosition

M.onPlayerCameraReady = onPlayerCameraReady
M.onTrafficStarted = onTrafficStarted
M.onTrafficStopped = onTrafficStopped
M.onPursuitAction = onPursuitAction
M.onVehicleParkingStatus = onVehicleParkingStatus
M.onVehicleSwitched = onVehicleSwitched
M.onCareerModulesActivated = onCareerModulesActivated
M.onClientStartMission = onClientStartMission
M.onUpdate = onUpdate

return M