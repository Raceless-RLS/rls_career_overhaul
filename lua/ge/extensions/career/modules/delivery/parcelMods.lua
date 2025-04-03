-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
local dParcelManager, dCargoScreen, dGeneral, dGenerator, dProgress, dParcelMods
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dProgress = career_modules_delivery_progress
end

local modifiers = {
  timed = {
    unlockFlag = "smallPackagesDelivery",
    makeTemplate = function(g,p,distance)
      local time = (distance / 12) + 30 * math.random() + 30
      return {
        type = "timed",
        timeUntilDelayed = time,
        timeUntilLate = time * 1.25 + 15,
        --paddingTime = time * 0.2 + 10,
        --timeMessageFlag = false,
        --paddingTimeMessageFlag = false,
        moneyMultipler = 1.25,
      }
    end,
    unlockLabel = "Time Sensitive Deliveries",
    priority = 1,
    icon = "stopwatchSectionSolidEnd",
    label = "Time Sensitive",
    shortDescription = "Increased rewards when on time, penalty if late.",
    important = true,
  },
  post = {
    unlockFlag = "smallPackagesDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "post",
        moneyMultipler = 1,
      }
    end,
    unlockLabel = "General Post Parcels",
    priority = 2,
    icon = "envelope",
    label = "Postage Parcel",
    shortDescription = "",
    hidden=true,
  },
  precious = {
    unlockFlag = "largePackagesDelivery",
    penalty = 3,
    makeTemplate = function(g,p,distance)
      return {
        type = "precious",
        moneyMultipler = 1.4,
        abandonMultiplier = 1.1,
      }
    end,
    unlockLabel = "Precious Cargo",
    priority = 3,
    icon = "fragile",
    label = "Precious",
    shortDescription = "Increased rewards, high penalty if lost or abandoned.",
    important = true,

  },
  aid = {
    unlockFlag = "largePackagesDelivery",
    penalty = 3,
    makeTemplate = function(g,p,distance)
      return {
        type = "aid",
        moneyMultipler = 8,
        abandonMultiplier = 1.1,
      }
    end,
    unlockLabel = "aid",
    priority = 3,
    icon = "fragile",
    label = "Subsidy Item",
    shortDescription = "Item Reward Adjusted",
    important = true,

  },

  supplies = {
    unlockFlag = "largePackagesDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "supplies",
        moneyMultipler = 5.0,
      }
    end,
    unlockLabel = "Supply & Logistics Cargo",
    priority = 4,
    icon = "cardboardBox",
    label = "Supply & Logistics",
    shortDescription = "",
    hidden=true,
  },
  large = {
    unlockFlag = "largePackagesDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "large",
        moneyMultipler = 1.5,
      }
    end,
    unlockLabel = "Large & Heavy Cargo",
    priority = 3,
    icon = "group",
    label = "Large & Heavy",
    shortDescription = "Drive carefully and beware of momentum!"
  },
  fluid = {
    unlockFlag = "hazardousMaterialsDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "fluid",
      }
    end,
    unlockLabel = "Fluids",
    priority = 6,
    icon = "droplet",
    label = "Fluid",
    shortDescription = "Requires a fluid-capable container or tank to transport."
  },
  dryBulk = {
    unlockFlag = "hazardousMaterialsDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "dryBulk",
      }
    end,
    unlockLabel = "Dry Bulk",
    priority = 6,
    icon = "rocks",
    label = "Dry Bulk",
    shortDescription = "Requires a drybulk-capable container to transport."
  },
  parcel = {
    unlockFlag = "smallPackagesDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "parcel",
      }
    end,
    unlockLabel = "Parcel",
    priority = 6,
    icon = "cardboardBox",
    label = "Parcel",
    shortDescription = "Requires a parcel-capable container transport.",
    hidden=true,
  },
  hazardous = {
    unlockFlag = "hazardousMaterialsDelivery",
    makeTemplate = function(g,p,distance)
      return {
        type = "hazardous",
      }
    end,
    unlockLabel = "Hazardous",
    priority = 6,
    icon = "roadblockL",
    label = "Hazardous",
    shortDescription = "Large penalty if lost or abandoned. Requires special license to handle.",

  },
}


local progressTemplate = {
  timed = {
    delivieries = 0,
    onTimeDeliveries = 0,
    delayedDeliveries = 0,
    lateDeliveries = 0,
  },
  large = {
    delivieries = 0,
  },
  precious = {
    delivieries = 0,
    lost = 0,
  },
  heavy = {
    delivieries = 0,
  },
  post = {
    delivieries = 0
  }
}

local progress = deepcopy(progressTemplate)

M.setProgress = function(data)
  progress = data or deepcopy(progressTemplate)
end

M.getProgress = function()
  return progress
end

M.getModData = function(key) return modifiers[key] end
M.getModifierIcon = function(key) return modifiers[key].icon end
M.getLabelAndShortDescription = function(key) return modifiers[key].label, modifiers[key].shortDescription end
M.isImportant = function(key) return modifiers[key].important or false end

local function calculateTimedModifierTime(distance)
  local r = math.random()+1
  return (distance / 13) + (30 * r)
end
M.calculateTimedModifierTime = calculateTimedModifierTime

local sortByPrio = function(a,b) return modifiers[a.type].priority < modifiers[b.type].priority end

local modifierProbability = 1
local largeSlotThreshold = 65
local heavyWeightThreshold = 80
local function generateModifiers(item, parcelTemplate, distance)
  local mods = {}
  math.randomseed(item.groupSeed)

  local r = math.random()
  --for _, modKey in ipairs(tableKeysSorted(modifiers)) do
  for _, modKey in ipairs(tableKeysSorted(parcelTemplate.modChance)) do
    if r <= parcelTemplate.modChance[modKey] then
      local modTemplate = modifiers[modKey].makeTemplate(item.groupSeed, parcelTemplate, distance)
      table.insert(mods, modTemplate)
    end
    r = math.random()
  end

  if item.slots >= largeSlotThreshold or item.weight >= heavyWeightThreshold and not parcelTemplate.modChance.large then
    table.insert(mods, modifiers.large.makeTemplate())
  end

  table.sort(mods, sortByPrio)
  return mods
end
M.generateModifiers = generateModifiers


local function isParcelModUnlocked(modKey)
  if not modifiers[modKey] or not modifiers[modKey].unlockFlag then return false end
  return career_modules_unlockFlags.getFlag(modifiers[modKey].unlockFlag)
end
M.isParcelModUnlocked = isParcelModUnlocked

local function lockedBecauseOfMods(modKeys)
  local minTier = 1
  local locked = false
  local definitions = {}
  for key, _ in pairs(modKeys) do
    if modifiers[key] and modifiers[key].unlockFlag then
      local unlockFlag = modifiers[key].unlockFlag
      local flagDefinition = career_modules_unlockFlags.getFlagDefinition(unlockFlag)
      table.insert(definitions, flagDefinition)
      if not career_modules_unlockFlags.getFlag(unlockFlag) then
        locked = true
      end
    end
  end
  table.sort(definitions, function(a,b) return (a and a.level or 0) > (b and b.level or 0) end)
  return locked, definitions[1]
end
M.lockedBecauseOfMods = lockedBecauseOfMods


local function getParcelModUnlockStatusSimple()
  local status = {}
  for modKey, info in pairs(modifiers) do
    status[modKey] = isParcelModUnlocked(modKey)
  end
  return status
end
M.getParcelModUnlockStatusSimple = getParcelModUnlockStatusSimple
M.getParcelModProgressLabel = function(key) return modifiers[key].unlockLabel end


local function trackModifierStats(cargo)
  for _, mod in ipairs(cargo.modifiers or {}) do
    progress[mod.type] = progress[mod.type] or {}
    progress[mod.type].delivered = (progress[mod.type].delivered or 0) + 1
    if mod.type == "timed" then
      local prog = progress.timed
      local expiredTime = dGeneral.time() - cargo.loadedAtTimeStamp

      if expiredTime <= mod.timeUntilDelayed then
        prog.onTimeDeliveries = (prog.onTimeDeliveries or 0) + 1
      elseif expiredTime <= mod.timeUntilLate then
        prog.delayedDeliveries = (prog.delayedDeliveries or 0) + 1
      else
        prog.lateDeliveries = (prog.lateDeliveries or 0) + 1
      end
    end
  end
end
M.trackModifierStats = trackModifierStats



--[[
local function onGetSkillUnlockInfoForUi(skill, unlocks)
  if skill.id ~= "delivery" then return end
  unlocks[1] = unlocks[1] or {}
  local modsByTier = {}
  for modKey, info in pairs(modifiers) do
    local tier = 1
    if info.requirements and info.requirements.delivery then
      tier = info.requirements.delivery
    end
    modsByTier[tier] = modsByTier[tier] or {}
    table.insert(modsByTier[tier], modKey)
  end
  for tier, list in pairs(modsByTier) do
    table.sort(list)
    unlocks[tier] = unlocks[tier] or {}
    for _, value in ipairs(list) do
      table.insert(unlocks[tier], {type="text", label = value})
    end
  end
end

M.onGetSkillUnlockInfoForUi = onGetSkillUnlockInfoForUi

]]
return M