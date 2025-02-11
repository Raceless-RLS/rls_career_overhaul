-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local yVec = vec3(0,1,0)

local camDistanceLimit = 100
local defaultRedLightTriggerSpeed = 5

local function speedCamLightJob(job, lightObj)
  job.sleep(0.1 / math.max(simTimeAuthority.getReal(), 0.001))
  lightObj.isEnabled = false
end

local function redLightLightJob(job, lightObj, delay)
  job.sleep(0.1 / math.max(simTimeAuthority.getReal(), 0.001))
  lightObj.isEnabled = false
  job.sleep(delay / math.max(simTimeAuthority.getReal(), 0.001))
  lightObj.isEnabled = true
  job.sleep(0.1 / math.max(simTimeAuthority.getReal(), 0.001))
  lightObj.isEnabled = false
end

local vehVelocity = vec3()
local triggerDir = vec3()
local vehPos = vec3()
local camPos = vec3()

--[[
  example data
  {
    event = "enter",
    speedLimit = "11.176",
    speedTrapLightName = "speedTrapLight1",
    speedTrapType = "speed",
    subjectID = 46855,
    subjectName = "clone0",
    triggerEvent = 0,
    triggerID = 16584,
    triggerName = "speedTrapTrigger1"
  }
]]
local function onBeamNGTrigger(data)
  if not data or not data.speedTrapType then return end

  if data.event == 'enter' and not gameplay_missions_missionManager.getForegroundMissionId() then
    -- Exit early if too far from camera
    vehPos:set(be:getObjectPositionXYZ(data.subjectID))
    camPos:set(core_camera.getPositionXYZ())
    if vehPos:distance(camPos) > camDistanceLimit then return end

    local isRedLightCamera = data.speedTrapType == "redLight"

    vehVelocity:set(be:getObjectVelocityXYZ(data.subjectID))
    local vehSpeed = vehVelocity:length()
    local speedLimit = data.speedLimit or 0
    local speedLimitTolerance = 4.5
    local triggerSpeed = isRedLightCamera and (tonumber(data.triggerSpeed) or defaultRedLightTriggerSpeed) or (speedLimit + speedLimitTolerance)
    local overSpeed = vehSpeed - speedLimit

    -- check if over speedlimit
    if vehSpeed > triggerSpeed then
      local triggerObj = scenetree.findObjectById(data.triggerID)
      if not triggerObj then return end

      -- TODO could also make a cache for the trigger direction
      local triggerRotation = quat(triggerObj:getRotation())
      triggerDir:setRotate(triggerRotation, yVec)

      if triggerDir:dot(vehVelocity) > 0 then

        local trafficSignalColor
        if isRedLightCamera then
          local trafficSignal = core_trafficSignals.getSignalByName(data.trafficSignalId)
          trafficSignalColor = trafficSignal:getState()
          if trafficSignalColor == "redTrafficLight" then
            extensions.hook('onRedLightCamTriggered', data, vehSpeed)
          end
        else
          extensions.hook('onSpeedTrapTriggered', data, vehSpeed, overSpeed)
        end

        if data.speedTrapLightName then
          -- TODO maybe build a cache with ids if findObject is too slow
          local lightObj = scenetree.findObject(data.speedTrapLightName)
          if isRedLightCamera then
            if lightObj and trafficSignalColor == "redTrafficLight" then
              lightObj.isEnabled = true
              core_jobsystem.create(redLightLightJob, 1, lightObj, 10 / math.max(vehSpeed, 0.01))
            end
          else
            if lightObj then
              lightObj.isEnabled = true
              core_jobsystem.create(speedCamLightJob, 1, lightObj)
            end
          end
        end
      end
    end
  end
end

local function getSpeedTrapsInCurrentLevel(speedTrapType)
  local objs = getObjectsByClass("BeamNGTrigger")
  if not objs then return {} end
  local res = {}
  for _, obj in pairs(objs) do
    if obj.speedTrapType == speedTrapType then
      table.insert(res, obj)
    end
  end
  return res
end

M.onBeamNGTrigger = onBeamNGTrigger

M.getSpeedTrapsInCurrentLevel = getSpeedTrapsInCurrentLevel

return M