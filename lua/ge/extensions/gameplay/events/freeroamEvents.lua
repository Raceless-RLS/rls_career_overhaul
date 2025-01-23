-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {}

local processRoad = require('gameplay/events/freeroam/processRoad')
local leaderboardManager = require('gameplay/events/freeroam/leaderboardManager')
local activeAssets = require('gameplay/events/freeroam/activeAssets')

local Assets = activeAssets.ActiveAssets.new()

local checkpointSoundPath = 'art/sound/ui_checkpoint.ogg'

-- Function to play the checkpoint sound
local function playCheckpointSound()
    Engine.Audio.playOnce('AudioGui', checkpointSoundPath, {
        volume = 2
    })
end

local debug = nil

-- This is used to track if the timer is active
local timerActive = false

-- This is used to track the active race
local mActiveRace

-- This is used to track if the race is staged
local staged = nil

-- This is used to track the time in the race
local in_race_time = 0

local playerInPursuit = false

local speedUnit = 2.788942922
local speedThreshold = 5
local lapCount = 0
local currCheckpoint = nil
local mHotlap = nil
local mAltRoute = nil
local mSplitTimes = {}
local mBestSplitTime = {}
local isLoop = false
local activeMarkers = {}
local checkpointsHit = 0
local totalCheckpoints = 0
local currentExpectedCheckpoint = 1
local invalidLap = false

local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}

local checkpoints = {}
local altCheckpoints = {}

-- This table stores the best time and reward for each race.
-- The best time is the ideal time for the race.
-- The reward is the potential reward for the race.
-- The label is the name of the race.
local races = nil

-- Function to check if career mode is active
local function isCareerModeActive()
    return career_career.isActive()
end

local previousTrafficAmount = nil

local function saveAndSetTrafficAmount(amount)
    if gameplay_traffic then
        previousTrafficAmount = gameplay_traffic.getNumOfTraffic()
        gameplay_traffic.setActiveAmount(amount or 0)
    else
        print("Warning: gameplay_traffic not available")
    end
end

local function restoreTrafficAmount()
    if gameplay_traffic then
        local settingsAmount = settings.getValue('trafficAmount') == 0 and getMaxVehicleAmount(10) or settings.getValue('trafficAmount')
        local trafficAmount = settingsAmount or previousTrafficAmount
        local pooledAmount = settings.getValue('trafficExtraAmount') or 0
        gameplay_traffic.setActiveAmount(trafficAmount + pooledAmount, trafficAmount)
    end
end

local function updateDisplay(side, finishTime, finishSpeed)
    local timeDisplayValue = {}
    local speedDisplayValue = {}
    local timeDigits = {}
    local speedDigits = {}

    if side == "r" then
        timeDigits = rightTimeDigits
        speedDigits = rightSpeedDigits
    elseif side == "l" then
        timeDigits = leftTimeDigits
        speedDigits = leftSpeedDigits
    end

    if finishTime < 10 then
        table.insert(timeDisplayValue, "empty")
    end

    if finishSpeed < 100 then
        table.insert(speedDisplayValue, "empty")
    end

    -- Three decimal points for time
    for num in string.gmatch(string.format("%.3f", finishTime), "%d") do
        table.insert(timeDisplayValue, num)
    end

    -- Two decimal points for speed
    for num in string.gmatch(string.format("%.2f", finishSpeed), "%d") do
        table.insert(speedDisplayValue, num)
    end

    if #timeDisplayValue > 0 and #timeDisplayValue < 6 then
        for i, v in ipairs(timeDisplayValue) do
            timeDigits[i]:preApply()
            timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_" .. v .. ".dae")
            timeDigits[i]:setHidden(false)
            timeDigits[i]:postApply()
        end
    end

    for i, v in ipairs(speedDisplayValue) do
        speedDigits[i]:preApply()
        speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_" .. v .. ".dae")
        speedDigits[i]:setHidden(false)
        speedDigits[i]:postApply()
    end
end

local function clearDisplay(digits)
    for i = 1, #digits do
        digits[i]:setHidden(true)
    end
end

local function resetDisplays()
    clearDisplay(leftTimeDigits)
    clearDisplay(rightTimeDigits)
    clearDisplay(leftSpeedDigits)
    clearDisplay(rightSpeedDigits)
end

local function initDisplays()
    -- Creating a table for the TStatics that are being used to display drag time and final speed

    if #leftTimeDigits > 0 or #rightTimeDigits > 0 or #leftSpeedDigits > 0 or #rightSpeedDigits > 0 then
        return
    end

    for i = 1, 5 do
        local leftTimeDigit = scenetree.findObject("display_time_" .. i .. "_l")
        table.insert(leftTimeDigits, leftTimeDigit)

        local rightTimeDigit = scenetree.findObject("display_time_" .. i .. "_r")
        table.insert(rightTimeDigits, rightTimeDigit)

        local rightSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_r")
        table.insert(rightSpeedDigits, rightSpeedDigit)

        local leftSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_l")
        table.insert(leftSpeedDigits, leftSpeedDigit)
    end
    resetDisplays()
end

local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

local function formatTime(seconds)
    local sign = seconds < 0 and "-" or ""
    seconds = math.abs(seconds)

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    local wholeSeconds = math.floor(remainingSeconds)
    local hundredths = math.floor((remainingSeconds - wholeSeconds) * 100)

    return string.format("%s%02d:%02d:%02d", sign, minutes, wholeSeconds, hundredths)
end

local function displayMessage(message, duration)
    ui_message(message, duration, "info", "info")
end

local function setActiveLight(event, color)
    local yellow = scenetree.findObject(event .. "_Yellow")
    local red = scenetree.findObject(event .. "_Red")
    local green = scenetree.findObject(event .. "_Green")
    if yellow then
        yellow:setHidden(color ~= "yellow")
    end
    if red then
        red:setHidden(color ~= "red")
    end
    if green then
        green:setHidden(color ~= "green")
    end

end

local function raceReward(goal, reward, time)
    -- The raceReward function calculates the reward based on the time taken to complete the race.
    -- If the actual time is greater than the ideal time, the reward (y) is reduced proportionally.
    -- If the actual time is less than or equal to the ideal time, the reward (y) is increased exponentially.
    --
    -- Parameters:
    --   x (number): Ideal time for the race.
    --   y (number): Base reward for the race.
    --   z (number, optional): Actual time taken to complete the race. Defaults to in_race_time.
    --
    -- Returns:
    --   number: Calculated reward based on the time taken.
    local x = goal
    local y = reward
    local z = time
    z = z or in_race_time
    if z == 0 then
        return 0
    end
    local ratio = x / z
    if ratio < 1 then
        local reward = math.floor(ratio * y * 100) / 100
        return reward
    else
        local reward = math.floor((math.pow(ratio, (1 + (y / 500)))) * y * 100) / 100
        if reward > y * 30 then
            return y * 30
        end
        return reward
    end
end

local function driftReward(raceName, time, driftScore)
    local goalTime = races[raceName].bestTime
    local goalDrift = races[raceName].driftGoal
    local timeFactor = (goalTime / time) ^ 1.2
    local driftFactor = (driftScore / goalDrift) ^ 1.2
    return races[raceName].reward * timeFactor * driftFactor
end

local function printTable(t, indent)
    -- This function prints all parts of a table with labels.
    -- It recursively prints nested tables with indentation.
    --
    -- Parameters:
    --   t (table): The table to print.
    --   indent (number, optional): The current level of indentation. Defaults to 0.
    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    for k, v in pairs(t) do
        if type(v) == "table" then
            --print(indentStr .. tostring(k) .. ":")
            printTable(v, indent + 1)
        else
            --print(indentStr .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

local function onPursuitAction(id, pursuitData)
    local playerVehicleId = be:getPlayerVehicleID(0)

    if id == playerVehicleId then
        if pursuitData.type == "start" then
            playerInPursuit = true
        elseif pursuitData.type == "evade" or pursuitData.type == "reset" then
            playerInPursuit = false
        elseif pursuitData.type == "arrest" then
            playerInPursuit = false
        end
    end
end

local function getActivityName(data)
    -- This helper function extracts the race name from the trigger's data.
    -- It expects the triggerName to follow the format "raceName_type".
    -- If the extracted race name is not found in the 'races' table,
    -- it defaults to "testTrack".
    --
    -- Parameters:
    --   data (table): The data containing the triggerName.
    --
    -- Returns:
    --   string: The race name if found in the 'races' table, otherwise "testTrack".
    local triggerName = data.triggerName
    if triggerName:match("^fre_") then
        triggerName = triggerName:sub(5)
    end
    local triggerType, raceName, index = triggerName:match("([^_]+)_([^_]+)_?(%d*)")
    return raceName
end

local function getActivityType(data)
    -- This helper function extracts the activity type from the trigger's data.
    -- It expects the triggerName to follow the format "raceName_type".
    -- If the extracted activity type is not found, it returns nil.
    --
    -- Parameters:
    --   data (table): The data containing the triggerName.
    --
    -- Returns:
    --   string: The activity type if found, otherwise nil.
    local activityType = data.triggerName:match("_[^_]+$")
    if activityType then
        activityType = activityType:sub(2) -- Remove the leading underscore
    end
    return activityType
end

local function driftCompletionMessage(oldScore, oldTime, driftScore, finishTime, reward, xp, data)
    local raceName = getActivityName(data)
    local raceData = races[raceName]
    local raceLabel = raceData.label

    -- Calculate rewards based on old and new performances
    local oldReward = 0
    if oldScore and oldTime then
        oldReward = driftReward(raceName, oldTime, oldScore)
    end
    local newReward = driftReward(raceName, finishTime, driftScore)

    -- Determine if this is a new best based on the reward
    local newBest = newReward > (oldReward or 0)

    local newBestMessage = newBest and "Congratulations! New Best Drift!\n" or ""

    local currentScoreTimeMessage = string.format("Drift Score: %d\nTime: %s", driftScore, formatTime(finishTime))

    local previousScoreTimeMessage = ""
    if oldScore and oldTime then
        previousScoreTimeMessage = string.format("Previous Best Score: %d\nPrevious Best Time: %s", oldScore,
            formatTime(oldTime))
    end

    local rewardMessage = string.format("XP: %d | Reward: $%.2f", xp, reward)
    if not newBest and oldReward > 0 then
        rewardMessage = rewardMessage .. "\n(Note: Reward reduced due to lower performance)"
    end

    local message = newBestMessage .. raceLabel .. "\n" .. currentScoreTimeMessage
    if previousScoreTimeMessage ~= "" then
        message = message .. "\n" .. previousScoreTimeMessage
    end
    message = message .. "\n" .. rewardMessage

    return message
end

local function raceCompletionMessage(newBestTime, oldTime, reward, xp, data)
    local raceName = getActivityName(data)
    local newBestTimeMessage = newBestTime and not invalidLap and "Congratulations! New Best Time!\n" or ""
    local raceLabel = races[raceName].label
    if mAltRoute then
        raceLabel = raceLabel .. " (Alternative Route)"
    end
    if mHotlap == raceName then
        raceLabel = raceLabel .. " (Hotlap)"
    end
    local timeMessage = string.format("New Time: %s\nOld Time: %s", formatTime(in_race_time), formatTime(oldTime))
    local rewardMessage = string.format("XP: %d | Reward: $%.2f", xp, reward)
    if races[raceName].hotlap then
        rewardMessage = rewardMessage .. string.format("\nLap Multiplier: %.2f", 1 + (lapCount - 1) / 10)
    end

    local message = newBestTimeMessage .. raceLabel .. "\n" .. timeMessage .. "\n" .. rewardMessage

    if races[raceName].displaySpeed then
        local speedMessage = string.format("Speed: %.2f Mph",
            math.abs(be:getObjectVelocityXYZ(data.subjectID) * speedUnit))
        message = message .. "\n" .. speedMessage
    end

    if races[raceName].hotlap then
        local hotlapMessage = "Hotlap Started\n"
        if mAltRoute then
            hotlapMessage = hotlapMessage .. string.format("Target: %s", formatTime(races[raceName].altRoute.hotlap))
        else
            hotlapMessage = hotlapMessage .. string.format("Target: %s", formatTime(races[raceName].hotlap))
        end
        message = message .. "\n" .. hotlapMessage
    end

    return message
end

local function rewardLabel(raceName, newBestTime)
    local raceLabel = races[raceName].label
    local timeLabel = formatTime(in_race_time)
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

local function payoutRace(data)
    -- This function handles the payout for a race.
    -- It calculates the reward based on the race's best time and the actual time taken.
    -- If the reward is greater than 0, it processes the payment and displays a message.
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    --
    -- Returns:
    --   number: The calculated reward for the race.
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if mActiveRace == nil then
        return 0
    end
    local raceName = getActivityName(data)
    if data.event == "enter" and raceName == mActiveRace then
    local msg = invalidLap and "Lap Invalidated\n" or ""
    mActiveRace = nil

        local time = races[raceName].bestTime
        local reward = races[raceName].reward 
        if mHotlap == raceName then
            time = races[raceName].hotlap
        end
        if mAltRoute then
            time = races[raceName].altRoute.bestTime
            reward = races[raceName].altRoute.reward
            if mHotlap == raceName then
                time = races[raceName].altRoute.hotlap
            end
        end

        local driftScore = 0
        if races[raceName].driftGoal then
        driftScore = getDriftScore()
            reward = driftReward(raceName, time, driftScore)
        else
            reward = raceReward(time, reward)
    end

        local leaderboardEntry = leaderboardManager.getLeaderboardEntry(raceName)
    if mAltRoute then
        leaderboardEntry = leaderboardEntry.altRoute
    end

    local oldTime = leaderboardEntry and leaderboardEntry.time or 0
    local oldScore = leaderboardEntry and leaderboardEntry.driftScore or 0

    local newEntry = {
            raceName = raceName,
        isAltRoute = mAltRoute,
            isHotlap = mHotlap == raceName,
        time = in_race_time,
        splitTimes = mSplitTimes,
        driftScore = driftScore
    }

    local newBest = leaderboardManager.addLeaderboardEntry(newEntry)

        if not newBest or invalidLap then
            reward = reward / 2
        end

    if not isCareerModeActive() then
        mActiveRace = nil
        local message = invalidLap and "Lap Invalidated\n" or ""
        if newBest and not invalidLap then
            message = message .. "New Best Time!\n"
        end
        
            if races[raceName].hotlap then
            message = message .. string.format("%s\nTime: %s\nLap: %d", 
                    races[raceName].label, 
                formatTime(in_race_time),
                lapCount
            )
        else
            message = message .. string.format("%s\nTime: %s", 
                    races[raceName].label, 
                formatTime(in_race_time)
            )
        end
        
        if newBest and not invalidLap and oldTime ~= math.huge then
            message = message .. string.format("\nPrevious Best: %s", formatTime(oldTime))
        end
        
        displayMessage(message, 10)
        return 0
    end
        if reward <= 0 then
            return 0
        end

        reward = invalidLap and 0 or reward
        lapCount = invalidLap and 1 or lapCount

        if races[raceName].hotlap then
            reward = reward * (1 + (lapCount - 1) / 10)
        end
        local xp = math.floor(reward / 20)
        local totalReward = {
            money = {
                amount = reward
            },
            beamXP = {
                amount = math.floor(xp / 10)
            },
            vouchers = {
                amount = (oldTime == 0 or oldTime > races[raceName].bestTime) and in_race_time <
                    races[raceName].bestTime and 1 or 0
            }
        }
        for _, type in ipairs(races[raceName].type) do
            totalReward[type] = {
                amount = xp
            }
        end
        local reason = {
            label = rewardLabel(raceName, newBest),
            tags = {"gameplay", "reward", "mission"}
        }
        --print("totalReward:")
        printTable(totalReward)
        career_modules_payment.reward(totalReward, reason)
    local message = invalidLap and "Lap Invalidated\n" or ""
        if races[raceName].driftGoal then
            message = message .. driftCompletionMessage(oldScore, oldTime, driftScore, in_race_time, reward, xp, data)
    else
            message = message .. raceCompletionMessage(newBest, oldTime, reward, xp, data)
    end
    ui_message(message, 20, "Reward")
    
    career_saveSystem.saveCurrent()
        return reward
    end
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

    if not isCareerModeActive() then
        local message = string.format("%s\nTime: %s\nSpeed: %.2f mph", races[raceName].label, formatTime(finishTime),
            finishSpeed)
        displayMessage(message, 10)
        return 0
    end
    
    -- Get race data
    local raceData = races[raceName]
    local targetTime = raceData.bestTime
    local baseReward = raceData.reward

    -- Calculate reward based on performance
    local reward = raceReward(targetTime, baseReward, finishTime)
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
        newBestTime and "Congratulations! New Best Time!" or "", raceData.label, formatTime(finishTime), finishSpeed,
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
    return string.format("%s%s", sign, formatTime(math.abs(diff)))
end

local motivationalMessages = { -- Enthusiastic
"Give it your all!", "Time to shine!", "Let's set a new record!", "It's go time!", -- Funny
"Try not to hit any trees this time!", "Remember, the brake is the other pedal!",
"First one to the finish line gets a cookie!", "Drive like you stole it... wait, you didn't, right?",

-- Passive-aggressive
"Try to keep it on the track this time, okay?", "Let's see if you've improved since last time...",
"Maybe today you'll actually finish the race?",
"I'm sure you'll do better than your last attempt. It can't get worse, right?", -- Encouraging
"Believe in yourself, you've got this!", "Today could be your personal best!",
"Focus and breathe, you're ready for this!", "Every second counts, make them all yours!", -- Challenging
"Think you can handle this? Prove it!", "Show us what you're really made of!",
"This track has beaten you before. Not today!", "Time to separate the rookies from the pros!", -- Quirky
"May the downforce be with you!", "Remember: turn left to go left, right to go right!",
"Gravity is just a suggestion, right?", "If in doubt, flat out! (Results may vary)", -- Intense
"Push it to the limit!", "Leave nothing on the table!", "Drive like your life depends on it!", "It's now or never!"}

local function getStartMessage(raceName)
    local activity = races[raceName]
    local message

    if math.random() < 0.5 then
        message = "GO!"
    else
        message = motivationalMessages[math.random(#motivationalMessages)]
    end

    return string.format("**%s Event Started!\n%s**", activity.label, message)
end

local function displayStagedMessage(raceName)
    local race = races[raceName]
    local times = leaderboardManager.getLeaderboardEntry(raceName) or {}
    local careerMode = isCareerModeActive()
    printTable(race)
    local message = string.format("Staged for %s.\n", race.label)

    local function addTimeInfo(bestTime, targetTime, reward, label)
        if not bestTime then
            if careerMode then
                return string.format("%sTarget Time: %s\n(Achieve this to earn a reward of $%.2f and 1 Bonus Star)", 
                    label, formatTime(targetTime), reward)
            else
                return string.format("%sTarget Time: %s", label, formatTime(targetTime))
            end
        elseif bestTime > targetTime then
            if careerMode then
                return string.format("%sYour Best Time: %s | Target Time: %s\n(Achieve target to earn a reward of $%.2f and 1 Bonus Star)",
                    label, formatTime(bestTime), formatTime(targetTime), reward)
            else
                return string.format("%sYour Best Time: %s | Target Time: %s",
                    label, formatTime(bestTime), formatTime(targetTime))
            end
        else
            if careerMode then
                local potentialReward = raceReward(targetTime, reward, bestTime)
                return string.format("%sYour Best Time: %s\n(Improve to earn at least $%.2f)", 
                    label, formatTime(bestTime), potentialReward)
            else
                return string.format("%sYour Best Time: %s", label, formatTime(bestTime))
            end
        end
    end

    if race.driftGoal then
        -- Handle drift event staging message
        local bestScore = times.driftScore
        local bestTime = times.driftTime
        local targetScore = race.driftGoal
        local targetTime = race.driftTargetTime or race.bestTime

        if bestScore and bestTime then
            -- Show player's best score and time
            if careerMode then
                message = message .. string.format(
                    "Your Best Drift Score: %d | Target Drift Score: %d\nYour Best Time: %s | Target Time: %s\n(Achieve targets to earn a reward of $%.2f and 1 Bonus Star)",
                    bestScore, targetScore, formatTime(bestTime), formatTime(targetTime), race.reward)
            else
                message = message .. string.format(
                    "Your Best Drift Score: %d | Target Drift Score: %d\nYour Best Time: %s | Target Time: %s",
                    bestScore, targetScore, formatTime(bestTime), formatTime(targetTime))
            end
        else
            -- No previous best score/time
            if careerMode then
                message = message .. string.format(
                    "Target Drift Score: %d\nTarget Time: %s\n(Achieve these to earn a reward of $%.2f and 1 Bonus Star)",
                    targetScore, formatTime(targetTime), race.reward)
            else
                message = message .. string.format(
                    "Target Drift Score: %d\nTarget Time: %s",
                    targetScore, formatTime(targetTime))
            end
        end
    else
        -- Handle normal time-based events
        if not times.bestTime then
            times.bestTime = nil
        end
        message = message .. addTimeInfo(times and times.bestTime or nil, race.bestTime, race.reward, "")
    end

    -- Handle hotlap if it exists
    if race.hotlap then
        if not times.hotlapTime then
            times.hotlapTime = nil
        end
        message = message .. "\n\n" .. addTimeInfo(times and times.hotlapTime or nil, race.hotlap, race.reward, "Hotlap: ")
    end

    -- Handle alternative route if it exists
    if race.altRoute then
        if not times.altRoute then
            times.altRoute = {}
        end
        message = message .. "\n\nAlternative Route:\n"
        message = message .. addTimeInfo(times and times.altRoute.bestTime or nil, race.altRoute.bestTime, race.altRoute.reward, "")

        if race.altRoute.hotlap then
            message = message .. "\n\n" ..
                          addTimeInfo(times and times.altRoute.hotlapTime or nil, race.altRoute.hotlap, race.altRoute.reward,
                    "Alt Route Hotlap: ")
        end
    end

    -- Add note for time-based events in career mode
    if careerMode and not race.driftGoal then
        message = message .. "\n\n**Note: All rewards are cut by 50% if they are below your best time.**"
    end

    displayMessage(message, 15)
end

local function createCheckpoint(index, isAlt)
    local checkpoint
    if isAlt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if not checkpoint then
        --print("Error: No checkpoint data found for index " .. index)
        return
    end

    if not checkpoint.width then
        checkpoint.width = 30
    end

    local position = vec3(checkpoint.pos.x, checkpoint.pos.y, checkpoint.pos.z)
    local radius = checkpoint.width / 2 -- Assuming width is diameter

    local triggerRadius = radius * 0.9 -- 90% of the marker radius for the trigger

    checkpoint.object = createObject('BeamNGTrigger')
    checkpoint.object:setPosition(position)
    checkpoint.object:setScale(vec3(triggerRadius, triggerRadius, triggerRadius))
    checkpoint.object.triggerType = 0 -- Use 0 for Sphere type

    -- Naming the trigger according to the new scheme
    local triggerName
    if isAlt then
        triggerName = string.format("fre_checkpoint_%s_alt_%d", mActiveRace, index)
    else
        triggerName = string.format("fre_checkpoint_%s_%d", mActiveRace, index)
    end
    checkpoint.object:registerObject(triggerName)

    --print("Checkpoint " .. index .. " created at: " .. tostring(position) .. " with radius: " .. radius)
    return checkpoint
end

local function createCheckpointMarker(index, alt)
    local checkpoint = alt and altCheckpoints[index] or checkpoints[index]
    if not checkpoint then
        --print("No checkpoint data for index " .. index)
        return
    end

    local marker = createObject('TSStatic')
    marker.shapeName = "art/shapes/interface/checkpoint_marker.dae"

    marker:setPosRot(checkpoint.pos.x, checkpoint.pos.y, checkpoint.pos.z, 0, 0, 0, 0)

    marker.scale = vec3(checkpoint.width / 2, checkpoint.width / 2, checkpoint.width)
    marker.useInstanceRenderData = true
    marker.instanceColor = ColorF(1, 0, 0, 0.5):asLinear4F() -- Default to red

    local markerName = (alt and "alt_" or "") .. "checkpoint_" .. index .. "_marker"
    marker:registerObject(markerName)

    checkpoint.marker = marker
    --print("Checkpoint marker " .. index .. " created at position: " .. tostring(position) .. " with width: " ..
    --          checkpoint.width)
    return checkpoint
end

local function removeCheckpointMarker(index, alt)
    local checkpoint = {}
    if alt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if checkpoint and checkpoint.marker then
        checkpoint.marker:delete()
        checkpoint.marker = nil
    end
    return checkpoint
end

local function removeCheckpoint(index, alt)
    local checkpoint = {}
    if alt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if checkpoint then
        if checkpoint.object then
            checkpoint.object:delete()
            checkpoint.object = nil
        end
        if checkpoint.marker then
            checkpoint.marker:delete()
            checkpoint.marker = nil
        end
        --print("Checkpoint " .. index .. " removed")
    end
    return checkpoint
end

local function createCheckpoints()
    for i = 1, #checkpoints do
        removeCheckpoint(i)
    end
    for i = 1, #checkpoints do
        --print("Creating checkpoint " .. i)
        createCheckpoint(i)
    end

    if altCheckpoints then
        for i = 1, #altCheckpoints do
            removeCheckpoint(i, true)
        end
        for i = 1, #altCheckpoints do
            createCheckpoint(i, true)
        end
    end
end

local function enableCheckpoint(checkpointIndex, alt)
    local ALT = {alt, alt}
    local index = {checkpointIndex, checkpointIndex + 1}
    if isLoop then
        index = {index[1] % #checkpoints + 1, index[2] % #checkpoints + 1}
    else
        index = {index[1] + 1, index[2] + 1}
    end
    for i = 1, 2 do
        if ALT[i] then
            if #altCheckpoints < index[i] then
                index[i] = races[mActiveRace].altRoute.mergeCheckpoints[2] + ((index[i] - 1) - #altCheckpoints)
                ALT[i] = false
            end
        end
    end
    currentExpectedCheckpoint = index[1]
    --print("Current expected checkpoint: " .. currentExpectedCheckpoint)
    --print("Index")
    --printTable(index)
    --print("ALT")
    --printTable(ALT)
    local checkpoint = {}
    if ALT[1] then
        checkpoint = altCheckpoints[index[1]]
    else
        checkpoint = checkpoints[index[1]]
    end
    local nextCheckpoint = nil
    local checkpointCount = ALT[2] and #altCheckpoints or #checkpoints
    if checkpointCount > 1 then
        if ALT[2] then
            nextCheckpoint = altCheckpoints[index[2]]
        else
            nextCheckpoint = checkpoints[index[2]]
        end
    end

    if checkpoint then
        if not checkpoint.marker then
            checkpoint = createCheckpointMarker(index[1], ALT[1])
        end
        if not ALT[1] then
            checkpoint.marker.instanceColor = ColorF(0, 1, 0, 0.7):asLinear4F() -- Green
        else
            checkpoint.marker.instanceColor = ColorF(0, 0, 1, 0.7):asLinear4F() -- Blue
        end

        if races[mActiveRace].altRoute and altCheckpoints and races[mActiveRace].altRoute.mergeCheckpoints[1] == index[1] then
            if not altCheckpoints[1].marker then
                local altCheckpoint = createCheckpointMarker(1, true)
                altCheckpoint.marker.instanceColor = ColorF(0, 0, 1, 0.7):asLinear4F() -- Blue
            end
        end

        if nextCheckpoint then
            if not nextCheckpoint.marker then
                nextCheckpoint = createCheckpointMarker(index[2], ALT[2])
            end
            nextCheckpoint.marker.instanceColor = ColorF(1, 0, 0, 0.5):asLinear4F() -- Red
        end
    end
end

local function removeCheckpoints()
    --print("Removing all checkpoints and markers")

    -- Function to remove checkpoints from a given list
    local function removeCheckpointList(checkpointList)
        if not checkpointList or #checkpointList == 0 then
            return
        end

        for i = 1, #checkpointList do
            local checkpoint = checkpointList[i]
            if checkpoint then
                -- Remove the checkpoint object
                if checkpoint.object then
                    checkpoint.object:delete()
                    checkpoint.object = nil
                end

                -- Remove the checkpoint marker
                if checkpoint.marker then
                    checkpoint.marker:delete()
                    checkpoint.marker = nil
                end
            end
        end

        -- Clear the checkpoint list
        for i = 1, #checkpointList do
            checkpointList[i] = nil
        end
    end

    -- Remove main checkpoints
    removeCheckpointList(checkpoints)

    -- Remove alternative checkpoints
    removeCheckpointList(altCheckpoints)

    -- Reset the checkpoint tables
    checkpoints = {}
    altCheckpoints = {}
    --print("All checkpoints and markers removed")
end

local function exitRace()
    if mActiveRace then
        setActiveLight(mActiveRace, "red")
        lapCount = 0
        mActiveRace = nil
        timerActive = false
        mAltRoute = nil
        mHotlap = nil
        currCheckpoint = nil
        mSplitTimes = {}
        Assets:hideAllAssets()
        removeCheckpoints()
        checkpoints = {}
        displayMessage("You exited the race zone, Race cancelled", 3)
        restoreTrafficAmount()
        if gameplay_drift_general.getContext() == "inChallenge" then
            gameplay_drift_general.setContext("inFreeRoam")
            gameplay_drift_general.reset()
        end
    end
end

local function exitCheckpoint(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if data.event == "enter" then
        exitRace()
    end
end

local function calculateTotalCheckpoints(race)
    local mainCount = #checkpoints
    local altCount = altCheckpoints and #altCheckpoints or 0
    local mergePoints = race.altRoute and race.altRoute.mergeCheckpoints or {0, 0}

    -- If the player is on the alt route, adjust total checkpoints accordingly
    local total
    if mAltRoute then
        total = altCount + (mainCount - mergePoints[2] + mergePoints[1])
    else
        total = mainCount
    end

    return total
end

local function hasFinishTrigger(race)
    return scenetree.findObject("fre_finish_" .. race) ~= nil
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
        --print("Trigger name doesn't match expected pattern.")
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
        if event == "enter" then
            if playerInPursuit then
                displayMessage("You cannot stage for an event while in a pursuit.", 2)
                return
            end

            local vehicleSpeed = math.abs(be:getObjectVelocityXYZ(data.subjectID)) * speedUnit
            if vehicleSpeed > 5 and mActiveRace then
                return
            end
            mHotlap = nil
            if vehicleSpeed > 5 then
                if races[raceName].runningStart then
                    displayMessage("Hotlap Staged", 2)
                    if races[raceName].hotlap then
                        mHotlap = raceName
                    end
                else
                    displayMessage("You are too fast to stage.\nPlease back up and slow down to stage.", 2)
                    staged = nil
                    return
                end
            end
            Assets:hideAllAssets()
            lapCount = 0


            -- Initialize displays if drag race
            if raceName == "drag" then
                initDisplays()
                resetDisplays()
            end

            -- Set staged race
            staged = raceName
            --print("Staged race: " .. raceName)
            displayStagedMessage(raceName)
            setActiveLight(raceName, "yellow")
        elseif event == "exit" then
            staged = nil
            if not mActiveRace then
                displayMessage("You exited the staging zone", 4)
                setActiveLight(raceName, "red")
            end
        end
    elseif triggerType == "start" then
        if event == "enter" and mActiveRace == raceName and not hasFinishTrigger(raceName) then
            if not currCheckpoint or checkpointsHit ~= totalCheckpoints then
                -- Player hasn't completed all checkpoints yet
                if not invalidLap then
                    displayMessage("You have not completed all checkpoints!", 5)
                    return
                end
            end
            activeAssets.displayAssets(data, Assets)
            playCheckpointSound()
            timerActive = false
            lapCount = lapCount + 1
            local reward = payoutRace(data)
            currCheckpoint = nil
            mSplitTimes = {}
            mActiveRace = raceName
            mAltRoute = nil
            in_race_time = 0
            timerActive = true
            checkpointsHit = 0
            totalCheckpoints = #checkpoints
            currentExpectedCheckpoint = 0
            if races[raceName].hotlap then
                mHotlap = raceName
            end
            invalidLap = false
        elseif event == "enter" and staged == raceName then
            -- Start the race
            saveAndSetTrafficAmount(0)
            activeAssets.displayAssets(data, Assets)
            timerActive = true
            in_race_time = 0
            mActiveRace = raceName
            lapCount = 0
            
            displayMessage(getStartMessage(raceName), 5)
            setActiveLight(raceName, "green")
            
            -- Handle drift races
            if tableContains(races[raceName].type, "drift") then
                gameplay_drift_general.setContext("inChallenge")
                if gameplay_drift_drift then
                    gameplay_drift_drift.setVehId(data.subjectID)
                end
            end

            -- Initialize checkpoints if applicable
            if races[raceName].checkpointRoad then
                -- Clear existing nodes and checkpoints
                processRoad.reset()
                checkpoints, altCheckpoints = processRoad.getCheckpoints(races[raceName])

                createCheckpoints()
                
                isLoop = processRoad.isLoop()
                currCheckpoint = 0
                checkpointsHit = 0
                totalCheckpoints = calculateTotalCheckpoints(races[raceName])
                currentExpectedCheckpoint = 1
                mAltRoute = false -- Initialize alt route flag
                
                enableCheckpoint(0)
            end
        else
            -- Player is not staged or race is not active
            setActiveLight(raceName, "red")
        end
    elseif triggerType == "checkpoint" and checkpointIndex then
        if event == "enter" and mActiveRace == raceName then
            -- Ensure that the checkpoint is the expected one
            if (checkpointIndex == currentExpectedCheckpoint) or (checkpointIndex == 1 and isAlt) or (currentExpectedCheckpoint == races[raceName].altRoute.mergeCheckpoints[1] and isAlt) then
                checkpointsHit = checkpointsHit + 1
                currCheckpoint = checkpointIndex
                mSplitTimes[checkpointsHit] = in_race_time
                playCheckpointSound()

                -- Prepare the next checkpoint
                if isAlt then
                    currentExpectedCheckpoint = checkpointIndex
                end

                enableCheckpoint(currentExpectedCheckpoint, isAlt)
                if isAlt and not mAltRoute then
                    mAltRoute = true
                    totalCheckpoints = calculateTotalCheckpoints(races[raceName])
                end

                -- Display checkpoint message
                local checkpointMessage = ""
                local splitDiff = getDifference(raceName, checkpointsHit)
                if splitDiff then
                    local totalDiff = nil
                    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(raceName)
                    if mAltRoute then
                        totalDiff = in_race_time - (leaderboardEntry.altRoute and leaderboardEntry.altRoute.splitTimes[checkpointsHit] or 0)
                    else
                        totalDiff = in_race_time - (leaderboardEntry.splitTimes[checkpointsHit] or 0)
                    end
                    
                    checkpointMessage = string.format("Checkpoint %d/%d - Time: %s\nSplit: %s | Total: %s", 
                        checkpointsHit,
                        totalCheckpoints, 
                        formatTime(in_race_time),
                        formatSplitDifference(splitDiff),
                        formatSplitDifference(totalDiff))
                else
                    checkpointMessage = string.format("Checkpoint %d/%d - Time: %s", 
                        checkpointsHit,
                        totalCheckpoints, 
                        formatTime(in_race_time))
                end
                displayMessage(checkpointMessage, 7)
                activeAssets.displayAssets(data)

                -- Remove the marker for this checkpoint
                removeCheckpointMarker(checkpointIndex, isAlt)
            else
                local missedCheckpoints = checkpointIndex - currentExpectedCheckpoint
                if missedCheckpoints > 0 then
                    -- Mark lap as invalid but continue with correct checkpoints
                    invalidLap = true
                    
                    -- Remove all existing checkpoint markers
                    for i = 1, #checkpoints do
                        removeCheckpointMarker(i, false)
                    end
                    if altCheckpoints then
                        for i = 1, #altCheckpoints do
                            removeCheckpointMarker(i, true)
                        end
                    end

                    -- Update current checkpoint and hit count
                    currCheckpoint = checkpointIndex
                    currentExpectedCheckpoint = currentExpectedCheckpoint + missedCheckpoints
                    checkpointsHit = math.min(checkpointsHit + missedCheckpoints + 1, totalCheckpoints)
                    
                    -- Enable next checkpoint
                    enableCheckpoint(currentExpectedCheckpoint, isAlt)
                    
                    -- Display message about invalid lap but continuing
                    local message = string.format("Missed a checkpoint\nLap Invalidated.", checkpointIndex)
                    local checkpointMessage = string.format("Checkpoint %d/%d - Time: %s", 
                    checkpointsHit,
                    totalCheckpoints, 
                    formatTime(in_race_time))
                    message = message .. "\n" .. checkpointMessage
                    displayMessage(message, 10)
                end
            end
        end
    
    elseif triggerType == "finish" then
        if event == "enter" and mActiveRace == raceName then
            -- Finish the race
            timerActive = false
            currCheckpoint = nil
            payoutRace(data)
            Assets:hideAllAssets()

            if raceName == "drag" then
                -- For drag races, update the display
                local side = "l" -- Determine side based on context if necessary
                updateDisplay(side, in_race_time, be:getObjectVelocityXYZ(data.subjectID) * speedUnit)
            end
            if tableContains(races[raceName].type, "drift") then
                local finalScore = getDriftScore()
                if gameplay_drift_general.getContext() == "inChallenge" then
                    gameplay_drift_general.setContext("inFreeRoam")
                    --print("Final Drift Score: " .. tostring(math.floor(finalScore)), 1, "info")
                end
            end

            mSplitTimes = {}
            mActiveRace = nil
            setActiveLight(raceName, "red")
            restoreTrafficAmount()
            --displayMessage("Race Finished!", 5)
        end
    else
        --print("Unknown trigger type: " .. triggerType)
    end
end

local function loadRaceData()
    local level = "levels/" .. getCurrentLevelIdentifier() .. "/race_data.json"
    local raceData = jsonReadFile(level)
    races = raceData.races or {}
    if races ~= {} then
        print("Race data loaded")
    else
        print("No race data found")
    end
end

local function onWorldReadyState(state)
    if state == 2 then
        loadRaceData()
    end
end

local function onInit()
    print("freeroamEvents onInit")
    if getCurrentLevelIdentifier() then
        loadRaceData()
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

M.displayMessage = displayMessage
M.onBeamNGTrigger = onBeamNGTrigger
M.createCheckpoints = createCheckpoints
M.createCheckpoint = createCheckpoint
M.removeCheckpoint = removeCheckpoint
M.onUpdate = onUpdate

M.payoutRace = payoutRace
M.raceReward = raceReward
M.isCareerModeActive = isCareerModeActive
M.exitCheckpoint = exitCheckpoint
M.saveAndSetTrafficAmount = saveAndSetTrafficAmount
M.restoreTrafficAmount = restoreTrafficAmount
M.onPursuitAction = onPursuitAction
M.displayStagedMessage = displayStagedMessage
M.payoutDragRace = payoutDragRace
M.getStartMessage = getStartMessage
M.onWorldReadyState = onWorldReadyState

M.onInit = onInit

return M
