-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {state={}}

local logTag = 'freeroam'

local inputActionFilter = extensions.core_input_actionFilter

local function startFreeroamHelper (level, startPointName, spawnVehicle)
  core_gamestate.requestEnterLoadingScreen(logTag .. '.startFreeroamHelper')
  unloadAutoExtensions()
  loadPresetExtensions()
  extensions.load("gameplay/events/freeroamEvents")
  setExtensionUnloadMode("gameplay/events/freeroamEvents", "manual")
  M.state = {}
  M.state.freeroamActive = true

  local levelPath = level
  if type(level) == 'table' then
    setSpawnpoint.setDefaultSP(startPointName, level.levelName)
    levelPath = level.misFilePath
  end

  inputActionFilter.clear(0)

  if spawnVehicle == false then
    -- clear the previous vehicle data so we don't spawn a vehicle
    TorqueScriptLua.setVar('$beamngVehicle', '')
    TorqueScriptLua.setVar('$beamngVehicleConfig', '')
    TorqueScriptLua.setVar('$beamngVehicleColor', '')
    TorqueScriptLua.setVar('$beamngVehicleMetallicPaintData', '')
    TorqueScriptLua.setVar('$beamngVehicleLicenseName', '')
    TorqueScriptLua.setVar('$beamngVehicleArgs', '')
  end

  core_levels.startLevel(levelPath, nil, nil, spawnVehicle)
  core_gamestate.requestExitLoadingScreen(logTag .. '.startFreeroamHelper')
end

local function startAssociatedFlowgraph(level)
-- load flowgraphs associated with this level.
  if level.flowgraphs then
    for _, absolutePath in ipairs(level.flowgraphs or {}) do
      local relativePath = level.misFilePath..absolutePath
      local path = FS:fileExists(absolutePath) and absolutePath or (FS:fileExists(relativePath) and (relativePath) or nil)
      if path then
        local mgr = core_flowgraphManager.loadManager(path)
        --core_flowgraphManager.startOnLoadingScreenFadeout(mgr)
        mgr:setRunning(true)
        mgr.stopRunningOnClientEndMission = true -- make mgr self-destruct when level is ended.
        mgr.removeOnStopping = true -- make mgr self-destruct when level is ended.
        log("I", "Flowgraph loading", "Loaded level-associated flowgraph from file "..dumps(path))
      else
        log("E", "Flowgraph loading", "Could not find file in either '" .. absolutePath.."' or '" .. relativePath.."'!")
      end
    end
  end
end

local function startFreeroam(level, startPointName, wasDelayed, spawnVehicle)
  core_gamestate.requestEnterLoadingScreen(logTag)
  -- if this was a delayed start, load the FGs now.
  --if wasDelayed then
  --  startAssociatedFlowgraph(level)
  --end

  -- this is to prevent bug where freeroam is started while a different level is still loaded.
  -- Loading the new freeroam causes the current loaded freeroam to unload which breaks the new freeroam
  local delaying = false
  if scenetree.MissionGroup then
    log('D', logTag, 'Delaying start of freeroam until current level is unloaded...')
    M.triggerDelayedStart = function()
      log('D', logTag, 'Triggering a delayed start of freeroam...')
      M.triggerDelayedStart = nil
      startFreeroam(level, startPointName, true, spawnVehicle)
    end
    endActiveGameMode(M.triggerDelayedStart)
    delaying = true
  elseif not core_gamestate.getLoadingStatus(logTag .. '.startFreeroamHelper') then -- remove again at some point
    startFreeroamHelper(level, startPointName, spawnVehicle)
    core_gamestate.requestExitLoadingScreen(logTag)
  end
  -- if there was no delaying and the function call itself didnt
  -- come from a delayed start, load the FGs (starting from main menu)
  if not delaying then
    startAssociatedFlowgraph(level)
  end
end

local function startFreeroamByName(levelName, startPointName, wasDelayed, spawnVehicle)
  local level = core_levels.getLevelByName(levelName)
  if level then
    startFreeroam(level, startPointName, wasDelayed, spawnVehicle)
    return true
  end
  return false
end

local function onPlayerCameraReady()
  if M.state.freeroamActive and gameplay_traffic.getState() == 'off' and settings.getValue('trafficLoadForFreeroam') then
    log('I', logTag, 'Now spawning traffic for freeroam mode')
    if settings.getValue('trafficParkedVehicles') then
      gameplay_parking.setupVehicles()
    end
    gameplay_traffic.setupTraffic()
  end
end

local function onClientPreStartMission(levelPath)
  local path, file, ext = path.splitWithoutExt(levelPath)
  file = path .. 'mainLevel'
  if not FS:fileExists(file..'.lua') then return end
  extensions.loadAtRoot(file,"")
  if mainLevel and mainLevel.onClientPreStartMission then
    mainLevel.onClientPreStartMission(levelPath)
  end
end

local function onClientStartMission(levelPath)
  local path, file, ext = path.splitWithoutExt(levelPath)
  file = path .. 'mainLevel'

  if M.state.freeroamActive then
    extensions.hook('onFreeroamLoaded', levelPath)

    local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:push() end
  end
end

local function onClientEndMission(levelPath)
  if M.state.freeroamActive then
    M.state.freeroamActive = false
    local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:pop() end
  end

  if not mainLevel then return end
  local path, file, ext = path.splitWithoutExt(levelPath)
  extensions.unload(path .. 'mainLevel')
end

-- Resets previous vehicle alpha when switching between different vehicles
-- Used to fix multipart highlighting when switching vehicles
local function onVehicleSwitched(oldId, newId, player)
  extensions.core_vehicle_partmgmt.showHighlightedParts(oldId)
end

local function onVehicleSpawned(vehID)
  extensions.core_vehicle_partmgmt.resetVehicleHighlights(true, vehID)
  extensions.core_vehicle_partmgmt.setNewParts(vehID)
  extensions.core_vehicle_partmgmt.showHighlightedParts(vehID)
end

local function onResetGameplay(playerID)
  if scenario_scenarios and scenario_scenarios.getScenario() then return end
  if campaign_campaigns and campaign_campaigns.getCampaign() then return end
  --if career_career and career_career.isActive() then return end
  if core_recoveryPrompt.isActive() then return end
  for _, mgr in ipairs(core_flowgraphManager.getAllManagers()) do
    if mgr:blocksOnResetGameplay() then return end
  end

  be:resetVehicle(playerID)
end

local function startTrackBuilder(levelName, forceLoad)
  extensions.load("trackbuilder_trackBuilder")

  if not trackbuilder_trackBuilder then
    log('E', logTag, 'Could not find trackbuilder extentions')
    return
  end

  if getCurrentLevelIdentifier() == nil or forceLoad then
    local level = core_levels.getLevelByName(levelName)
    if not level then
      log('E', logTag, 'Level not found: ' .. tostring(levelName))
      return
    end

    local callback = function ()
      log('I', logTag, 'startTrackBuilder callback triggered...')
      trackbuilder_trackBuilder.showTrackBuilder()
    end

    extensions.setCompletedCallback("onClientStartMission", callback);
    startFreeroam(level)
  else
    trackbuilder_trackBuilder.toggleTrackBuilder()
    guihooks.trigger("MenuHide")
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if worldReadyState == 0 then
    commands.initCamera()
    if not getPlayerVehicle(0) then
      commands.setFreeCamera()
    end
  end
end

local function isStateFreeroam()
  if core_gamestate.state and (core_gamestate.state.state == "freeroam") then
    return true
  end
  return false
end

local function onSpeedTrapTriggered(speedTrapData, playerSpeed, overSpeed)
  if not speedTrapData.speedLimit then return end
  if not isStateFreeroam() or speedTrapData.subjectID ~= be:getPlayerVehicleID(0) then
    return
  end
  local veh = getPlayerVehicle(0)
  local highscore, leaderboard = gameplay_speedTrapLeaderboards.addRecord(speedTrapData, playerSpeed, overSpeed, veh)
  ui_message({txt="ui.freeroam.speedTrap.speedingMessage", context={licensePlate = core_vehicles.getVehicleLicenseText(veh), recordedSpeed = playerSpeed, speedLimit = speedTrapData.speedLimit}}, 10, 'speedTrap')

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
  if not isStateFreeroam() or speedTrapData.subjectID ~= be:getPlayerVehicleID(0) then
    return
  end
  local veh = getPlayerVehicle(0)
  ui_message({txt="ui.freeroam.speedTrap.redLightMessage", context={licensePlate = core_vehicles.getVehicleLicenseText(veh)}}, 10, 'speedTrap')
end

-- public interface
M.startFreeroam = startFreeroam
M.startFreeroamByName = startFreeroamByName
M.onPlayerCameraReady = onPlayerCameraReady
M.onClientPreStartMission = onClientPreStartMission
M.onClientPostStartMission = onClientPostStartMission
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleSpawned = onVehicleSpawned
M.onResetGameplay = onResetGameplay
M.startTrackBuilder = startTrackBuilder
M.onUpdate = onUpdate
M.onSpeedTrapTriggered = onSpeedTrapTriggered
M.onRedLightCamTriggered = onRedLightCamTriggered

return M
