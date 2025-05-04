-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this tiny module helps setting the steam rich presence

local M = {}

-- How to use: print(extensions.util_richPresence.set('yolo'))
M.state = { levelName = "", vehicleName = "" ,levelIdentifier=""}
M.richPresenceEnabled = true

local internal = not shipping_build or not string.match(beamng_windowtitle, "RELEASE")

--discord assets
local vehAssets = {"pickup"}
local lvlAssets = {
  "automation_test_track",
  "cliff",
  "derby",
  "driver_training",
  "east_coast_usa",
  "glow_city",
  "gridmap",
  "hirochi_raceway",
  "industrial",
  "italy",
  "jungle_rock_island",
  "small_island",
  "smallgrid",
  "utah",
  "west_coast_usa",
}


local timelineEvents = {}
timelineEvents["vehicle/crash"] = {icon="steam_death", title="Crash"}
timelineEvents["vehicle/airtime.time"] = {icon="steam_effect", title="Air"}
timelineEvents["vehicle/rollover"] = {icon="steam_starburst", title="Rollover"}
timelineEvents["vehicle/jturn"] = {icon="steam_triangle", title="jturn"}
timelineEvents["drift/crashes"] = {icon="steam_bolt", title="drift crash"}
-- timelineEvents["drift/leftDrifts"] = {icon="steam_explosion", title="drift left"}
-- timelineEvents["drift/rightDrifts"] = {icon="steam_explosion", title="drift right"}


local function msgFormat()
  local fgActivityId = gameplay_missions_missionManager.getForegroundMissionId()
  local mission = gameplay_missions_missions.getMissionById(fgActivityId)

  local msg = ""
  local appendLevel, appendVehicle
  if editor and editor.isEditorActive() then
    msg = "Using World Editor"
    appendLevel, appendVehicle = true, false
  elseif fgActivityId and mission then
    msg = "Playing " .. translateLanguage(mission.name, mission.name, true) -- suppress errors for translations
    appendLevel, appendVehicle = true, true
  elseif scenario_scenarios and scenario_scenarios.getScenario() then
    local scenario = scenario_scenarios.getScenario()
    if scenario.name then
      msg = "Playing " .. translateLanguage(scenario.name, scenario.name, true)
    elseif scenario.isQuickRace then
      msg = "Playing Time Trials"
    else
      msg = "Playing Scenario"
    end
    appendLevel, appendVehicle = true, true
  elseif M.state.vehicleName == 'Unicycle' then
    msg = "Walking around"
    appendLevel, appendVehicle = true, false
  else
    msg = "Playing"
    if extensions.core_gamestate.state.state then
      if tostring((core_gamestate.state.state:gsub("^%l", string.upper)) ) == "Career" then
        msg = msg.. " RLS Career"
      else
        msg = msg.. " " ..tostring((core_gamestate.state.state:gsub("^%l", string.upper)) )
      end
    end
    appendLevel, appendVehicle = true, true
  end

  if msg ~= "" then
    -- append level and vehicle if possible
    if appendLevel and M.state.levelName ~= "" then
      msg = msg .. " on " .. M.state.levelName
    end

    if appendVehicle and M.state.vehicleName ~= "" and M.state.vehicleName ~= "Unicycle" then
      msg = msg .. " with " .. M.state.vehicleName
    end

    if Steam then
      Steam.timelineSetStateDescription(msg,0)
    end

    M.set(msg)
    -- only set discord state is there is a msg for steam
    if Discord and Discord.isWorking() then
      local dActivity = {state="Playing ",details="",asset_largeimg="",asset_largetxt="",asset_smallimg="",asset_smalltxt=""}
      -- discord will use the same message as steam
      dActivity.state = msg

      if M.state.levelName ~= "" then
        dActivity.details = M.state.levelName
        dActivity.asset_largetxt = M.state.levelName
      end
      if M.state.vehicleName ~= "" then
        dActivity.asset_smalltxt = M.state.vehicleName
        dActivity.details = M.state.vehicleName
      end
      if M.state.levelIdentifier and M.state.levelIdentifier ~= "" and tableContains(lvlAssets,M.state.levelIdentifier)then
        dActivity.asset_largeimg= "lvl_"..M.state.levelIdentifier
      else
        dActivity.asset_largeimg="missingnormaltexture"
      end
      -- if M.state.vehicleJbeam and M.state.vehicleJbeam ~= "" and tableContains(vehAssets,M.state.vehicleJbeam) then
      --   dActivity.asset_smallimg= M.state.vehicleJbeam
      -- else
      --   dActivity.asset_smallimg= "warnmat"
      -- end
      --log("E","msgFormat", dumps(dActivity))
      Discord.setActivity(dActivity)
    end
  end
end

local function onVehicleSwitched(oldId, newId, player)
  local currentVehicle = core_vehicles.getCurrentVehicleDetails()
  if currentVehicle.model and currentVehicle.model.Name then
    if currentVehicle.model.Brand then
      M.state.vehicleName = currentVehicle.model.Brand .. " " .. currentVehicle.model.Name
    else
      M.state.vehicleName = currentVehicle.model.Name
    end
  end
  M.state.vehicleJbeam = currentVehicle.current.key
  msgFormat()
end

local function onClientPostStartMission(levelPath)
  local currentLevel = getCurrentLevelIdentifier() or ''
  M.state.levelIdentifier = string.lower(currentLevel)
  if currentLevel ~= "" then
    M.state.levelName = currentLevel:gsub("^%l", string.upper)
    M.state.levelName = M.state.levelName:gsub("_", " ")
    M.state.levelName = string.gsub(" "..M.state.levelName, "%W%l", string.upper):sub(2)
    msgFormat()
  end
end
--[[
-- this was the old editor
local function onEditorEnabled(enabled)
  if enabled then
    M.set('Level editing')
  else
    msgFormat()
  end
end
]]

local function onEditorActivated()
  msgFormat()
  if Steam then
    Steam.timelineSetGameMode(2)
  end
end

local function onEditorDeactivated()
  msgFormat()
  if Steam then
    Steam.timelineSetGameMode(1)
  end
end

local function onGameStateUpdate(state)
  msgFormat()
end

local function onAnyMissionChanged()
  msgFormat()
end

local function statCbTimeline(name, oldentry, newentry)
  if Steam then
    Steam.timelineAddEvent(
      timelineEvents[name].icon,
      timelineEvents[name].title,
      "",
      timelineEvents[name].priority or 0,
      -0.05,
      0.1,
      2
    )
  end
  -- print(name)
end

local function onExtensionLoaded()
  if not internal and settings.getValue('richPresence') then
    if Steam then
      Steam.setRichPresence('steam_display', '#BNGGSW') -- BNGGSW = BeamNG Generic Status Wrapper
      Steam.setRichPresence('status', beamng_windowtitle) -- will show up in the 'view game info' dialog in the Steam friends list.
      Steam.setRichPresence('b', "   ")
    end
    if Discord then
      Discord.setEnabled(settings.getValue('richPresenceDiscord'))
    end
  end
  if Steam then
    Steam.timelineSetGameMode(0)
  end
  for k,v in pairs(timelineEvents) do
    gameplay_statistic.callbackRegister(k, false, statCbTimeline)
  end
end

local function onExtensionUnloaded()
  if Steam then
    Steam.setRichPresence('b', "   ")
    -- Steam.clearRichPresence() --not working
  end
  if Discord then
    Discord.clearActivity()
  end
  for k,v in pairs(timelineEvents) do
    gameplay_statistic.callbackRemove(k, false, statCbTimeline)
  end
end

-- returns true on success
local function set(v)
  log("D","Rich Presence", tostring(v))
  if Steam then
    return Steam.setRichPresence('b', tostring(v))
  end
end

local toggleableFunctions = {
  set = set
}

local function enableToggleableFunctions(enabled)
  M.richPresenceEnabled = enabled
  for k, v in pairs(toggleableFunctions) do
    M[k] = enabled and v or nop
  end
end

local function onSettingsChanged()
  if internal or not settings.getValue('richPresence') then
    -- log("D","Rich Presence", "Rich Presence is disabled.")
    if Steam then
      Steam.setRichPresence('b', "   ")
      -- Steam.clearRichPresence() --not working
    end
    if Discord then
      Discord.setEnabled(false)
    end
    enableToggleableFunctions(false)
  elseif M.set == nop and settings.getValue('richPresence') then --re-enabled
    if Steam then
      log("D","Rich Presence", "Rich Presence is enabled.")
      Steam.setRichPresence('steam_display', '#BNGGSW')
      Steam.setRichPresence('status', beamng_windowtitle)
      Steam.setRichPresence('b', "   ")
      enableToggleableFunctions(true)
    end
    if Discord then
      Discord.setEnabled(settings.getValue('richPresenceDiscord'))
    end
    msgFormat()
  end
end

local function timelineStartLoadingScreen(levelpath)
  -- log("I","AAA","timelineStartLoadingScreen")
  if Steam then
    Steam.timelineSetGameMode(4)
  end
end

local function onUiReady()
  --log("I","onUiReady","") --usually used when reloading
  local state = 0 --invalid
  if extensions.core_gamestate.state.state then
    local s = extensions.core_gamestate.state.state
    --log("E","onUiReady",dumps(s))
    if string.startswith(s,"menu.") then
      state = 3 --menu
      if Steam then
        Steam.timelineSetStateDescription("Menu",0)
      end
    elseif s == "loading" then
      state = 4 --loadingscreen
      if Steam then
        Steam.timelineSetStateDescription("Loading screen",0)
      end
    elseif string.startswith(s,"scenario-") then
      state = 2 --stagging
    else
      state = 1 --playing
    end
  end
  if Steam then
    Steam.timelineSetGameMode(state)
  end
end


local function onUiChangedState(toState, fromState)
  -- log("I","onUiChangedState", "from="..dumps(fromState))
  -- log("I","onUiChangedState", "to="..dumps(toState))
  local state = 0 --invalid
  if string.startswith(toState,"menu.") then
    state = 3 --menu
    if Steam then
      Steam.timelineSetStateDescription("Menu",0)
    end
  elseif toState == "loading" then
    state = 4 --loadingscreen
    if Steam then
      Steam.timelineSetStateDescription("Loading screen",0)
    end
  elseif string.startswith(toState,"scenario-") then
    state = 2 --stagging
  else
    state = 1 --playing
  end
  if Steam then
    Steam.timelineSetGameMode(state)
  end
end

local function onResetGameplay()
  if Steam then
    Steam.timelineAddEvent(
      "steam_circle",
      "reset",
      "",
      0,-0.05,0.1,2)
  end
end

local function onNewAttempt(attemptData)
  if Steam then
    Steam.timelineAddEvent(
      "steam_circle",
      "New attempt",
      "",
      0,-0.05,0.1,2)
  end
end

local function onAttemptFailed(attemptData)
  if Steam then
    Steam.timelineAddEvent(
      "steam_invalid",
      "Failed",
      "",
      0,-0.05,0.1,2)
  end
end

local function onAttemptCompleted(attemptData)
  if Steam then
    Steam.timelineAddEvent(
      "steam_checkmark",
      "Completed",
      "",
      0,-0.05,0.1,2)
  end
end

local function onRaceWaypointReached(data)
  if Steam then
    Steam.timelineAddEvent(
      "steam_marker",
      "Race waypoint",
      "",
      0,-0.05,0.1,2)
  end
end

local function onRaceLap(data)
  local timeStr = string.format("%.2d:%.2d.%.3d", (data.time)/60, (data.time)%60, (data.time%1)*1000)
  if Steam then
    Steam.timelineAddEvent(
      "steam_flag",
      "Race lap "..dumps(data.lap),
      timeStr,
      10,-0.05,0.1,2)
  end
end

local function onRaceBranchChosen(data)
  -- log("E","onRaceBranchChosen", "  data="..dumps(data))
  if Steam then
    Steam.timelineAddEvent(
      "steam_transfer",
      "Race branch",
      "",
      0,-0.05,0.1,2)
  end
end

local function onRaceResult(data)
  local timeStr = string.format("%.2d:%.2d.%.3d", (data.finalTime)/60, (data.finalTime)%60, data.finalTime%1*1000)
  if Steam then
    Steam.timelineAddEvent(
      "steam_flag",
      "Race Result",
      timeStr,
      10,-0.05,0.1,2)
  end
end

local function onMissionAttemptAggregated(attempt, mission)
  -- log("E","onMissionAttemptAggregated", "  !!!!!!!!!!!!!!")
  if Steam then
    Steam.timelineAddEvent(
      "steam_flag",
      "Mission "..dumps(attempt.type),
      mission.name,
      0,-0.05,0.1,2)
  end
end


M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSettingsChanged = onSettingsChanged
M.onAnyMissionChanged = onAnyMissionChanged
M.onDeserialized    = nop -- do not remove

M.onVehicleSwitched = onVehicleSwitched
M.onClientPostStartMission = onClientPostStartMission
M.onGameStateUpdate = onGameStateUpdate
M.onAnyMissionChanged = onAnyMissionChanged
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.clientEndMission = timelineStartLoadingScreen
M.clientPreStartMission = timelineStartLoadingScreen
M.onUiReady = onUiReady
M.onUiChangedState = onUiChangedState
-- M.onScenarioFinished = onScenarioFinished
-- M.onScenarioChange = onScenarioChange
-- M.onScenarioRestarted = onScenarioRestarted
M.onResetGameplay = onResetGameplay
M.onAnyMissionChanged = onAnyMissionChanged
-- M.onPursuitOffense = onPursuitOffense
M.onNewAttempt = onNewAttempt
M.onAttemptFailed = onAttemptFailed
M.onAttemptCompleted = onAttemptCompleted
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceLap = onRaceLap
M.onRaceBranchChosen = onRaceBranchChosen
M.onRaceResult = onRaceResult
M.onMissionAttemptAggregated = onMissionAttemptAggregated
-- M.onScenarioUIReady = onScenarioUIReady

if not internal then
  enableToggleableFunctions(true)
else
  enableToggleableFunctions(false)

  if Steam then
    Steam.setRichPresence('b', "   ")
    --Steam.clearRichPresence()
  end
  if Discord then
    Discord.clearActivity()
    Discord.setEnabled(false)
  end
end

return M
