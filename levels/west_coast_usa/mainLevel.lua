-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- garage lights

--local function setupGarageTables() -- creates garage lights data
  --if true then
    --extensions.load('core_extendedTriggers')
    --core_extendedTriggers.setup()
    --return
  --end
--end

local function setAllLightsEnabled(group, value)
  for i = 0, group.obj:getCount(), 1 do
      local id = group.obj:idAt(i)
      local obj = scenetree.findObjectById(id)
      if obj and obj.obj:isSubClassOf('LightBase') then
          obj.obj:setLightEnabled( value )
      end
  end
end

local lastValue = nil

local function onUpdate()
  local tod = scenetree.tod
  if not tod then return end

  local value = false
  if tod.time > 0.21 and tod.time < 0.77 then
      value = true
  end

  if lastValue == value then return end
  lastValue = value

  if scenetree.night_light then
    setAllLightsEnabled(scenetree.night_light, value )
  end
  if scenetree.night_light_shadow then
    setAllLightsEnabled(scenetree.night_light_shadow, value )
  end
end

M.onUpdate = onUpdate

return M