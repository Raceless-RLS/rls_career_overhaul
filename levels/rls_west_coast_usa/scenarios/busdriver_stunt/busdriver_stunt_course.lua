-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Busdriver_stunt_crash'

local finalWaypointName = 'course_wp4'
local playerInstance = 'scenario_player0'

local scenarioStarted = false
local running = false
local playerWon = false
local aiWon = false

local shell1 = nil
local shell2 = nil
local shell3 = nil
local shell4 = nil

local function reset()
  running = false
  scenarioStarted = false
  playerWon = false
  aiWon = false
end

local function fail(reason)
  scenario_scenarios.finish({failed = reason})
  reset()
end

local function success(reason)
  scenario_scenarios.finish({msg = reason})
  reset()
end

local function onPreRender(dt)
  --make sure that code is only executed after onRaceStart() has been called
  if scenarioStarted == false then
    shell1 = helper.getVehicleByName('shell1')
    shell2 = helper.getVehicleByName('shell2')
    shell3 = helper.getVehicleByName('shell3')
    shell4 = helper.getVehicleByName('shell4')
    if shell1 and shell2 and shell3 and shell4 then
    helper.queueLuaCommand(shell1, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell2, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell2, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell2, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell3, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell3, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    helper.queueLuaCommand(shell4, 'fire.igniteRandomNode()')
    scenarioStarted = true
    end
  end

end


M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult
M.onVehicleStoppedMoving = onVehicleStoppedMoving
M.onPreRender = onPreRender
return M