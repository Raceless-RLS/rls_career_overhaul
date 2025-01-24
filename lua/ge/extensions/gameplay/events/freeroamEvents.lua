-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {}

local processRoad = require('gameplay/events/freeroam/processRoad')
local leaderboardManager = require('gameplay/events/freeroam/leaderboardManager')
local activeAssets = require('gameplay/events/freeroam/activeAssets')
local checkpointManager = require('gameplay/events/freeroam/checkpointManager')
local utils = require('gameplay/events/freeroam/utils')

local Assets = activeAssets.ActiveAssets.new()

local timerActive = false
local mActiveRace
local staged = nil
local in_race_time = 0

local speedUnit = 2.2369362921
local lapCount = 0
local currCheckpoint = nil
local mHotlap = nil
local mAltRoute = nil
local mSplitTimes = {}
local isLoop = false
local checkpointsHit = 0
local totalCheckpoints = 0
local currentExpectedCheckpoint = 1
local invalidLap = false

local races = nil

local function rewardLabel(raceName, newBestTime)
    local raceLabel = races[raceName].label
    local timeLabel = utils.formatTime(in_race_time)
    local performanceLabel = newBestTime and "New Best Time!" or "Completion"

    local label = string.format("%s - %s: %s", raceLabel, performanceLabel, timeLabel)

    if mAltRoute then
        label = label .. " (Alternative Route)"
    end

    if mHotlap == raceName then
        label = label .. " (Hotlap)"
    end

    return label
end

local function getDriftScore()
    local finalScore = 0
    if gameplay_drift_scoring then
        local scoreData = gameplay_drift_scoring.getScore()
        if scoreData then
            finalScore = scoreData.score or 0
            if scoreData.cachedScore then
                finalScore = finalScore + math.floor(scoreData.cachedScore * scoreData.combo)
            end
            gameplay_drift_general.reset()
        end
    end
    return finalScore
end

local function payoutRace()
    if not mActiveRace then
        return 0
    end

    local race = races[mActiveRace]
    local time = race.bestTime
    local reward = race.reward
    local raceLabel = race.label

    -- Get appropriate time and reward values based on route type
    if mHotlap == mActiveRace then
        time = race.hotlap
    end
    if mAltRoute then
        time = race.altRoute.bestTime
        reward = race.altRoute.reward
        raceLabel = race.altRoute.label
        if mHotlap == mActiveRace then
            time = race.altRoute.hotlap
        end
    end
    if mHotlap == mActiveRace then
        raceLabel = raceLabel .. " (Hotlap)"
    end

    -- Calculate scores and rewards
    local driftScore = 0
    if race.driftGoal then
        driftScore = getDriftScore()
        reward = utils.driftReward(mActiveRace, time, driftScore)
    else
        reward = utils.raceReward(time, reward, in_race_time)
    end

    -- Handle leaderboard
    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(mActiveRace)
    if mAltRoute and leaderboardEntry then
        leaderboardEntry = leaderboardEntry.altRoute
    end

    local oldTime = leaderboardEntry and leaderboardEntry.time or 0
    local oldScore = leaderboardEntry and leaderboardEntry.driftScore or 0

    local newEntry = {
        raceName = mActiveRace,
        isAltRoute = mAltRoute,
        isHotlap = mHotlap == mActiveRace,
        time = in_race_time,
        splitTimes = mSplitTimes,
        driftScore = driftScore
    }

    local newBest = leaderboardManager.addLeaderboardEntry(newEntry)

    -- Build the base message that's shown regardless of career mode
    local message = invalidLap and "Lap Invalidated\n" or ""

    if race.driftGoal then
        message = message .. string.format("%s\nDrift Score: %d\nTime: %s", raceLabel, driftScore, utils.formatTime(in_race_time))
        if oldScore and oldTime then
            message = message .. string.format("\nPrevious Best Score: %d\nPrevious Best Time: %s", oldScore, utils.formatTime(oldTime))
        end
    else
        if newBest and not invalidLap then
            message = message .. "New Best Time!\n"
        end
        if race.hotlap then
            message = message .. string.format("%s\nTime: %s\nLap: %d", raceLabel, utils.formatTime(in_race_time), lapCount)
        else
            message = message .. string.format("%s\nTime: %s", raceLabel, utils.formatTime(in_race_time))
        end
        if newBest and not invalidLap and oldTime ~= math.huge then
            message = message .. string.format("\nPrevious Best: %s", utils.formatTime(oldTime))
        end
    end

    -- Handle career mode specific rewards
    if career_career.isActive() then
        if not newBest or invalidLap then
            reward = reward / 2
        end
        reward = invalidLap and 0 or reward
        lapCount = invalidLap and 1 or lapCount
        if race.hotlap then
            reward = reward * (1 + (lapCount - 1) / 10)
        end

        if reward > 0 then
            local xp = math.floor(reward / 20)
            local totalReward = {
                money = { amount = reward },
                beamXP = { amount = math.floor(xp / 10) },
                vouchers = {
                    amount = (oldTime == 0 or oldTime > time) and in_race_time < time and 1 or 0
                }
            }
            for _, type in ipairs(race.type) do
                totalReward[type] = { amount = xp }
            end
            
            career_modules_payment.reward(totalReward, {
                label = rewardLabel(mActiveRace, newBest),
                tags = {"gameplay", "reward", "mission"}
            })
            
            message = message .. string.format("\nXP: %d | Reward: $%.2f", xp, reward)
            career_saveSystem.saveCurrent()
        end
    end

    mActiveRace = nil
    utils.displayMessage(message, 20, "Reward")
    return reward
end

-- Simplified payoutRace function for drag races
local function payoutDragRace(raceName, finishTime, finishSpeed)
    -- Load the leaderboard
    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(raceName)
    local oldTime = leaderboardEntry and leaderboardEntry.time or 0

    local newEntry = {
        raceName = raceName,
        time = finishTime,
        splitTimes = mSplitTimes
    }

    local newBestTime = leaderboardManager.addLeaderboardEntry(newEntry)

    if not career_career.isActive() then
        local message = string.format("%s\nTime: %s\nSpeed: %.2f mph", races[raceName].label, utils.formatTime(finishTime),
            finishSpeed)
        utils.displayMessage(message, 10)
        return 0
    end

    -- Get race data
    local raceData = races[raceName]
    local targetTime = raceData.bestTime
    local baseReward = raceData.reward

    -- Calculate reward based on performance
    local reward = utils.raceReward(targetTime, baseReward, finishTime)
    if reward <= 0 then
        reward = baseReward / 2 -- Minimum reward for completion
    end

    reward = newBestTime and reward or reward / 2

    -- Calculate experience points
    local xp = math.floor(reward / 20)

    -- Prepare total reward
    local totalReward = {
        money = {
            amount = reward
        },
        beamXP = {
            amount = math.floor(xp / 10)
        },
        vouchers = {
            amount = newBestTime and 1 or 0
        }
    }

    -- Create reason for reward
    local reason = {
        label = raceData.label .. (newBestTime and " - New Best Time!" or " - Completion"),
        tags = {"gameplay", "reward", "drag"}
    }

    -- Process the reward
    career_modules_payment.reward(totalReward, reason)

    -- Prepare the completion message
    local message = string.format("%s\n%s\nTime: %s\nSpeed: %.2f mph\nXP: %d | Reward: $%.2f",
        newBestTime and "Congratulations! New Best Time!" or "", raceData.label, utils.formatTime(finishTime), finishSpeed,
        xp, reward)

    -- Display the message
    ui_message(message, 20, "Reward")

    -- Save the leaderboard and game state
    career_saveSystem.saveCurrent()

    return reward
end

local function getDifference(raceName, currentCheckpointIndex)
    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(raceName)
    if not leaderboardEntry then
        return nil
    end

    local splitTimes = {}
    if mAltRoute then
        if not leaderboardEntry.altRoute then
            return nil
        end
        if mHotlap == raceName then
            splitTimes = leaderboardEntry.altRoute.hotlapSplitTimes
        else
            splitTimes = leaderboardEntry.altRoute.splitTimes
        end
    else
        if mHotlap == raceName then
            splitTimes = leaderboardEntry.hotlapSplitTimes
        else
            splitTimes = leaderboardEntry.splitTimes
        end
    end

    if not splitTimes or not splitTimes[currentCheckpointIndex] then
        return nil
    end

    -- Calculate the time difference for this split
    local currentSplitDiff
    if not mSplitTimes[currentCheckpointIndex] or not splitTimes[currentCheckpointIndex] then
        return nil
    end

    if currentCheckpointIndex == 1 then
        -- For first checkpoint, compare directly
        currentSplitDiff = mSplitTimes[currentCheckpointIndex] - splitTimes[currentCheckpointIndex]
    else
        -- Check if we have the previous checkpoint times before calculating
        if not mSplitTimes[currentCheckpointIndex - 1] or not splitTimes[currentCheckpointIndex - 1] then
            return nil
        end

        -- For subsequent checkpoints, compare the differences between splits
        local previousBestSplit = splitTimes[currentCheckpointIndex] - splitTimes[currentCheckpointIndex - 1]
        local currentSplit = mSplitTimes[currentCheckpointIndex] - mSplitTimes[currentCheckpointIndex - 1]
        currentSplitDiff = currentSplit - previousBestSplit
    end

    return currentSplitDiff
end

local function formatSplitDifference(diff)
    local sign = diff >= 0 and "+" or "-"
    return string.format("%s%s", sign, utils.formatTime(math.abs(diff)))
end

local function exitRace()
    if mActiveRace then
        utils.setActiveLight(mActiveRace, "red")
        lapCount = 0
        mActiveRace = nil
        timerActive = false
        mHotlap = nil
        currCheckpoint = nil
        mSplitTimes = {}
        Assets:hideAllAssets()
        checkpointManager.removeCheckpoints()
        utils.displayMessage("You exited the race zone, Race cancelled", 3)
        utils.restoreTrafficAmount()
        if gameplay_drift_general.getContext() == "inChallenge" then
            gameplay_drift_general.setContext("inFreeRoam")
            gameplay_drift_general.reset()
        end
    end
end

local function onBeamNGTrigger(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end

    local triggerName = data.triggerName
    local event = data.event

    if not triggerName:match("^fre_") then
        -- Not a free roam event trigger, ignore
        return
    end

    -- Remove the 'fre_' prefix for processing
    triggerName = triggerName:sub(5)

    -- Extract trigger information
    local triggerType, raceName, rest = triggerName:match("^([^_]+)_([^_]+)(.*)$")

    if not triggerType or not raceName then
        -- print("Trigger name doesn't match expected pattern.")
        return
    end

    -- Initialize altFlag and index
    local altFlag = nil
    local index = nil

    -- Process the rest of the trigger name
    if rest ~= "" then
        -- Remove leading underscores
        rest = rest:gsub("^_+", "")

        -- Check if rest starts with 'alt'
        if rest:sub(1, 3) == "alt" then
            altFlag = "alt"
            rest = rest:sub(4) -- Remove 'alt' and move forward
            rest = rest:gsub("^_+", "") -- Remove any additional underscores
        end

        -- If there's still something left, it's the index
        if rest ~= "" then
            index = rest
        end
    end

    -- Convert index to number if it exists
    local checkpointIndex = index and tonumber(index) or nil

    local isAlt = altFlag == "alt" -- TEMP must change to acount for alt routes that intersect with the main route multiple times

    if triggerType == "staging" then
        if event == "enter" and mActiveRace == nil then
            if utils.isPlayerInPursuit() then
                utils.displayMessage("You cannot stage for an event while in a pursuit.", 2)
                return
            end

            local vehicleSpeed = math.abs(be:getObjectVelocityXYZ(data.subjectID)) * speedUnit
            if vehicleSpeed > 5 and mActiveRace then
                return
            end
            mHotlap = nil
            if vehicleSpeed > 5 then
                if races[raceName].runningStart then
                    utils.displayMessage("Hotlap Staged", 2)
                    if races[raceName].hotlap then
                        mHotlap = raceName
                    end
                else
                    utils.displayMessage("You are too fast to stage.\nPlease back up and slow down to stage.", 2)
                    staged = nil
                    return
                end
            end
            Assets:hideAllAssets()
            lapCount = 0

            -- Initialize displays if drag race
            if raceName == "drag" then
                utils.initDisplays()
                utils.resetDisplays()
            end

            -- Set staged race
            staged = raceName
            -- print("Staged race: " .. raceName)
            utils.displayStagedMessage(raceName)
            utils.setActiveLight(raceName, "yellow")
        elseif event == "exit" then
            staged = nil
            if not mActiveRace then
                utils.displayMessage("You exited the staging zone", 4)
                utils.setActiveLight(raceName, "red")
            end
        end
    elseif triggerType == "start" then
        if event == "enter" and mActiveRace == raceName and not utils.hasFinishTrigger(raceName) then
            if not currCheckpoint or checkpointsHit ~= totalCheckpoints then
                -- Player hasn't completed all checkpoints yet
                if not invalidLap then
                    utils.displayMessage("You have not completed all checkpoints!", 5)
                    return
                end
            end
            checkpointManager.setRace(races[raceName], raceName)
            activeAssets.displayAssets(data, Assets)
            utils.playCheckpointSound()
            timerActive = false
            lapCount = lapCount + 1
            local reward = payoutRace()
            currCheckpoint = nil
            mSplitTimes = {}
            mActiveRace = raceName
            checkpointManager.setAltRoute(false)
            mAltRoute = false
            in_race_time = 0
            timerActive = true
            checkpointsHit = 0
            totalCheckpoints = checkpointManager.calculateTotalCheckpoints()
            currentExpectedCheckpoint = 0
            if races[raceName].hotlap then
                mHotlap = raceName
                currentExpectedCheckpoint = checkpointManager.enableCheckpoint(0)
            end
            invalidLap = false
        elseif event == "enter" and staged == raceName then
            -- Start the race
            utils.saveAndSetTrafficAmount(0)
            checkpointManager.setRace(races[raceName], raceName)
            activeAssets.displayAssets(data, Assets)
            timerActive = true
            in_race_time = 0
            mActiveRace = raceName
            lapCount = 0

            utils.displayStartMessage(raceName)
            utils.setActiveLight(raceName, "green")

            -- Handle drift races
            if utils.tableContains(races[raceName].type, "drift") then
                gameplay_drift_general.setContext("inChallenge")
                if gameplay_drift_drift then
                    gameplay_drift_drift.setVehId(data.subjectID)
                end
            end

            -- Initialize checkpoints if applicable
            if races[raceName].checkpointRoad then
                -- Clear existing nodes and checkpoints
                processRoad.reset()
                local checkpoints, altCheckpoints = processRoad.getCheckpoints(races[raceName])

                checkpointManager.createCheckpoints(checkpoints, altCheckpoints)

                isLoop = processRoad.isLoop()
                currCheckpoint = 0
                checkpointsHit = 0
                totalCheckpoints = checkpointManager.calculateTotalCheckpoints(races[raceName])
                currentExpectedCheckpoint = 1
                mAltRoute = false -- Initialize alt route flag
                checkpointManager.setAltRoute(mAltRoute)

                currentExpectedCheckpoint = checkpointManager.enableCheckpoint(0)
            end
        else
            -- Player is not staged or race is not active
            utils.setActiveLight(raceName, "red")
        end
    elseif triggerType == "checkpoint" and checkpointIndex then
        if event == "enter" and mActiveRace == raceName then
            -- Ensure that the checkpoint is the expected one
            if (checkpointIndex == currentExpectedCheckpoint) or (checkpointIndex == 1 and isAlt) or
                (currentExpectedCheckpoint == races[raceName].altRoute.mergeCheckpoints[1] and isAlt) then
                checkpointsHit = checkpointsHit + 1
                currCheckpoint = checkpointIndex
                mSplitTimes[checkpointsHit] = in_race_time
                utils.playCheckpointSound()

                -- Prepare the next checkpoint
                if isAlt then
                    currentExpectedCheckpoint = checkpointIndex
                end

                currentExpectedCheckpoint = checkpointManager.enableCheckpoint(checkpointIndex, isAlt)
                if isAlt and not mAltRoute then
                    mAltRoute = true
                    checkpointManager.setAltRoute(true)
                    totalCheckpoints = checkpointManager.calculateTotalCheckpoints(races[raceName])
                end

                -- Display checkpoint message
                local checkpointMessage = ""
                local splitDiff = getDifference(raceName, checkpointsHit)
                if splitDiff then
                    local totalDiff = nil
                    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(raceName)
                    if mAltRoute then
                        if mHotlap == raceName then
                            totalDiff = in_race_time -
                                (leaderboardEntry.altRoute and
                                    leaderboardEntry.altRoute.hotlapSplitTimes[checkpointsHit] or 0)
                        else
                            totalDiff = in_race_time -
                                (leaderboardEntry.altRoute and
                                    leaderboardEntry.altRoute.splitTimes[checkpointsHit] or 0)
                        end
                    else
                        if mHotlap == raceName then
                            totalDiff = in_race_time - (leaderboardEntry.hotlapSplitTimes[checkpointsHit] or 0)
                        else
                            totalDiff = in_race_time - (leaderboardEntry.splitTimes[checkpointsHit] or 0)
                        end
                    end

                    checkpointMessage = string.format("Checkpoint %d/%d - Time: %s\nSplit: %s | Total: %s",
                        checkpointsHit, totalCheckpoints, utils.formatTime(in_race_time), formatSplitDifference(splitDiff),
                        formatSplitDifference(totalDiff))
                else
                    checkpointMessage = string.format("Checkpoint %d/%d - Time: %s", checkpointsHit, totalCheckpoints,
                        utils.formatTime(in_race_time))
                end
                utils.displayMessage(checkpointMessage, 7)
                activeAssets.displayAssets(data)
            else
                local missedCheckpoints = checkpointIndex - currentExpectedCheckpoint
                if missedCheckpoints > 0 then
                    -- Mark lap as invalid but continue with correct checkpoints
                    invalidLap = true

                    -- Update current checkpoint and hit count
                    currCheckpoint = checkpointIndex
                    currentExpectedCheckpoint = currentExpectedCheckpoint + missedCheckpoints
                    checkpointsHit = math.min(checkpointsHit + missedCheckpoints + 1, totalCheckpoints)

                    -- Enable next checkpoint
                    currentExpectedCheckpoint = checkpointManager.enableCheckpoint(checkpointIndex, isAlt)

                    -- Display message about invalid lap but continuing
                    local message = string.format("Missed a checkpoint\nLap Invalidated.", checkpointIndex)
                    local checkpointMessage = string.format("Checkpoint %d/%d - Time: %s", checkpointsHit,
                        totalCheckpoints, utils.formatTime(in_race_time))
                    message = message .. "\n" .. checkpointMessage
                    utils.displayMessage(message, 10)
                end
            end
        end

    elseif triggerType == "finish" then
        if event == "enter" and mActiveRace == raceName then
            -- Finish the race
            timerActive = false
            currCheckpoint = nil
            payoutRace()
            Assets:hideAllAssets()

            if raceName == "drag" then
                -- For drag races, update the display
                local side = "l" -- Determine side based on context if necessary
                utils.updateDisplay(side, in_race_time, math.abs(be:getObjectVelocityXYZ(data.subjectID)) * speedUnit)
            end
            if utils.tableContains(races[raceName].type, "drift") then
                local finalScore = getDriftScore()
                if gameplay_drift_general.getContext() == "inChallenge" then
                    gameplay_drift_general.setContext("inFreeRoam")
                    -- print("Final Drift Score: " .. tostring(math.floor(finalScore)), 1, "info")
                end
            end

            mSplitTimes = {}
            mActiveRace = nil
            utils.setActiveLight(raceName, "red")
            utils.restoreTrafficAmount()
        end
    else
        -- print("Unknown trigger type: " .. triggerType)
    end
end

local function onWorldReadyState(state)
    if state == 2 then
        races = utils.loadRaceData()
    end
end

local function onInit()
    print("Initializing Freeroam Events Main")
    if getCurrentLevelIdentifier() then
        races = utils.loadRaceData()
        if races ~= {} then
            print("Race data loaded for level: " .. getCurrentLevelIdentifier())
        else
            print("No race data found for level: " .. getCurrentLevelIdentifier())
        end
    end
end

local function onUpdate(dtReal, dtSim, dtRaw)

    -- This function updates the race time.
    -- It increments the in_race_time if the timer is active.
    --
    -- Parameters:
    --   dtReal (number): Real delta time.
    --   dtSim (number): Simulated delta time.
    --   dtRaw (number): Raw delta time.
    if mActiveRace and races[mActiveRace].checkpointRoad then
        if processRoad.checkPlayerOnRoad() == false then
            exitRace()
        end
    end
    if timerActive == true then
        in_race_time = in_race_time + dtSim
    else
        in_race_time = 0
    end
end

M.onBeamNGTrigger = onBeamNGTrigger
M.onUpdate = onUpdate

M.payoutRace = payoutRace
M.payoutDragRace = payoutDragRace
M.onWorldReadyState = onWorldReadyState
M.getRace = function(raceName) return races[raceName] end

M.onInit = onInit

return M