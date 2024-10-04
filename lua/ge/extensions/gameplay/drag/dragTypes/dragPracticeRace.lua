-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"gameplay_drag_general"}

local logTag = ""
local dragData
local hasActivityStarted = false
local freeroamEvents = require("career/modules/freeroamEvents")

local minDistance = 0.8 --m
local minVelToStop = 20 --m/s

local function changeRacerPhase(racer)
  local index = racer.currentPhase + 1
  if index > #dragData.phases then
    racer.isFinished = true
    return
  end
  racer.currentPhase = index
  log("I", logTag, "This is the new phase: " .. racer.phases[racer.currentPhase].name .. " for vehicle: " .. tostring(racer.vehId))
end

local tmp = vec3()
local function calculateDistanceFromStagePos(racer)
  tmp:set(dragData.strip.lanes[racer.lane].stage.transform.pos)
  tmp:setSub(racer.frontWheelCenter)
  return tmp:dot(dragData.strip.lanes[racer.lane].stage.toEndNormalized)
end

-- TODO: this seems not to be used?
--[[
local function getDistanceFromOrigin(vehId, origin)
  if not vehId or not dragData.racers[vehId].vehObj then return end
  local vehPos = getFrontWheelTransform(vehId)
  local dir = vec3(dragData.racers[vehId].vehObj:getDirectionVector())
  return dir:dot(vehPos-origin)
end
]]

local function areFrontWheelsParallelToLine(racer, lineTransform)
  if not lineTransform then
    log('E', logTag, 'Invalid line definition.')
    return false
  end

  -- Check if the two directions are parallel by comparing their dot product
  local dotProduct = racer.vehDirectionVector:dot(lineTransform.y)
  local tolerance = 0.70
  return math.abs(dotProduct) >= tolerance
end

--This is called from the dragRace/display.lua once the christmasTree is finished or any other system determine that the race must start
local function startRaceFromTree(vehId)
  if not dragData then return end
  dragData.racers[vehId].phases[dragData.racers[vehId].currentPhase].completed = true
end

-- local function prestage(phase, racer, dtSim)
--   if not dragData then log('E', logTag, 'No drag data aviable, stopping phase') return end

--   if not phase.completed then
--     local distance = calculateDistanceFromStagePos(racer, dragData.strip.lanes[racer.lane].stage.transform.pos)
--     phase._distance = distance
--     if not distance then --If there is no distance return the next frame
--       log("E", logTag, 'No distance found, returning nil')
--       return
--     end
--     if not phase.started then
--       local timer = phase.timerOffset + dtSim
--       phase.timerOffset = timer
--       if  phase.timerOffset >= phase.startedOffset then
--         phase.started = true
--         extensions.hook("preStageStarted")
--         log('I', logTag, racer.vehId .. " started prestage")
--       end
--     end
--     -- be closer than 0.8m to complete prestage
--     if distance < 0.8 then
--       extensions.hook("preStageEnded", racer.vehId)
--       phase.completed = true
--       log('I', logTag, racer.vehId .. " completed prestage")
--       return
--     end

--     if math.abs(distance) > 25 then
--       racer.isDesqualified = true
--       racer.desqualifiedReason = "missions.dragRace.gameplay.disqualified.outOfLane"
--       extensions.hook("jumpDescualifiedDrag", racer.vehId)
--       log('I', logTag, 'Desqualifying '..racer.vehId)
--       M.resetDragRace()
--     end
--   end
-- end

local function stage(phase, racer, dtSim)
  if not dragData then log('E', logTag, 'No drag data aviable, stopping phase') return end

  if not phase.completed then
    local distance = calculateDistanceFromStagePos(racer)
    phase._distance = distance
    if not distance then --If there is no distance return the next frame
      log("E", logTag, 'No distance found, returning nil')
      return
    end
    if not phase.started then
      local timer = phase.timerOffset + dtSim
      phase.timerOffset = timer
      if  phase.timerOffset >= phase.startedOffset then
        phase.started = true
        extensions.hook("stageStarted")
        log('I', logTag, racer.vehId .. " started stage" )
      end
    end
    if math.abs(distance) > 25 then
      racer.isDesqualified = true
      racer.desqualifiedReason = "missions.dragRace.gameplay.disqualified.outOfLane"
      extensions.hook("jumpDescualifiedDrag", racer.vehId)
      log('I', logTag, 'Desqualifying '..racer.vehId)
      M.resetDragRace()
    elseif distance > 0.278 then
      extensions.hook("preStageStarted", racer.vehId)
      freeroamEvents.displayStagedMessage("drag")
      phase.completeTimer = 0
    elseif distance <= 0.278 and distance >= 0.1 then
      extensions.hook("preStageEnded", racer.vehId)
      phase.completeTimer = 0
    elseif distance < 0 and distance >= -0.1 and areFrontWheelsParallelToLine(racer, dragData.strip.lanes[racer.lane].stage.transform) then
      extensions.hook("dragRaceStageEndedDeep", racer.vehId)
      phase.completeTimer = (phase.completeTimer or 0) + dtSim
      if phase.completeTimer > 1 then
        phase.completed = true
        log('I', logTag, "Stage completed for vehicle: " .. racer.vehId)
        return
      end
    elseif distance < -0.1 then
      extensions.hook("dragRaceOutForward", racer.vehId)
      phase.completeTimer = 0
    elseif areFrontWheelsParallelToLine(racer, dragData.strip.lanes[racer.lane].stage.transform) then
      extensions.hook("stageEnded", racer.vehId)
      phase.completeTimer = (phase.completeTimer or 0) + dtSim

      if phase.completeTimer > 1 then
        phase.completed = true
        log('I', logTag, "Stage completed for vehicle: " .. racer.vehId)
        return
      end
    else
      extensions.hook("dragRaceOutParallel", racer.vehId)
      phase.completeTimer = 0
    end
  end
end

local function startTreeLight(phase, racer, dtSim)
  if not dragData then log('E', logTag, 'No drag data aviable, stopping phase') return end

  if not phase.completed then
    local distance = calculateDistanceFromStagePos(racer)
    phase._distance = distance
    if not distance then --If there is no distance return the next frame
      log("E", logTag, 'No distance found, returning nil')
      return
    end
    if not phase.started then
      local timer = phase.timerOffset + dtSim
      phase.timerOffset = timer
      if  phase.timerOffset >= phase.startedOffset then
        extensions.hook("startDragCountdown")
        phase.started = true
        log('I', logTag, 'Starting countdown for '..racer.vehId)
        freeroamEvents.saveAndSetTrafficAmount(0)
      end
    end
     --Determines if the vehicle moved too much during the tree lights countdown.
    if distance > 0.2 or distance < -0.2 then
      racer.isDesqualified = true
      racer.desqualifiedReason = "missions.dragRace.gameplay.disqualified.jumping"
      extensions.hook("jumpDescualifiedDrag", racer.vehId)
      log('I', logTag, 'Desqualifying '..racer.vehId)
      M.resetDragRace()
      freeroamEvents.restoreTrafficAmount()
      return
    end
  end
end

local function race(phase, racer, dtSim)
  if not dragData then log('E', logTag, 'No drag data aviable, stopping phase') return end

  if not phase.completed then
    if not phase.started then

      local timer = phase.timerOffset + dtSim
      phase.timerOffset = timer
      if  phase.timerOffset >= phase.startedOffset then
        phase.started = true
        extensions.hook("dragRaceStarted")
        log('I', logTag, 'Starting Phase '..phase.name..' for '..racer.vehId)
        freeroamEvents.displayMessage(freeroamEvents.getStartMessage("drag"), 5)
      end
    end

    if racer.timers.time_1_4.isSet then
      phase.completed = true
      extensions.hook("dragRaceEndLineReached", racer.vehId)
      log('I', logTag, 'Completed Phase '..phase.name..' for '..racer.vehId)
      freeroamEvents.payoutDragRace("drag", racer.timers.time_1_4.value, racer.vehSpeed * 2.2369362921)
      return
    else
      local dist = calculateDistanceFromStagePos(racer)
      phase._distance = dist
      if not M.isRacerInsideBoundary(racer) or dist > 1 then
        racer.isDesqualified = true
        racer.desqualifiedReason = "missions.dragRace.gameplay.disqualified.outOfLane" --TODO
        extensions.hook("jumpDescualifiedDrag", racer.vehId)
        log('I', logTag, 'Desqualifying '..racer.vehId)
        M.resetDragRace()
        freeroamEvents.displayMessage("You Jumped the Start", 5)
      end
    end
  end
end

local function stop(phase, racer, dtSim)
  if not dragData then log('E', logTag, 'No drag data aviable, stopping phase') return end

  if not phase.completed then
    if not phase.started then
      local timer = phase.timerOffset + dtSim
      phase.timerOffset = timer
      if  phase.timerOffset >= phase.startedOffset then
        phase.started = true
        extensions.hook("stoppingVehicleDrag", racer.vehId)
      end
    end
    if racer.vehSpeed < minVelToStop then
      extensions.hook("dragRaceVehicleStopped", racer.vehId)
      phase.completed = true
      log('I', logTag, 'Completed Phase '..phase.name..' for '..racer.vehId)
    end
  end
end

--This will have all the phases aviable in all the different types of the drag gameplay, so if we want to add any phase we will only have to add it here.
local funcPhases = {
  ["prestage"] = prestage,
  ["stage"] = stage,
  ["start"] = startTreeLight,
  ["race"] = race,
  ["stop"] = stop,
}

local function resetDragRace()
  if not dragData then return end
  extensions.hook("resetDragRaceValues")
  --[[
  log('I', logTag, 'Reseting Drag Race')
  hasActivityStarted = false

  dragData.isStarted = false
  dragData.isCompleted = false

  for vehId, racerData in pairs(dragData.racers) do
    log('I', logTag, 'Reseting racer: '.. vehId)
    racerData.currentPhase = 1
    racerData.isDesqualified = false
    racerData.desqualifiedReason = "None"
    racerData.isFinished = false

    --Reset Phases
    log('I', logTag, 'Reseting phases for: '.. vehId)
    for _, p in ipairs(racerData.phases) do
      p.started = false
      p.completed = false
      p.timerOffset = 0
    end
  end

  ]]
  gameplay_drag_general.unloadRace()
end

local function startActivity()
  dragData = gameplay_drag_general.getData()

  if not dragData then
    log('E', logTag, 'No drag race data found')
  end
  dragData.isStarted = true

  hasActivityStarted = dragData.isStarted
end

local function isRacerInsideBoundary(racer)
  local playerLane = racer.lane
  if not playerLane or not dragData.strip.lanes[playerLane] then
    log('E', logtag, 'No valid lane found for racer: ' .. racer.vehId)
    return false
  end

  local boundary = dragData.strip.lanes[playerLane].boundary.transform
  if not boundary or type(boundary) ~= "table" then
    log('E', logTag, 'No valid boundary found for racer: ' .. racer.vehId)
    return false
  end
  local x, y, z = boundary.rot * vec3(boundary.scl.x,0,0), boundary.rot * vec3(0,boundary.scl.y,0), boundary.rot * vec3(0,0,boundary.scl.z)
  return containsOBB_point(boundary.pos, x, y, z, racer.vehPos )
end
M.isRacerInsideBoundary = isRacerInsideBoundary


-- TODO: put this into a general "racer.lua" file
local function updateRacer(racer)
  local veh = scenetree.findObjectById(racer.vehId)
  racer.vehPos:set(veh:getPositionXYZ())
  racer.vehDirectionVector:set(veh:getDirectionVectorXYZ())
  racer.vehDirectionVectorUp:set( veh:getDirectionVectorUpXYZ())
  -- todo: optimize...
  racer.vehRot = quatFromDir(racer.vehDirectionVector, racer.vehDirectionVectorUp)

  racer.vehVelocity:set(veh:getVelocityXYZ())
  racer.prevSpeed = racer.vehSpeed
  racer.vehSpeed = racer.vehVelocity:length()

  -- front wheelcenter
  racer.frontWheelCenter:set(0,0,0)
  for _, offset in ipairs(racer.wheelsOffsets) do
    racer.frontWheelCenter:setAdd(racer.vehRot*offset)
  end
  racer.frontWheelCenter:setScaled(racer.wheelCountInv)
  racer.frontWheelCenter:setAdd(racer.vehPos)
end



local function onUpdate(dtReal, dtSim, dtRaw)
  if hasActivityStarted then
    if not dragData then
      log('E', logTag, 'No drag data found!')
      return
      end
    if not dragData.racers then
      log('E', logTag, 'There is no racers in the drag data.')
      return
    end

    for vehId, racer in pairs(dragData.racers) do
      if racer.isFinished then
        dragData.isCompleted = true
        resetDragRace()
        freeroamEvents.restoreTrafficAmount()
        hasActivityStarted = false
        return
      end

      updateRacer(racer)

      local phase = racer.phases[racer.currentPhase]
      funcPhases[phase.name](phase, racer, dtSim)
      --making sure that the vehicle reference is not used outside of phase update
      racer.veh = nil
      if phase.completed and not racer.isFinished then
        log('I', logTag, 'Racer: '.. racer.vehId ..' completed phase: '.. phase.name)
        changeRacerPhase(racer)
      end
    end
  end
end

local function onExtensionLoaded()
  log("I", logTag, "dragRace extension loaded")
  dragData = gameplay_drag_general.getData()
  if dragData.strip.prefabs.christmasTree.isUsed then
    extensions.load('gameplay_drag_times')
  end
  if dragData.strip.prefabs.displaySign.isUsed then
    extensions.load('gameplay_drag_display')
  end

  if not dragData then
    log('E', logTag, 'No drag race data found')
  end
  dragData.isStarted = true

  hasActivityStarted = dragData.isStarted
end

--PUBLIC INTERFACE
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.startRaceFromTree = startRaceFromTree
M.getDistanceFromOrigin = getDistanceFromOrigin
M.getRacerVelocity = getVelocity
M.startActivity = startActivity
M.resetDragRace = resetDragRace

return M