-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Mountain_race'

local finalWaypointName = 'stfinish'
local playerInstance = 'scenario_player0'
local aiInstance = 'scenario_crew'
local running = false
local playerWon = false
local aiWon = false
local aiArrived = false
local damageFail = false
local messageText = ""
local lastMessage = ""
local distance = 0
local playerDamage = 0
local aiDamage = 0

local function reset()
  running = false
  playerWon = false
  aiWon = false
  damageFail = false
  aiArrived = false
  playerDamage = 0
  aiDamage = 0
  distance = 0
  lastMessage = ""
end

local function fail(reason)
  scenario_scenarios.finish({failed = reason})
  reset()
end

local function success(reason)
  scenario_scenarios.finish({msg = reason})
  reset()
end

local function onRaceResult(outcome)
  if aiWon then
    fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_follow.fail.msg')
  end
  if damageFail then
    fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_follow.damage.msg')
  end
  if playerWon then
    success('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_follow.win.msg')
  end
end

local function onCountdownStarted()
  reset()

  local aiData = jsonReadFile('levels/rls_west_coast_usa/scenarios/busdriver_stunt/busdriver_stunt_follow_scenario_crew.track.json')
  scenetree.findObject(aiInstance):queueLuaCommand("ai.startFollowing("..serialize(aiData.recording)..")")
end

local function onRaceStart()
  -- log('I', logTag,'onRaceStart called')
  running = true
end

local function onPreRender(dt)

  if running == true then
    local playerVehicle = scenetree.findObject(playerInstance)
    local playerVehicleData = map.objects[playerVehicle:getID()]
    playerDamage = playerVehicleData.damage
    local playerVehiclePos = playerVehicle:getPosition()

    local aiVehicle = scenetree.findObject(aiInstance)
    local aiVehicleData = map.objects[aiVehicle:getID()]
    aiDamage = aiVehicleData.damage
    local aiVehiclePos = aiVehicle:getPosition()
    distance = (playerVehiclePos - aiVehiclePos):len()
  end

  if playerDamage > 10000 or aiDamage > 2000 then
    onRaceResult()
    damageFail = true
  end

  if distance > 140 then
    messageText = "Keep up with the film crew!"
  else
    messageText = ""
  end

  if messageText ~= lastMessage then
    helper.realTimeUiDisplay(messageText)
    lastMessage = messageText
  end

end

local function onRaceWaypointReached(data)
  --log('I', logTag,'onRaceWaypointReached called ')
  --dump(data)
  local playerVehicleId = be:getPlayerVehicleID(0)

  if data.waypointName == finalWaypointName and data.vehicleId == playerVehicleId then
    local playerVehicleId = be:getPlayerVehicleID(0)
    if data.vehicleId ~= playerVehicleId and distance > 200 then
      aiWon = true
      onRaceResult()
    else
      playerWon = true
      onRaceResult()
    end
  end
end

M.onPreRender = onPreRender
M.onCountdownStarted = onCountdownStarted
M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult
return M