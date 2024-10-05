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

M.onGeneralMilestonesCollect = function(milestonesList)
  milestones = career_modules_milestones_milestones

  for i, branchInfo in ipairs(career_branches.getSortedBranches()) do
    if not branchInfo.isInDevelopment then
      local levelCount = branchInfo.maxReachableLevel -1 -- account for entry 0
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
        getValue = function() return career_modules_playerAttributes.getAttributeValue(attKey) end,
        getLabel = function(step, displayValue, target) return {txt=isBranch and "ui.career.branchSemicolon" or "ui.career.skillSemicolon", context = {branch = branchInfo.name}} end,
        getDescription = function(step, displayValue, target) return {txt=isBranch and "ui.career.milestones.branches.reachBranchLevel.description" or "ui.career.milestones.branches.reachSkillLevel.description", context={lvl = step+1, name = branchInfo.name}} end,
        getProgressLabel = function(step, current, target) return string.format("%d xp / %d xp", current, target) end,
        getTarget = function(step) return branchInfo.levels[step+1].requiredValue end,
        getRewards = isBranch and milestones.majorLinear or milestones.minorLinear,
        maxStep = levelCount
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
  local step = milestones.saveData.general[milestoneConfig.id].notificationStep +1
  -- check if milestone is completed
  if milestoneConfig.maxStep and step > milestoneConfig.maxStep then return end
  local target = milestoneConfig.getTarget(step)
  if target then
    milestoneConfig._target = target
  end
end

local function onPlayerAttributesChanged(change)
  for attKey, val in pairs(change) do
    if val > 0 then
      local milestoneConfig = attKeyToMilestone[attKey]
      if not milestoneConfig then return end
      local step = milestones.saveData.general[milestoneConfig.id].notificationStep +1
      if milestoneConfig._target and milestoneConfig.getValue() >= milestoneConfig._target then
        extensions.hook("onBranchTierReached",milestoneConfig.branchKey, step+1)
        milestones.milestoneReached(milestoneConfig.getLabel(step))
        milestoneConfig._target = nil
        milestones.saveData.general[milestoneConfig.id].notificationStep = step
        M.setNotificationTarget(attKey)
      end
    end
  end
end
M.setNotificationTarget = setNotificationTarget
M.onPlayerAttributesChanged = onPlayerAttributesChanged



return M