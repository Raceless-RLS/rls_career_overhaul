-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local defaultSaveSlot = 'default'
local currentSaveSlotName = defaultSaveSlot
local saveRoot = 'settings/cloud/missionProgress/'
local savePath = saveRoot .. defaultSaveSlot .. "/"


local batchMode = false

local conditionTypes = {}

-- increasing version will purge all save data for dev/testing
local version = 20

local plog = log

local autoAggregateExamples = {
  simpleHighscore = {
    type = 'simpleHighscore', -- type to get correct aggregating function
    attemptKey = 'points', -- key in the attempt
    aggregateKey = 'highscore', -- key in the aggregate
    sorting = 'descending', -- keeping the higher score
    newBestKey = 'newHighscore', -- key value for when a new best value was aggregated
  },
  simpleMedal = {
    type = 'simpleMedal',
    attemptKey = 'medal', -- key in the attempt
    aggregateKey = 'bestMedal', -- key in the aggregate
    newBestKey = 'newBestMedal',
  },
  simpleSum = {
    type = 'simpleSum',
    attemptKey = 'distance', -- key in the attempt
    aggregateKey = 'totalDistance', -- key in the aggregate
    newBestKey = 'newTotalDistance',
  },
  simpleComboCounter = {
    type = 'simpleComboCounter', -- type to get correct aggregating function
    attemptKey = 'success', -- key in the attempt
    aggregateKeyCurrent = 'currentCombo', -- key in the aggregate
    aggregateKeyMax = 'maxCombo', -- key in the aggregate
    newBestKey = 'newMaxCombo', -- key value for when a new best value was aggregated
  },
  successFailCounter = {
    type = 'successFailCounter', -- type to get correct aggregating function
    attemptKey = 'success', -- key in the attempt
    aggregateKeySuccessCount = 'successCount', -- key in the aggregate
    aggregateKeyFailCount = 'failCount', -- key in the aggregate
    newSuccessKey = 'newSuccessCount', -- key value for when a new value was aggregated
    newFailKey = 'newFailCount', -- key value for when a new value was aggregated
  },
}

local medalPrio = {
  gold = 0,
  silver = 10,
  bronze = 20,
  wood = 100,
  none = 1000,
}

local defaultLeaderboardSize = 5

local autoAggregate = {
  simpleHighscore = function(progress, attempt, config, mission, change)
    local aggregate = progress.aggregate
    local aggValue = aggregate[config.aggregateKey]
    local attValue = attempt.data[config.attemptKey]
    if attValue == nil then
      return
    end
    if not aggValue or (attValue > aggValue == (config.sorting == 'descending')) then
      if config.newBestKey then
        change.newBestKeysByKey[config.newBestKey] = true
        table.insert(change.list, {
          key = config.aggregateKey,
          old = aggregate[config.aggregateKey],
          new = attempt.data[config.attemptKey]
        })
      end
      aggregate[config.aggregateKey] = attValue
    end

    -- update leaderboard
    if config.leaderboardKey then
      -- create leaderboard if missing
      if not progress.leaderboards[config.leaderboardKey] then
        progress.leaderboards[config.leaderboardKey] = {}
      end
      local leaderboard = progress.leaderboards[config.leaderboardKey]
      local attempts = progress.attempts
      local lastIdx = #leaderboard
      local attemptInsertIdx = lastIdx + 1
      -- go backwards from the leaderboard and check if current attempt is better than the entry
      while lastIdx > 0 do
        local leaderboardEntryValue = attempts[leaderboard[lastIdx]].data[config.attemptKey]
        -- if our attempt is better, then
        if (attValue > leaderboardEntryValue == (config.sorting == 'descending')) then
          lastIdx = lastIdx - 1
          attemptInsertIdx = attemptInsertIdx - 1
        else
          lastIdx = 0
        end
      end
      if attemptInsertIdx < defaultLeaderboardSize then
        -- insert the attempt idx into the leaderboard. attempt is already in the list of attempts, so we can use that as the id of our attempt.
        table.insert(leaderboard, attemptInsertIdx, #attempts)

        -- cull leaderbord
        while #leaderboard > defaultLeaderboardSize do
          table.remove(leaderboard, #leaderboard)
        end

        -- also put a note in the change
        if config.newLeaderboardEntryKey then
          change.newBestKeysByKey[config.newLeaderboardEntryKey] = attemptInsertIdx
        end
      end
    end

  end,
  simpleMedal = function(progress, attempt, config, mission, change)
    local aggregate = progress.aggregate
    local aggPrio = medalPrio[aggregate[config.aggregateKey] or 'none']
    local attPrio = medalPrio[attempt.data[config.attemptKey] or 'none']
    --if attValue == nil then return end
    if attPrio < aggPrio then
      if config.newBestKey then
        change.newBestKeysByKey[config.newBestKey] = true
        table.insert(change.list, {
          key = config.aggregateKey,
          old = aggregate[config.aggregateKey] or 'none',
          new = attempt.data[config.attemptKey]
        })
      end
      aggregate[config.aggregateKey] = attempt.data[config.attemptKey] or 'none'
    end
  end,
  simpleSum = function(progress, attempt, config, mission, change)
    local aggregate = progress.aggregate
    local aggValue = aggregate[config.aggregateKey] or 0
    local attValue = attempt.data[config.attemptKey]
    if attValue == nil then
      return
    end
    if attValue > 0 then
      if config.newBestKey then
        change.newBestKeysByKey[config.newBestKey] = true
        table.insert(change.list, {
          key = config.aggregateKey,
          old = aggValue,
          new = aggValue + attValue
        })
      end
    end
    aggregate[config.aggregateKey] = aggValue + attValue
  end,
  simpleComboCounter = function(progress, attempt, config, mission, change)
    if attempt.data[config.attemptKey] == nil then
      return
    end
    local aggregate = progress.aggregate
    local aggCurrent = aggregate[config.aggregateKeyCurrent] or 0
    local aggMax = aggregate[config.aggregateKeyMax] or 0
    if attempt.data[config.attemptKey] then
      aggCurrent = aggCurrent + 1
    end
    if config.newBestKey and aggCurrent > aggMax then
      change.newBestKeysByKey[config.newBestKey] = true
      table.insert(change.list, {
        key = config.aggregateKey,
        old = aggMax,
        new = aggCurrent
      })
      aggMax = aggCurrent
    end

    aggregate[config.aggregateKeyCurrent] = aggCurrent
    aggregate[config.aggregateKeyMax] = aggMax
  end,
  successFailCounter = function(progress, attempt, config, mission, change)
    if attempt.data[config.attemptKey] == nil then
      return
    end
    local aggregate = progress.aggregate
    local aggSuccess = aggregate[config.aggregateKeySuccessCount] or 0
    local aggFail = aggregate[config.aggregateKeyFailCount] or 0
    if attempt.data[config.attemptKey] then
      change.newBestKeysByKey[config.newSuccessKey] = true
      table.insert(change.list, {
        key = config.newSuccessKey,
        old = aggSuccess,
        new = aggSuccess + 1
      })
      aggSuccess = aggSuccess + 1
    else
      change.newBestKeysByKey[config.newFailKey] = true
      table.insert(change.list, {
        key = config.newFailKey,
        old = aggFail,
        new = aggFail + 1
      })
      aggFail = aggFail + 1
    end
    aggregate[config.aggregateKeySuccessCount] = aggSuccess
    aggregate[config.aggregateKeyFailCount] = aggFail


  end
}

local typePrios = {
  completed = 0,
  passed = 10,
  attempted = 20,
  abandoned = 50,
  failed = 100,
  none = 1000,
}

local function newAttempt(type, data)
  return { type = type, date = os.time(), humanDate = os.date("!%Y-%m-%dT%TZ"), data = data or {} }
end

local function aggregateProgress(progress, attempt, change, mission)
  local aggregate = progress.aggregate


  local currentType = attempt.type



  -- best result
  local curTypePrio = typePrios[aggregate.bestType or 'none']
  local newTypePrio = typePrios[currentType]
  if newTypePrio < curTypePrio then
    change.newBestKeysByKey.newBestType = true
    table.insert(change.list, {
      key = 'newBestType',
      old = aggregate.bestType or 'none',
      new = currentType
    })
    aggregate.bestType = currentType
    aggregate.passed = currentType == 'completed' or currentType == 'passed' or aggregate.passed
    aggregate.completed = currentType == 'completed' or aggregate.completed
  end


  -- most recent entry
  aggregate.mosttimespan = attempt.date > (aggregate.mosttimespan or 0) and attempt.date or aggregate.mosttimespan

  -- count
  aggregate.attemptCount = aggregate.attemptCount + 1
  attempt.attemptNumber = aggregate.attemptCount

  -- update "recent" leaderboard
  local leaderboard = progress.leaderboards['recent']
  table.insert(leaderboard, 1, #progress.attempts)
  while #leaderboard > defaultLeaderboardSize do
    table.remove(leaderboard, #leaderboard)
  end
  change.newBestKeysByKey['newRecentLeaderboardEntryKey'] = 1

  return aggregate
end


local function setSaveSlot(slotName)
  plog("I", "", "Progress Save Slot changed to " .. dumps(slotName))
  savePath = saveRoot .. slotName .. "/"
  currentSaveSlotName = slotName
end

local function setSavePath(path)
  savePath = path and path or (saveRoot .. defaultSaveSlot .. "/")
end

local function getSaveSlot()
  return currentSaveSlotName, savePath
end

local function saveMissionSaveData(id, dirtyDate)
  plog("I", "", "Saved Mission Progress for mission id " .. dumps(id))
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to saveMissionAttempt nonexitent mission by ID: " .. dumps(id))
    return
  end
  local path = savePath .. id .. '.json'
  mission.saveData.dirtyDate = dirtyDate
  return jsonWriteFile(path, mission.saveData, true)
end

local permaLogFile = 'permaMissionProgressLog.json'
local function permaLog(data)
  local file = {}
  if FS:fileExists(permaLogFile) then
    local state, result = xpcall(function()
      return jsonReadFile(permaLogFile)
    end, debug.traceback)
    if state ~= false and result ~= nil then
      file = result
    else
      plog("E", "", "Could not read permaProgress version file under " .. dumps(permaLogFile))
    end
  end
  local entry = { date = os.time(), humanDate = os.date("!%Y-%m-%dT%TZ"), data = data or {}, source = debug.tracesimple() }
  table.insert(file, entry)
  jsonWriteFile(permaLogFile, file, true)
  --log("","D",dumps(entry))
end

local function sanitizeAttempt(attempt, mission)
  attempt.type = attempt.type or 'none'
  -- remove all non-active stars from attempt
  local unlockedClean = {}
  for key, val in pairs(attempt.unlockedStars or {}) do
    if mission.careerSetup.starsActive[key] then
      unlockedClean[key] = val
    end
  end
  attempt.unlockedStars = unlockedClean

    -- automatically calculate the type (passed/completed etc) based on the stars
  local currentType = "none"
  local defaultStarsUnlockedCount = 0
  local bonusStarsUnlockedCount = 0
  for key, _ in pairs(mission.careerSetup._activeStarCache.defaultStarKeysByKey) do
    if attempt.unlockedStars[key] then
      defaultStarsUnlockedCount = defaultStarsUnlockedCount +1
    end
  end
  for key, _ in pairs(mission.careerSetup._activeStarCache.bonusStarKeysByKey) do
    if attempt.unlockedStars[key] then
      bonusStarsUnlockedCount = defaultStarsUnlockedCount +1
    end
  end
  if defaultStarsUnlockedCount >= 1 then
    currentType = 'passed'
  end
  if defaultStarsUnlockedCount == mission.careerSetup._activeStarCache.defaultStarCount
    and bonusStarsUnlockedCount ==  mission.careerSetup._activeStarCache.bonusStarCount then
    currentType = "completed"
  end
  attempt.type = currentType
end

local function aggregateAttempt(id, attempt, progressKey)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to saveMissionAttempt nonexitent mission by ID: " .. dumps(id))
    return
  end
  progressKey = progressKey or mission.defaultProgressKey or "default"
  local progress = mission.saveData.progress[progressKey]
  local unlockBefore = gameplay_missions_unlocks.getSimpleUnlockedStatus()
  -- sanitize attempt
  sanitizeAttempt(attempt, mission)
  extensions.hook("onMissionAttemptAggregated", attempt, mission)
  -- insert into progress
  table.insert(progress.attempts, attempt)

  local aggregateChange = { list = {}, newBestKeysByKey = {} }
  --log("","D",dumps(attempt))

  if not batchMode then
    plog("I", "aggregating regular progress.")
  end

  -- aggregate stars
  local unlockedStarsChanged = {}
  local starRewards = {list = {}, sums = {}, sumList = {}}
  for star, _ in pairs(attempt.unlockedStars or {}) do
    if mission.careerSetup.starsActive[star] then
      if mission.saveData.unlockedStars[star] then mission.saveData.unlockedStars[star] = 1 end
      mission.saveData.unlockedStars[star] = mission.saveData.unlockedStars[star] or 0
      --if attempt.unlockedStars[star] then --rls- allows repeat star rewards
        unlockedStarsChanged[star] = true
        mission.saveData.unlockedStars[star] = mission.saveData.unlockedStars[star] + 1
        for _, reward in ipairs(mission.careerSetup.starRewards[star] or {}) do
          starRewards.sums[reward.attributeKey] = (starRewards.sums[reward.attributeKey] or 0) + reward.rewardAmount
          local rCopy = deepcopy(reward)
          rCopy.sourceStar = star
          table.insert(starRewards.list, rCopy)
        end
      --end
    end
  end
  local ordered = tableKeysSorted(starRewards.sums)
  career_branches.orderAttributeKeysByBranchOrder(ordered)
  for _, key in ipairs(ordered) do
    table.insert(starRewards.sumList,{attributeKey = key, rewardAmount = starRewards.sums[key]})
  end




  -- aggregate generic values
  progress.aggregate = aggregateProgress(progress, attempt, aggregateChange, mission)
  -- configurable aggregates
  for _, config in ipairs(mission.autoAggregates or {}) do
    if autoAggregate[config.type] then
      plog("I", "aggregating auto-" .. config.type)
      autoAggregate[config.type](progress, attempt, config, mission, aggregateChange)
    end
  end
  -- let the mission also aggregate, for leaderboards, custom scores etc
  if mission.aggregateProgress then
    plog("I", "aggregating mission custom progress.")
    local succ, err, agg = xpcall(function()
      mission:aggregateProgress(progress, attempt, aggregateChange)
    end, debug.traceback)
    if not succ then
      plog("E", "", "Error while aggregating progress for mission ID: " .. dumps(id) .. ". Error follows:")
      plog("E", "", err)
    else
      progress.aggregate = agg
    end
  end

  -- unlock quicktravel when attempt is at least passed or completed
  local quickTravelBefore = mission.saveData.quickTravelUnlocked
  mission.saveData.quickTravelUnlocked = attempt.type == 'completed' or attempt.type == 'passed' or mission.saveData.quickTravelUnlocked

  -- unlock userSettings when attempt is at least passed or completed
  local userSettingsBefore = mission.saveData.userSettingsUnlocked
  mission.saveData.userSettingsUnlocked = attempt.type == 'completed' or attempt.type == 'passed' or mission.saveData.userSettingsUnlocked



  -- do rewards
  if career_career and career_career.isActive() then
    local sumChange = {}
    for key, amount in pairs(starRewards.sums) do
      sumChange[key] = (sumChange[key] or 0) + amount
    end
    if next(sumChange) then
      career_modules_playerAttributes.addAttributes(sumChange, {tags={"gameplay","reward","mission"}, label="Received challenge rewards: " .. (translateLanguage(mission.name,mission.name,true) or "(Unnamed Mission)")})
    end
  end

  -- put into career playbook if active
  if career_career and career_career.isActive() and career_modules_playbookWriter then
    career_modules_playbookWriter.addMissionPlayedEntry(id, attempt.unlockedStars)
  end

  --reduce rewards for successive attempts
  M.reduceCareerRewardsForDefaultStars(mission)


  if not batchMode then
    gameplay_missions_unlocks.updateUnlockStatus()
    local unlockAfter = gameplay_missions_unlocks.getSimpleUnlockedStatus()
    local unlockChange = gameplay_missions_unlocks.getUnlockDiff(unlockBefore, unlockAfter)
    local unlockedMissions = unlockChange.missionsList or {}
    -- notify career for unlocked missions
    if career_career and career_career.isActive() and career_modules_logbook then
      for _, elem in ipairs(unlockedMissions) do
        career_modules_logbook.missionUnlocked(elem.id)
        extensions.hook("onMissionUnlocked", elem.id)
        gameplay_rawPois.clear()
      end
    end


    local ret = {
      aggregateChange = aggregateChange,
      unlockChange = unlockChange,
      nextMissionsUnlock = gameplay_missions_unlocks.getMissionBasedUnlockDiff(mission, unlockChange),
      unlockedMissions = unlockedMissions,
      unlockedStarsAttempt = attempt.unlockedStars,
      unlockedStarsChanged = unlockedStarsChanged,
      starRewards = starRewards,
    }

    if quickTravelBefore ~= mission.saveData.quickTravelUnlocked then
      ret.quickTravelUnlockedChange = true
    end
    if userSettingsBefore ~= mission.saveData.userSettingsUnlocked then
      ret.userSettingsUnlockedChange = true
    end
    permaLog(ret)
    return ret
  else
    return {}
  end
  -- actually save progress
  --saveMissionSaveData(id)
end

local function getCleanSaveData(mission)
  local defaultKey = mission.defaultProgressKey
  local ret = {}
  local prog = {}
  prog[defaultKey] = {
    aggregate = {
      bestType = 'none',
      passed = false,
      completed = false,
      mosttimespan = nil,
      attemptCount = 0
    },
    attempts = {},
    leaderboards = {
      recent = {},
    }
  }

  for progressKey, defaults in pairs(mission.defaultAggregateValues or {}) do
    if progressKey ~= "all" then
      if not prog[progressKey] then
        prog[progressKey] = deepcopy(prog[defaultKey])
      end
      --for key, val in pairs(defaults) do
      --  prog[progressKey].aggregate[key] = val
      --end
    end
  end

  ret.progress = prog

  ret.unlockedStars = {}

  if mission.latestVersion then
    ret.version = mission.latestVersion
  else
    log("E","","Mission type '"..mission.missionType.."' needs version added!")
  end

  if mission.setupSaveData then
    local succ, err, prog = xpcall(function()
      mission:setupSaveData(ret)
    end, debug.traceback)
    if not succ then
      plog("E", "", "Error setting up custom mission progress, ID: " .. dumps(id) .. ". Error follows:")
      plog("E", "", err)
    else
      ret = prog
    end
  end
  return ret
end

local function updateSaveData(mission, saveData)
  log("I", "", "UpdateSaveData was called")
  local fileVersion = saveData.version
  log("I", "", dumps(saveData))

  -- iterate over version updates
  while (fileVersion < mission.latestVersion) do

    -- iterate over progressKeys
    for progressKey, progressData in pairs(saveData.progress) do

      -- iterate over attempts
      for _, attempt in ipairs(progressData.attempts) do

        -- update attempt
        mission:updateAttempt(attempt, fileVersion)
      end
    end

    fileVersion = fileVersion + 1
  end

  -- saveData has to be already set here, because it's used in aggregateAttempt
  mission.saveData = getCleanSaveData(mission)

  -- iterate over progressKeys
  for progressKey, progressData in pairs(saveData.progress) do

    -- create empty progressKeys to insert attemptData into
    M.ensureProgressExistsForKey(mission, progressKey)
    -- iterate over attempts
    for _, attempt in ipairs(progressData.attempts) do

      -- batchmode to stop unlock stuff from happening, this happens after loading the missions anyway
      batchMode = true
      aggregateAttempt(mission.id, attempt, progressKey)
      batchMode = false
    end
  end

  -- setup
  local saveFile = savePath .. mission.id .. '.json'
  local backupFile = savePath .. mission.id .. '-backup.json'
  FS:copyFile(saveFile,backupFile)

  -- update (if application quits before finishing, we should replace saveFile with backupFile)
  jsonWriteFile(saveFile, mission.saveData, true)

  -- cleanup
  FS:removeFile(backupFile)
  plog("I", "", "Updated Mission Progress for mission id " .. dumps(mission.id))

  return mission.saveData
end

local function loadMissionSaveData(mission)
  local id = mission.id
  local path = savePath .. id .. '.json'

  if FS:fileExists(path) then
    local state, result = xpcall(function()
      local saveData = jsonReadFile(path)
      if career_career and career_career.isActive() then
        career_modules_missionWrapper.onMissionLoaded(id, saveData.dirtyDate)
      end

      -- check if saveData is outdated and if it has an update function
      if saveData.version < mission.latestVersion and mission.updateAttempt then
        saveData = updateSaveData(mission, saveData)
      end

      -- upgrade start unlocks into star attempts count.

      return saveData
    end, debug.traceback)
    if state ~= false and result ~= nil then
      -- sanitize progress (add default)
      if mission.loadSaveData then
        local succ, err, prog = xpcall(function()
          mission:loadSaveData(result)
        end, debug.traceback)
        if not succ then
          plog("E", "", "Error loading custom mission progress, ID: " .. dumps(id) .. ". Error follows:")
          plog("E", "", err)
        else
          result = prog
        end
      end
      return result
    else
      -- check for backupFile
    end
  end

  return getCleanSaveData(mission)
end

local function reduceCareerRewardsForDefaultStars(mission)
  if career_career.isActive() then
    for key, count in pairs(mission.saveData.unlockedStars) do
      if mission.careerSetup._activeStarCache.defaultStarKeysByKey[key] then
        local list = mission.careerSetup.starRewards[key] or {}
        local starCount = count
        if starCount == true then starCount = 1 end
        if starCount then
          local rewardMultiplier = starCount == 0 and 1 or 1 --math.max(0.1,(1-(starCount or 0) * 0.2))
          print(string.format("%s - %s reduced to x%0.2f", mission.id, key, rewardMultiplier*100 ))
          for _, reward in ipairs(list) do
            reward.rewardAmount = (round(reward._originalRewardAmount*rewardMultiplier))
          end
        end
      end
    end
  end

  -- always compute totals/sums
  mission.careerSetup._activeStarCache.sortedStarRewardsByKey = {}
  for key, list in pairs(mission.careerSetup.starRewards) do
    local newList = {}
    for _, reward in ipairs(list) do
      local elem = {rewardAmount = reward.rewardAmount, icon = "star", attributeKey = reward.attributeKey}
      table.insert(newList, elem)
    end
    mission.careerSetup._activeStarCache.sortedStarRewardsByKey[key] = newList
  end
end

M.reduceCareerRewardsForDefaultStars = reduceCareerRewardsForDefaultStars

local function ensureProgressExistsForKey(missionInstance, progressKey)
  if not missionInstance.saveData.progress[progressKey] then
    plog("I", "Created Missing Progress for key " .. dumps(progressKey))
    missionInstance.saveData.progress[progressKey] = {
      aggregate = {
        bestType = 'none',
        passed = false,
        completed = false,
        mosttimespan = nil,
        attemptCount = 0
      },
      attempts = {},
      leaderboards = {
        recent = {}
      }
    }
  end
end

M.missionHasQuickTravelUnlocked = function(missionId)
  local mission = gameplay_missions_missions.getMissionById(missionId)
  if not mission then
    plog("E", "", "Trying to missionHasQuickTravelUnlocked nonexistent mission by ID: " .. dumps(id))
    return false
  end
  if not career_career or not career_career.isActive() then
    return true
  end
  --return mission.saveData.quickTravelUnlocked or false
  return true
end

M.missionHasUserSettingsUnlocked = function(missionId)
  local mission = gameplay_missions_missions.getMissionById(missionId)
  if not mission then
    plog("E", "", "Trying to missionHasUserSettingsUnlocked nonexistent mission by ID: " .. dumps(id))
    return false
  end

  -- allow userSettings if in freeroam always
  if not career_career or not career_career.isActive() then
    return true
  end
  -- allow usersettings if no stars are set up for this mission always
  if not next(mission.careerSetup._activeStarCache.defaultStarKeysSorted) then
    return true
  end
  --return mission.saveData.userSettingsUnlocked or false
  return true
end

M.getLeaderboardChangeKeys = function(missionId)
  local mission = gameplay_missions_missions.getMissionById(missionId)
  local ret = {}
  if not mission then
    return ret
  end
  ret['recent'] = 'newRecentLeaderboardEntryKey'
  for _, elem in ipairs(mission.autoAggregates) do
    if elem.leaderboardKey and elem.newLeaderboardEntryKey then
      ret[elem.leaderboardKey] = elem.newLeaderboardEntryKey
    end
  end
  return ret
end


-----------------
-- UI FUNCTIONS--
-----------------

local genericUiAttemptProgress = {
  recent = {
    {
      type = 'simple',
      attemptKey = 'attemptNumber',
      columnLabel = '#',
      attemptIsSource = true
    },
    {
      type = 'simple',
      attemptKey = 'date',
      columnLabel = '',
      attemptIsSource = true,
      formatFunction = "timespan"
    },
    {
      type = 'simple',
      attemptKey = 'unlockedStars',
      columnLabel = '',
      attemptIsSource = true,
      formatFunction = "stars"
    }
  },
  highscore = {
    {
      type = 'simple',
      customValue = true,
      columnLabel = '#',
    },
    {
      type = 'simple',
      attemptKey = 'date',
      columnLabel = '',
      attemptIsSource = true,
      formatFunction = "timespan"
    },
    {
      type = 'simple',
      attemptKey = 'unlockedStars',
      columnLabel = '',
      attemptIsSource = true,
      formatFunction = "stars"
    }
  }
}
--[[{
  type = 'simple',
  attemptKey = 'completed',
  columnLabel = 'Completed',
},
{
  type = 'simple',
  attemptKey = 'passed',
  columnLabel = 'Passed',
}
}]]

local genericUiAggregateProgress = {
  {
    type = 'simple',
    aggregateKey = 'attemptCount',
    columnLabel = 'Attempts',
  },

  --[[
  {
    type = 'simple',
    aggregateKey = 'bestType',
    columnLabel = 'Status',
    newBestKey = 'newBestType'
  }
  {
    type = 'simple',
    aggregateKey = 'completed',
    columnLabel = 'Completed',
  },
  {
    type = 'simple',
    aggregateKey = 'passed',
    columnLabel = 'Passed',
  }]]
}

-- formats text depending on formatFunction
local function tryFormatValueForFunction(val, fun, m)
  if val == nil then
    return { text = "-" }
  end
  -- add new formatFunctions here if needed
  if fun == 'distance' then
    local result, unit = translateDistance(val, 'auto')
    return { format = "distance", distance = val or 0, text = string.format("%.2f %s", result, unit) }
  elseif fun == 'detailledTime' then
    return { format = "detailledTime", detailledTime = val or 0, text = string.format("%d:%02d:%03d", math.floor(val / 60), val % 60, 1000 * (val % 1)) }
  elseif fun == 'timespan' then
    return { format = 'timespan', timestamp = val or 0, text = "ts: " .. (val or 0) }
  elseif fun == 'stars' then
    local txt = ""
    local sortedKeys = m.careerSetup._activeStarCache.sortedStars
    local simpleStars = ""

    --dump(sortedKeys)
    for i = 1, #sortedKeys do
      if i == #m.careerSetup.defaultStarKeys+1 then
        txt = txt .. "|"
      end
      txt = txt .. (val[sortedKeys[i]] and "X" or "-")
      if i <= #m.careerSetup.defaultStarKeys then
        simpleStars = simpleStars .. (val[sortedKeys[i]] and "D" or "d")
      else
        simpleStars = simpleStars .. (val[sortedKeys[i]] and "B" or "b")
      end
    end
    return {format = simpleStars, text = txt, simpleStars = simpleStars }
  else
    return { text = tostring(val) }
  end
  return { text = "?" }
end

-- gets value from attempt depending on type (type defines the location of value in attempt table)
local function getValueForAttemptUiProgressType(attempt, config)
  local res = nil
  local src = attempt.data
  if config.attemptIsSource then
    src = attempt
  end

  if config.type == 'simple' then
    res = src[config.attemptKey]
  end

  return res
end

-- gets value from aggregate depending on type (type defines the location of value in aggregate table)
local function getValueForAggregateUiProgressType(aggregate, config)
  local res = nil

  if config.type == 'simple' then
    res = aggregate[config.aggregateKey]
  end

  return res
end


-- in-situ reversal
local function reverse(list)
  local i, j = 1, #list
  while i < j do
    list[i], list[j] = list[j], list[i]
    i = i + 1
    j = j - 1
  end
end
local function formatAttempts(mission, progressKey, limit, includeMostRecentAttempt)
  local res = { labels = {}, rows = {} }

  local missionInstance = gameplay_missions_missions.getMissionById(mission.id)
  M.ensureProgressExistsForKey(missionInstance, progressKey)
  local attemptsForProgressKey = missionInstance.saveData.progress[progressKey].attempts
  local leaderboardKey = mission.defaultLeaderboardKey or 'recent'
  local attemptIndices = missionInstance.saveData.progress[progressKey].leaderboards[leaderboardKey] or {}

  -- genericData column headers
  for _, col in pairs(genericUiAttemptProgress[leaderboardKey] or {}) do
    table.insert(res.labels, col.columnLabel)
  end

  -- automaticData column headers
  for _, col in pairs(mission.autoUiAttemptProgress or {}) do
    table.insert(res.labels, col.columnLabel)
  end

  -- customData column headers would be here

  -- build rows
  for count, attemptIndex in ipairs(attemptIndices) do
    if not limit or count <= limit then
      local attempt = attemptsForProgressKey[attemptIndex]
      local row = {}--{ { text = translateLanguage(mission.name, mission.name, true) } }

      -- genericData cells
      for _, col in pairs(genericUiAttemptProgress[leaderboardKey] or {}) do
        if col.customValue then
          table.insert(row, { text = tonumber(count) })
        else
          table.insert(row, tryFormatValueForFunction(getValueForAttemptUiProgressType(attempt, col), col.formatFunction, mission))
        end
      end

      -- automaticData cells
      for _, col in pairs(mission.autoUiAttemptProgress or {}) do
        table.insert(row, tryFormatValueForFunction(getValueForAttemptUiProgressType(attempt, col), col.formatFunction, mission))
      end

      -- customData cells would be here
      table.insert(res.rows, row)
    end
  end
  if includeMostRecentAttempt then
    local attempt = attemptsForProgressKey[#attemptsForProgressKey]
    local row = {}--{ { text = translateLanguage(mission.name, mission.name, true) } }

    -- genericData cells
    for _, col in pairs(genericUiAttemptProgress[leaderboardKey] or {}) do
      if col.customValue then
        table.insert(row, { text = "DNQ" })
      else
        table.insert(row, tryFormatValueForFunction(getValueForAttemptUiProgressType(attempt, col), col.formatFunction, mission))
      end
    end

    -- automaticData cells
    for _, col in pairs(mission.autoUiAttemptProgress or {}) do
      table.insert(row, tryFormatValueForFunction(getValueForAttemptUiProgressType(attempt, col), col.formatFunction, mission))
    end

    -- customData cells would be here
    table.insert(res.rows, row)
  end
  --reverse(res.rows)


  return res
end

local function formatAggregates(mission, progressKey, onlySelf)
  local res = { labels = {--[['Mission']]}, rows = {}, newBestKeys = {} }
  local missions = gameplay_missions_missions.getMissionsByMissionType(mission.missionType)

  -- genericData column headers
  for _, col in pairs(genericUiAggregateProgress or {}) do
    table.insert(res.labels, col.columnLabel)
    table.insert(res.newBestKeys, "none")
  end

  -- automaticData column headers
  for _, col in pairs(mission.autoUiAggregateProgress or {}) do
    table.insert(res.labels, col.columnLabel)
    table.insert(res.newBestKeys, col.newBestKey or "none")
  end

  -- customData column headers would be here

  -- build rows
  for _, m in pairs(missions) do
    if not onlySelf or (m == mission) then
      local missionInstance = gameplay_missions_missions.getMissionById(m.id)
      if missionInstance.saveData.progress[progressKey] ~= nil then
        local row = {}--{ { text = translateLanguage(m.name, m.name, true) } }
        local aggregateForProgressKey = missionInstance.saveData.progress[progressKey].aggregate

        -- genericData cells
        for _, col in pairs(genericUiAggregateProgress or {}) do
          table.insert(row, tryFormatValueForFunction(getValueForAggregateUiProgressType(aggregateForProgressKey, col), col.formatFunction, m))
        end

        -- automaticData cells
        for _, col in pairs(mission.autoUiAggregateProgress or {}) do
          local value = table.insert(row, tryFormatValueForFunction(getValueForAggregateUiProgressType(aggregateForProgressKey, col), col.formatFunction, m))
        end

        -- customData cells would be here

        table.insert(res.rows, row)
      end
    end
  end

  return res
end




local function tryBuildContext(label, data)
  if not label then return {} end
  local context = {}
  for key, value in pairs(data) do
    if type(value) == 'string' or type(value) == 'number' then
      context[key] = tostring(value)
    end
  end
  return context
end

local function formatStars(mission)
  if--[[ not career_career or not career_career.isActive() or ]]not mission.saveData.unlockedStars
    or not mission.careerSetup.starsActive or not next(mission.careerSetup.starsActive) then
    return {
      disabled = true
    }
  end
  -- get a list of all stars, sorted according to
  local starKeys, defaultCache = mission.careerSetup._activeStarCache.sortedStars, mission.careerSetup._activeStarCache.defaultStarKeysByKey
  local defaultStarKeysToIndex = mission.careerSetup._activeStarCache.defaultStarKeysToIndex


  local unlockedStarsFormatted = {stars = {}, totalStars = #starKeys}

  local totalUnlockedStarCount = 0
  local defaultUnlockedStarCount, totalDefaultStarCount = 0,0
  local bonusUnlockedStarCount, totalBonusStarCount = 0,0

  for i, key in ipairs(starKeys) do
    local count = mission.saveData.unlockedStars[key]
    if count == true then count = 1 end
    if count == nil or count == false then count = 0 end

    local elem = {
      key = key,
      label = {
        txt = mission.starLabels[key] or "Missing Star Description",
        context = tryBuildContext(mission.starLabels[key], mission.missionTypeData),
      },
      rewards = mission.careerSetup._activeStarCache.sortedStarRewardsByKey[key] or {},
      unlocked = count > 0,
      isDefaultStar = defaultCache[key] and true or false,
      defaultStarIndex = defaultStarKeysToIndex[key] or false,
      globalStarIndex = i,
    }
    totalUnlockedStarCount = totalUnlockedStarCount + (elem.unlocked and 1 or 0)
    totalDefaultStarCount = totalDefaultStarCount + (elem.isDefaultStar and 1 or 0)
    defaultUnlockedStarCount = defaultUnlockedStarCount + (elem.unlocked and elem.isDefaultStar and 1 or 0)
    totalBonusStarCount = totalBonusStarCount + ((not elem.isDefaultStar) and 1 or 0)
    bonusUnlockedStarCount = bonusUnlockedStarCount + (elem.unlocked and (not elem.isDefaultStar) and 1 or 0)
    table.insert(unlockedStarsFormatted.stars, elem)
  end

  unlockedStarsFormatted.totalUnlockedStarCount = totalUnlockedStarCount

  unlockedStarsFormatted.defaultUnlockedStarCount = defaultUnlockedStarCount
  unlockedStarsFormatted.totalDefaultStarCount = totalDefaultStarCount

  unlockedStarsFormatted.bonusUnlockedStarCount = bonusUnlockedStarCount
  unlockedStarsFormatted.totalBonusStarCount = totalBonusStarCount

  return unlockedStarsFormatted
end

local function formatSaveDataForUi(id, onlyKey, includeMostRecentAttempt)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to formatSaveDataForUi nonexitent mission by ID: " .. dumps(id))
    return
  end
  local allProgressKeys = tableKeysSorted(mission.saveData.progress)
  local formattedProgressByKey = {}
  if onlyKey then
    allProgressKeys = { onlyKey }
  end
  for _, key in ipairs(allProgressKeys) do
    formattedProgressByKey[key] = {
      attempts = formatAttempts(mission, key, nil, includeMostRecentAttempt),
      --aggregates = formatAggregates(mission, key),
      ownAggregate = formatAggregates(mission, key, true)
    }
  end
  local progressKeyTranslations = {}
  for _, key in ipairs(allProgressKeys) do
    progressKeyTranslations[key] = mission.getProgressKeyTranslation and mission:getProgressKeyTranslation(key) or key
  end
  local ret = {
    defaultProgressKey = mission.defaultProgressKey,
    allProgressKeys = allProgressKeys,
    progressKeyTranslations = progressKeyTranslations,
    formattedProgressByKey = formattedProgressByKey,
    unlockedStars = formatStars(mission)
  }
  return ret
end

local function formatSaveDataForBigmap(id)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to saveMissionAttempt nonexitent mission by ID: " .. dumps(id))
    return
  end
  local ret = {}
  local bigmapConf = mission.autoUiBigmap or {}
  bigmapConf.rating = bigmapConf.rating or {}

  for key, conf in pairs(bigmapConf.aggregates or {}) do
    local sd = mission.saveData.progress[conf.progressKey or mission.defaultProgressKey]
    if sd then
      local agg = sd.aggregate or {}
      ret[key] = {
        label = { text = conf.label, context = {} },
        value = tryFormatValueForFunction(getValueForAggregateUiProgressType(agg, conf), conf.formatFunction, mission)
      }
    end
  end

  ret.rating = {}

  local agg = (mission.saveData.progress[bigmapConf.rating.progressKey or mission.defaultProgressKey] or {}).aggregate or {}

  if not mission.unlocks.startable then
    ret.rating = { type = 'locked' }
  elseif agg.attemptCount == 0 then
    ret.rating = { type = 'new' }
  elseif agg.completed then
    ret.rating = { type = 'done' }
  else
    ret.rating = { type = 'attempts', attempts = agg.attemptCount }
  end

  ret.unlockedStars = formatStars(mission)

  return ret
end

M.aggregateAttempt = aggregateAttempt
M.saveMissionSaveData = saveMissionSaveData
M.loadMissionSaveData = loadMissionSaveData
M.ensureProgressExistsForKey = ensureProgressExistsForKey
M.newAttempt = newAttempt

M.setSaveSlot = setSaveSlot
M.getSaveSlot = getSaveSlot
M.setSaveSlotVersion = setSaveSlotVersion
M.getSaveSlotVersion = getSaveSlotVersion
M.setSavePath = setSavePath

M.formatSaveDataForUi = formatSaveDataForUi
M.formatSaveDataForBigmap = formatSaveDataForBigmap
M.formatAggregatesForMissionTypeWithProgKey = formatAggregatesForMissionTypeWithProgKey
M.getProgressAggregateCache = getProgressAggregateCache
M.formatStars = formatStars

M.startConditionMet = startConditionMet

local function onExtensionLoaded()
  local files = FS:findFiles('/lua/ge/extensions/gameplay/missions/progress/conditions', '*.lua', -1)
  local count = 0
  for _, file in ipairs(files) do
    local aConds = require(file:sub(0, -5))

    for key, value in pairs(aConds) do
      count = count + 1
      conditionTypes[key] = value
    end
  end
  plog("D", "", "Loaded " .. count .. " condition types from " .. #files .. " files.")
end
M.onExtensionLoaded = onExtensionLoaded

-- helper stuff

local medals = { 'wood', 'bronze', 'bronze', 'silver', 'silver', 'gold', }
local attempts = { 'attempted', 'attempted', 'passed', 'passed', 'completed', 'failed' }
M.testHelper = {
  randomBool = function()
    return math.random() > 0.5
  end,
  randomAttemptType = function()
    return attempts[math.floor(math.random() * 6) + 1]
  end,
  randomMedal = function()
    return medals[math.floor(math.random() * 6) + 1]
  end,
  randomVehicle = function()
    return { model = "Random", config = "Vehicle", isConfigFile = false }
  end,
  randomNumber = function(min, max)
    return math.random() * (max - min) + min
  end
}

M.generateAttempt = function(id, addAttemptData)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to saveMissionAttempt nonexitent mission by ID: " .. dumps(id))
    return
  end
  if not mission.getRandomizedAttempt then
    dumpz(mission, 2)
    dump("no attempt generator?")
    return
  end

  local attempt = M.newAttempt(mission:getRandomizedAttempt())
  for k, v in pairs(addAttemptData) do
    attempt[k] = v
  end
  dump(attempt)
  local totalChange = M.aggregateAttempt(id, attempt, mission.defaultProgressKey)

  if career_career and career_career.isActive() then
    career_modules_missionWrapper.saveMission(id)
  else
    M.saveMissionSaveData(id)
  end
  return totalChange
end

M.generateAttempts = function(id, amount, dumpChange)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then
    plog("E", "", "Trying to saveMissionAttempt nonexitent mission by ID: " .. dumps(id))
    return
  end
  if not mission.getRandomizedAttempt then
    return
  end
  local allProgressKeys = tableKeysSorted(mission.saveData.progress)
  for _, progressKey in ipairs(allProgressKeys) do
    for i = 1, amount do
      local attempt = M.newAttempt(mission:getRandomizedAttempt())
      local totalChange = M.aggregateAttempt(id, attempt, progressKey)
      if dumpChange then
        dump(totalChange)
      end
    end
  end
  if career_career and career_career.isActive() then
    career_modules_missionWrapper.saveMission(id)
  else
    M.saveMissionSaveData(id)
  end

end

M.startBatchMode = function()
  batchMode = true
end
M.endBatchMode = function()
  batchMode = false
end

M.exportAllProgressToCSV = function()


end

return M
