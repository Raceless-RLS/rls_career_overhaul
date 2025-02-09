-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local leaderboardFolder = "/career/speedTrapLeaderboards/"

M.dependencies = {'career_career', 'gameplay_speedTraps', 'gameplay_traffic'}
local fines = {
  {overSpeed = 6.7056, fine = {money = {amount = 35, canBeNegative = true}}},
  {overSpeed = 11.176, fine = {money = {amount = 70, canBeNegative = true}}},
}
local maxFine = {money = {amount = 100, canBeNegative = true}}
local playerPursuiting = false

local function getFineFromSpeed(overSpeed)
  for _, fineInfo in ipairs(fines) do
    if overSpeed <= fineInfo.overSpeed then
      fineInfo.fine.money.amount = fineInfo.fine.money.amount * (career_modules_hardcore.isHardcoreMode() and 10 or 1)
      return fineInfo.fine
    end
  end
  return maxFine
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

local function onSpeedTrapTriggered(speedTrapData, playerSpeed, overSpeed)
  if not speedTrapData.speedLimit then return end
  local vehId = speedTrapData.subjectID
  if not vehId then
    return
  end

  local playerRole = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)].role.name
  if playerPursuiting and playerRole == "police" then
    return
  end

  if vehId ~= be:getPlayerVehicleID(0) then
    return
  end
  local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)

  local veh = getPlayerVehicle(0)
  local vehInfo = career_modules_inventory.getVehicles()[inventoryId]

  local penaltyType
  if not inventoryId then
    penaltyType = "default"
  elseif hasLicensePlate(inventoryId) then
    if vehInfo.owned then
      penaltyType = "default"
    elseif vehInfo.loanType == "work" then
      penaltyType = "workVehicle"
    end
  else
    penaltyType = "noLicensePlate"
  end

  if penaltyType == "default" then
    local fine = getFineFromSpeed(overSpeed)
    local message = ""
    
    if playerRole == "police" then
      message = string.format("Traffic Violation (Officer Misconduct): \n - %q | Fine %d$\n - {{%f | unit: \"speed\":0}} | ({{%f | unit: \"speed\":0}})\n - Abuse of power is not permitted", core_vehicles.getVehicleLicenseText(veh), fine.money.amount, playerSpeed, speedTrapData.speedLimit)
    else
      message = string.format("Traffic Violation: \n - %q | Fine %d$\n - {{%f | unit: \"speed\":0}} | ({{%f | unit: \"speed\":0}})", core_vehicles.getVehicleLicenseText(veh), fine.money.amount, playerSpeed, speedTrapData.speedLimit)
    end
    
    career_modules_payment.pay(fine, {label="Fine for speeding", tags={"fine"}})
    ui_message(message, 10, "speedTrap")
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Speedcam_Snapshot')

  elseif penaltyType == "noLicensePlate" then
    ui_message(string.format("Traffic Violation: \n - No license plate detected | Fine could not be issued\n - {{%f | unit: \"speed\":0}} | ({{%f | unit: \"speed\":0}})", playerSpeed, speedTrapData.speedLimit), 10, "speedTrap")
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Speedcam_Snapshot')

  elseif penaltyType == "workVehicle" then
    if vehInfo.owningOrganization then
      local fine = {}
      fine[vehInfo.owningOrganization .. "Reputation"] = {amount = 10, canBeNegative = true}
      career_modules_payment.pay(fine, {label="Reputation cost for speeding", tags={"fine"}})
    end
  end

  local highscore, leaderboard = gameplay_speedTrapLeaderboards.addRecord(speedTrapData, playerSpeed, overSpeed, veh)

  local message
  if highscore then
    if leaderboard[2] then
      message = {txt="ui.freeroam.speedTrap.newRecord", context={recordedSpeed = playerSpeed, previousSpeed = leaderboard[2].speed}}
    else
      message = {txt="ui.freeroam.speedTrap.newRecordNoOld", context={recordedSpeed = playerSpeed}}
    end
  else
    message = {txt="ui.freeroam.speedTrap.noNewRecord", context={recordedSpeed = playerSpeed, recordSpeed = leaderboard[1].speed}}
  end

  ui_message(message, 10, 'speedTrapRecord')
end

local function onRedLightCamTriggered(speedTrapData, playerSpeed)
  local vehId = speedTrapData.subjectID
  if not vehId then
    return
  end

  local playerRole = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)].role.name
  if playerPursuiting and playerRole == "police" then
    return
  end

  if vehId ~= be:getPlayerVehicleID(0) then
    return
  end
  local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)

  local veh = getPlayerVehicle(0)
  if not inventoryId or hasLicensePlate(inventoryId) then
    local fine = {money = {amount = 500 * (career_modules_hardcore.isHardcoreMode() and 2 or 1), canBeNegative = true}}
    local message = ""
    
    if playerRole == "police" then
      message = string.format("Traffic Violation (Officer Misconduct): \n - %q | Fine %d$\n - Abuse of power is not permitted", core_vehicles.getVehicleLicenseText(veh), fine.money.amount)
    else
      message = string.format("Traffic Violation (Failure to stop at Red Light): \n - %q | Fine %d$", core_vehicles.getVehicleLicenseText(veh), fine.money.amount)
    end
    
    career_modules_payment.pay(fine, {label="Fine for driving over a red light", tags={"fine"}})
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Speedcam_Snapshot')
    ui_message(message, 10, "speedTrap")
  else
    ui_message(string.format("Traffic Violation (Failure to stop at Red Light): \n - No license plate detected | Fine could not be issued"), 10, "speedTrap")
  end
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()

  gameplay_speedTrapLeaderboards.loadLeaderboards(savePath .. leaderboardFolder)
end

local function onSaveCurrentSaveSlot(currentSavePath)
  -- TODO maybe add option to only save file for current level
  gameplay_speedTrapLeaderboards.saveLeaderboards(currentSavePath .. leaderboardFolder, true)
end

local function onPursuitAction(id, pursuitData)
  local playerVehicleId = be:getPlayerVehicleID(0)

  if id ~= playerVehicleId then
      if pursuitData.type == "start" then
          playerPursuiting = true
      elseif pursuitData.type == "evade" or pursuitData.type == "reset" then
          playerPursuiting = false
      elseif pursuitData.type == "arrest" then
          playerPursuiting = false
      end
  end
end

M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered
M.onExtensionLoaded = onExtensionLoaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onPursuitAction = onPursuitAction

return M