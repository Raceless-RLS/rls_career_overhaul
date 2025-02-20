-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local minimumValue = -50
local maximumValue = 700

local isHardcore = false

local reputationValues = {
  returnLoanerDamaged = -20,
  discardDeliveryVehicle = -10
}

local levelDefaults = {
  [-1] = {
    label = "Questionable",
    levelLabel = "Reputation: Level -1",
    requiredValue = minimumValue,
    loanerCut = {
      value = isHardcore and 0.95 or 0.5,
      icon = "boxPickUp03"
    },
    deliveryBonus = {
      value = 0.9,
    }
  },
  [0] = {
    label = "Neutral",
    levelLabel = "Reputation: Level 0",
    requiredValue = -25, -- needs to lose 50 (from 0) to go to -1
    loanerCut = {
      value = isHardcore and 0.8 or 0.35,
      icon = "boxPickUp03"
    },
    deliveryBonus = {
      value = 1,
    }
  },
  [1] = {
    label = "Reliable",
    levelLabel = "Reputation: Level 1",
    requiredValue = 40, -- needs 50 (from 0) to lvlup to 1
    loanerCut = {
      value = isHardcore and 0.7 or 0.25,
      icon = "boxPickUp03"
    },
    deliveryBonus = {
      value = 1.1,
    }
  },
  [2] = {
    label = "Preferred",
    levelLabel = "Reputation: Level 2",
    requiredValue = 175, --  needs 150 to lvlup to 2
    loanerCut = {
      value = isHardcore and 0.6 or 0.15,
      icon = "boxPickUp03"
    },
    deliveryBonus = {
      value = 1.2,
    }
  },
  [3] = {
    label = "Partner",
    levelLabel = "Reputation: Level 3",
    requiredValue = 400, -- need 250 to lvlup to 3
    loanerCut = {
      value = isHardcore and 0.5 or 0,
      icon = "boxPickUp03"
    },
    deliveryBonus = {
      value = 1.4,
    }
  },
}

local function getloanerCutValue(level)
  local loanerCutValues = {
    [-1] = isHardcore and 0.95 or 0.5,
    [0] = isHardcore and 0.8 or 0.35,
    [1] = isHardcore and 0.7 or 0.25,
    [2] = isHardcore and 0.6 or 0.15,
    [3] = isHardcore and 0.5 or 0,
  }
  return loanerCutValues[level]
end

local function updateLevelDefaults()
  for i, lvl in pairs(levelDefaults) do
    lvl.loanerCut.value = getloanerCutValue(i)
  end
end

local function getValueForEvent(eventId)
  return reputationValues[eventId]
end

local function calcLevelFromReputationValue(val, organization)
  local level = -1

  local levels = organization.reputationLevels or {}
  for i, lvl in ipairs(levels) do
    if not lvl.requiredValue or val >= lvl.requiredValue then
      level = i
    end
  end
  local currentLevelRequiredValue = levels[level].requiredValue or minimumValue
  local nextLevelRequiredValue = levels[level+1] and levels[level+1].requiredValue or maximumValue

  local prevThreshold = currentLevelRequiredValue
  local neededForNext = nextLevelRequiredValue - currentLevelRequiredValue
  local curLvlProgress = val - currentLevelRequiredValue
  local nextThreshold = nextLevelRequiredValue
  return level - 2, curLvlProgress, neededForNext, prevThreshold, nextThreshold
end

local function addReputationToOrg(organization)
  if not organization then
    return
  end

  local value = career_modules_playerAttributes.getAttributeValue(organization.id .. "Reputation")
  local level, curLvlProgress, neededForNext, prevThreshold, nextThreshold = calcLevelFromReputationValue(value, organization)
  local data = {
    value = value,
    level = level,
    curLvlProgress = curLvlProgress,
    neededForNext = neededForNext,
    prevThreshold = prevThreshold,
    nextThreshold = nextThreshold
  }

  updateLevelDefaults()

  for i, levelInfo in ipairs(organization.reputationLevels) do
    for attributeKey, attributeValue in pairs(levelDefaults[i-2]) do
      if levelInfo[attributeKey] then
        if type(levelInfo[attributeKey]) == "table" then
          for key, value in pairs(attributeValue) do
            levelInfo[attributeKey][key] = levelInfo[attributeKey][key] or value
          end
        end
      else
        levelInfo[attributeKey] = attributeValue
      end
    end
  end
  organization.reputation = data
end

local function getLabel(lvl)
  updateLevelDefaults()
  return levelDefaults[lvl].label
end

local function getMinimumValue()
  return minimumValue
end

local function getMaximumValue()
  return maximumValue
end

M.onHardcoreModeChanged = function(hardcoreMode)
  isHardcore = hardcoreMode
  updateLevelDefaults()
end

M.addReputationToOrg = addReputationToOrg
M.getLabel = getLabel
M.getMinimumValue = getMinimumValue
M.getMaximumValue = getMaximumValue
M.getValueForEvent = getValueForEvent

return M
