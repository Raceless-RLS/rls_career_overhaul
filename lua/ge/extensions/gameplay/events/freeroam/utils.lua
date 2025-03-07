local M = {}

local leaderboardManager = require('gameplay/events/freeroam/leaderboardManager')

local previousTrafficAmount = nil

local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}

local races = {}

local checkpointSoundPath = 'art/sound/ui_checkpoint.ogg'

-- Function to play the checkpoint sound
local function playCheckpointSound()
    Engine.Audio.playOnce('AudioGui', checkpointSoundPath, {
        volume = 2
    })
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

local function displayMessage(message, duration)
    ui_message(message, duration, "info", "info")
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


local function hasFinishTrigger(race)
    return scenetree.findObject("fre_finish_" .. race) ~= nil
end

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
        local settingsAmount = settings.getValue('trafficAmount') == 0 and getMaxVehicleAmount() or
                                   settings.getValue('trafficAmount')
        local trafficAmount = settingsAmount or previousTrafficAmount
        local pooledAmount = settings.getValue('trafficExtraAmount') or 0
        gameplay_traffic.setActiveAmount(trafficAmount + pooledAmount, trafficAmount)
    end
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

local function tableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
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
    z = z
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
    local race = races[raceName]
    local goalTime = race.bestTime
    local goalDrift = race.driftGoal
    local timeFactor = (goalTime / time) ^ 1.2
    local driftFactor = (driftScore / goalDrift) ^ 1.2
    return race.reward * timeFactor * driftFactor
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

local function displayStartMessage(raceName)
    local race = races[raceName]
    local message

    if math.random() < 0.5 then
        message = "GO!"
    else
        message = motivationalMessages[math.random(#motivationalMessages)]
    end

    message = string.format("**%s Event Started!\n%s**", race.label, message)
    displayMessage(message, 5)
end

local function getRaceLabel(raceName, altRoute, hotlap)
    local race = races[raceName]
    local raceLabel = race.label

    if altRoute then
        raceLabel = race.altRoute.label
    end
    if hotlap then
        raceLabel = raceLabel .. " (Hotlap)"
    end
    return raceLabel
end

local function displayStagedMessage(vehId, raceName, getMessage)
    if career_career.isActive() then
        vehId = career_modules_inventory.getInventoryIdFromVehicleId(vehId) or vehId
    end
    local race = races[raceName]
    local leaderboardEntry = leaderboardManager.getLeaderboardEntry(vehId, getRaceLabel(raceName)) or {}
    local careerMode = career_career.isActive()

    local message = ""
    if not getMessage then
        message = string.format("Staged for %s.\n", race.label)
    end

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
                return string.format(
                    "%sYour Best Time: %s | Target Time: %s\n(Achieve target to earn a reward of $%.2f and 1 Bonus Star)",
                    label, formatTime(bestTime), formatTime(targetTime), reward)
            else
                return string.format("%sYour Best Time: %s | Target Time: %s", label, formatTime(bestTime),
                    formatTime(targetTime))
            end
        else
            if careerMode then
                local potentialReward = raceReward(targetTime, reward, bestTime)
                return string.format("%sYour Best Time: %s\n(Improve to earn at least $%.2f)", label,
                    formatTime(bestTime), potentialReward)
            else
                return string.format("%sYour Best Time: %s", label, formatTime(bestTime))
            end
        end
    end

    if race.driftGoal then
        -- Handle drift event staging message
        local bestScore = leaderboardEntry.driftScore
        local bestTime = leaderboardEntry.time
        local targetScore = race.driftGoal
        local targetTime = race.driftTargetTime or race.bestTime

        if bestScore and bestTime then
            -- Show player's best score and time
            if careerMode then
                message = message .. string.format(
                    "Your Best Drift Score: %d | Target Drift Score: %d\nYour Best Time: %s | Target Time: %s\n(Achieve targets to earn a reward of $%.2f and 1 Bonus Star)",
                    bestScore, targetScore, formatTime(bestTime), formatTime(targetTime), race.reward)
            else
                message = message ..
                              string.format(
                        "Your Best Drift Score: %d | Target Drift Score: %d\nYour Best Time: %s | Target Time: %s",
                        bestScore, targetScore, formatTime(bestTime), formatTime(targetTime))
            end
        else
            -- No previous best score/time
            if careerMode then
                message = message ..
                              string.format(
                        "Target Drift Score: %d\nTarget Time: %s\n(Achieve these to earn a reward of $%.2f and 1 Bonus Star)",
                        targetScore, formatTime(targetTime), race.reward)
            else
                message = message ..
                              string.format("Target Drift Score: %d\nTarget Time: %s", targetScore,
                        formatTime(targetTime))
            end
        end
    else
        message = message .. addTimeInfo(leaderboardEntry and leaderboardEntry.time or nil, race.bestTime, race.reward, "")
    end

    -- Handle hotlap if it exists
    if race.hotlap then
        leaderboardEntry = leaderboardManager.getLeaderboardEntry(vehId, getRaceLabel(raceName, nil, true))
        message = message .. "\n\n" ..
                      addTimeInfo(leaderboardEntry and leaderboardEntry.time or nil, race.hotlap, race.reward, "Hotlap: ")
    end

    -- Handle alternative route if it exists
    if race.altRoute then
        leaderboardEntry = leaderboardManager.getLeaderboardEntry(vehId, getRaceLabel(raceName, true))
        message = message .. "\n\nAlternative Route:\n"
        message = message ..
                      addTimeInfo(leaderboardEntry and leaderboardEntry.time or nil, race.altRoute.bestTime,
                race.altRoute.reward, "")

        if race.altRoute.hotlap then
            leaderboardEntry = leaderboardManager.getLeaderboardEntry(vehId, getRaceLabel(raceName, true, true))
            message = message .. "\n\n" ..
                          addTimeInfo(leaderboardEntry and leaderboardEntry.time or nil, race.altRoute.hotlap,
                    race.altRoute.reward, "Alt Route Hotlap: ")
        end
    end

    -- Add note for time-based events in career mode
    if careerMode and not race.driftGoal then
        message = message .. "\n\n**Note: All rewards are cut by 50% if they are below your best time.**"
    end

    if not getMessage then
        displayMessage(message, 15)
        return
    end
    return message
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

local playerInPursuit = false

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

local function loadRaceData()
    if getCurrentLevelIdentifier() then
        local level = "levels/" .. getCurrentLevelIdentifier() .. "/race_data.json"
        local raceData = jsonReadFile(level)
        if raceData then
            races = raceData.races or {}
        end
        return deepcopy(races)  
    end
    return {}
end

local function onInit()
    if getCurrentLevelIdentifier() then
        loadRaceData()
    end
    print("Initializing Freeroam Utils and Extensions")
end

M.onPursuitAction = onPursuitAction
M.playCheckpointSound = playCheckpointSound
M.displayStartMessage = displayStartMessage
M.displayStagedMessage = displayStagedMessage
M.displayMessage = displayMessage
M.formatTime = formatTime
M.raceReward = raceReward
M.driftReward = driftReward
M.saveAndSetTrafficAmount = saveAndSetTrafficAmount
M.restoreTrafficAmount = restoreTrafficAmount
M.tableContains = tableContains
M.hasFinishTrigger = hasFinishTrigger
M.setActiveLight = setActiveLight
M.loadRaceData = loadRaceData
M.onInit = onInit

M.isPlayerInPursuit = function() return playerInPursuit end

return M