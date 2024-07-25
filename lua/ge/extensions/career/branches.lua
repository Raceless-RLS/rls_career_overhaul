-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local branchesDir = "/gameplay/branches/"
local missingBranch = {id = "missing", name = "Missing branch!", description = "A missing branch.", levels = {}}

local branchesById
local branchesByAttributeKey
local sortedBranches

local order = {money = 0,beamXP = 1, bonusStars = 9999}
local function sortAttributes(a,b) return (order[a] or math.huge) < (order[b] or math.huge) end
local branchNameOrder = {}
local function sortBranchNames(a,b) return (order[a] or math.huge) < (order[b] or math.huge) end

local function sanitizeBranch(branch, filePath)
  local infoDir, _, _ = path.split(filePath)
  branch.dir = string.sub(infoDir, 1, -1)  -- Remove trailing '/'
  branch.id = ""

  -- Extracting folders
  local folders = {}
  for folder in string.gmatch(string.sub(infoDir, #branchesDir, -2), "[^/]+") do
      table.insert(folders, folder)
  end
  -- Setting isSkill based on number of folders
  branch.isSkill = #folders > 1
  -- branch is only toplevel folders
  branch.isBranch = #folders == 1

  -- Setting id as the last folder
  if #folders > 0 then
    branch.id = folders[#folders]
  end

  -- Setting parentBranch if isSkill is true
  if branch.isSkill then
    branch.parentBranch = folders[1]
  end

  branch.file = filePath

  branch.name = branch.name or ("Unnamed Branch: " .. branch.id)
  branch.description = branch.description or "No Description for this branch."
  branch.attributeKey = branch.attributeKey or branch.id
  branch.order = branch.order or (10000 + #(sortedBranches or {}))
  branch.progressCover = branch.dir .. "progressCover.jpg"
  branch.isInDevelopment = branch.isInDevelopment or false
end

-- gets all branches in a dict by ID
local function getBranches()
  if not branchesById then
    branchesById = {}
    branchesByAttributeKey = {}
    for _, filePath in ipairs(FS:findFiles(branchesDir, 'info.json', -1, false, true)) do
      local fileInfo = jsonReadFile(filePath)
      if not fileInfo.ignore then
        sanitizeBranch(fileInfo, filePath)
        branchesById[fileInfo.id] = fileInfo
        branchesByAttributeKey[fileInfo.attributeKey] = fileInfo
        order[fileInfo.attributeKey] = fileInfo.order
        branchNameOrder[fileInfo.id] = fileInfo.order
      end
    end
  end
  return branchesById
end

local function getBranchById(id)
  return getBranches()[id] or missingBranch
end

local function getSortedBranches()
  if not sortedBranches then
    sortedBranches = {}
    local keysSorted = tableKeys(getBranches())
    table.sort(keysSorted, sortBranchNames)
    for _, key in ipairs(keysSorted) do
      table.insert(sortedBranches, getBranchById(key))
    end
  end
  return sortedBranches
end

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
  local branch = getBranchById(id)
  local level = -1
  local curLvlProgress, neededForNext, prevThreshold, nextThreshold = -1, -1, -1, -1

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
  if xpLevels[level + 1] then
      prevThreshold = xpLevels[level]
      neededForNext = xpLevels[level + 1] - xpLevels[level]
      curLvlProgress = val - xpLevels[level]
      nextThreshold = xpLevels[level + 1]
  end

  return level, curLvlProgress, neededForNext, prevThreshold, nextThreshold
end

local function getBranchLevel(id)
  local branch = getBranchById(id)
  if branch.id == 'missing' then return nil end
  local attValue = career_modules_playerAttributes and career_modules_playerAttributes.getAttributeValue(branch.attributeKey) or 0
  return calcBranchLevelFromValue(attValue, id)
end

local function getBranchXP(id)
  local branch = getBranchById(id)
  if branch.id == 'missing' then return nil end
  local attValue = career_modules_playerAttributes and career_modules_playerAttributes.getAttributeValue(branch.attributeKey)
  return attValue or -1
end


local function orderAttributeKeysByBranchOrder(list)
  table.sort(list, sortAttributes)
  return list
end


local function orderBranchNamesKeysByBranchOrder(list)
  list = list or tableKeys(branchesById)
  table.sort(list, sortBranchNames)
  return list
end


M.getBranches = getBranches
M.getBranchById = getBranchById
M.getSortedBranches = getSortedBranches
M.getBranchLevel = getBranchLevel
M.getBranchXP = getBranchXP
M.calcBranchLevelFromValue = calcBranchLevelFromValue

M.orderAttributeKeysByBranchOrder = orderAttributeKeysByBranchOrder
M.orderBranchNamesKeysByBranchOrder = orderBranchNamesKeysByBranchOrder

M.onPlayerAttributesChanged = onPlayerAttributesChanged
return M