-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {}

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
local leaderboardFile = 'career/leaderboard.json'
local leaderboard = {}
local mSplitTimes = {}
local mBestSplitTime = {}
local isLoop = false
local roadNodes = {}
local altRoadNodes = {}
local activeMarkers = {}
local checkpointsHit = 0
local totalCheckpoints = 0
local currentExpectedCheckpoint = 1
local invalidLap = false

local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}
local maxAssets = 6
local maxActiveAssets = 2
local ActiveAssets = {}
ActiveAssets.__index = ActiveAssets

local maxActiveAssets = 2

-- Constants for road nodes
local checkpoints = {}
local altCheckpoints = {}
local STRAIGHT_THRESHOLD = math.rad(10) -- Angle threshold for straight segments
local HAIRPIN_THRESHOLD = math.rad(120) -- Angle threshold for hairpin turns
local MIN_SEGMENT_LENGTH = 20 -- Minimum length for a segment in meters
local MAX_TURN_MERGE_ANGLE = math.rad(20) -- Maximum angle difference to merge turns
local MIN_CHECKPOINT_DISTANCE = 90 -- Minimum distance between checkpoints
local CURVATURE_WINDOW = 3 -- Number of nodes to consider on each side for curvature calculation
local MAX_MERGE_DISTANCE = 50
local END_SEARCH_RANGE = 0.2
local MIN_JUNCTION_DISTANCE = 10

-- Player off road constants
local MAX_DISTANCE_FROM_PATH = 10 -- meters
local ALERT_COOLDOWN = 3 -- seconds
local WRONG_DIRECTION_THRESHOLD = 0.5 -- cosine of angle
local lastAlertTime = 0
local currentNodeIndex = 1
local nextNodeIndex = 2
local lastVehiclePos = nil
local exitCountdown = 0
local exitCountdownStart = 5
local lastCountdownTime = 0

-- This table stores the best time and reward for each race.
-- The best time is the ideal time for the race.
-- The reward is the potential reward for the race.
-- The label is the name of the race.
local races = {
    drag = {
        bestTime = 11,
        reward = 1000,
        checkpoints = 2,
        label = "Drag Strip",
        displaySpeed = true,
        type = {"motorsport"}
    },
    roadOval = {
        bestTime = 25,
        reward = 500,
        hotlap = 22,
        checkpointRoad = "roadOval",
        label = "Paved Oval",
        type = {"motorsport"}
    },
    dirtOval = {
        bestTime = 25,
        reward = 500,
        hotlap = 22,
        checkpointRoad = "dirtOval",
        label = "Dirt Oval",
        type = {"motorsport"}
    },
    quarryCircuit = {
        bestTime = 30,
        reward = 1250,
        hotlap = 25,
        checkpointRoad = "quarryCircuit",
        label = "Quarry Circuit",
        type = {"motorsport"}
    },
    beachCircuit = {
        bestTime = 30,
        reward = 1500,
        hotlap = 25,
        checkpointRoad = "beachCircuit",
        label = "Beach Circuit",
        displaySpeed = true,
        type = {"motorsport"},
        minCheckpointDistance = 45
    },
    hotrolledDrift = {
        bestTime = 30,
        driftGoal = 3500,
        reward = 1500,
        checkpointRoad = "hotrolledDrift",
        label = "Hotrolled Drift",
        type = {"motorsport", "drift"}
    },
    redwoodDrift = {
        bestTime = 60,
        driftGoal = 6000,
        reward = 1500,
        checkpointRoad = "redwoodDrift",
        label = "Redwood Drift",
        type = {"motorsport", "drift"}
    },
    redwoodDriftR = {
        bestTime = 60,
        driftGoal = 6000,
        reward = 1500,
        checkpointRoad = "redwoodDriftR",
        label = "Redwood Drift Reverse",
        type = {"motorsport", "drift"}
    },
    raceTrackDrift = {
        bestTime = 60,
        hotlap = 45,
        driftGoal = 6000,
        reward = 1500,
        checkpointRoad = "raceTrackDrift",
        label = "Parking Lot Drift",
        type = {"motorsport", "drift"}
    },
    sealbrikDrift = {
        bestTime = 30,
        driftGoal = 4500,
        reward = 1500,
        checkpointRoad = "sealbrikDrift",
        label = "Sealbrik Drift",
        type = {"motorsport", "drift"}
    },
    islandTouge = {
        bestTime = 25,
        reward = 3000,
        driftGoal = 3500,
        checkpointRoad = "islandTouge",
        label = "Island Touge Drift",
        type = {"motorsport", "drift"}
    },
    dragHighway = {
        bestTime = 17,
        reward = 1700,
        checkpointRoad = "dragHighway",
        label = "No Prep Highway Drag",
        displaySpeed = true,
        type = {"motorsport"}
    },
    rockClimbS = {
        bestTime = 8,
        reward = 700,
        checkpointRoad = "rockClimbS",
        label = "Rock Crawl Short",
        type = {"motorsport", "crawl"}
    },
    rockClimbL = {
        bestTime = 12,
        reward = 1500,
        checkpointRoad = "rockClimbL",
        label = "Rock Crawl Long",
        type = {"motorsport", "crawl"}
    },
    mudDrag1 = {
        bestTime = 8,
        reward = 1500,
        checkpointRoad = "mudDrag1",
        label = "Mud Drag Easy",
        type = {"motorsport"}
    },
    mudDrag2 = {
        bestTime = 10,
        reward = 3000,
        checkpointRoad = "mudDrag2",
        label = "Mud Drag Hard",
        type = {"motorsport"}
    },
    koh1 = {
        bestTime = 120,
        reward = 2000,
        checkpointRoad = "koh1",
        label = "King of the Hammer 1",
        type = {"motorsport"}
    },
    koh2 = {
        bestTime = 180,
        reward = 3000,
        checkpointRoad = "koh2",
        label = "King of the Hammer 2",
        type = {"motorsport"}
    },
    rally1 = {
        bestTime = 70,
        reward = 2000,
        checkpointRoad = "rally1",
        label = "Rally Stage 1",
        type = {"motorsport"}
    },
    rally2 = {
        bestTime = 120,
        reward = 2500,
        checkpointRoad = "rally2",
        label = "Rally Stage 2",
        type = {"motorsport"}
    },
    rally3 = {
        bestTime = 185,
        reward = 3000,
        checkpointRoad = "rally3",
        label = "Rally Stage 3",
        apexOffset = 1,
        type = {"motorsport"}
    },
    rally4 = {
        bestTime = 90,
        reward = 2000,
        checkpointRoad = "rally4",
        label = "Rally Stage 4 - Final",
        type = {"motorsport"}
    },
    rubberBand = {
        bestTime = 60,
        reward = 2500,
        label = "Rubberband Ridge",
        checkpointRoad = "rubberBandMain",
        hotlap = 45,
        altRoute = {
            bestTime = 70,
            reward = 2500,
            label = "Rubberband Ridge Joker",
            checkpointRoad = "rubberBandJoker",
            mergeCheckpoints = {6, 7},
            hotlap = 50,
            altInfo = "**Continue Right at the fork for the joker lap."
        },
        type = {"motorsport"}
    },
    track = {
        bestTime = 140,
        reward = 2500,
        label = "Track",
        checkpointRoad = "trackloop",
        hotlap = 125,
        runningStart = true,
        altRoute = {
            bestTime = 110,
            reward = 2000,
            label = "Short Track",
            checkpointRoad = "trackalt",
            mergeCheckpoints = {1, 10},
            hotlap = 95,
            altInfo = "**Continue Left for Standard Track\nHair Pin Right for Short Track**"
        },
        type = {"motorsport", "apexRacing"}
    },
    dirtCircuit = {
        bestTime = 65,
        reward = 2000,
        checkpointRoad = "dirtloop",
        hotlap = 55,
        label = "Dirt Circuit",
        type = {"motorsport", "apexRacing"}
    },
    testTrack = {
        bestTime = 5.5,
        reward = 1000,
        label = "Test Track",
        type = {"motorsport"}
    }
}


local function onLeaderboardDataReceived(data)
    if data and type(data) == "table" then
        leaderboard = data
        print("[LeaderboardManager] Received leaderboard data")
    else
        print("[LeaderboardManager] Received invalid leaderboard data")
    end
end

local function onInit()
end

function ActiveAssets.new()
    local self = setmetatable({}, ActiveAssets)
    self.assets = {} -- Ensure this is always initialized as an empty table
    return self
end

function ActiveAssets:addAssetList(triggerName, newAssets)
    if not self.assets then
        self.assets = {} -- Reinitialize if it's somehow nil
    end
    -- Create a new asset list for this trigger
    local assetList = {
        triggerName = triggerName,
        assets = newAssets
    }

    -- Add the new asset list
    table.insert(self.assets, assetList)

    -- If we exceed maxActiveAssets, remove and hide the oldest asset list
    if #self.assets > maxActiveAssets then
        local oldestAssetList = table.remove(self.assets, 1)
        self:hideAssetList(oldestAssetList)
    end
end

function ActiveAssets:hideAssetList(assetList)
    if assetList and assetList.assets then
        for _, asset in ipairs(assetList.assets) do
            if asset then
                asset:setHidden(true)
            end
        end
    end
end

function ActiveAssets:hideAllAssets()
    if not self.assets then
        --print("Warning: self.assets is nil in hideAllAssets")
        self.assets = {} -- Reinitialize if it's nil
        return
    end
    for _, assetList in ipairs(self.assets) do
        self:hideAssetList(assetList)
    end
    self.assets = {}
end

function ActiveAssets:getOldestAssetList()
    if not self.assets or #self.assets == 0 then
        return nil
    end
    return self.assets[1]
end

-- Create an instance of ActiveAssets
local activeAssets = ActiveAssets.new()

-- Function to display assets
local function displayAssets(data)
    --print("displayAssets function called with triggerName: " .. tostring(data.triggerName))
    local triggerName = data.triggerName
    local newAssets = {}

    -- Unhide assets and add them to newAssets table
    for i = 0, maxAssets - 1 do
        local assetName = triggerName .. "asset" .. i
        --print("Searching for asset: " .. assetName)
        local asset = scenetree.findObject(assetName)
        if asset then
            --print("Asset found: " .. assetName)
            asset:setHidden(false)
            table.insert(newAssets, asset)
        else
            --print("Asset not found: " .. assetName)
            break -- Stop if an asset is not found
        end
    end

    -- If no assets were found, return early
    if #newAssets == 0 then
        --print("No assets found for triggerName: " .. triggerName)
        return
    end

    --print("Number of new assets found: " .. #newAssets)

    -- Add the new asset list to activeAssets
    --print("Attempting to add new asset list to activeAssets")
    activeAssets:addAssetList(triggerName, newAssets)

    -- If we have reached the maximum number of active asset lists,
    -- we might want to do something with the oldest one
    --print("Number of active asset lists: " .. #activeAssets.assets)
    if #activeAssets.assets == maxActiveAssets then
        --print("Maximum number of active asset lists reached")
        local oldestAssetList = activeAssets:getOldestAssetList()
        --print("Oldest asset list triggerName: " .. oldestAssetList.triggerName)
        -- Here you can add code to clear or update the display of the oldest asset list
        -- For example:
        -- clearAssetListDisplay(oldestAssetList)
    end

    --print("displayAssets function completed")
end

-- Function to check if career mode is active
local function isCareerModeActive()
    return career_career.isActive()
end

local function onLeaderboardDataReceived(data)
    if data and type(data) == "table" then
        leaderboard = data
        print("Received leaderboard data from server")
    else
        print("Received invalid leaderboard data from server")
    end
end

-- Function to read the leaderboard from the file
local function loadLeaderboard()
    if not isCareerModeActive() then
        return
    end
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    local file = savePath .. '/' .. leaderboardFile
    local file = io.open(file, "r")
    if file then
        local content = file:read("*a")
        leaderboard = jsonDecode(content) or {}
        file:close()
    else
        leaderboard = {} -- Initialize as empty if file does not exist
    end
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
        local trafficAmount = settings.getValue('trafficAmount') or previousTrafficAmount
        local pooledAmount = settings.getValue('trafficExtraAmount') or 0
        gameplay_traffic.setActiveAmount(trafficAmount + pooledAmount, trafficAmount)
    end
end

-- Function to save the leaderboard to the file in all autosave folders
local function saveLeaderboard()
    --[[
    if MPCoreNetwork and MPCoreNetwork.isMPSession() then
        print("[LeaderboardManager] In multiplayer session, saving leaderboard")
        local data = {
            playerID = MPCoreNetwork.getPlayerServerID(),
            data = leaderboard
        }
        TriggerServerEvent("saveLeaderboard", jsonEncode(data))
    else
        print("[LeaderboardManager] Not in multiplayer session")
        -- Your existing single player save code here
    end
    --]]

    if not isCareerModeActive() then
        return
    end
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    --print("saveSlot: " .. saveSlot)
    --print("savePath: " .. savePath)

    -- Extract the base path by removing the current autosave folder
    local basePath = savePath:match("(.*/)")

    -- Define the paths for all three autosave folders
    local autosavePaths = {basePath .. "autosave1/" .. leaderboardFile, basePath .. "autosave2/" .. leaderboardFile,
                           basePath .. "autosave3/" .. leaderboardFile}

    -- Save the leaderboard to each autosave folder
    for _, filePath in ipairs(autosavePaths) do
        local file = io.open(filePath, "w")
        if file then
            file:write(jsonEncode(leaderboard))
            file:close()
            --print("Saved leaderboard to: " .. filePath)
        else
            --print("Error: Unable to open leaderboard file for writing: " .. filePath)
        end
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

local function isNewBestTime(raceName, in_race_time)
    if not leaderboard[raceName] then
        return true
    end

    local currentBest
    if mAltRoute then
        if mHotlap == raceName then
            currentBest = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.hotlapTime
        else
            currentBest = leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.bestTime
        end
    else
        if mHotlap == raceName then
            currentBest = leaderboard[raceName].hotlapTime
        else
            currentBest = leaderboard[raceName].bestTime
        end
    end

    return not currentBest or in_race_time < currentBest
end

local function getOldTime(raceName)
    if not leaderboard[raceName] then
        return nil
    end

    if mAltRoute then
        if not leaderboard[raceName].altRoute then
            return nil
        end
        return mHotlap == raceName and leaderboard[raceName].altRoute.hotlapTime or
                   leaderboard[raceName].altRoute.bestTime
    else
        return mHotlap == raceName and leaderboard[raceName].hotlapTime or leaderboard[raceName].bestTime
    end
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

local function saveNewBestTime(raceName, driftScore)
    if not leaderboard[raceName] then
        leaderboard[raceName] = {}
    end

    if races[raceName].driftGoal then
        -- Save the driftScore into the leaderboard for drift events
        if not leaderboard[raceName].driftScore or driftScore > leaderboard[raceName].driftScore then
            leaderboard[raceName].driftScore = driftScore
            leaderboard[raceName].bestTime = in_race_time
            leaderboard[raceName].splitTimes = mSplitTimes
        end
    elseif mAltRoute then
        if not leaderboard[raceName].altRoute then
            leaderboard[raceName].altRoute = {}
        end

        if mHotlap == raceName then
            leaderboard[raceName].altRoute.hotlapTime = in_race_time
            leaderboard[raceName].altRoute.hotlapSplitTimes = mSplitTimes
        else
            leaderboard[raceName].altRoute.bestTime = in_race_time
            leaderboard[raceName].altRoute.splitTimes = mSplitTimes
        end
    else
        if mHotlap == raceName then
            leaderboard[raceName].hotlapTime = in_race_time
            leaderboard[raceName].hotlapSplitTimes = mSplitTimes
        else
            leaderboard[raceName].bestTime = in_race_time
            leaderboard[raceName].splitTimes = mSplitTimes
        end
    end
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

        -- Save the best time to the leaderboard
        loadLeaderboard()
        local oldTime = getOldTime(raceName) or 0
        local oldScore = leaderboard[raceName] and leaderboard[raceName].driftScore or 0
        local newBest = false
        if races[raceName].driftGoal then
            newBest = not leaderboard[raceName] or driftReward(raceName, in_race_time, driftScore) >
                          driftReward(raceName, oldTime, oldScore)
        else
            newBest = isNewBestTime(raceName, in_race_time)
        end

        if newBest and not invalidLap then
            saveNewBestTime(raceName, driftScore)
        else
            reward = reward / 2
        end
        saveLeaderboard()

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
            bonusStars = {
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
    loadLeaderboard()
    local oldTime = getOldTime(raceName) or math.huge
    local newBestTime = finishTime < oldTime

    -- Update leaderboard if new best time
    if newBestTime then
        leaderboard[raceName] = {
            bestTime = finishTime,
            bestSpeed = finishSpeed
        }
    end
    saveLeaderboard()

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
        bonusStars = {
            amount = newBestTime and 1 or 0
        }
    }
    -- Assuming 'type' is defined in raceData for categorizing XP
    for _, raceType in ipairs(raceData.type or {}) do
        totalReward[raceType] = {
            amount = xp
        }
    end

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
    if not leaderboard[raceName] then
        return nil
    end

    local splitTimes = {}
    if mAltRoute then
        if mHotlap == raceName then
            splitTimes = leaderboard[raceName].altRoute and leaderboard[raceName]["altRoute"].hotlapSplitTimes
        else
            splitTimes = leaderboard[raceName].altRoute and leaderboard[raceName]["altRoute"].splitTimes
        end
    else
        if mHotlap == raceName then
            splitTimes = leaderboard[raceName].hotlapSplitTimes
        else
            splitTimes = leaderboard[raceName].splitTimes
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

local function routeInfo(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if data.event == "enter" then
        local raceName = getActivityName(data)
        if races[raceName].altRoute and mActiveRace == raceName then
            displayMessage(races[raceName].altRoute.altInfo, 10)
            displayAssets(data)
        end
    end
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
    local times = leaderboard[raceName] or {}
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
        message = message .. addTimeInfo(times.bestTime, race.bestTime, race.reward, "")
    end

    -- Handle hotlap if it exists
    if race.hotlap then
        message = message .. "\n\n" .. addTimeInfo(times.hotlapTime, race.hotlap, race.reward, "Hotlap: ")
    end

    -- Handle alternative route if it exists
    if race.altRoute then
        if not times.altRoute then
            times.altRoute = {}
        end
        message = message .. "\n\nAlternative Route:\n"
        message = message .. addTimeInfo(times.altRoute.bestTime, race.altRoute.bestTime, race.altRoute.reward, "")

        if race.altRoute.hotlap then
            message = message .. "\n\n" ..
                          addTimeInfo(times.altRoute.hotlapTime, race.altRoute.hotlap, race.altRoute.reward,
                    "Alt Route Hotlap: ")
        end
    end

    -- Add note for time-based events in career mode
    if careerMode and not race.driftGoal then
        message = message .. "\n\n**Note: All rewards are cut by 50% if they are below your best time.**"
    end

    displayMessage(message, 15)
end

local function calculateAngle(node1, node2, node3)
    if not node1 or not node2 or not node3 then
        --print("Warning: Nil node encountered in calculateAngle")
        return 0, "straight"
    end
    local vec1 = {
        x = node2.x - node1.x,
        y = node2.y - node1.y
    }
    local vec2 = {
        x = node3.x - node2.x,
        y = node3.y - node2.y
    }
    local angle = math.atan2(vec2.y, vec2.x) - math.atan2(vec1.y, vec1.x)

    -- Normalize angle to be between -pi and pi
    if angle > math.pi then
        angle = angle - 2 * math.pi
    elseif angle < -math.pi then
        angle = angle + 2 * math.pi
    end

    local degrees = math.deg(angle)
    local direction = "straight"
    if degrees > 1 then
        direction = "left"
    elseif degrees < -1 then
        direction = "right"
    end

    return angle, direction, degrees
end

local function calculateDistance(node1, node2)
    if not node1 or not node2 then
        --print("Warning: Nil node encountered in calculateDistance")
        return 0
    end
    local dx, dy = node2.x - node1.x, node2.y - node1.y
    return math.sqrt(dx * dx + dy * dy)
end

local function hasFinishTrigger(race)
    return scenetree.findObject("fre_finish_" .. race) ~= nil
end


local function calculateCurvature(nodes, index)
    local sum = 0
    local count = 0
    for i = math.max(1, index - CURVATURE_WINDOW), math.min(#nodes - 2, index + CURVATURE_WINDOW) do
        sum = sum + math.abs(calculateAngle(nodes[i], nodes[i + 1], nodes[i + 2]))
        count = count + 1
    end
    return sum / count
end

local function findApex(nodes, startIndex, endIndex)
    local maxCurvature = 0
    local apexIndex = startIndex
    for i = startIndex, endIndex do
        local prevNode = nodes[math.max(1, i - 1)]
        local currNode = nodes[i]
        local nextNode = nodes[math.min(#nodes, i + 1)]
        local angle, _, _ = calculateAngle(prevNode, currNode, nextNode)
        local curvature = math.abs(angle)
        if curvature > maxCurvature then
            maxCurvature = curvature
            apexIndex = i
        end
    end
    local apexOffset = races[mActiveRace].apexOffset or 0
    apexIndex = nodes[apexIndex + apexOffset] and apexIndex + apexOffset or #nodes
    return apexIndex
end

local function processRoadNodes(mainNodes, altNodes)
    if not altNodes then
        altNodes = {}
    end
    --print("Starting processRoadNodes with " .. #mainNodes .. " main nodes and " .. (#altNodes or 0) .. " alt nodes")

    local function processRoute(nodes, isAlt)
        print("Processing route with " .. #nodes .. " nodes")
        local segments = {}
        local checkpoints = {}
        local currentSegment = {
            startIndex = 1,
            type = "straight",
            totalAngle = 0,
            length = 0,
            direction = nil
        }
        local startIndex = isAlt and 3 or 1 -- Start from the 3rd node for alternative route

        local function addCheckpoint(startIndex, endIndex, type, direction)
            local apexIndex = findApex(nodes, startIndex, endIndex)
            local roadWidth = 20
        
            -- Function to check if position already exists in checkpoints
            local function isDuplicatePosition(newPos)
                for _, checkpoint in ipairs(checkpoints) do
                    if checkpoint.pos.x == newPos.x and checkpoint.pos.y == newPos.y and checkpoint.pos.z == newPos.z then
                        --print("Duplicate checkpoint position found, skipping...")
                        return true
                    end
                end
                return false
            end
        
            -- Check for existing checkpoints with same direction
            if #checkpoints > 0 then
                local lastCheckpoint = checkpoints[#checkpoints]
                if lastCheckpoint.direction == direction then
                    local distance = calculateDistance(nodes[lastCheckpoint.index], nodes[apexIndex])
                    if distance < MIN_CHECKPOINT_DISTANCE then
                        if calculateCurvature(nodes, apexIndex) > calculateCurvature(nodes, lastCheckpoint.index) then
                            -- Check if new position is duplicate before updating
                            if not isDuplicatePosition(nodes[apexIndex]) then
                                checkpoints[#checkpoints] = {
                                    pos = nodes[apexIndex],
                                    type = type,
                                    index = apexIndex,
                                    direction = direction
                                }
                            end
                        end
                        return
                    end
                end
            end
        
            -- Check if new position is duplicate before inserting
            if not isDuplicatePosition(nodes[apexIndex]) then
                table.insert(checkpoints, {
                    pos = nodes[apexIndex],
                    type = type,
                    index = apexIndex,
                    direction = direction,
                    width = roadWidth
                })
                --print((isAlt and "Alt " or "") .. "Checkpoint added: Type: " .. type .. ", Index: " .. apexIndex ..
                --          ", Direction: " .. direction .. ", Width: " .. roadWidth)
            end
        end

        local function addStraightCheckpoints()
            if #checkpoints < 2 then return end
            
            local newCheckpoints = {}
            
            -- Function to insert checkpoint between two existing ones
            local function insertMiddleCheckpoint(cp1, cp2)
                -- Calculate the distance between checkpoints
                local distance = calculateDistance(cp1.pos, cp2.pos)
                
                if distance > 450 then
                    -- Find the middle node index
                    local middleIndex = math.floor((cp1.index + cp2.index) / 2)
                    
                    -- Create new checkpoint at middle position
                    table.insert(newCheckpoints, {
                        pos = nodes[middleIndex],
                        type = "straight",
                        index = middleIndex,
                        direction = "straight",
                        width = 20
                    })
                end
            end
            
            -- First pass: collect all new checkpoints needed
            for i = 1, #checkpoints - 1 do
                insertMiddleCheckpoint(checkpoints[i], checkpoints[i + 1])
            end
            
            -- If it's a loop, check between last and first checkpoint
            if isLoop then
                insertMiddleCheckpoint(checkpoints[#checkpoints], checkpoints[1])
            end
            
            -- Second pass: insert all new checkpoints into the main checkpoints table
            -- Sort them by their index to maintain proper order
            for _, newCp in ipairs(newCheckpoints) do
                local insertIndex = 1
                while insertIndex <= #checkpoints and checkpoints[insertIndex].index < newCp.index do
                    insertIndex = insertIndex + 1
                end
                table.insert(checkpoints, insertIndex, newCp)
            end
        end

        local function finishSegment(endIndex)
            if currentSegment.length >= MIN_SEGMENT_LENGTH then
                table.insert(segments, currentSegment)
                if currentSegment.type == "turn" or currentSegment.type == "hairpin" then
                    addCheckpoint(currentSegment.startIndex, endIndex, currentSegment.type, currentSegment.direction)
                end
            end
        end

        for i = startIndex + 1, #nodes - 1 do
            local angle = calculateAngle(nodes[i - 1], nodes[i], nodes[i + 1])
            currentSegment.totalAngle = currentSegment.totalAngle + angle
            currentSegment.length = currentSegment.length + calculateDistance(nodes[i - 1], nodes[i])

            if math.abs(angle) > STRAIGHT_THRESHOLD then
                local newDirection = angle > 0 and "left" or "right"
                if currentSegment.type == "straight" then
                    finishSegment(i - 1)
                    currentSegment = {
                        startIndex = i - 1,
                        type = "turn",
                        direction = newDirection,
                        totalAngle = angle,
                        length = 0
                    }
                elseif currentSegment.type == "turn" then
                    if currentSegment.direction ~= newDirection then
                        finishSegment(i - 1)
                        currentSegment = {
                            startIndex = i - 1,
                            type = "turn",
                            direction = newDirection,
                            totalAngle = angle,
                            length = 0
                        }
                    elseif math.abs(currentSegment.totalAngle - angle) > MAX_TURN_MERGE_ANGLE then
                        addCheckpoint(currentSegment.startIndex, i, "turn", newDirection)
                        currentSegment.totalAngle = angle
                        currentSegment.startIndex = i
                    end
                end
            elseif currentSegment.type == "turn" and currentSegment.length >= MIN_SEGMENT_LENGTH then
                finishSegment(i - 1)
                currentSegment = {
                    startIndex = i - 1,
                    type = "straight",
                    totalAngle = 0,
                    length = 0,
                    direction = nil
                }
            end

            if math.abs(currentSegment.totalAngle) > HAIRPIN_THRESHOLD then
                currentSegment.type = "hairpin"
                finishSegment(i)
                currentSegment = {
                    startIndex = i,
                    type = "straight",
                    totalAngle = 0,
                    length = 0,
                    direction = nil
                }
            end
        end

        finishSegment(#nodes)

        -- addStraightCheckpoints()

        return checkpoints
    end

    local mainCheckpoints = processRoute(mainNodes, false)
    local altCheckpoints = altNodes and processRoute(altNodes, true) or nil

    -- Adjust the last checkpoint if it's too close to the first one (for both routes)
    local function adjustLastCheckpoint(checkpoints, nodes)
        if #checkpoints >= 2 then
            local firstCheckpoint = checkpoints[1]
            local lastCheckpoint = checkpoints[#checkpoints]
            local distance = calculateDistance(firstCheckpoint.pos, lastCheckpoint.pos)

            if distance < MIN_CHECKPOINT_DISTANCE then
                --print("Adjusting last checkpoint: too close to first checkpoint")

                local newLastIndex = lastCheckpoint.index
                while newLastIndex > 1 and calculateDistance(nodes[newLastIndex], firstCheckpoint.pos) <
                    MIN_CHECKPOINT_DISTANCE do
                    newLastIndex = newLastIndex - 1
                end

                if newLastIndex > 1 and newLastIndex ~= lastCheckpoint.index then
                    lastCheckpoint.pos = nodes[newLastIndex]
                    lastCheckpoint.index = newLastIndex
                    --print("Last checkpoint moved to index: " .. newLastIndex)
                else
                    --print("Could not find a suitable position for the last checkpoint")
                end
            end
        end
    end

    adjustLastCheckpoint(mainCheckpoints, mainNodes)
    if altCheckpoints then
        adjustLastCheckpoint(altCheckpoints, altNodes)
    end

    --print("Main route: Total checkpoints created: " .. #mainCheckpoints)
    if altCheckpoints then
        --print("Alt route: Total checkpoints created: " .. #altCheckpoints)
    end

    return mainCheckpoints, altCheckpoints
end

-- Function to get DecalRoad by name
local function getRoad(roadName)
    local road = scenetree.findObject(roadName)
    if road and road:getClassName() == "DecalRoad" then
        return road
    else
        --print("Error: Road '" .. roadName .. "' not found or is not a DecalRoad")
        return nil
    end
end

-- Function to get nodes from a DecalRoad
local function getRoadNodes(roadName)
    local road = scenetree.findObject(roadName)
    if road and road:getClassName() ~= "DecalRoad" then
        return
    end

    if not road then
        --print("Error: Road '" .. roadName .. "' not found")
        return
    end

    --print("Road '" .. roadName .. "' found. Class: " .. road:getClassName())

    local nodeCount = road:getNodeCount()
    --print("Total nodes in the road: " .. nodeCount)

    local roadNodes = {}
    for i = 0, nodeCount - 1 do
        local pos = road:getNodePosition(i)
        table.insert(roadNodes, {
            x = pos.x,
            y = pos.y,
            z = pos.z
        })
        --print("Node " .. i .. ": (" .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ")")
    end
    return roadNodes
end

local function findClosestEndPoints(nodes1, nodes2)
    local connections = {}
    local searchRange1 = math.floor(#nodes1 * END_SEARCH_RANGE)
    local searchRange2 = math.floor(#nodes2 * END_SEARCH_RANGE)

    local function checkConnection(start1, end1, start2, end2, isStart1, isStart2)
        local minDist = math.huge
        local bestIndex1, bestIndex2

        for i = start1, end1, start1 < end1 and 1 or -1 do
            for j = start2, end2, start2 < end2 and 1 or -1 do
                local dist = calculateDistance(nodes1[i], nodes2[j])
                if dist < minDist then
                    minDist = dist
                    bestIndex1, bestIndex2 = i, j
                end
            end
        end

        if minDist <= MAX_MERGE_DISTANCE then
            table.insert(connections, {
                index1 = bestIndex1,
                index2 = bestIndex2,
                distance = minDist,
                isStart1 = isStart1,
                isStart2 = isStart2
            })
        end
    end

    -- Check all combinations
    checkConnection(1, searchRange1, 1, searchRange2, true, true)
    checkConnection(1, searchRange1, #nodes2, #nodes2 - searchRange2 + 1, true, false)
    checkConnection(#nodes1, #nodes1 - searchRange1 + 1, 1, searchRange2, false, true)
    checkConnection(#nodes1, #nodes1 - searchRange1 + 1, #nodes2, #nodes2 - searchRange2 + 1, false, false)

    table.sort(connections, function(a, b)
        return a.distance < b.distance
    end)
    return connections
end

local function mergeRoads(road1, road2)
    local nodes1 = getRoadNodes(road1)
    local nodes2 = getRoadNodes(road2)

    local connections = findClosestEndPoints(nodes1, nodes2)
    printTable(connections)

    if #connections == 0 then
        --print("Roads cannot be merged: no close endpoints found")
        return nil
    end

    local mergedNodes = {}
    local junctions = {}

    local function createJunction(node1, node2)
        return {
            x = (node1.x + node2.x) / 2,
            y = (node1.y + node2.y) / 2,
            z = (node1.z + node2.z) / 2,
            isJunction = true
        }
    end

    local function addJunction(junction)
        table.insert(junctions, junction)
        table.insert(mergedNodes, junction)
    end

    local conn1, conn2 = connections[1], connections[2]

    -- Determine if we need to reverse one of the roads
    local reverseRoad1 = false
    local reverseRoad2 = false
    if conn1.isStart1 == conn1.isStart2 then
        if #nodes1 < #nodes2 then
            reverseRoad1 = true
        else
            reverseRoad2 = true
        end
    end

    -- Determine the range for each road
    local start1 = math.min(conn1.index1, conn2.index1)
    local end1 = math.max(conn1.index1, conn2.index1)
    local start2 = math.min(conn1.index2, conn2.index2)
    local end2 = math.max(conn1.index2, conn2.index2)

    -- Add first junction
    addJunction(createJunction(nodes1[conn1.index1], nodes2[conn1.index2]))

    -- Add nodes from road1
    if reverseRoad1 then
        for i = end1, start1, -1 do
            table.insert(mergedNodes, nodes1[i])
        end
    else
        for i = start1, end1 do
            table.insert(mergedNodes, nodes1[i])
        end
    end

    -- Add second junction
    addJunction(createJunction(nodes1[conn2.index1], nodes2[conn2.index2]))

    -- Add nodes from road2
    if reverseRoad2 then
        for i = end2, start2, -1 do
            table.insert(mergedNodes, nodes2[i])
        end
    else
        for i = start2, end2 do
            table.insert(mergedNodes, nodes2[i])
        end
    end

    --print(string.format("Roads merged with %d connection(s)", #connections))
    --print(string.format("Merged road has %d nodes (Road1: %d-%d%s, Road2: %d-%d%s)", #mergedNodes, start1, end1,
    --    reverseRoad1 and " reversed" or "", start2, end2, reverseRoad2 and " reversed" or ""))
    --print(string.format("Number of junctions: %d", #junctions))

    --print("\nMerged Nodes:")
    for i, node in ipairs(mergedNodes) do
        if node.isJunction then
            --print(string.format("Node %d: JUNCTION (%.2f, %.2f, %.2f)", i, node.x, node.y, node.z))
        else
            --print(string.format("Node %d: (%.2f, %.2f, %.2f)", i, node.x, node.y, node.z))
        end
    end
    return mergedNodes
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
    --print("Removing checkpoints")
    --printTable(checkpoints)
    -- Clear existing checkpoint objects and markers
    for i = 1, #checkpoints do
        --print("Removing checkpoint " .. i)
        removeCheckpoint(i)
    end
    --print("Creating checkpoints")
    --printTable(checkpoints)
    -- Create new checkpoint objects and markers
    for i = 1, #checkpoints do
        --print("Creating checkpoint " .. i)
        createCheckpoint(i)
    end

    if altCheckpoints then
        --print("Removing alt checkpoints")
        --printTable(altCheckpoints)
        for i = 1, #altCheckpoints do
            --print("Removing alt checkpoint " .. i)
            removeCheckpoint(i, true)
        end
        --print("Creating alt checkpoints")
        --printTable(altCheckpoints)
        for i = 1, #altCheckpoints do
            --print("Creating alt checkpoint " .. i)
            createCheckpoint(i, true)
        end
    end
end

local function isNodeGroupLoop(nodeGroup)
    if #nodeGroup < 3 then
        -- A loop needs at least 3 nodes
        return false
    end

    local firstNode = nodeGroup[1]
    local lastNode = nodeGroup[#nodeGroup]

    -- Define a small threshold for floating-point comparisons
    local threshold = 50 -- You can adjust this value based on your needs

    -- Check if the first and last nodes are close enough to be considered the same point
    local isLoop = math.abs(firstNode.x - lastNode.x) < threshold and math.abs(firstNode.y - lastNode.y) < threshold and
                       math.abs(firstNode.z - lastNode.z) < threshold
    --print("isNodeGroupLoop isLoop: " .. tostring(isLoop))
    return isLoop
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

local function log(message)
    if debug then
        --print("[RoadCheck] " .. message)
    end
end

local function vec3FromTable(t)
    return vec3(t.x, t.y, t.z)
end

local function printRoadInfo()
    log("Total road nodes: " .. #roadNodes)
    log("First 5 road nodes:")
    for i = 1, math.min(5, #roadNodes) do
        log("Node " .. i .. ": " .. tostring(vec3FromTable(roadNodes[i])))
    end
    log("Last 5 road nodes:")
    for i = math.max(1, #roadNodes - 4), #roadNodes do
        log("Node " .. i .. ": " .. tostring(vec3FromTable(roadNodes[i])))
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
        activeAssets:hideAllAssets()
        removeCheckpoints()
        checkpoints = {}
        roadNodes = {}
        lastVehiclePos = nil
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
            activeAssets:hideAllAssets()
            lapCount = 0


            -- Initialize displays if drag race
            if raceName == "drag" then
                initDisplays()
                resetDisplays()
            end

            -- Load leaderboard
            loadLeaderboard()

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
            displayAssets(data)
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
            currentExpectedCheckpoint = 1
            if races[raceName].hotlap then
                mHotlap = raceName
            end
            invalidLap = false
        elseif event == "enter" and staged == raceName then
            -- Start the race
            saveAndSetTrafficAmount(0)
            displayAssets(data)
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
            removeCheckpoints()
            MIN_CHECKPOINT_DISTANCE = races[raceName].minCheckpointDistance or 90
            if races[raceName].checkpointRoad then
                -- Clear existing nodes and checkpoints
                roadNodes = nil
                altRoadNodes = nil
                checkpoints = nil
                altCheckpoints = nil
                -- Load main route nodes
                if type(races[raceName].checkpointRoad) == "table" then
                    roadNodes = mergeRoads(races[raceName].checkpointRoad[1], races[raceName].checkpointRoad[2])
                else
                    roadNodes = getRoadNodes(races[raceName].checkpointRoad)
                end

                -- Check for alternative route
                if races[raceName].altRoute and races[raceName].altRoute.checkpointRoad then
                    altRoadNodes = getRoadNodes(races[raceName].altRoute.checkpointRoad)
                    checkpoints, altCheckpoints = processRoadNodes(roadNodes, altRoadNodes)
                else
                    checkpoints = processRoadNodes(roadNodes)
                    altCheckpoints = nil
                end

                createCheckpoints()
                
                isLoop = isNodeGroupLoop(roadNodes)
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
                    if mAltRoute then
                        totalDiff = in_race_time - (leaderboard[raceName].altRoute and leaderboard[raceName].altRoute.splitTimes[checkpointsHit] or 0)
                    else
                        totalDiff = in_race_time - (leaderboard[raceName] and leaderboard[raceName].splitTimes[checkpointsHit] or 0)
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
                displayAssets(data)

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
            local reward = payoutRace(data)
            activeAssets:hideAllAssets()

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

local function distanceToLineSegment(point, lineStart, lineEnd)
    local lineVec = vec3FromTable(lineEnd) - vec3FromTable(lineStart)
    local pointVec = point - vec3FromTable(lineStart)
    local lineLength = lineVec:length()

    if lineLength < 0.001 then -- Check if line segment is too short
        return pointVec:length(), 0
    end

    local t = pointVec:dot(lineVec) / (lineLength * lineLength)
    t = math.max(0, math.min(1, t))

    local projection = vec3FromTable(lineStart) + lineVec * t

    return (point - projection):length(), t
end

local function findNearestNode(vehiclePos, nodes)
    if not nodes then
        return nil, nil
    end
    local nearestIndex = 1
    local minDistance = math.huge
    for i, node in ipairs(nodes) do
        local distance = (vehiclePos - vec3FromTable(node)):length()
        if distance < minDistance then
            minDistance = distance
            nearestIndex = i
        end
    end
    return nearestIndex, minDistance
end

local STATIONARY_TIMEOUT = 10 -- seconds before ending race due to no movement
local lastMovementTime = nil
local lastCountdownUpdate = nil
local remainingTime = STATIONARY_TIMEOUT

local function checkPlayerOnRoad()
    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then
        log("No player vehicle found")
        return false
    end

    local vehiclePos = playerVehicle:getPosition()
    local vehicleVel = playerVehicle:getVelocity()
    local currentTime = os.time()

    if vehicleVel:length() < 0.5 then -- Very low speed threshold
        local currentTime = os.time()
        
        if not lastMovementTime then
            lastMovementTime = currentTime
            lastCountdownUpdate = currentTime
            remainingTime = STATIONARY_TIMEOUT
        else
            local timeStopped = currentTime - lastMovementTime
            
            -- Update countdown every second
            if currentTime - lastCountdownUpdate >= 1 then
                remainingTime = STATIONARY_TIMEOUT - timeStopped
                lastCountdownUpdate = currentTime
                
                if remainingTime > 0 then
                    ui_message("Warning: Move your vehicle! Race ends in " .. remainingTime .. " seconds!", 2, "info")
                end
            end
            
            -- End race when time runs out
            if timeStopped >= STATIONARY_TIMEOUT then
                exitRace()
                ui_message("Race ended - Vehicle stationary for too long!", 3, "info")
                return false
            end
        end
    else
        -- Reset timers when vehicle is moving
        lastMovementTime = nil
        lastCountdownUpdate = nil
        remainingTime = STATIONARY_TIMEOUT
    end

    log("Vehicle position: " .. tostring(vehiclePos))
    log("Vehicle velocity: " .. tostring(vehicleVel))

    -- Check both main and alt routes
    local mainNearestIndex, mainDistance = findNearestNode(vehiclePos, roadNodes)
    local altNearestIndex, altDistance = findNearestNode(vehiclePos, altRoadNodes)

    if not mainNearestIndex and not mainDistance then
        return true
    end
    if not altNearestIndex and not altDistance then
        altDistance = 1000000
    end

    local useAltRoute = altDistance < mainDistance
    local currentNodes = useAltRoute and altRoadNodes or roadNodes
    local nearestNodeIndex = useAltRoute and altNearestIndex or mainNearestIndex

    log("Using " .. (useAltRoute and "alternative" or "main") .. " route")
    log("Nearest node index: " .. nearestNodeIndex .. ", Distance: " .. (useAltRoute and altDistance or mainDistance))

    local currentNode = currentNodes[nearestNodeIndex]
    local nextNodeIndex = (nearestNodeIndex % #currentNodes) + 1
    local prevNodeIndex = ((nearestNodeIndex - 2) % #currentNodes) + 1
    local nextNode = currentNodes[nextNodeIndex]
    local prevNode = currentNodes[prevNodeIndex]

    log("Current node position: " .. tostring(currentNode))
    log("Next node position: " .. tostring(nextNode))
    log("Prev node position: " .. tostring(prevNode))

    local distanceFromPath, t = distanceToLineSegment(vehiclePos, currentNode, nextNode)
    log("Distance from path: " .. distanceFromPath .. ", t: " .. t)

    -- Check if we need to consider the previous or next segment
    if t < 0.1 then
        local prevDistance, prevT = distanceToLineSegment(vehiclePos, prevNode, currentNode)
        if prevDistance < distanceFromPath then
            distanceFromPath = prevDistance
            t = prevT
            log("Using previous segment. New distance from path: " .. distanceFromPath .. ", t: " .. t)
        end
    elseif t > 0.9 then
        local nextNextNode = currentNodes[(nextNodeIndex % #currentNodes) + 1]
        local nextDistance, nextT = distanceToLineSegment(vehiclePos, nextNode, nextNextNode)
        if nextDistance < distanceFromPath then
            distanceFromPath = nextDistance
            t = nextT
            log("Using next segment. New distance from path: " .. distanceFromPath .. ", t: " .. t)
        end
    end

    -- Improved wrong direction detection
    local isWrongDirection = false
    if vehicleVel:length() > 1 then -- Only check direction if the vehicle is moving
        local playerDirection = vehicleVel:normalized()
        local forwardDirection = (vec3FromTable(nextNode) - vec3FromTable(currentNode)):normalized()
        local backwardDirection = (vec3FromTable(prevNode) - vec3FromTable(currentNode)):normalized()
        local forwardDot = playerDirection:dot(forwardDirection)
        local backwardDot = playerDirection:dot(backwardDirection)
        log("Forward dot product: " .. forwardDot)
        log("Backward dot product: " .. backwardDot)
        isWrongDirection = forwardDot < WRONG_DIRECTION_THRESHOLD and backwardDot < WRONG_DIRECTION_THRESHOLD
    else
        log("Vehicle not moving significantly")
    end

    log("Is wrong direction: " .. tostring(isWrongDirection))
    log("MAX_DISTANCE_FROM_PATH: " .. MAX_DISTANCE_FROM_PATH)

    local currentTime = os.time()
    if distanceFromPath > (MAX_DISTANCE_FROM_PATH + 25) then
        if exitCountdown == 0 then
            exitCountdown = exitCountdownStart
            ui_message("Warning: You are exiting the event! " .. exitCountdown .. " seconds to return!", 3, "info")
            lastCountdownTime = currentTime
        elseif currentTime - lastCountdownTime >= 1 then
            exitCountdown = exitCountdown - 1
            lastCountdownTime = currentTime
            if exitCountdown > 0 then
                ui_message("Exiting event in " .. exitCountdown .. " seconds!", 2, "info")
            else
                exitRace()
                ui_message("Event exited!", 3, "info")
            end
        end
        log("Player off road, countdown: " .. exitCountdown)
        return false
    elseif isWrongDirection then
        if currentTime - lastAlertTime > ALERT_COOLDOWN then
            --ui_message("Warning: You're going the wrong way!", 3, "info")
            lastAlertTime = currentTime
        end
        log("Player going wrong direction")
        -- Note: We're not returning false here, allowing the player to continue even if going the wrong way
    else
        if exitCountdown > 0 then
            exitCountdown = 0
            ui_message("Back on track!", 2, "info")
        end
    end

    log("Player on road")
    return true
end

local function spawnAINextToPlayer(data)
    local function safeGetPlayerVehicle()
        if be and be.getPlayerVehicle then
            return be:getPlayerVehicle(0)
        end
        return nil
    end
    if data.event ~= "enter" then
        return
    end
    local playerVehicle = safeGetPlayerVehicle()
    if not playerVehicle or playerVehicle:getID() ~= data.subjectID then
        --print("No player vehicle found")
        return
    end

    local playerPos = playerVehicle:getPosition()
    local playerRot = playerVehicle:getRotation()

    if not playerPos or not playerRot then
        --print("Unable to get player position or rotation")
        return
    end

    --print("Player position: " .. tostring(playerPos))
    --print("Player rotation: " .. tostring(playerRot))

    -- Offset the AI spawn position to the right of the player and slightly above ground
    local spawnPos = vec3(playerPos.x + 5, playerPos.y, playerPos.z + 1)

    --print("Spawn position: " .. tostring(spawnPos))

    -- Use a specific vehicle model that's likely to exist
    local aiVehicleModel = chooseVehicle()

    --print("Attempting to spawn vehicle model: " .. aiVehicleModel)

    -- Spawn the AI vehicle
    local options = {
        pos = spawnPos,
        rot = playerRot,
        autoEnterVehicle = false
    }

    local success, aiVehicle = pcall(function()
        return core_vehicles.spawnNewVehicle(aiVehicleModel, options)
    end)

    if not success or not aiVehicle then
        --print("Failed to spawn AI vehicle: " .. tostring(aiVehicle))
        return
    end

    --print("AI vehicle spawned successfully")

    -- Set up AI driver
    local success, error = pcall(function()
        aiVehicle:queueLuaCommand("ai.setMode('chase')")
        aiVehicle:queueLuaCommand("ai.setTargetVehicle(be:getPlayerVehicle(0))")
    end)

    if not success then
        --print("Error setting AI to chase player: " .. tostring(error))
    else
        --print("AI vehicle set to chase player")
    end

    return aiVehicle
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
        checkPlayerOnRoad()
        -- --print("checking player on road")
    end
    if timerActive == true then
        in_race_time = in_race_time + dtSim
    else
        in_race_time = 0
    end
end

M.spawnAINextToPlayer = spawnAINextToPlayer
M.displayMessage = displayMessage
M.isNodeGroupLoop = isNodeGroupLoop
M.onBeamNGTrigger = onBeamNGTrigger
M.processRoadNodes = processRoadNodes
M.createCheckpoints = createCheckpoints
M.createCheckpoint = createCheckpoint
M.removeCheckpoint = removeCheckpoint
M.onUpdate = onUpdate

M.payoutRace = payoutRace
M.raceReward = raceReward
M.loadLeaderboard = loadLeaderboard
M.saveLeaderboard = saveLeaderboard
M.isCareerModeActive = isCareerModeActive
M.exitCheckpoint = exitCheckpoint
M.routeInfo = routeInfo
M.saveAndSetTrafficAmount = saveAndSetTrafficAmount
M.restoreTrafficAmount = restoreTrafficAmount
M.onPursuitAction = onPursuitAction
M.displayStagedMessage = displayStagedMessage
M.payoutDragRace = payoutDragRace
M.getStartMessage = getStartMessage

M.onInit = onInit

return M
