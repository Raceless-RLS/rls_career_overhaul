-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- Store lights with their positions
local lightRegistry = {
  -- Format: { obj = lightObject, pos = vec3Position }
  nightLights = {},
  nightLightsShadow = {}
}

local isDaytime = true
local BASE_ACTIVATION_DISTANCE = 75
local VELOCITY_SCALE_FACTOR = 7
local MIN_VELOCITY_THRESHOLD = 5
local LIGHT_PERSISTENCE_TIME = 3.0
local CAMERA_VIEW_ANGLE = 0.5
local MIN_VIEW_DISTANCE = 500
local FORWARD_PERSISTENCE_MULTIPLIER = 2.0
local initialized = false
local updateTimer = 0
local UPDATE_INTERVAL = 0.5

local function registerLightsInGroup(group, registryTable)
  if not group or not group.obj then return end
  
  for i = 0, group.obj:getCount() - 1 do
    local id = group.obj:idAt(i)
    local obj = scenetree.findObjectById(id)
    if obj then
      if obj.obj:isSubClassOf('LightBase') then
        table.insert(registryTable, {
          obj = obj,
          pos = obj:getPosition(),
          fadeTimer = 0
        })
      elseif obj.obj:isSubClassOf('SimGroup') then
        registerLightsInGroup(obj, registryTable)
      end
    end
  end
end

local function initializeLightRegistry()
  if scenetree.night_light then
    registerLightsInGroup(scenetree.night_light, lightRegistry.nightLights)
  end
  if scenetree.night_light_shadow then
    registerLightsInGroup(scenetree.night_light_shadow, lightRegistry.nightLightsShadow)
  end
end

local function disableAllLights()
  for _, light in ipairs(lightRegistry.nightLights) do
    light.obj.obj:setLightEnabled(false)
    light.obj:setHidden(true)
  end
  for _, light in ipairs(lightRegistry.nightLightsShadow) do
    light.obj.obj:setLightEnabled(false)
    light.obj:setHidden(true)
  end
end

local function getExtendedActivationDistance(lightPos, playerPos, playerVel, cameraDir)
  local toLight = lightPos - playerPos
  local distance = toLight:length()
  
  -- Always keep close lights on
  if distance <= BASE_ACTIVATION_DISTANCE then
    return true, LIGHT_PERSISTENCE_TIME
  end
  
  -- Check if light is visible to camera
  local lightDir = toLight:normalized()
  local cameraDotProduct = cameraDir:dot(lightDir)
  local isInView = cameraDotProduct > CAMERA_VIEW_ANGLE
  
  -- Keep visible lights on within reasonable distance
  if isInView and distance < MIN_VIEW_DISTANCE then
    return true, LIGHT_PERSISTENCE_TIME
  end
  
  -- Calculate velocity-based extension
  local velocity = playerVel:length()
  if velocity < MIN_VELOCITY_THRESHOLD then
    return false, 0
  end
  
  -- Get direction alignment with velocity
  local velDir = playerVel:normalized()
  local dotProduct = velDir:dot(lightDir)
  
  -- Calculate extended range based on velocity and direction
  local extensionMultiplier = math.max(0, dotProduct)
  local velocityExtension = velocity * VELOCITY_SCALE_FACTOR * extensionMultiplier
  local extendedRange = BASE_ACTIVATION_DISTANCE + velocityExtension
  
  -- Calculate persistence time based on direction
  local persistenceTime = LIGHT_PERSISTENCE_TIME
  if dotProduct > 0.7 then -- Light is roughly in front
    persistenceTime = persistenceTime * 2
  elseif dotProduct < -0.3 then -- Light is behind
    persistenceTime = persistenceTime * 0.5
  end
  
  return distance <= extendedRange, persistenceTime
end

local function updateNearbyLights(playerPos, playerVel, dtSim)
  local cameraDir = core_camera.getForward()

  for _, light in ipairs(lightRegistry.nightLights) do
    -- Initialize fadeTimer if it doesn't exist
    light.fadeTimer = light.fadeTimer or 0
    
    -- Check if light should be active
    local isActive, persistenceTime = getExtendedActivationDistance(light.pos, playerPos, playerVel, cameraDir)
    
    -- Update fade timer
    if isActive then
      light.fadeTimer = persistenceTime
    else
      light.fadeTimer = math.max(0, light.fadeTimer - dtSim)
    end
    
    -- Enable light if either active or fading
    local shouldBeEnabled = isActive or light.fadeTimer > 0
    light.obj.obj:setLightEnabled(shouldBeEnabled)
    light.obj:setHidden(not shouldBeEnabled)
  end
  
  -- Do the same for shadow lights
  for _, light in ipairs(lightRegistry.nightLightsShadow) do
    light.fadeTimer = light.fadeTimer or 0
    local isActive, persistenceTime = getExtendedActivationDistance(light.pos, playerPos, playerVel, cameraDir)
    
    if isActive then
      light.fadeTimer = persistenceTime
    else
      light.fadeTimer = math.max(0, light.fadeTimer - dtSim)
    end
    
    local shouldBeEnabled = isActive or light.fadeTimer > 0
    light.obj.obj:setLightEnabled(shouldBeEnabled)
    light.obj:setHidden(not shouldBeEnabled)
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  -- One-time initialization
  if not initialized then
    print('Initializing mainLevel.lua light system')
    initializeLightRegistry()
    -- Initially disable all lights if starting during daytime
    if scenetree.tod and not (scenetree.tod.time > 0.21 and scenetree.tod.time < 0.77) then
      disableAllLights()
    end
    initialized = true
  end

  -- Update timer
  updateTimer = updateTimer + dtSim
  if updateTimer < UPDATE_INTERVAL then
    return
  end
  updateTimer = 0  -- Reset timer

  local tod = scenetree.tod
  if not tod then return end

  -- Check if it's daytime (between 0.21 and 0.77)
  local newIsDaytime = not (tod.time > 0.21 and tod.time < 0.77)

  -- If transitioning from night to day
  if not isDaytime and newIsDaytime then
    disableAllLights()
  end
  
  isDaytime = newIsDaytime
  
  -- Only update lights during nighttime
  if not isDaytime then
    local playerVehicle = be:getPlayerVehicle(0)
    if playerVehicle then
      local playerPos = playerVehicle:getPosition()
      local playerVel = playerVehicle:getVelocity()
      updateNearbyLights(playerPos, playerVel, 0.5)
    end
  end
end

M.onUpdate = onUpdate

return M