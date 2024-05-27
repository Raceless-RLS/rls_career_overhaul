-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'gameplay_missions_missions', 'gameplay_missions_missionManager','freeroam_bigMapMode', 'gameplay_playmodeMarkers', 'freeroam_bigMapPoiProvider','ui_missionInfo'}

local skipIconFading = false
-- detect player velocity
local lastPosition = vec3(0,0,0)
local lastVel
local tmpVec = vec3()
local garageBorderClr = {1,0.5,0.5}
local forceReevaluateOpenPrompt = true

local vel = vec3()
local function getVelocity(dtSim, position)
  if not position then return 0 end
  lastVel = lastVel or 10

  if dtSim > 0 then
    vel:setSub2(position, lastPosition)
    lastVel = vel:length() / dtSim
  end
  lastPosition:set(position)
  return lastVel
end

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end


local atParkingSpeed, atParkingSpeedPrev
local parkingSpeedMin, parkingSpeedMax = 1/3.6, 3/3.6
local function getParkingSpeedFactor(playerVelocity)
  if playerVelocity < parkingSpeedMin then atParkingSpeed =  true end
  if playerVelocity > parkingSpeedMax then atParkingSpeed = false end
  if atParkingSpeed == nil    then atParkingSpeed = playerVelocity < parkingSpeedMin end
  local atParkingSpeedChanged = atParkingSpeed ~= atParkingSpeedPrev
  atParkingSpeedPrev = atParkingSpeed
  return clamp(inverseLerp(parkingSpeedMin*1.25, parkingSpeedMin*0.75, playerVelocity),0,1), atParkingSpeed, atParkingSpeedChanged
end

local atCruisingSpeed, atCruisingSpeedPrev
local CruisingSpeedMin, CruisingSpeedMax = 20/3.6, 30/3.6
local function getCruisingSpeedFactor(playerVelocity)
  if playerVelocity < CruisingSpeedMin then atCruisingSpeed =  false end
  if playerVelocity > CruisingSpeedMax then atCruisingSpeed = true end
  if atCruisingSpeed == nil    then atCruisingSpeed = playerVelocity > CruisingSpeedMin end
  local atCruisingSpeedChanged = atCruisingSpeed ~= atCruisingSpeedPrev
  atCruisingSpeedPrev = atCruisingSpeed
  return (atCruisingSpeed and 1 or 0), atCruisingSpeed, atCruisingSpeedChanged
end


local currentInteractableElements = {}

local function getCurrentInteractableElements()
  return currentInteractableElements
end
M.getCurrentInteractableElements = getCurrentInteractableElements

M.formatMission = function(m)
  local info = {
    id = m.id,
    name = m.name,
    description = m.description,
    preview = m.previewFile,
    missionTypeLabel = m.missionTypeLabel or mission.missionType,
    userSettings = m:getUserSettingsData() or {},
    defaultUserSettings = m.defaultUserSettings or {},
    additionalAttributes = {},
    progress = m.saveData.progress,
    currentProgressKey = m.currentProgressKey or m.defaultProgressKey,
    unlocks = m.unlocks,
    hasUserSettingsUnlocked = gameplay_missions_progress.missionHasUserSettingsUnlocked(m.id),
    devMission = m.devMission,
    tutorialActive = (career_modules_linearTutorial and career_modules_linearTutorial.isLinearTutorialActive()) or nil,
  }

  info.hasUserSettings = #info.userSettings > 0
  local additionalAttributes, additionalAttributesSortedKeys = gameplay_missions_missions.getAdditionalAttributes()

  for _, attKey in ipairs(additionalAttributesSortedKeys) do
    local att = additionalAttributes[attKey]
    local mAttKey = m.additionalAttributes[attKey]
    local val
    if type(mAttKey) == 'string' then
      val = att.valuesByKey[m.additionalAttributes[attKey]]
    elseif type(mAttKey) == 'table' then
      val = m.additionalAttributes[attKey]
    end
    if val then
      table.insert(info.additionalAttributes, {
        icon = att.icon or "",
        labelKey = att.translationKey,
        valueKey = val.translationKey
      })
    end
  end
  for _, customAtt in ipairs(m.customAdditionalAttributes or {}) do
    table.insert(info.additionalAttributes, customAtt)
  end
  info.formattedProgress =  gameplay_missions_progress.formatSaveDataForUi(m.id)
  info.leaderboardKey = m.defaultLeaderboardKey or 'recent'

  --info.gameContextUiButtons = {}
  info.gameContextUiButtons = m.getGameContextUiButtons and m:getGameContextUiButtons()
  return info
end
M.formatDataForUi = function()
  if not M.isStateFreeroam() then return nil end
  local dataToSend = {}
  if not currentInteractableElements then return end
  for _, m in ipairs(currentInteractableElements or {}) do
    if m.missionId then
      table.insert(dataToSend, M.formatMission(gameplay_missions_missions.getMissionById(m.missionId)))
    end
  end
  table.sort(dataToSend, gameplay_missions_unlocks.depthIdSort)
  return dataToSend
end

M.startMissionById = function(id, userSettings, startingOptions)
  local m = gameplay_missions_missions.getMissionById(id)
  if m then
    if m.unlocks.startable then
      gameplay_missions_missionManager.startWithFade(m, userSettings, startingOptions or {})
      return
    else
      log("E","","Trying to start mission that is not startable due to unlocks: " .. dumps(id))
    end
  else
    log("E","","Trying to start mission with invalid id: " .. dumps(id))
  end

end

M.stopMissionById = function(id, force)
  for _, m in ipairs(gameplay_missions_missions.get()) do
    if m.id == id then
      gameplay_missions_missionManager.attemptAbandonMissionWithFade(m, force)
      return
    end
  end
end

M.changeUserSettings = function(id, settings)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then return end
  mission:processUserSettings(settings)
  guihooks.trigger('missionProgressKeyChanged', id, mission.currentProgressKey)
end

local preselectedMissionId = nil
M.setPreselectedMissionId = function(mId)
  preselectedMissionId = mId
end


local function getGameContext(fromMissionMenu)
  if gameplay_missions_missionManager.getForegroundMissionId() ~= nil then
    local activeMission = nil
    for _, m in ipairs(gameplay_missions_missions.get()) do
      if m.id == gameplay_missions_missionManager.getForegroundMissionId() then
        activeMission = m
      end
    end
    if fromMissionMenu then
      preselectedMissionId = nil
    end
    return {context = 'ongoingMission', mission = M.formatMission(activeMission)}
  else

    local missions = M.formatDataForUi()
    if M.isStateFreeroam() and missions and next(missions) then
      if fromMissionMenu then
        extensions.hook("onAvailableMissionsSentToUi", context)
      end
      local ret = {
        context = 'availableMissions',
        missions = missions,
        isWalking = gameplay_walk.isWalking(),
        isCareerActive = career_career.isActive(),
        preselectedMissionId = fromMissionMenu and preselectedMissionId or nil,
      }
      if career_modules_permissions then
        local status, message = career_modules_permissions.getStatusForTag("interactMission")
        if message then
          ret.startWarning = {label = message, title ="Delivery in progress!" }
        end
      end
      --ret.startWarning = {label = "Test Warning some long text", title="Warning"}
      if career_modules_playerAttributes then
        ret.repairOptions = {
          {
            type = "noRepair",
            label = "No",
            available = false,
            notEnoughDisplay = "Repaired vehicle needed"
          },
          {
            type = "bonusStarRepair",
            cost = 1,
            label = "For 1 bonus star",
            available = career_modules_playerAttributes.getAttributeValue('bonusStars') >= 1,
            notEnoughDisplay = "Not enough bonus stars for repair"
          },
          {
            type = "moneyRepair",
            cost = 5000,
            label = "For 5000 money",
            available = career_modules_playerAttributes.getAttributeValue('money') >= 5000,
            notEnoughDisplay = "Not enough money for repair"
          }
        }
      end
      if fromMissionMenu then
        preselectedMissionId = nil
      end
      return ret
    else
      if fromMissionMenu then
        preselectedMissionId = nil
      end
      return {context = 'empty' }
    end
  end
end
M.getGameContext = getGameContext



local detailPromptOpen = false
local promptData = {}
local function openViewDetailPrompt(elemData)
  --[[
  table.clear(promptData)
  extensions.hook("onPoiDetailPromptOpening", elemData, promptData)
  if next(promptData) then
    local label = "Prompt"
    local buttons = {}
    if #promptData == 1 then
      label = promptData[1].label
      table.insert(buttons, {
          action = "accept",
          text = promptData[1].buttonText,
          cmd = "gameplay_markerInteraction.onSelectDetailPromptClicked(1)"
        })
      table.insert(buttons, {
        action = "decline",
        text = "missions.missions.general.accept.close",
        cmd = "gameplay_markerInteraction.onCloseDetailPropmptClicked()"
      })
    else
      -- todo: design proper solution for overlapping pois...
      log("E","","Multipe Prompts are currently not supported :D")
    end
    local content = {title = label, typeName = "", altMode = false, actionMap = true, buttons = buttons }
    ui_missionInfo.openDialogue(content)
    -- TODO: fix this :)
    local missionCount = 0
    for _, elem in ipairs(elemData) do
      if elem.type == "mission" then
        missionCount = missionCount + 1
      end
    end
    guihooks.trigger("onMissionAvailabilityChanged", {missionCount = missionCount})
    extensions.hook("onOpenViewDetailPrompt", {missionCount = missionCount, elemData = elemData, promptData = promptData})
    detailPromptOpen = true
  else
    log("E","","There is no prompt data to open the prompt!")
  end
  ]]
  local activityData = {}
  extensions.hook("onActivityAcceptGatherData", elemData, activityData)
  ui_missionInfo.openActivityAcceptDialogue(activityData)
  --guihooks.trigger('ActivityAcceptUpdate', activityData)
end

local function onSelectDetailPromptClicked(idx)
  detailPromptOpen = false
  ui_missionInfo.closeDialogue()
  guihooks.trigger('ActivityAcceptUpdate', nil)
  local prompt = promptData[idx]
  if prompt and prompt.buttonFun then
    prompt.buttonFun()
  end
  table.clear(promptData)
end
M.onSelectDetailPromptClicked = onSelectDetailPromptClicked




local function closeViewDetailPrompt(force)
  if detailPromptOpen or force then
    ui_missionInfo.closeDialogue()
    guihooks.trigger("onMissionAvailabilityChanged", {missionCount = 0})
    guihooks.trigger('ActivityAcceptUpdate', nil)
    detailPromptOpen = false
    extensions.hook("onMissionAvailabilityChanged", {missionCount = 0})
  end
end
M.onCloseDetailPropmptClicked = function()
  closeViewDetailPrompt()
end

local function onUiChangedState(newUIState, prevUIState)
  if newUIState:sub(1, 4) == 'menu' then
    closeViewDetailPrompt()
  end
end


local screenWidth, screenHeight, screenRatio = 1,1,1
local function onSettingsChanged()
  local vm = GFXDevice.getVideoMode()
  screenWidth = vm.width
  screenHeight = vm.height
  screenRatio = screenWidth / screenHeight
end
M.onSettingsChanged = onSettingsChanged

local p1, p2, p3, p4, p5, p6, p7, p8 = vec3(), vec3(), vec3(), vec3(), vec3(), vec3(), vec3(), vec3()
local bbPoints = {}
local function getBBPoints(bbCenter, bbAxis0, bbAxis1, bbAxis2)
  p1:set(bbCenter) p1:setAdd(bbAxis0) p1:setAdd(bbAxis1) p1:setSub(bbAxis2)
  p2:set(bbCenter) p2:setAdd(bbAxis0) p2:setAdd(bbAxis1) p2:setAdd(bbAxis2)
  p3:set(bbCenter) p3:setSub(bbAxis0) p3:setAdd(bbAxis1) p3:setAdd(bbAxis2)
  p4:set(bbCenter) p4:setSub(bbAxis0) p4:setAdd(bbAxis1) p4:setSub(bbAxis2)
  p5:set(bbCenter) p5:setAdd(bbAxis0) p5:setSub(bbAxis1) p5:setSub(bbAxis2)
  p6:set(bbCenter) p6:setAdd(bbAxis0) p6:setSub(bbAxis1) p6:setAdd(bbAxis2)
  p7:set(bbCenter) p7:setSub(bbAxis0) p7:setSub(bbAxis1) p7:setAdd(bbAxis2)
  p8:set(bbCenter) p8:setSub(bbAxis0) p8:setSub(bbAxis1) p8:setSub(bbAxis2)
  bbPoints[1] = p1; bbPoints[2] = p2; bbPoints[3] = p3; bbPoints[4] = p4;
  bbPoints[5] = p5; bbPoints[6] = p6; bbPoints[7] = p7; bbPoints[8] = p8;
  return bbPoints
end

local veh

local updateData = {}
local decals = {}
local nearbyIds = {}
local quadTreeSettings = {}
local clustersById = {}
local interactableElements = {}

local lastCamPos = vec3()
local lastCamVel = vec3()
local playerVelLast = vec3()
local timeSincePlayerTeleport

local function displayMissionMarkers(level, dtSim, dtReal)
  profilerPushEvent("MissionMarker precalc")
  local activeMission = gameplay_missions_missionManager.getForegroundMissionId()
  local globalAlpha = 1
  if activeMission then
    globalAlpha = 0
  end
  veh = getPlayerVehicle(0)
  if veh then
    updateData.veh = veh
    updateData.vehPos = updateData.vehPos or vec3()
    updateData.vehPos:set(veh:getPositionXYZ())
    updateData.vehPos2d = updateData.vehPos2d or vec3()
    updateData.vehPos2d:set(updateData.vehPos)
    updateData.vehPos2d.z = 0
    updateData.vehVelocity = updateData.vehVelocity or vec3()
    updateData.vehVelocity:set(veh:getVelocityXYZ())

    local vehId = veh:getID()
    updateData.bbCenter = updateData.bbCenter or vec3()
    updateData.bbCenter:set(be:getObjectOOBBCenterXYZ(vehId))
    updateData.bbHalfAxis0 = updateData.bbHalfAxis0 or vec3()
    updateData.bbHalfAxis0:set(be:getObjectOOBBHalfAxisXYZ(vehId, 0))
    updateData.bbHalfAxis1 = updateData.bbHalfAxis1 or vec3()
    updateData.bbHalfAxis1:set(be:getObjectOOBBHalfAxisXYZ(vehId, 1))
    updateData.bbHalfAxis2 = updateData.bbHalfAxis2 or vec3()
    updateData.bbHalfAxis2:set(be:getObjectOOBBHalfAxisXYZ(vehId, 2))

    updateData.bbPoints = getBBPoints(updateData.bbCenter, updateData.bbHalfAxis0, updateData.bbHalfAxis1, updateData.bbHalfAxis2)

    updateData.highestBBPointZ = math.max(updateData.bbPoints[2].z, math.max(updateData.bbPoints[3].z, math.max(updateData.bbPoints[6].z, updateData.bbPoints[7].z)))
  end

  updateData.playerPosition = veh and updateData.vehPos or updateData.camPos


  local playerVelocity = getVelocity(dtSim, updateData.playerPosition)
  -- this is 64 garbage
  updateData.isWalking = gameplay_walk and gameplay_walk.isWalking() or false

  profilerPushEvent("MissionEnter parkingSpeedFactor")
  local parkingSpeedFactor, isAtParkingSpeed, parkingSpeedChanged = getParkingSpeedFactor(playerVelocity)
  local cruisingSpeedFactor, isAtcruisingSpeed, cruisingSpeedChanged = getCruisingSpeedFactor(playerVelocity)

  profilerPopEvent("MissionEnter parkingSpeedFactor")
  -- put reference for icon manager in
  updateData.parkingSpeedFactor = parkingSpeedFactor
  updateData.cruisingSpeedFactor = cruisingSpeedFactor
  updateData.dt = dtReal
  updateData.globalAlpha = globalAlpha
  updateData.camPos = updateData.camPos or vec3()
  updateData.camPos:set(core_camera.getPositionXYZ())
  updateData.camRot = updateData.camRot or quat()
  updateData.camRot:set(core_camera.getQuatXYZW())
  updateData.bigMapActive = freeroam_bigMapMode.bigMapActive()
  updateData.bigmapTransitionActive = freeroam_bigMapMode.isTransitionActive()
  updateData.isFreeCam = commands.isFreeCamera()
  updateData.windowAspectRatio = screenRatio
  updateData.screenHeight = screenHeight
  -- TODO: Clean this up
  table.clear(nearbyIds)
  -- hide all the markers behind the camera
  local maxRadius = 100
  profilerPushEvent("MissionEnter QTStuff")
      -- transitioning or normal play mode
  if   (not freeroam_bigMapMode.bigMapActive())
    or (freeroam_bigMapMode.bigMapActive() and freeroam_bigMapMode.isTransitionActive()) then
    local clusterQt = gameplay_playmodeMarkers.getPlaymodeClustersAsQuadtree()
    for id in clusterQt:queryNotNested(updateData.playerPosition.x-maxRadius, updateData.playerPosition.y-maxRadius, updateData.playerPosition.x+maxRadius, updateData.playerPosition.y + maxRadius) do
      nearbyIds[id] = true
    end
  end

  if freeroam_bigMapMode.navigationPoiId  then
    nearbyIds[freeroam_bigMapMode.navigationPoiId] = true
  end

  profilerPopEvent("MissionEnter QTStuff")
  --table.clear(visibleIdsSorted)
  --tableKeys(visibleIds, visibleIdsSorted)
  --table.sort(visibleIdsSorted)
  profilerPopEvent("MissionEnter precalc")
  if not isAtParkingSpeed then
    table.clear(currentInteractableElements)
  end
  table.clear(decals)

  local decalCount = 0
  local careerActive = (career_career and career_career.isActive())
  table.clear(interactableElements)
  local showMissionMarkers = settings.getValue("showMissionMarkers")
  -- draw/show all visible markers.
  if not timeSincePlayerTeleport then
    timeSincePlayerTeleport = core_camera.objectTeleported(updateData.camPos, lastCamPos, playerVelLast, dtReal) and 0.5
  end
  if timeSincePlayerTeleport then
    timeSincePlayerTeleport = timeSincePlayerTeleport - dtReal
    if timeSincePlayerTeleport <= 0 then timeSincePlayerTeleport = nil end
  end

  for i, cluster in ipairs(gameplay_playmodeMarkers.getPlaymodeClusters()) do
    local marker = gameplay_playmodeMarkers.getMarkerForCluster(cluster)
    if nearbyIds[cluster.id] or marker.focus or timeSincePlayerTeleport then
      -- Check if the marker should be visible
      local showMarker = not photoModeOpen and not editor.active
      if marker.type == "missionMarker" then
        showMarker = (showMissionMarkers or cluster.focus)
      end
      if showMarker or timeSincePlayerTeleport then
        -- debug drawing for testing
        --debugDrawer:drawTextAdvanced(cluster.pos, String(tostring(id)), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
        --debugDrawer:drawSphere(cluster.pos, cluster.radius, ColorF(0.91,0.05,0.48,0.2))
        marker:show()
        marker:update(updateData)
        -- post-marker decals, so they can be all drawn at once
        if marker.groundDecalData then
          decalCount = decalCount + 1
          decals[decalCount] = marker.groundDecalData
        end

        if not freeroam_bigMapMode.bigMapActive() and not activeMission and not core_recoveryPrompt.isOpen() then
          if marker.interactInPlayMode then
            -- todo: optimize this
            if veh then
              local canInteract = isAtParkingSpeed and (forceReevaluateOpenPrompt or parkingSpeedChanged)

              updateData.canInteract = canInteract
              if updateData.canInteract then
                marker:interactInPlayMode(updateData, interactableElements)
              end
              --simpleDebugText3d(dumps(marker.cluster.clusterId), marker.cluster.pos, 0.25)
            end
          end
        end
      else
        marker:hide()
      end
    else
      marker:hide()
    end
  end
  lastCamPos:set(updateData.camPos)
  if veh then
    playerVelLast:set(be:getObjectVelocityXYZ(veh:getID()))
  end
  --print("Force forceReevaluateOpenPrompt " .. dumps(forceReevaluateOpenPrompt))
  forceReevaluateOpenPrompt = false
  if next(interactableElements) then
    table.clear(currentInteractableElements)
    for i, elem in ipairs(interactableElements) do
      currentInteractableElements[i] = elem
    end
    openViewDetailPrompt(interactableElements)
  end
  if not activeMission and not next(interactableElements) then
    if not isAtParkingSpeed or parkingSpeedChanged then
      closeViewDetailPrompt(parkingSpeedChanged)
    end
  end
  skipIconFading = false
  Engine.Render.DynamicDecalMgr.addDecals(decals, decalCount)
end

local pos2Offset = vec3(0, 0, 1000)
local columnColor = ColorF(1,1,1,1)
local function drawDistanceColumn(targetPos)
  local camPos = core_camera.getPosition()
  local dist = camPos:distance(targetPos)
  local radius = math.max(dist/400, 0.1)
  local targetPos2 = targetPos + pos2Offset
  local alpha = clamp((dist-50)/200, 0, 0.6)
  columnColor.alpha = alpha
  debugDrawer:drawCylinder(targetPos, targetPos2, radius, columnColor)
end

-- gets called only while career mode is enabled
local function onPreRender(dtReal, dtSim)
  if not M.isStateFreeroam() then
    gameplay_playmodeMarkers.clear()
    closeViewDetailPrompt()
    return
  end
  profilerPushEvent("MissionEnter onPreRender")
  profilerPushEvent("MissionEnter groundMarkers")
  -- Disable navigation when player is close to the goal
  if gameplay_missions_missionManager then
    if gameplay_missions_missionManager.getForegroundMissionId() == nil and core_groundMarkers.currentlyHasTarget() then
      if freeroam_bigMapMode and not freeroam_bigMapMode.bigMapActive() and type(core_groundMarkers.endWP[1]) == "cdata" then -- is vec3
        local nextFixedWP = core_groundMarkers.routePlanner:getNextFixedWP()
        if nextFixedWP then
          drawDistanceColumn(nextFixedWP)
        end
        if core_groundMarkers.getPathLength() < 10 then
          freeroam_bigMapMode.reachedTarget()
        end
      end
    end
    if freeroam_bigMapMode and freeroam_bigMapMode.reachedTargetPos then
      local veh = getPlayerVehicle(0)
      if veh then
        local vehPos = veh:getPosition()
        if vehPos:distance(freeroam_bigMapMode.reachedTargetPos) > 50 then
          freeroam_bigMapMode.resetForceVisible()
        end
      end
    end
  end

  profilerPopEvent("MissionEnter groundMarkers")


  -- check if we've switched level
  local level = getCurrentLevelIdentifier()
  if level then
    profilerPushEvent("DisplayMissionMarkers")
    displayMissionMarkers(level, dtSim, dtReal)
    profilerPopEvent("DisplayMissionMarkers")
  end

  profilerPopEvent("MissionEnter onPreRender")

end


local function clearCache()
  M.setForceReevaluateOpenPrompt()
end


local function skipNextIconFading()
  skipIconFading = true
end

local function showMissionMarkersToggled(active)
  gameplay_rawPois.clear()
  freeroam_bigMapPoiProvider.forceSend()

  closeViewDetailPrompt()
end


local function onAnyMissionChanged(state)
  freeroam_bigMapPoiProvider.forceSend()
  if state == "started" then
    freeroam_bigMapMode.deselect()
    freeroam_bigMapMode.resetForceVisible()
  end
end

M.isStateFreeroam = function()
  if core_gamestate.state and (core_gamestate.state.state == "freeroam" or core_gamestate.state.state == 'career') then
    return true
  end
  return false
end

M.closeViewDetailPrompt = closeViewDetailPrompt
M.showMissionMarkersToggled = showMissionMarkersToggled

M.restartCurrent = restartCurrent
M.abandonCurrent = abandonCurrent

M.skipNextIconFading = skipNextIconFading
M.onPreRender = onPreRender

M.getClusterMarker = getClusterMarker

M.onUiChangedState = onUiChangedState
M.onAnyMissionChanged = onAnyMissionChanged
M.clearCache = clearCache
M.setForceReevaluateOpenPrompt = function()
  forceReevaluateOpenPrompt = true
end

M.onUIPlayStateChanged = function(enteredPlay)
  if enteredPlay then
    M.setForceReevaluateOpenPrompt()
  end
end
return M