-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'mountainRace'

local finalWaypointName = 'scenario_finish1'
local finalTriggerName = 'trigger_finish1'
local playerInstance = 'scenario_player0'
local aiInstance = 'scenario_opponent'
local aiDamageThreshold = 10000

local playerWon = false
local aiFinished = false
local playerCrash = false
local aiCrash = false
local running = false
local aiDamage = 0

local function reset()
  running = false
  playerWon = false
  playerCrash = false
  aiCrash = false
  aiFinished = false
  aiDamage = 0

  scenetree.findObject(aiInstance):queueLuaCommand('ai.stopFollowing()')
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
  if aiCrash then
    fail('This is not banger racing!')
  end
  if playerWon then
    success('Well done !')
  else
    fail('You lost the race...')
  end
end

local function onCountdownStarted()
  reset()
end

local function onRaceStart()
  -- log('I', logTag,'onRaceStart called')
  local aiData = jsonReadFile('levels/rls_west_coast_usa/scenarios/mountain_race.track.json')
  scenetree.findObject(aiInstance):queueLuaCommand("ai.startFollowing("..serialize(aiData.recording)..")")
  running = true
end

local function onRaceTick()
  if running == true then
    local aiVehicle = scenetree.findObject(aiInstance)
    local aiVehicleData = map.objects[aiVehicle:getID()]
    aiDamage = aiVehicleData.damage

    if aiDamage > 10000 then
      aiCrash = true
      onRaceResult()
    end
  end
end

local function onRaceWaypointReached(data)
  if data.vehicleName == playerInstance and data.waypointName == finalWaypointName then
    if aiFinished == false then
      playerWon = true
    end
    onRaceResult()
  end
end

local function onBeamNGTrigger(data)
  if scenario_scenarios.getScenario().timer > 30 and data.subjectName == aiInstance and data.triggerName == finalTriggerName and data.event == 'enter' then
    -- timer is used to prevent false trigger at start
    aiFinished = true
  end
end

M.onCountdownStarted = onCountdownStarted
M.onRaceStart = onRaceStart
M.onRaceTick = onRaceTick
M.onRaceWaypointReached = onRaceWaypointReached
M.onBeamNGTrigger = onBeamNGTrigger
M.onRaceResult = onRaceResult
return M