-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Busdriver_stunt_crash'

local AIStartWaypointName = 'course_wp1'
local AIStopWaypointName = 'course_wp2'
local AIResumeWaypointName = 'course_wp3'
local finalWaypointName = 'course_wp4'
local playerInstance = 'scenario_player0'
local targetInstance = 'scenario_targetcar'
local maxDamageDonePoints = 1000
local damageDoneStatName = 'Damagedone'
local bumpBonusStatName = 'Bump'
local scriptAIRecording1 = 'levels/rls_west_coast_usa/scenarios/busdriver_stunt/busdriver_stunt_crush1.track.json'

local bumpScore = 0
local playerDamageAtJump = 0
local targetDamageAtJump = 0
local targetDamageAtBumpZone = 0
local waitTimer = 0
local jumpTimer = 0

local crushValidity = true
local passedLastWaypoint = false
local running = false
local playerWon = false
local aiWon = false
local bumpZone = false --zone for extra points ramming car

local function reset()
  bumpScore = 0
  playerDamageAtJump = 0
  targetDamageAtJump = 0
  targetDamageAtBumpZone = 0
  waitTimer = 0
  jumpTimer = 0
  crushValidity = true
  running = false
  passedLastWaypoint = false
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

local function resumeAIVehicle()
    
    local arg = {vehicleName = 'scenario_targetcar', 
                waypoints = {'crush_aiwp5', 'crush_aiwp6'}, 
                routeSpeed = 55/3.6,
                routeSpeedMode = 'limit',
                aggression = 1,
                aggressionMode = 'none',
                resetLearning = true -- leave blank or set to false if not needed
                }
    helper.setAiPath(arg)

end

local function scenarioJudge(scoreCard)
  local playerVehicle = scenetree.findObject(playerInstance)
  local playerVID = playerVehicle:getID()

  local data = {
    points=bumpScore,
    value=1
  }
  statistics_statistics.setStatProgress(playerVID, damageDoneStatName, playerInstance, data)  

  local scorePoints = clamp((scoreCard / 100), 0, maxDamageDonePoints)
  data = {
    points=scorePoints,
    value=scoreCard
  }
  statistics_statistics.setStatProgress(playerVID, damageDoneStatName, playerInstance, data)  

  if scoreCard <=0 then
    fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_crush.failMiss.msg')
  end

  if crushValidity then
    if scoreCard > 0 and scoreCard < 10000 then
      fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_crush.failBig.msg')
    end
    if scoreCard >= 10000 and scoreCard < 40000 then
      success('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_crush.winSmall')
    end
    if scoreCard >= 40000 then
      success('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_crush.winBig')
    end
  else
    fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_crush.failInvalid.msg')
  end
end



local function onRaceWaypointReached(data)
  --log('I', logTag,'onRaceWaypointReached called ')
  --dump(data)
  
  if data.waypointName == AIStartWaypointName then
    local aiData = jsonReadFile(scriptAIRecording1)
    scenetree.findObject(targetInstance):queueLuaCommand("ai.startFollowing("..serialize(aiData.recording)..")")
  end
  
  
  if data.waypointName == AIResumeWaypointName then
    resumeAIVehicle()
  
    running = true
    local targetVehicle = scenetree.findObject(targetInstance)
    local targetVehicleData = map.objects[targetVehicle:getID()]
    targetDamageAtBumpZone = targetVehicleData.damage --record target damage for bonus bump points
    bumpZone = true
  end
   
  if data.waypointName == finalWaypointName then
    bumpZone = false
    passedLastWaypoint = true
    local playerVehicle = scenetree.findObject(playerInstance)
    local playerVehicleData = map.objects[playerVehicle:getID()]
    playerDamageAtJump = playerVehicleData.damage
    local targetVehicle = scenetree.findObject(targetInstance)
    local targetVehicleData = map.objects[targetVehicle:getID()]
    targetDamageAtJump = targetVehicleData.damage
  end
end

local function onPreRender(dt)
  --make sure that code is only executed after onRaceStart() has been called
  if not running then
    return
  end

  local targetVehicle = scenetree.findObject(targetInstance)
  local playerVehicle = scenetree.findObject(playerInstance)
  
  if bumpZone then --zone for extra points bumping car
    local targetVehicleData = map.objects[targetVehicle:getID()]
    if targetVehicleData and (targetVehicleData.damage - targetDamageAtBumpZone) > 0 then
      if bumpScore == 0 then
        bumpScore = 100
        helper.flashUiMessage("Bump +"..bumpScore, 2, true)
      end
    end
  end

  if passedLastWaypoint then
    jumpTimer = jumpTimer + dt
    if jumpTimer > 4 then
      scenarioJudge(-1) --fail if 4 seconds passes after jump with no damage inflicted        
    end
    local targetVehicleData = map.objects[targetVehicle:getID()]
    local playerVehicleData = map.objects[playerVehicle:getID()]
    if playerVehicleData and (playerVehicleData.damage - playerDamageAtJump) > 100 then
        if targetVehicleData and (targetVehicleData.damage - targetDamageAtJump) <= 0 then
            crushValidity = false
        end
    end
      
    if targetVehicleData and (targetVehicleData.damage - targetDamageAtJump) > 0 then
        waitTimer = waitTimer + dt
        jumpTimer = 0
        if waitTimer > 3 then
          local finalDamage = targetVehicleData.damage - targetDamageAtJump
          scenarioJudge(finalDamage)
          running = false
        end
    end
  end
end

local function onRaceStart()
  log('I', 'BusCrash', 'onRaceStart called...')
  reset()
  local playerVehicle = scenetree.findObject(playerInstance)
  local playerVID = playerVehicle:getID()

  local data = {
    decimals = 1,
    enabled = true,
    label='ui.stats.bumpBonus',
    maxPoints=100
  }
  statistics_statistics.setStatProgress(playerVID, bumpBonusStatName, playerInstance, data)

  data = {
    decimals = 1,
    enabled = true,
    label='ui.stats.damageDone',
    maxPoints=maxDamageDonePoints
  }
  statistics_statistics.setStatProgress(playerVID, damageDoneStatName, playerInstance, data)
end

M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onVehicleStoppedMoving = onVehicleStoppedMoving
M.onPreRender = onPreRender
return M