-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local moduleVersion = 42

local branchesDir = "/gameplay/branches/"
local missingBranch = {id = "missing", name = "Missing branch!", description = "A missing branch.", levels = {}}

local branchesById
local branchesByAttributeKey
local sortedBranches

local order = {money = 0,beamXP = 1, vouchers = 9999}
local function sortAttributes(a,b) return (order[a] or math.huge) < (order[b] or math.huge) end
M.getOrder = function(key) return order[key] end
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

  -- go through levels and add some helper fields
  local maxReachableLevel = 0
  for i, level in ipairs(branch.levels) do
    if not level.isInDevelopment then
      maxReachableLevel = i
    end
  end
  if maxReachableLevel > 0 then
    branch.levels[maxReachableLevel].isMaxLevel = true
  end
  branch.maxReachableLevel = maxReachableLevel


  --expand automatic unlocks for skills
  for i, level in ipairs(branch.levels) do
    if level.unlocks then
      level.unlocks = M.expandUnlocks(branch, i, level.unlocks)
    end
  end

  --branch/skill itself unlock
  branch.unlocked = true
  if branch.startLocked then
    branch.unlocked = false
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

local function calcBranchLevelFromValue(val, id)
  local branch = getBranchById(id)
  local level = -1
  local curLvlProgress, neededForNext, prevThreshold, nextThreshold = -1, -1, -1, -1

  local levels = branch.levels or {}
  for i, lvl in ipairs(levels) do
    if lvl.requiredValue and  val >= lvl.requiredValue then
      level = i
    end
  end
  if levels[level+1] and levels[level+1].requiredValue then
    prevThreshold = levels[level].requiredValue
    neededForNext = levels[level+1].requiredValue - levels[level].requiredValue
    curLvlProgress = val - levels[level].requiredValue
    nextThreshold = levels[level+1].requiredValue
  end
  return level, curLvlProgress, neededForNext, prevThreshold, nextThreshold

end

local function getBranchSimpleInfo(id)
  local branch = M.getBranchById(id)
  local xp = M.getBranchXP(id)
  local level, curLvlProgress, neededForNext, prevThreshold, nextThreshold = calcBranchLevelFromValue(xp, id)
  return {
    label = branch.name,
    level = level,
    icon = branch.icon,
    curLvlProgress = curLvlProgress,
    neededForNext = neededForNext,
    processPercent = curLvlProgress / neededForNext,
    max = #branch.levels,
  }
end
M.getBranchSimpleInfo = getBranchSimpleInfo

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

local function getBranchIcon(id)
  local branch = getBranchById(id)
  if branch.id == 'missing' then return nil end
  return branch.icon
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


local function expandUnlocks(skill, level, unlocks)
  local newUnlocks = {}
  for _, unlock in ipairs(unlocks) do
    if unlock.type == "automaticMission" then
      -- find all missions that are unloked by this skill and level
      local missions = {}
      for i, mission in ipairs(gameplay_missions_missions.get()) do
        if mission.careerSetup.showInCareer then
          for branchKey, _ in pairs(mission.unlocks.branchTags) do
            if branchKey == skill.id then
              table.insert(missions, mission)
            end
          end
        end
      end
      table.insert(newUnlocks, {
        type="unlockCard",
        heading="New Challenges",
        description=string.format("%d new challenges available.", #missions)
      })
    else
      table.insert(newUnlocks, unlock)
    end
  end
  return newUnlocks

end
M.expandUnlocks = expandUnlocks



-- Career Saving stuff
local saveFile = "branchUnlocks.json"
local savedFields = {"unlocked"}

local function onSaveCurrentSaveSlot(currentSavePath)
  local filePath = currentSavePath .. "/career/" .. saveFile
  local saveData = { }
  for id, branch in pairs(getBranches()) do
    saveData[id] = {}
    for _, field in ipairs(savedFields) do
      saveData[id][field] = branch[field]
    end
  end
  -- save the data to file
  career_saveSystem.jsonWriteFileSafe(filePath, saveData, true)
end

local function onCareerModulesActivated(alreadyInLevel)
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  local saveInfo = savePath and jsonReadFile(savePath .. "/info.json")
  local outdated = not saveInfo or saveInfo.version < moduleVersion

  local data = (savePath and not outdated and jsonReadFile(savePath .. "/career/"..saveFile)) or {}
  for id, branch in pairs(getBranches()) do
    for k, v in pairs(data[id] or {}) do
      branch[k] = v
    end
  end
end

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onCareerModulesActivated = onCareerModulesActivated




M.getBranches = getBranches
M.getBranchById = getBranchById
M.getSortedBranches = getSortedBranches
M.getBranchLevel = getBranchLevel
M.getBranchXP = getBranchXP
M.getBranchIcon = getBranchIcon
M.calcBranchLevelFromValue = calcBranchLevelFromValue

M.orderAttributeKeysByBranchOrder = orderAttributeKeysByBranchOrder
M.orderBranchNamesKeysByBranchOrder = orderBranchNamesKeysByBranchOrder

M.onPlayerAttributesChanged = onPlayerAttributesChanged
return M