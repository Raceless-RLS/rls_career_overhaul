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
local LIGHT_ACTIVATION_DISTANCE = 200 -- meters
local initialized = false
local updateTimer = 0  -- Add timer variable
local UPDATE_INTERVAL = 0.5  -- Update every 0.5 seconds

local function registerLightsInGroup(group, registryTable)
  if not group or not group.obj then return end
  
  for i = 0, group.obj:getCount() - 1 do
    local id = group.obj:idAt(i)
    local obj = scenetree.findObjectById(id)
    if obj then
      if obj.obj:isSubClassOf('LightBase') then
        -- Store light object with its position
        table.insert(registryTable, {
          obj = obj,
          pos = obj:getPosition()
        })
      elseif obj.obj:isSubClassOf('SimGroup') then
        registerLightsInGroup(obj, registryTable)
      end
    end
  end
end

local function initializeLightRegistry()
  -- Register all lights once at initialization
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

local function updateNearbyLights(playerPos)
  for _, light in ipairs(lightRegistry.nightLights) do
    local distance = (light.pos - playerPos):length()
    local shouldBeEnabled = distance <= LIGHT_ACTIVATION_DISTANCE
    light.obj.obj:setLightEnabled(shouldBeEnabled)
    light.obj:setHidden(not shouldBeEnabled)
  end
  
  for _, light in ipairs(lightRegistry.nightLightsShadow) do
    local distance = (light.pos - playerPos):length()
    local shouldBeEnabled = distance <= LIGHT_ACTIVATION_DISTANCE
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
      updateNearbyLights(playerPos)
    end
  end
end

M.onUpdate = onUpdate

return M