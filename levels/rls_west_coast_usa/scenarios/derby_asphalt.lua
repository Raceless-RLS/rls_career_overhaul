-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Derby_Asphalt'

local finalWaypointName = 'drifttrack_wp0'
local finalTriggerName = 'trigger_finish1'
local modeTriggerName = 'trigger_mode1'
local playerInstance = 'scenario_player0'
local aiInstance1 = 'scenario_opponent1'
local aiInstance2 = 'scenario_opponent2'
local aiInstance3 = 'scenario_opponent3'

local running = false
local playerWon = false
local aiModeReady = false
local aiFinished = false
local noOfLaps = 5
local lapsCompleted = {}
local waypoints = {}

-- NOTE: since v0.32, there are a few hacks needed to get the AI to work, due to the updated navgraph layout of the area. Unfortunate...

local function reset()
  lapsCompleted['scenario_player0'] = 0
  lapsCompleted['scenario_opponent1'] = 0
  lapsCompleted['scenario_opponent2'] = 0
  lapsCompleted['scenario_opponent3'] = 0

  scenetree.findObject(aiInstance1):queueLuaCommand('ai.setMode("stop")')
  scenetree.findObject(aiInstance2):queueLuaCommand('ai.setMode("stop")')
  scenetree.findObject(aiInstance3):queueLuaCommand('ai.setMode("stop")')

  running = false
  playerWon = false
  aiModeReady = false
  aiFinished = false
end

local function fail(reason)
  scenario_scenarios.finish({failed = reason})
  reset()
end

local function success(reason)
  scenario_scenarios.finish({msg = reason})
  reset()
end

local function onRaceStart()
  for _, ai in ipairs({aiInstance1, aiInstance2, aiInstance3}) do
    local veh = scenetree.findObject(ai)
    local origin = veh:getPosition()
    local target = scenetree.findObject('extra'):getPosition()
    target = target - origin
    local path = {}
    for i = 1, 20 do
      local vec = origin + target * (i / 20)
      local currDist = origin:distance(vec)
      local t = currDist / 100
      table.insert(path, {x = vec.x, y = vec.y, z = vec.z, t = t})
    end

    veh:queueLuaCommand('ai.startFollowing(' .. serialize({path = path}) .. ', nil, 0, "neverReset")')
  end

  scenario_scenarios.trackVehicleMovementAfterDamage(playerInstance, {waitTimerLimit = 10})

  running = true
end

local function onCountdownStarted()
  reset()

  if not waypoints[1] then
    for _, wp in ipairs({'drifttrack_ai1', 'drifttrack_ai2', 'drifttrack_wp0', 'drifttrack_ai1'}) do
      local n1 = map.findClosestRoad(scenetree.findObject(wp):getPosition())
      table.insert(waypoints, n1)
    end
  end
end

local function onRaceWaypointReached(data)
  if data.waypointName == finalWaypointName and data.vehicleName == playerInstance then
    lapsCompleted[data.vehicleName] = lapsCompleted[playerInstance] + 1
    if lapsCompleted[playerInstance] == noOfLaps and not aiFinished then
      playerWon = true
    end
  end
end

local function onRaceResult()
  if playerWon then
    success('scenarios.west_coast_usa.derby_asphalt.win.msg')
  else
    fail('scenarios.west_coast_usa.derby_asphalt.fail.msg')
  end
end

local function onVehicleStoppedMoving(vehicleID, damaged)
  if running then
    local playerVehicleID = scenetree.findObject(playerInstance):getID()
    if vehicleID == playerVehicleID and damaged and not playerWon then
      fail('scenarios.west_coast_usa.derby_asphalt.fail.msg')
    end
  end
end

local function onBeamNGTrigger(data)
  if data.event == 'enter' and (data.subjectName == aiInstance1 or data.subjectName == aiInstance2 or data.subjectName == aiInstance3) then
    if data.triggerName == modeTriggerName then
      if lapsCompleted[data.subjectName] == 0 then
        aiModeReady = true
        local arg = {vehicleName = data.subjectName,
                    waypoints = waypoints,
                    lapCount = noOfLaps,
                    aggression = math.random(80, 100) * 0.01,
                    avoidCars = 'on'}

        helper.queueLuaCommandByName(data.subjectName, 'ai.stopFollowing()')
        helper.setAiPath(arg)
      end
    elseif data.triggerName == finalTriggerName then
      if aiModeReady then
        lapsCompleted[data.subjectName] = lapsCompleted[data.subjectName] + 1
        if lapsCompleted[data.subjectName] == noOfLaps then
          aiFinished = true
        end
      end
    end
  end
end

M.onRaceStart = onRaceStart
M.onCountdownStarted = onCountdownStarted
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult
M.onVehicleStoppedMoving = onVehicleStoppedMoving
M.onBeamNGTrigger = onBeamNGTrigger

return M