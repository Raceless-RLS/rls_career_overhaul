
-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local helper = require('scenario/scenariohelper')
local logTag = 'Busdriver_stunt_crash'

local random = math.random

local breakTimer = 0
local bombTimer = 10
local fireTimer = 0
local endTimer = 3
local escapeTimer = 5
local escapeGoal = false
local running = false
local bombEnabled = false
local bombActive = false
local aiMissionOver = false
local playerMissionOver = false
local rescueMessage = false
local messageText = ""
local nextMessageText = ""
local lastMessage = ""
local bombReveal = 1.5
local messageTimer = 0
local nextMessageTimer = 0
local lastWaypointReached = ""

local events = require('timeEvents').create()

local minSpeed = 15 --m/s
local startBeamBreaking = false
local groupBreakCounter = 1
local vehicle1 = nil
local vehicle2 = nil

local busWindowL = {"wallglass_2_L_break","wallglass_3_L_break","wallglass_4_L_break","wallglass_5_L_break"}
local busWindowR = {"wallglass_2_R_break","wallglass_3_R_break","wallglass_4_R_break"}
local busWindowLBroken = false
local busWindowRBroken = false

local function reset()
  bombTimer = 10
  running = false
  aiMissionOver = false
  playerMissionOver = false
  escapeGoal = false
  rescueMessage = false
  escapeTimer = 10
  endTimer = 3
  bombEnabled = false
  bombActive = false
  messageText = ""
  nextMessageText = ""
  bombReveal = 2
  messageTimer = 0
  nextMessageTimer = 0
  lastWaypointReached = 0
  events:clear()
  busWindowLBroken = false
  busWindowRBroken = false
end

-- super hacky do not copy or take an example of
local function convertSpeed (ms)
  local tmp = settings.getValue('uiUnitLength')
  if tmp == 'metric' then
    return tostring(math.ceil(ms * 3.6)) .. 'km/h'
  elseif tmp == 'imperial' then
    return tostring(math.ceil(ms * 2.23693629)) .. 'mph'
  end
  return tostring(ms) .. 'm/s'
end

local function shuffle(array)
    local n, j, k = #array
    for i=1, n do
        j,k = random(n), random(n)
        array[j],array[k] = array[k],array[j]
    end
    return array
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
  lastMessage = ""
  running = true
  helper.queueLuaCommandByName('scenario_player0', 'controller.onGameplayEvent("bus_setLineInfo",{direction = "Star Diner", routeColor = "#3b9c00", routeID = "1", tasklist = {{ "wcu_bs_26", "Agave Lookout"},{ "wcu_bs_29", "Single Pine Motel"}, { "wcu_bs_27", "E Horizon Estates"}, { "wcu_bs_28", "Redwood Motel"}, { "wcu_bs_25", "Lens Flare Studios"}, { "wcu_bs_20", "Star Diner"}}, variance = "a" } )')
end

local function scenarioOutcome()
    if playerMissionOver and escapeGoal then
      success('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_minspeed.success.msg')
    elseif escapeGoal then
      fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_minspeed.fail2.msg')
    else
      fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_minspeed.fail1.msg')
    end
end

local function startAIVehicle()

    local arg = {vehicleName = 'scenario_rescue',
                waypoints = {'ai_WP1', 'ai_WP2', 'ai_WP3', 'ai_WP4'},
                routeSpeed = 80/3.6,
                routeSpeedMode = 'limit',
                aggression = 1,
                aggressionMode = 'none',
                resetLearning = true -- leave blank or set to false if not needed
                }
    helper.setAiPath(arg)

end

local function stopAIVehicle()

    if lastWaypointReached == "course_wp5" or lastWaypointReached == "course_wp6" then
      local arg = {vehicleName = 'scenario_rescue',
                waypoints = {'ai_endpoint1', 'ai_endpoint1b'},
                routeSpeed = 60/3.6,
                routeSpeedMode = 'limit',
                aggression = 1,
                aggressionMode = 'none',
                resetLearning = true -- leave blank or set to false if not needed
                }
      helper.setAiPath(arg)
    elseif lastWaypointReached == "junction1" then
      local arg = {vehicleName = 'scenario_rescue',
                waypoints = {'ai_endpoint2', 'ai_endpoint2b'},
                routeSpeed = 60/3.6,
                routeSpeedMode = 'limit',
                aggression = 1,
                aggressionMode = 'none',
                resetLearning = true -- leave blank or set to false if not needed
                }
      helper.setAiPath(arg)
    else
      local arg = {vehicleName = 'scenario_rescue',
                waypoints = {'ai_endpoint3', 'ai_endpoint3b'},
                routeSpeed = 60/3.6,
                routeSpeedMode = 'limit',
                aggression = 1,
                aggressionMode = 'none',
                resetLearning = true -- leave blank or set to false if not needed
                }
      helper.setAiPath(arg)
    end

end

local function onRaceWaypointReached(data)
  local playerVehicleId = be:getPlayerVehicleID(0)
  lastWaypointReached = data.waypointName
  if data.vehicleId == playerVehicleId then
    if lastWaypointReached == "course_wp1" then
      helper.queueLuaCommandByName('scenario_player0', 'controller.onGameplayEvent("bus_setLineInfo",{direction = "Star Diner", routeColor = "#3b9c00", routeID = "1", tasklist = {{ "wcu_bs_29", "Single Pine Motel"}, { "wcu_bs_27", "E Horizon Estates"}, { "wcu_bs_28", "Redwood Motel"}, { "wcu_bs_25", "Lens Flare Studios"}, { "wcu_bs_20", "Star Diner"}}, variance = "a" } )')
    end
    if lastWaypointReached == "course_wp3" then
      bombEnabled = true
    end
    if lastWaypointReached == "course_wp4" then
      startAIVehicle()
    end
    if lastWaypointReached == "canal_WP3" or lastWaypointReached == "pier_WP3" or lastWaypointReached == "bridge_WP7" then
      playerMissionOver = true

      bombTimer = math.min(bombTimer, 1.5)
    end
    guihooks.trigger('WayPoint', 'Checkpoint ' .. tostring(data.cur) .. ' / 7 ')
    -- TODO: don't like that this is hardcoded, we should fix this soon
  end
end

local function checkWindow(playerPos,playerVehicle, aiPos)
  if busWindowLBroken and busWindowRBroken then return end

  local posdiff = aiPos - playerPos
  local vDirVec=vec3(playerVehicle:getDirectionVector())
  local vUpVec=vec3(playerVehicle:getDirectionVectorUp())
  local vLeftVec=vDirVec:cross(vUpVec)

  if vLeftVec:dot(posdiff) > 0 then
    if not busWindowRBroken then
      for _,g in pairs(busWindowR) do
        helper.triggerDeformGroup("scenario_player0", g)
      end
      busWindowRBroken = true
    end
  else
    if not busWindowLBroken then
      for _,g in pairs(busWindowL) do
        helper.triggerDeformGroup("scenario_player0", g)
      end
      busWindowLBroken = true
    end
  end
end

local lastDtSim
local function onPreRender(dtReal, dtSim, dtRaw)
  if not running then
      return true
  end
  local isPaused = (lastDtSim or dtSim) <= 0
  lastDtSim = dtSim
  if isPaused then return true end

  events:process(dtSim)

  local playerVehicle = scenetree.findObject("scenario_player0")
  local playerVehicleData = map.objects[playerVehicle:getID()]
  local playerVehiclePos = playerVehicle:getPosition()

  local aiVehicle = scenetree.findObject("scenario_rescue")
  --local aiVehicleData = map.objects[aiVehicle:getID()]
  local aiVehiclePos = aiVehicle:getPosition()

  local distance = (playerVehiclePos - aiVehiclePos):len()

  local endpoint1 = scenetree.findObject("canal_WP3") --compute distance to final waypoint options
  local endpoint1Pos = endpoint1:getPosition()
  local endpoint2 = scenetree.findObject("pier_WP3")
  local endpoint2Pos = endpoint2:getPosition()
  local endpoint3 = scenetree.findObject("bridge_WP7")
  local endpoint3Pos = endpoint3:getPosition()

  if distance < 40 and distance > 4.5 and not escapeGoal then
    messageText = "Pull alongside rescue truck"
    messageTimer = 4
  end

  if distance < 4.5 then
    escapeTimer = escapeTimer - dtSim
    if escapeTimer > 0 then
      messageText = "Rescuing Passengers...<br>"..tostring(math.ceil( escapeTimer*1.5 )).." passenger(s) remaning"
      messageTimer = 0.1
      checkWindow(playerVehiclePos, playerVehicle, aiVehiclePos)
    end
  end

  if escapeTimer <= 0 and not escapeGoal then
    messageText = "All Passengers Rescued"
    messageTimer = 3
    nextMessageText = "Get the Bus to a safe location!"
    nextMessageTimer = 3
    escapeGoal = true
  end

  if bombReveal == 2 and playerVehicleData.damage > 5000 then
      fail('scenarios.west_coast_usa.busdriver_stunt.busdriver_stunt_minspeed.fail3.msg')
  end

  if bombReveal and bombReveal <= 0 then
    messageText = "There is a bomb on board!"
    messageTimer = 3
    bombReveal = false

    --helper.breakBreakGroup("scenario_player0", "hvacdoor_latch_r")
    --helper.breakBreakGroup("scenario_player0", "hvacdoor_latch_l")
    helper.breakBreakGroup("scenario_player0", "hvacdoor_hinge_r")
    helper.breakBreakGroup("scenario_player0", "hvacdoor_hinge_l")
    helper.queueLuaCommandByName('scenario_player0', 'controller.getControllerSafe("bomb").setTimer('..tostring(bombTimer)..')')

    events:addEvent( 2.5, function()
      messageText = "Don't slow down! Stay above " .. convertSpeed(minSpeed) .. "!"
      messageTimer = 2.5
    end)

    events:addEvent( 5, function()
      bombActive = true
    end)
  end

  if lastWaypointReached == "course_wp4" and messageText == "" and not rescueMessage then
    messageText = "Rescue incoming..."
    messageTimer = 3
    rescueMessage = true
  end

  if lastWaypointReached == "canal_WP2" or lastWaypointReached == "pier_WP2" or lastWaypointReached == "bridge_WP6" then
    if (playerVehiclePos - endpoint1Pos):len() < 120 or (playerVehiclePos - endpoint2Pos):len() < 120 or (playerVehiclePos - endpoint3Pos):len() < 120 then
      helper.breakBreakGroup("scenario_player0", "door_hinge_FA")
      helper.breakBreakGroup("scenario_player0", "door_hinge_FB")
      messageText = "Bailing out..."
      messageTimer = 10
    end
  end

  if bombActive == true then
    if playerVehicleData.vel:length() < minSpeed and bombTimer > 0 then
      bombTimer = bombTimer - dtSim
      helper.queueLuaCommandByName('scenario_player0', 'controller.getControllerSafe("bomb").setTimer('..tostring(bombTimer)..')')
      messageText = string.format("%.1f", bombTimer)
      messageTimer = 0.1
      if playerVehicleData.vel:length() < 2 then
        bombTimer = 0
      end
    elseif playerMissionOver then
      bombTimer = bombTimer - dtSim
      messageText = ""
    end
  end

  if bombTimer <= 0 then --blow up the bus
    helper.queueLuaCommandByName('scenario_player0', 'fire.explodeVehicle()')
    helper.queueLuaCommandByName('scenario_player0', 'beamstate.breakAllBreakgroups()')
    helper.queueLuaCommandByName('scenario_player0', 'controller.getControllerSafe("bomb").setTimer(0)')
  end

  if messageText == "Get the Bus to a safe location!" and not aiMissionOver then
    stopAIVehicle()
    aiMissionOver = true
  end

  messageTimer = messageTimer - dtSim --count how long messages display for
  if bombEnabled and bombReveal then
    bombReveal = bombReveal - dtSim
  end

  if messageTimer <= 0 then
    messageText = ""
    if nextMessageText and nextMessageTimer > 0 then
      nextMessageTimer = nextMessageTimer - dtSim
      messageText = nextMessageText
    end
  end

  if(messageText ~= lastMessage) then
    helper.realTimeUiDisplay(messageText)
    lastMessage = messageText
  end

  if bombTimer <= 0 then
    endTimer = endTimer - dtSim
  end

  if endTimer <= 0 then
    scenarioOutcome()
  end

end

M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onPreRender = onPreRender

return M
