-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
M.dependencies = {"career_modules_milestones_milestones", "career_branches"}
local attKeyToMilestone = {}
local milestones

local branchIcon = {
  motorsport = "raceFlag",
  labourer = "deliveryTruckArrows",
  specialized = "carChase01",
  adventurer = "jump",
}

local function calculateXPForLevels(levels, growthRate, maxLevel, constantLevel)
  local xpLevels = {}
  for i, level in ipairs(levels) do
    xpLevels[i] = level.requiredValue
  end

  local lastLevelXP = levels[#levels].requiredValue
  local secondLastLevelXP = levels[#levels - 1].requiredValue
  local difference = lastLevelXP - secondLastLevelXP

  for level = #levels + 1, maxLevel do
    if level <= constantLevel then
      local requiredXP = lastLevelXP + difference * ((level - #levels) ^ growthRate)
      table.insert(xpLevels, math.floor(requiredXP))
    else
      local requiredXP = xpLevels[constantLevel] + difference * (level - constantLevel)
      table.insert(xpLevels, math.floor(requiredXP))
    end
  end
  return xpLevels
end
local function calcBranchLevelFromValue(val, id)
  local branch = career_branches.getBranchById(id)
  if not branch then
    print("Error: Branch not found for id: " .. tostring(id))
    return 0, 0, 0, 0, 0
  end

  local level = 0
  local curLvlProgress, neededForNext, prevThreshold, nextThreshold = 0, 0, 0, 0

  local levels = branch.levels or {}
  local maxLevel = 50  -- Define the maximum level you want to calculate up to
  local constantLevel = 25  -- Define the level after which XP required becomes constant
  local growthRate = 1.05  -- Define the growth rate

  -- Calculate the XP required for each level up to maxLevel
  local xpLevels = calculateXPForLevels(levels, growthRate, maxLevel, constantLevel)

  -- Determine the current level based on the XP value
  for i, requiredXP in ipairs(xpLevels) do
    if val >= requiredXP then
      level = i
    else
      break
    end
  end

  -- Calculate the thresholds and progress
  if xpLevels[level] and xpLevels[level + 1] then
    prevThreshold = xpLevels[level]
    neededForNext = xpLevels[level + 1] - xpLevels[level]
    curLvlProgress = val - prevThreshold
    nextThreshold = xpLevels[level + 1]
  else
    -- Handle case where we're at or beyond the last calculated level
    prevThreshold = xpLevels[#xpLevels] or 0
    neededForNext = 0
    curLvlProgress = val - prevThreshold
    nextThreshold = prevThreshold
  end

  return level, curLvlProgress, neededForNext, prevThreshold, nextThreshold
end

M.onGeneralMilestonesCollect = function(milestonesList)
  milestones = career_modules_milestones_milestones

  for i, branchInfo in ipairs(career_branches.getSortedBranches()) do
    if not branchInfo.isInDevelopment then
      local attKey = branchInfo.attributeKey
      local isBranch = not branchInfo.isSkill
      local color = branchInfo.color
      if not color then
        local parentBranch = career_branches.getBranchById(branchInfo.parentBranch)
        color = parentBranch.color
      end

      local milestoneConfig = {
        id = "branch_"..branchInfo.id,
        sortIndex = 100 + i,
        branchKey = branchInfo.id,
        filter = {branch=true, ["branch_"..branchInfo.id]=true},
        type = "branch",
        minValueIsPreviousStepTarget = true,
        icon = branchIcon[branchInfo.parentBranch or branchInfo.id],
        color=color,
        getValue = function() 
          local val = career_modules_playerAttributes.getAttributeValue(attKey)
          local level, curLvlProgress, neededForNext, prevThreshold, nextThreshold = calcBranchLevelFromValue(val, branchInfo.id)
          -- Return the current level progress and the XP needed for next level
          return curLvlProgress, neededForNext
        end,
        getLabel = function(step, displayValue, target) 
          return {txt=isBranch and "ui.career.branchSemicolon" or "ui.career.skillSemicolon", context = {branch = branchInfo.name}} 
        end,
        getDescription = function(step, displayValue, target)
          local val = career_modules_playerAttributes.getAttributeValue(attKey)
          local level = calcBranchLevelFromValue(val, branchInfo.id)
          return {txt=isBranch and "ui.career.milestones.branches.reachBranchLevel.description" or "ui.career.milestones.branches.reachSkillLevel.description", context={lvl = level + 1, name = branchInfo.name}}
        end,
        getProgressLabel = function(step, current, target) 
          local val = career_modules_playerAttributes.getAttributeValue(attKey)
          local level, curLvlProgress, neededForNext = calcBranchLevelFromValue(val, branchInfo.id)
          return string.format("Level %d: %d / %d XP", level, curLvlProgress, neededForNext)
        end,
        getTarget = function(step)
          local val = career_modules_playerAttributes.getAttributeValue(attKey)
          local level, curLvlProgress, neededForNext, prevThreshold, nextThreshold = calcBranchLevelFromValue(val, branchInfo.id)
          return nextThreshold
        end,
        getRewards = isBranch and milestones.majorLinear or milestones.minorLinear,
        maxStep = 100  -- Set a very high number to allow for many levels
      }
      if isBranch then
        milestoneConfig.filter.general = true
      end
      attKeyToMilestone[branchInfo.attributeKey] = milestoneConfig
      milestones.saveData.general[milestoneConfig.id] = milestones.saveData.general[milestoneConfig.id] or {claimedStep = 0, notificationStep = 0}
      table.insert(milestonesList, milestoneConfig)
    end
  end
end

M.onGeneralMilestonesSetupCallbacks = function()
  for attKey, milestone in pairs(attKeyToMilestone) do
    M.setNotificationTarget(attKey)
  end
end


-- branch related updates
local function setNotificationTarget(attKey)
  local milestoneConfig = attKeyToMilestone[attKey]
  local step = milestones.saveData.general[milestoneConfig.id].notificationStep
  -- check if milestone is completed
  if milestoneConfig.maxStep and step >= milestoneConfig.maxStep then return end
  local level, curLvlProgress, neededForNext = milestoneConfig.getValue()
  local target = milestoneConfig.getTarget(level)
  if target then
    milestoneConfig._target = target
  end
end

local function onPlayerAttributesChanged(change)
  for attKey, val in pairs(change) do
    if val > 0 then
      local milestoneConfig = attKeyToMilestone[attKey]
      if not milestoneConfig then return end
      local level, curLvlProgress, neededForNext = milestoneConfig.getValue()
      local step = milestones.saveData.general[milestoneConfig.id].notificationStep
      if milestoneConfig._target and level > step then
        extensions.hook("onBranchTierReached", milestoneConfig.branchKey, level)
        milestones.milestoneReached(milestoneConfig.getLabel(step))
        milestoneConfig._target = nil
        milestones.saveData.general[milestoneConfig.id].notificationStep = level
        M.setNotificationTarget(attKey)
      end
    end
  end
end
M.setNotificationTarget = setNotificationTarget
M.onPlayerAttributesChanged = onPlayerAttributesChanged



return M