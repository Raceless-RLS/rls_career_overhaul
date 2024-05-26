-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local playerData = {
  trafficActive = 0, -- traffic data, parking data, etc.
  pursuitStartTime = nil, -- track the start time of the pursuit
}

local _devTraffic = {traffic = 1, police = 1, parkedCars = 1, active = 1} -- amounts to use while not in shipping mode

M.ensureTraffic = false
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



--RLS
local function getVehicleConfigType()
    local playerVehicleId = be:getPlayerVehicleID(0)
    
    if not playerVehicleId then
        print("Player is not in a vehicle.")
        return nil
    end

    local playerVehicle = be:getObjectByID(playerVehicleId)

    if not playerVehicle then
        print("Unable to find the player's vehicle object.")
        return nil
    end

    local configContent = playerVehicle:getField('partConfig', '')

    if not configContent or configContent == '' then
        print("Player's vehicle has an empty or undefined config path.")
        return nil
    end

    if configContent and string.find(configContent, 'soundscape_siren') then
        return "police"
    else
        print("Player's vehicle is not a police vehicle.")
        return nil
    end
end

local function isPlayerInPoliceVehicle()
    local configType = getVehicleConfigType()
    if configType then
        print("Vehicle Config Type: " .. configType)
        if configType == "police" then
            print("Player is in a police vehicle!")
            return true
        else
            print("Player is not in a police vehicle.")
            return false
        end
    end
    return false
end

local function endPolicePursuit()
  local playerVehicleID = be:getPlayerVehicleID(0)
  if playerVehicleID then
    gameplay_police.setPursuitMode(0, playerVehicleID)
  end
end


local function setTrafficVars()
    -- temporary police adjustment
    local playerIsCop = isPlayerInPoliceVehicle()
    if playerIsCop == true then
        gameplay_traffic.setTrafficVars({enableRandomEvents = true})    
        print("random events on")
    else
        gameplay_traffic.setTrafficVars({enableRandomEvents = false})
        print("random events off")
    end
    gameplay_police.setPursuitVars({arrestRadius = 15, evadeLimit = 50})
    gameplay_parking.setParkingVars({precision = 0.2}) -- allows for relaxed parking detection
end

local function setupTraffic(forceSetup)
    local playerIsCop = isPlayerInPoliceVehicle()
    if playerIsCop == true then
        if forceSetup or (gameplay_traffic.getState() == "off" and not gameplay_traffic.getTrafficList(true)[1] and playerData.trafficActive == 0) then
            log("I", "career", "Now spawning traffic for career mode")
            -- TODO: revise this
            local amount = clamp(gameplay_traffic.getIdealSpawnAmount(), 4, 10) -- returns amount from user settings; at least 3 vehicles should get spawned
            if not getAllVehiclesByType()[1] then -- if player vehicle does not exist yet
                amount = amount - 1
            end
            local policeAmount = 0
            print("police amount 0")
            --local policeAmount = 2 -- temporarily disabled by default
            local extraAmount = policeAmount -- enables traffic pooling
            playerData.trafficActive = M.debugMode and _devTraffic.active or amount -- store the amount here for future usage
            if playerData.trafficActive == 0 then playerData.trafficActive = math.huge end

            --gameplay_traffic.queueTeleport = true -- forces traffic vehicles to teleport away

            -- TEMP: this is a temporary measure; it spawns vehicles far away, but skips the step of force teleporting them
            -- hopefully, this cures the vehicle instability issue
            local trafficPos, trafficRot, parkingPos
            local trafficSpawnPoint = scenetree.findObject("spawns_refinery")
            local parkingSpawnPoint = scenetree.findObject("spawns_servicestation") -- TODO: replace this with the intended player position (player veh not ready yet)
            if trafficSpawnPoint then
                trafficPos, trafficRot = trafficSpawnPoint:getPosition(), quat(trafficSpawnPoint:getRotation()) * quat(0, 0, 1, 0)
            end
            if parkingSpawnPoint then
                parkingPos = parkingSpawnPoint:getPosition()
            end

            gameplay_parking.setupVehicles(M.debugMode and _devTraffic.parkedCars, {pos = parkingPos})
            gameplay_traffic.setupTraffic(M.debugMode and _devTraffic.traffic + extraAmount or amount + extraAmount, 0, {policeAmount = policeAmount, simpleVehs = true, autoLoadFromFile = true, pos = trafficPos, rot = trafficRot})
            setTrafficVars()

            M.ensureTraffic = false
        else  -- Added else block to handle the alternative condition
            if playerData.trafficActive == 0 then
                playerData.trafficActive = gameplay_traffic.getTrafficVars().activeAmount
            end
            if not career_career.tutorialEnabled then
                setPlayerData(be:getPlayerVehicleID(0))
            end
        end  -- Added end to close the nested if-else block
    else  -- Added else block to handle playerIsCop == false case
        if forceSetup or (gameplay_traffic.getState() == "off" and not gameplay_traffic.getTrafficList(true)[1] and playerData.trafficActive == 0) then
            log("I", "career", "Now spawning traffic for career mode")
            -- TODO: revise this
            local amount = clamp(gameplay_traffic.getIdealSpawnAmount(), 4, 10) -- returns amount from user settings; at least 3 vehicles should get spawned
            if not getAllVehiclesByType()[1] then -- if player vehicle does not exist yet
                amount = amount - 1
            end
            local policeAmount = 2
            print("police amount 2")
            --local policeAmount = 2 -- temporarily disabled by default
            local extraAmount = policeAmount -- enables traffic pooling
            playerData.trafficActive = M.debugMode and _devTraffic.active or amount -- store the amount here for future usage
            if playerData.trafficActive == 0 then playerData.trafficActive = math.huge end

            --gameplay_traffic.queueTeleport = true -- forces traffic vehicles to teleport away

            -- TEMP: this is a temporary measure; it spawns vehicles far away, but skips the step of force teleporting them
            -- hopefully, this cures the vehicle instability issue
            local trafficPos, trafficRot, parkingPos
            local trafficSpawnPoint = scenetree.findObject("spawns_refinery")
            local parkingSpawnPoint = scenetree.findObject("spawns_servicestation") -- TODO: replace this with the intended player position (player veh not ready yet)
            if trafficSpawnPoint then
                trafficPos, trafficRot = trafficSpawnPoint:getPosition(), quat(trafficSpawnPoint:getRotation()) * quat(0, 0, 1, 0)
            end
            if parkingSpawnPoint then
                parkingPos = parkingSpawnPoint:getPosition()
            end

            gameplay_parking.setupVehicles(M.debugMode and _devTraffic.parkedCars, {pos = parkingPos})
            gameplay_traffic.setupTraffic(M.debugMode and _devTraffic.traffic + extraAmount or amount + extraAmount, 0, {policeAmount = policeAmount, simpleVehs = true, autoLoadFromFile = true, pos = trafficPos, rot = trafficRot})
            setTrafficVars()

            M.ensureTraffic = false
        else  -- Added else block to handle the alternative condition
            if playerData.trafficActive == 0 then
                playerData.trafficActive = gameplay_traffic.getTrafficVars().activeAmount
            end
            if not career_career.tutorialEnabled then
                setPlayerData(be:getPlayerVehicleID(0))
            end
        end  -- Added end to close the nested if-else block
    end  -- Added end to close the main if-else block
end  -- Added end to close the function


--RLS
local function displayMessage(message, duration)
    ui_message(message, duration, "yourMessageCategory")
end


local function hasLicensePlate(inventoryId)
  for partId, part in pairs(career_modules_partInventory.getInventory()) do
    if part.location == inventoryId then
      if string.find(part.name, "licenseplate") then
        return true
      end
    end
  end
end

local function onPursuitAction(vehId, data)
    local playerIsCop = isPlayerInPoliceVehicle()
    local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)

    if data.type == "start" then -- pursuit started
        playerData.pursuitStartTime = os.time()
        gameplay_parking.disableTracking(vehId)
        -- core_recoveryPrompt.deactivateAllButtons()
        log("I", "career", "Police pursuing player, now deactivating recovery prompt buttons")                     
        elseif data.type == "reset" then -- pursuit ended, return to normal
        if not gameplay_walk.isWalking() then
            gameplay_parking.enableTracking(vehId)
            if playerIsCop == true then
                endPolicePursuit()
                print("Reset")
                -- Additional code specific to when the player is a cop
            elseif playerIsCop == false then
                    print("Player is not a cop")          
            end
            end
            -- core_recoveryPrompt.setDefaultsForCareer()
            log("I", "career", "Pursuit ended, now activating recovery prompt buttons")                       
        elseif data.type == "evade" then 
            if not gameplay_walk.isWalking() then
                gameplay_parking.enableTracking(vehId)
                if playerIsCop == true then
                    local pity = -1250
                    career_saveSystem.saveCurrent()
                    career_modules_payment.pay({money = {amount = pity}}, {label = "Fine for being arrested by the police"})
                    ui_message("The suspect got away, Here is $1250 for repairs", 5)
                    career_saveSystem.saveCurrent()
                else
                    if playerIsCop == false then
                        local pursuitEndTime = os.time()
                        local pursuitDuration = pursuitEndTime - playerData.pursuitStartTime
                        if not inventoryId or hasLicensePlate(inventoryId) then
                            local reward = pursuitDuration * (12 * data.uniqueOffensesCount)
                            career_modules_payment.pay({money = {amount = -reward}}, {label = "Fine for being arrested by the police"})
                            ui_message("You sold your dashcam footage for $" .. reward, 5)
                            endPolicePursuit()
                            playerData.pursuitStartTime = nil
                                    if targetVeh.role.name == 'suspect' then
                                         targetVeh.role:setAction('clear')
                                         suspectActive = false
                                    end
                            career_saveSystem.saveCurrent()
                        else
                             local reward = pursuitDuration * (30 * data.uniqueOffensesCount)
                            career_modules_payment.pay({money = {amount = -reward}}, {label = "Fine for being arrested by the police"})
                            ui_message("Because you had no plates, your dashcam footage was able to go viral $" .. reward, 5)
                            endPolicePursuit()
                            playerData.pursuitStartTime = nil
                                    if targetVeh.role.name == 'suspect' then
                                         targetVeh.role:setAction('clear')
                                         suspectActive = false
                                    end
                            career_saveSystem.saveCurrent()
                        end
                    end
                end
                -- core_recoveryPrompt.setDefaultsForCareer()
                log("I", "career", "Pursuit ended, now activating recovery prompt buttons")
            end
        elseif data.type == "arrest" then -- pursuit arrest, make the player pay a fine
            if playerIsCop == true then
                local pursuitEndTime = os.time()
                local pursuitDuration = pursuitEndTime - playerData.pursuitStartTime
                local bonus = pursuitDuration * (18 * data.uniqueOffensesCount)
                --local bonus = data.mode * data.uniqueOffensesCount + pursuitDuration * 50
                print(pursuitDuration)
                career_saveSystem.saveCurrent()
                career_modules_payment.pay({money = {amount = -bonus}}, {label = "Fine for being arrested by the police"})
                ui_message("Arrest Bonus: $" .. bonus, 5)
            else
              if not inventoryId or hasLicensePlate(inventoryId) then
                    local fine = data.mode * data.uniqueOffensesCount * 1000 -- fine value is WIP
                    career_saveSystem.saveCurrent()
                    career_modules_payment.pay({money = {amount = fine}}, {label = "Fine for being arrested by the police"})
                    ui_message(translateLanguage("ui.traffic.policeFine", "You got fined by the police: $")..fine, 5, "careerPursuit")               
                    career_saveSystem.saveCurrent()
                    else
                    local fine = data.mode * data.uniqueOffensesCount * 5000 -- fine value is WIP
                    career_saveSystem.saveCurrent()
                    career_modules_payment.pay({money = {amount = fine}}, {label = "Fine for being arrested by the police"})
                    ui_message(translateLanguage("ui.traffic.policeFine", "You got fined by the police extra for missing licenseplate: $")..fine, 5, "careerPursuit")
                    career_saveSystem.saveCurrent()
                    end        
            end
        end
    end


    local function onVehicleSwitched(oldId, newId)
    local playerIsCop = isPlayerInPoliceVehicle()
  if not career_career.tutorialEnabled and not gameplay_missions_missionManager.getForegroundMissionId() then
    setPlayerData(newId, oldId)
    setTrafficVars()
        if playerIsCop == true then
           -- setupTraffic(true)
            print("onVehicleSwitched to player is cop")
        else
            --setupTraffic(true)
            print("onvehicleswitched to player is not a cop")
        end
   --endPolicePursuit()
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
  freeroam_bigMapMode.navigateToMission(nil)
  freeroam_facilities.teleportToGarage(garageId, veh, resetVeh)

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
      end
    )
  end
end

local function onSaveCurrentSaveSlot(currentSavePath)
end

local function onVehicleParkingStatus(vehId, data)
  if not gameplay_missions_missionManager.getForegroundMissionId() and not career_modules_linearTutorial.isLinearTutorialActive() and vehId == be:getPlayerVehicleID(0) then
    if data.event == "valid" then -- this refers to fully stopping while aligned in a parking spot
      if not playerData.isParked then
        playerData.isParked = true
        --RLS ADDED BACK SAVE ON PARK
        career_saveSystem.saveCurrent()
        log("I", "career", "Player saved progress in parking spot")
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
        v.activeProbability = 0.65 -- this should be based on career progression as well as zones
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





local function onPlayerCameraReady()
  setupTraffic() -- spawns traffic while the loading screen did not fade out yet
end



local function onUpdate(dtReal, dtSim, dtRaw)
  if not playerPursuitActive() then 
    --endPolicePursuit()
    return
  end

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

local function onExtensionLoaded()
end

local function onClientStartMission()
  setupTraffic()
end

M.getPlayerData = getPlayerData
M.retrieveFavoriteVehicle = retrieveFavoriteVehicle
M.playerPursuitActive = playerPursuitActive
M.resetPlayerState = resetPlayerState
M.teleportToGarage = teleportToGarage

M.displayMessage = displayMessage
M.isPlayerInPoliceVehicle = isPlayerInPoliceVehicle
M.getVehicleConfigType = getVehicleConfigType

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onPlayerCameraReady = onPlayerCameraReady
M.onTrafficStarted = onTrafficStarted
M.onTrafficStopped = onTrafficStopped
M.onPursuitAction = onPursuitAction
M.onVehicleParkingStatus = onVehicleParkingStatus
M.onVehicleSwitched = onVehicleSwitched
M.onCareerModulesActivated = onCareerModulesActivated
M.onClientStartMission = onClientStartMission
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
