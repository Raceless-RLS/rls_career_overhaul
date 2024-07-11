-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {}

local testDriveVehInfo
local isCloseToSpawnedVehicle
local didTestDrive
local freezeVehicleCounter
local hasLeftTheSale = true
local inspectScreenActive = false
local playStateActive

local inspectScreenDist = 6.5
local leaveSaleDist = 20
local activateTetherDist = 17
local inspectTether, leaveSaleTether
local testDriveInfo


local function resetSomeData()
  freezeVehicleCounter = 5
  didTestDrive = false
  hasLeftTheSale = true
end

local function onInspectScreenChanged(enabled)
  inspectScreenActive = enabled
end

local function setInspectScreen(enabled)
  if enabled == inspectScreenActive then return end
  if enabled then
    guihooks.trigger('ChangeState', {state = 'inspectVehicle', params = {}})
  else
    guihooks.trigger('ChangeState', {state = 'play', params = {}})
  end
end

local function despawnCurrentVehicle()
  if not testDriveVehInfo then return end

  local veh = be:getObjectByID(testDriveVehInfo.vehId)
  if veh then
    veh:delete()
    testDriveVehInfo = nil
  end

  setInspectScreen(false)
end

local function spawnVehicle(shopId)
  local vehicleInfo = career_modules_vehicleShopping.getVehiclesInShop()[shopId]
  local spawnOptions = {}
  spawnOptions.config = vehicleInfo.key
  spawnOptions.autoEnterVehicle = false
  local newVeh = core_vehicles.spawnNewVehicle(vehicleInfo.model_key, spawnOptions)
  core_vehicleBridge.executeAction(newVeh,'setIgnitionLevel', 0)
  core_vehicleBridge.executeAction(newVeh, 'setFreeze', true)
  newVeh:queueLuaCommand(string.format("partCondition.initConditions(nil, %d, nil, %f)", vehicleInfo.Mileage, career_modules_vehicleShopping.getVisualValueFromMileage(vehicleInfo.Mileage)))
  if vehicleInfo.aggregates.Type.Trailer then
    gameplay_walk.addVehicleToBlacklist(newVeh:getId())
  end
  return newVeh
end

local function showVehicle(vehicleInfo)
  if testDriveVehInfo then
    despawnCurrentVehicle()
  end

  local vehObj
  if vehicleInfo then
    vehObj = spawnVehicle(vehicleInfo.shopId)
    hasLeftTheSale = false
    testDriveVehInfo = {shopId = vehicleInfo.shopId, vehId = vehObj:getID(), name = vehicleInfo.Brand .. " " .. vehicleInfo.Name, value = vehicleInfo.Value}

    career_modules_testDrive.resetData()
  end

  return vehObj
end

local function checkDamage()
  career_modules_insurance.genericVehNeedsRepair(testDriveVehInfo.vehId,
    function(needsRepair)
      -- only make a claim if the vehicle is damaged
      if needsRepair then
        career_modules_insurance.makeTestDriveDamageClaim(testDriveVehInfo)
      end
      career_modules_vehicleDeletionService.flagForDeletion(testDriveVehInfo.vehId)
    end
  )
end

local function stopInspection()
  if not testDriveVehInfo then return end

  setInspectScreen(false)
  checkDamage()
  resetSomeData()
end

local function defineTestDriveInfo(vehicleInfo, parkingSpot)
  if vehicleInfo.sellerId == "private" then
    testDriveInfo = {
      timeLimit = 120,
      abandonFees = 0
    }
  else
    local dealership = freeroam_facilities.getDealership(vehicleInfo.sellerId)
    local route
    if dealership.testDrive then
      if dealership.testDrive.parkingSpotRoutes then
        for i, parkingSpotRoute in pairs(dealership.testDrive.parkingSpotRoutes) do
          if parkingSpotRoute.parkingSpotName == parkingSpot.name then
            route = parkingSpotRoute.route
          end
        end
      end
      testDriveInfo = {
        timeLimit = dealership.testDrive.timeLimit,
        areaLimit = dealership.testDrive.areaLimit,
        abandonFees = dealership.testDrive.abandonFees or 0,
        route = route,
        dealershipName = dealership.name,
        dealershipPreview = dealership.preview
      }
      if dealership.testDrive.enableEndParkingSpot then
        testDriveInfo.endParkingSpot = parkingSpot
      end
    else
      testDriveInfo = {}
      log('W','testDrive', "Dealership : '" .. dealership.name .. "' doesn't have any 'testDriveRules' which shouldn't be possible. At least one constraint has to be given")
    end
  end

  testDriveInfo.vehicleInfo = vehicleInfo
end

local function turnTowardsPos(pos)
  core_vehicleBridge.requestValue(getPlayerVehicle(0), function()
    gameplay_walk.setRot(pos - getPlayerVehicle(0):getPosition())
  end , 'ping')
end

local function leaveSaleCallback()
  if not testDriveVehInfo then return end
  if not leaveSaleTether then return end

  core_jobsystem.create(function(job)
    setInspectScreen(false)
    job.sleep(0.1)
    -- always inform the player that they left the sale
    if career_modules_testDrive.isActive() then
      -- end testdrive, no TP, just stop
      career_modules_testDrive.abandonTestDrive()
    else
      ui_message("You have left the sale.")
    end
    resetSomeData()
    checkDamage()
  end,1)
  career_modules_tether.removeTether(leaveSaleTether)
  leaveSaleTether = nil
  dump("Leaving sale...")
end

local function startInspection(vehicleInfo, teleportToVehicle)
  core_jobsystem.create(function(job)

    if not hasLeftTheSale then
      leaveSaleCallback()
      job.sleep(0.2)
    end

    local vehObj = showVehicle(vehicleInfo)
    if not vehObj then return end

    local parkingSpot
    local spawnPointElsewhere

    if vehicleInfo.sellerId == "private" then
      parkingSpot = gameplay_parking.getParkingSpots().byName[vehicleInfo.parkingSpotName]
      spawnPointElsewhere = true
    else
      local dealership = freeroam_facilities.getDealership(vehicleInfo.sellerId)
      local parkingSpots = freeroam_facilities.getParkingSpotsForFacility(dealership)
      parkingSpot = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(vehObj:getID(), parkingSpots)

      if vehicleInfo.sellerId == career_modules_vehicleShopping.getCurrentSellerId() then
        gameplay_walk.setWalkingMode(true)
        turnTowardsPos(parkingSpot.pos)
      else
        spawnPointElsewhere = true
      end
    end

    -- Check if there is a vehicle already in the spot and teleport it away
    local hasVehicles, vehicleIds = parkingSpot:hasAnyVehicles()
    if hasVehicles then
      for _, vehId in ipairs(vehicleIds) do
        gameplay_traffic.forceTeleport(vehId)
      end
    end

    parkingSpot:moveResetVehicleTo(vehObj:getID(), nil, nil, nil, nil, true)

    if teleportToVehicle then
      career_modules_quickTravel.quickTravelToPos(parkingSpot.pos, true)
    else
      if spawnPointElsewhere then
        core_groundMarkers.setFocus(parkingSpot.pos)
      end
    end

    defineTestDriveInfo(vehicleInfo, parkingSpot)
    leaveSaleTether = nil
  end,1)
end

local function buySpawnedVehicle()
  local vehObj = be:getObjectByID(testDriveVehInfo.vehId)
  core_vehicleBridge.executeAction(vehObj, 'setFreeze', false)
  career_modules_vehicleShopping.buySpawnedVehicle(testDriveVehInfo)
  career_modules_tether.removeTether(leaveSaleTether)
  leaveSaleTether = nil
  resetSomeData()
  testDriveVehInfo = nil --now the vehicle belongs to the player
  setInspectScreen(false)
end

local function sendUIData()
  local veh = be:getObjectByID(testDriveVehInfo.vehId)
  if not veh then return end

  core_vehicleBridge.requestValue(veh,
    function(res)
      guihooks.trigger('inspectVehicleData',
      {
        spawnedVehicleInfo = testDriveVehInfo,
        needsRepair = career_modules_insurance.partConditionsNeedRepair(res.result),
        isTutorial = career_modules_linearTutorial and career_modules_linearTutorial.isLinearTutorialActive() or false,
        didTestDrive = didTestDrive,
        claimPrice = career_modules_insurance.getTestDriveClaimPrice()
      })
    end,
    'getPartConditions')
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if not testDriveVehInfo then return end

  local vehObj = be:getObjectByID(testDriveVehInfo.vehId)

  local playerVehObj = getPlayerVehicle(0)
  local distanceToVeh = vehObj:getPosition():distance(playerVehObj:getPosition())
  isCloseToSpawnedVehicle = distanceToVeh < inspectScreenDist

  if not leaveSaleTether and distanceToVeh < activateTetherDist then
    leaveSaleTether = career_modules_tether.startVehicleTether(testDriveVehInfo.vehId, leaveSaleDist, false, leaveSaleCallback)
  end

  -- Freeze the vehicle after some frames
  if freezeVehicleCounter then
    freezeVehicleCounter = freezeVehicleCounter - 1
    if freezeVehicleCounter <= 0 then
      core_vehicleBridge.executeAction(vehObj, 'setFreeze', true)
      freezeVehicleCounter = nil
    end
  end

  -- enable/disable the inspect screen only when in play mode or in the inspect screen.
  -- specifically not in the esc menu
  if playStateActive or inspectScreenActive then
    if isCloseToSpawnedVehicle and not hasLeftTheSale then
      setInspectScreen(true)
    else
      if not career_modules_testDrive.isActive() then
        setInspectScreen(false)
      end
    end
  end

end

local function onUIPlayStateChanged(enteredPlay)
  playStateActive = enteredPlay
end

local function onAnyMissionChanged(state, mission)
  if not (career_career and career_career.isActive()) then return end
  if mission then
    if state == "started" then
      showVehicle(nil)
    end
  end
end

local function onVehicleDestroyed(vehId)
  if not testDriveVehInfo then return end
  if vehId == testDriveVehInfo.vehId then
    testDriveVehInfo = nil
  end
end

local function onTestDriveStarted()
  didTestDrive = true
end

local function onAnyMissionChanged(status, id)
  if status == "started" then
    leaveSaleCallback()
  end
end

local function onDeliveryModeStarted()
  leaveSaleCallback()
end

local function startTestDrive()
  career_modules_testDrive.start(testDriveVehInfo.vehId, testDriveInfo)
end

local function getSpawnedVehicleInfo()
  return testDriveVehInfo
end

--this function is only used during tutorial
local function repairVehicleJob(job)
  ui_fadeScreen.start(1)
  job.sleep(1.5)
  career_modules_insurance.payRepairIfNeededGenericVeh(testDriveVehInfo.vehId)
  ui_fadeScreen.stop(1)
  job.sleep(1.0)
end

local function repairVehicle()
  core_jobsystem.create(repairVehicleJob)
end

M.repairVehicle = repairVehicle
M.showVehicle = showVehicle
M.buySpawnedVehicle = buySpawnedVehicle
M.startTestDrive = startTestDrive
M.startInspection = startInspection
M.setInspectScreen = setInspectScreen
M.stopInspection = stopInspection
M.sendUIData = sendUIData
M.getSpawnedVehicleInfo = getSpawnedVehicleInfo

M.onDeliveryModeStarted = onDeliveryModeStarted
M.onVehicleDestroyed = onVehicleDestroyed
M.onInspectScreenChanged = onInspectScreenChanged
M.onAnyMissionChanged = onAnyMissionChanged
M.onTestDriveStarted = onTestDriveStarted
M.onUpdate = onUpdate
M.onUIPlayStateChanged = onUIPlayStateChanged
M.onAnyMissionChanged = onAnyMissionChanged
return M
