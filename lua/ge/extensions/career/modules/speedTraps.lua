-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local leaderboardFolder = "/career/speedTrapLeaderboards/"

M.dependencies = {'career_career', 'gameplay_speedTraps'}



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



local fines = {
  {overSpeed = 6.7056, fine = {money = {amount = 1000, canBeNegative = true}}},
  {overSpeed = 11.176, fine = {money = {amount = 2500, canBeNegative = true}}},
}
local maxFine = {money = {amount = 5000, canBeNegative = true}}

local function getFine(overSpeed)
  for _, fineInfo in ipairs(fines) do
    if overSpeed <= fineInfo.overSpeed then
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

  if vehId ~= be:getPlayerVehicleID(0) then
    return
  end
  local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)

  local veh = getPlayerVehicle(0)
  local highscore, leaderboard = gameplay_speedTrapLeaderboards.addRecord(speedTrapData, playerSpeed, overSpeed, veh)
  
  local playerIsCop = isPlayerInPoliceVehicle()
        if playerIsCop == true then
        else
    
  
  if not inventoryId or hasLicensePlate(inventoryId) then
    local fine = getFine(overSpeed)
    career_modules_payment.pay(fine, {label="Fine for speeding", tags={"fine"}})
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Speedcam_Snapshot')
    ui_message(string.format("Traffic Violation: \n - %q | Fine %d$\n - {{%f | unit: \"speed\":0}} | ({{%f | unit: \"speed\":0}})", core_vehicles.getVehicleLicenseText(veh), fine.money.amount, playerSpeed, speedTrapData.speedLimit), 10, "speedTrap")
  else
    ui_message(string.format("Traffic Violation: \n - No license plate detected | Fine could not be issued\n - {{%f | unit: \"speed\":0}} | ({{%f | unit: \"speed\":0}})", playerSpeed, speedTrapData.speedLimit), 10, "speedTrap")
  end

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
end

local function onRedLightCamTriggered(speedTrapData, playerSpeed)
  local vehId = speedTrapData.subjectID
  if not vehId then
    return
  end

  if vehId ~= be:getPlayerVehicleID(0) then
    return
  end
  local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)

  local veh = getPlayerVehicle(0)

  local playerIsCop = isPlayerInPoliceVehicle()
        if playerIsCop == true then
        else


  if not inventoryId or hasLicensePlate(inventoryId) then
    local fine = {money = {amount = 2000, canBeNegative = true}}
    career_modules_payment.pay(fine, {label="Fine for driving over a red light", tags={"fine"}})
    Engine.Audio.playOnce('AudioGui','event:>UI>Career>Speedcam_Snapshot')
    ui_message(string.format("Traffic Violation (Failure to stop at Red Light): \n - %q | Fine %d$", core_vehicles.getVehicleLicenseText(veh), fine.money.amount), 10, "speedTrap")
  else
    ui_message(string.format("Traffic Violation (Failure to stop at Red Light): \n - No license plate detected | Fine could not be issued"), 10, "speedTrap")
  end
end
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  gameplay_speedTrapLeaderboards.loadLeaderboards(savePath .. leaderboardFolder)
end

local function onSaveCurrentSaveSlot(currentSavePath, oldSaveDate, forceSyncSave)
  -- TODO maybe add option to only save file for current level
  gameplay_speedTrapLeaderboards.saveLeaderboards(currentSavePath .. leaderboardFolder, true)
end

M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered
M.onExtensionLoaded = onExtensionLoaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

return M