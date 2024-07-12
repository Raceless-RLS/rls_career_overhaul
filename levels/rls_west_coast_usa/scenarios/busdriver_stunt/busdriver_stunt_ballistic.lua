-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Mountain_race'

local finalWaypointName = 'stcheck_1'
local rampPositionName = 'ramp_base'
local playerInstance = 'scenario_player0'
local messageText = ""
local running = false
local playerWon = true
local bailedOut = false
local scenarioEnd = false
local altitudeScore = 0
local distanceScore = 0
local playerDamage = 0
local messageTimer = 0
local crashTimer = 5

local min = math.min
local max = math.max

local function reset()
  running = false
  playerWon = true
  crashTimer = 5
  playerDamage = 0
  altitudeScore = 0
  distanceScore = 0
  bailedOut = false
end

local function fail(reason)
  scenario_scenarios.finish({failed = reason})
end

local function success(reason)
  scenario_scenarios.finish({msg = reason})
end

local function onCountdownStarted()
  reset()

end

local function onRaceResult()
  local playerVehicle = scenetree.findObject("scenario_player0")
  if playerVehicle then
    local maxDistance = 600
    local maxPoints = 500
    local distancePoints = math.floor((distanceScore / maxDistance) * maxPoints)
    local distData = {
      value = distanceScore,
      points= distancePoints,
      maxPoints= maxPoints
    }
    statistics_statistics.setStatProgress(playerVehicle:getID(), 'distance', playerInstance, distData)

   local maxAltitude = 400
   maxPoints = 500
   local altitudePoints = math.floor((altitudeScore / maxAltitude) * maxPoints)
      local altitudeData = {
      value = altitudeScore,
      points= altitudePoints,
      maxPoints= maxPoints
    }
   statistics_statistics.setStatProgress(playerVehicle:getID(), 'altitude', playerInstance, altitudeData)
 end
end

local function onRaceStart()
  -- log('I', logTag,'onRaceStart called')
  reset()

  running = true
  local playerVehicle = scenetree.findObject("scenario_player0")

  local sharedData = {
      enabled = false
    }

  statistics_statistics.setStatProgress(playerVehicle:getID(), 'distance', "scenario_player0", sharedData)
  statistics_statistics.setStatProgress(playerVehicle:getID(), 'altitude', "scenario_player0", sharedData)
end

local function onPreRender(dt)
  if running then
    local playerVehicle = scenetree.findObject("scenario_player0")
    local playerVehicleData = map.objects[playerVehicle:getID()]
    local playerVehiclePos = playerVehicle:getPosition()

    playerDamage = playerVehicleData.damage

    if playerDamage > 40000 then
      crashTimer = crashTimer - dt
      if not bailedOut then
        playerWon = false
      end
    end

    if crashTimer <= 0 and not scenarioEnd then
     if playerWon == true then
        success('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_ballistic.win.msg')
      else
        fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_ballistic.fail.msg')
      end
      scenarioEnd = true
    end

    local ramp = scenetree.findObject("ramp_base") --compute distance to from ramp base
    local rampPos = ramp:getPosition()

    local altitude = playerVehiclePos.z - rampPos.z
    local distance = (playerVehiclePos - rampPos):len()

    altitudeScore = max(altitudeScore, altitude)--keep track of highest altitude achieved

    if playerDamage < 40000 then --keep recording distance until impact occurs
      distanceScore = max(distanceScore, distance)--keep track of maximum distance achieved
    end

    if altitude > 120 and playerVehicleData.vel.z < 10 and not bailedOut then
      helper.breakBreakGroup("scenario_player0", "door_hinge_FA")
      helper.breakBreakGroup("scenario_player0", "door_hinge_FB")
      messageText = "Bailing out..."
      messageTimer = 4
      bailedOut = true
    end
    messageTimer = messageTimer - dt --count how long messages display for
    if messageTimer <= 0 then
      messageText = ""
    end
    helper.realTimeUiDisplay(messageText)
  end
end


M.onPreRender = onPreRender
M.onCountdownStarted = onCountdownStarted
M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult
--M.onVehicleStoppedMoving = onVehicleStoppedMoving
return M