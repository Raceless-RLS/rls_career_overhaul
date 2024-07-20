-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {'career_career', 'career_modules_insurance', 'career_saveSystem', 'career_modules_playerAttributes'}

local checkpointSoundPath = 'art/sound/ui_checkpoint.ogg'

-- Function to play the checkpoint sound
local function playCheckpointSound()
    Engine.Audio.playOnce('AudioGui', checkpointSoundPath, {volume = 4.5})
end

-- This is used to track if the timer is active
local timerActive = false

-- This is used to track the active race
local mActiveRace

-- This is used to track if the race is staged
local staged = nil

-- This is used to track the time in the race
local in_race_time = 0

local speedUnit = 2.2369362920544
local speedThreshold = 5
local currCheckpoint = nil
local mHotlap = nil
local mAltRoute = nil
local leaderboardFile = 'career/leaderboard.json'
local leaderboard = {}
local mSplitTimes = {}
local mBestSplitTime = {}

local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}
local maxAssets = 6
local maxActiveAssets = 2
local ActiveAssets = {}
ActiveAssets.__index = ActiveAssets

local maxActiveAssets = 2

function ActiveAssets.new()
    local self = setmetatable({}, ActiveAssets)
    self.assets = {}  -- Ensure this is always initialized as an empty table
    return self
end

function ActiveAssets:addAssetList(triggerName, newAssets)
    if not self.assets then
        self.assets = {}  -- Reinitialize if it's somehow nil
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
        print("Warning: self.assets is nil in hideAllAssets")
        self.assets = {}  -- Reinitialize if it's nil
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
    print("displayAssets function called with triggerName: " .. tostring(data.triggerName))
    local triggerName = data.triggerName
    local newAssets = {}

    -- Unhide assets and add them to newAssets table
    for i = 0, maxAssets - 1 do
        local assetName = triggerName .. "asset" .. i
        print("Searching for asset: " .. assetName)
        local asset = scenetree.findObject(assetName)
        if asset then
            print("Asset found: " .. assetName)
            asset:setHidden(false)
            table.insert(newAssets, asset)
        else
            print("Asset not found: " .. assetName)
            break  -- Stop if an asset is not found
        end
    end

    -- If no assets were found, return early
    if #newAssets == 0 then
        print("No assets found for triggerName: " .. triggerName)
        return
    end

    print("Number of new assets found: " .. #newAssets)

    -- Add the new asset list to activeAssets
    print("Attempting to add new asset list to activeAssets")
    activeAssets:addAssetList(triggerName, newAssets)

    -- If we have reached the maximum number of active asset lists,
    -- we might want to do something with the oldest one
    print("Number of active asset lists: " .. #activeAssets.assets)
    if #activeAssets.assets == maxActiveAssets then
        print("Maximum number of active asset lists reached")
        local oldestAssetList = activeAssets:getOldestAssetList()
        print("Oldest asset list triggerName: " .. oldestAssetList.triggerName)
        -- Here you can add code to clear or update the display of the oldest asset list
        -- For example:
        -- clearAssetListDisplay(oldestAssetList)
    end

    print("displayAssets function completed")
end

-- Function to check if career mode is active
local function isCareerModeActive()
    return career_career.isActive()
end

-- Function to read the leaderboard from the file
local function loadLeaderboard()
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

local function displayDragInfo()
    
end

-- Function to save the leaderboard to the file in all autosave folders
local function saveLeaderboard()
    if not isCareerModeActive() then
        return
    end
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    print("saveSlot: " .. saveSlot)
    print("savePath: " .. savePath)
    
    -- Extract the base path by removing the current autosave folder
    local basePath = savePath:match("(.*/)")
    
    -- Define the paths for all three autosave folders
    local autosavePaths = {
        basePath .. "autosave1/" .. leaderboardFile,
        basePath .. "autosave2/" .. leaderboardFile,
        basePath .. "autosave3/" .. leaderboardFile
    }
    
    -- Save the leaderboard to each autosave folder
    for _, filePath in ipairs(autosavePaths) do
        local file = io.open(filePath, "w")
        if file then
            file:write(jsonEncode(leaderboard))
            file:close()
            print("Saved leaderboard to: " .. filePath)
        else
            print("Error: Unable to open leaderboard file for writing: " .. filePath)
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
    for i,v in ipairs(timeDisplayValue) do
      timeDigits[i]:preApply()
      timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
      timeDigits[i]:setHidden(false)
      timeDigits[i]:postApply()
    end
  end

  for i,v in ipairs(speedDisplayValue) do
    speedDigits[i]:preApply()
    speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
    speedDigits[i]:setHidden(false)
    speedDigits[i]:postApply()
  end
end

local function clearDisplay(digits)
  for i=1, #digits do
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

  for i=1, 5 do
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

local function formatTime(seconds)
    local sign = seconds < 0 and "-" or ""
    seconds = math.abs(seconds)
    
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    local wholeSeconds = math.floor(remainingSeconds)
    local hundredths = math.floor((remainingSeconds - wholeSeconds) * 100)
    
    return string.format("%s%02d:%02d:%02d", sign, minutes, wholeSeconds, hundredths)
end

-- Simple sleep function using os.clock
local function sleep(seconds)
    local start = os.clock()
    while os.clock() - start < seconds do
        -- Busy-wait loop
    end
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

local function raceReward(x, y, z)
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
    z = z or in_race_time
    if z == 0 then
        return 0
    end
    local ratio = x / in_race_time
    if ratio < 1 then
        local reward = math.floor(ratio * y * 100) / 100
        return reward
    else
        local reward = math.floor((math.pow(ratio, (1 + (y / 500)))) * y * 100) / 100
        if reward > y*30 then
            return y*30
        end
        return reward
    end
end

-- This table stores the best time and reward for each race.
-- The best time is the ideal time for the race.
-- The reward is the potential reward for the race.
-- The label is the name of the race.
local races = {
    mudDrag = {
        bestTime = 9,
        reward = 2000,
        checkpoint = 1,
        label = "Mud Track"
    },
    drag = {
        bestTime = 11,
        reward = 1500,
        checkpoints = 2,
        label = "Drag Strip",
        displaySpeed = true
    },
    rockcrawls = {
        bestTime = 35,
        reward = 2500,
        label = "Left Rock Crawl"
    },
    rockcrawlm = {
        bestTime = 40,
        reward = 5500,
        label = "Middle Rock Crawl"
    },
    rockcrawll = {
        bestTime = 30,
        reward = 2000,
        label = "Right Rock Crawl"
    },
    smallCrawll = {
        bestTime = 20,
        reward = 1500,
        label = "Left Small Crawl"
    },
    smallCrawlr = {
        bestTime = 20,
        reward = 2000,
        label = "Right Small Crawl"
    },
    hillclimbl = {
        bestTime = 20,
        reward = 2000,
        label = "Left Hill Climb"
    },
    hillclimbm = {
        bestTime = 15,
        reward = 3000,
        label = "Middle Hill Climb"
    },
    hillclimbr = {
        bestTime = 12,
        reward = 2000,
        label = "Right Hill Climb"
    },
    bnyHill = {
        bestTime = 30,
        reward = 3000,
        checkpoint = 3,
        label = "Bunny Hill Climb"
    },
    track = {
        bestTime = 140,
        reward = 3000,
        label = "Track",
        checkpoints = 18,
        hotlap = 125,
        altRoute = {
            bestTime = 110,
            reward = 2000,
            label = "Short Track",
            checkpoints = 14,
            hotlap = 95,
            altCheckpoints = {0, 1, 2, 3, 4, 5, 6, 7, 12, 13, 14, 15, 16, 17},
            altInfo = "**Continue Left for Standard Track\nHair Pin Right for Short Track**"
        }
    },
    dirtCircuit = {
        bestTime = 65,
        reward = 2000,
        checkpoints = 10,
        hotlap = 55,
        label = "Dirt Circuit"
    },
    testTrack = {
        bestTime = 5.5,
        reward = 1000,
        label = "Test Track"
    }
}

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
            print(indentStr .. tostring(k) .. ":")
            printTable(v, indent + 1)
        else
            print(indentStr .. tostring(k) .. ": " .. tostring(v))
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
    local name = data.triggerName:match("([^_]+)")
    if not races[name] then
        name = "testTrack"
    end
    return name
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
        return mHotlap == raceName and leaderboard[raceName].altRoute.hotlapTime or leaderboard[raceName].altRoute.bestTime
    else
        return mHotlap == raceName and leaderboard[raceName].hotlapTime or leaderboard[raceName].bestTime
    end
end

local function raceCompletionMessage(newBestTime, oldTime, reward, xp, data)
    local raceName = getActivityName(data)
    local newBestTimeMessage = newBestTime and "Congratulations! New Best Time!\n" or ""
    local raceLabel = races[raceName].label
    if mAltRoute then
        raceLabel = raceLabel .. " (Alternative Route)"
    end
    if mHotlap == raceName then
        raceLabel = raceLabel .. " (Hotlap)"
    end
    local timeMessage = string.format("New Time: %s\nOld Time: %s", formatTime(in_race_time), formatTime(oldTime))
    local rewardMessage = string.format("XP: %d | Reward: $%.2f", xp, reward)
    
    local message = newBestTimeMessage .. raceLabel .. "\n" .. timeMessage .. "\n" .. rewardMessage
    
    if races[raceName].displaySpeed then
        local speedMessage = string.format("Speed: %.2f Mph", math.abs(be:getObjectVelocityXYZ(data.subjectID) * speedUnit))
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
    if not isCareerModeActive() then
        mActiveRace = nil
        local message = string.format("%s\nTime: %s", races[raceName].label, formatTime(in_race_time))
        displayMessage(message, 10)
        return 0
    end
    if data.event == "enter" and raceName == mActiveRace then
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
        local reward = raceReward(time, reward)
        if reward <= 0 then
            return 0
        end
        -- Save the best time to the leaderboard
        loadLeaderboard()
        local oldTime = getOldTime(raceName) or 0
        local newBestTime = isNewBestTime(raceName, in_race_time)
        if newBestTime then
            if not leaderboard[raceName] then
                leaderboard[raceName] = {}
            end
            if mAltRoute then
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
        else 
            print("No new best time for" .. raceName)
            reward = reward / 2
        end
        local xp = math.floor(reward / 20)
        career_modules_payment.reward({
            money = {
                amount = reward
            },
            beamXP = {
                amount = math.floor(xp / 10)
            },
            motorsport = {
                amount = xp
            },
            bonusStars = {
                amount = oldTime > races[raceName].bestTime and in_race_time < races[raceName].bestTime and 1 or 0
            }
            }, 
            {
                label = rewardLabel(raceName, newBestTime),
                tags = {"gameplay", "reward", "mission"}
            })
        local message = raceCompletionMessage(newBestTime, oldTime, reward, xp, data)
        ui_message(message, 20, "Reward")
        print("leaderboard:")
        printTable(leaderboard)
        saveLeaderboard()
        career_saveSystem.saveCurrent()
        return reward
    end
end

local function getDifference(raceName, currentCheckpointIndex)
    if not leaderboard[raceName] then
        return 0
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

    if not splitTimes or not splitTimes[currentCheckpointIndex + 1] then
        return 0
    end
    return mSplitTimes[currentCheckpointIndex + 1] - splitTimes[currentCheckpointIndex + 1]
end

local function checkpoint(data)
    if data.event == "exit" then
        print("Checkpoint function exited due to 'exit' event")
        return
    end
    print("Checkpoint function called with data:")
    
    local raceName = getActivityName(data)
    local activityType = getActivityType(data)
    local check = tonumber(activityType:match("%d+")) or 0
    local alt = activityType:match("alt") and true or false
    
    print(string.format("raceName: %s, activityType: %s, check: %d, alt: %s", raceName, activityType, check, tostring(alt)))
    print(string.format("mActiveRace: %s, currCheckpoint: %s, mAltRoute: %s", tostring(mActiveRace), tostring(currCheckpoint), tostring(mAltRoute)))
    
    if mActiveRace == raceName then
        if currCheckpoint == nil then
            print("currCheckpoint is nil, initializing...")
            if check == 0 then
                currCheckpoint = -1
                if alt then
                    mAltRoute = true
                else
                    mAltRoute = false
                end
            else 
                local message = string.format("Checkpoint %d/%d reached\nTime: %s\n**You must complete this race in the designated order.**",
                    check, races[raceName].checkpoints, formatTime(in_race_time))
                displayMessage(message, 10)
            end
            print(string.format("currCheckpoint set to: %s, mAltRoute: %s", tostring(currCheckpoint), tostring(mAltRoute)))
        end
        
        local nextCheckpoint
        local totalCheckpoints
        local currentCheckpointIndex

        if mAltRoute then
            print("Processing alt route...")
            local altCheckpoints = races[raceName].altRoute.altCheckpoints
            totalCheckpoints = #altCheckpoints
            print(string.format("Alt route checkpoints: %s", table.concat(altCheckpoints, ", ")))
            for i, cp in ipairs(altCheckpoints) do
                if cp == currCheckpoint then
                    currentCheckpointIndex = i
                    break
                end
            end
            currentCheckpointIndex = currentCheckpointIndex or 0
            nextCheckpoint = altCheckpoints[currentCheckpointIndex + 1]
        else
            print("Processing standard route...")
            totalCheckpoints = races[raceName].checkpoints
            currentCheckpointIndex = currCheckpoint + 1
            nextCheckpoint = currentCheckpointIndex
        end

        if check == nextCheckpoint then
            print(string.format("Checkpoint %d reached correctly", check))
            currCheckpoint = check
            mSplitTimes[currentCheckpointIndex + 1] = in_race_time
            -- Play the checkpoint sound
            playCheckpointSound()
            local checkpointMessage
            if totalCheckpoints and totalCheckpoints > 1 then
                checkpointMessage = string.format("Checkpoint %d/%d reached\nTime: %s\n%s",
                currentCheckpointIndex + 1, totalCheckpoints, formatTime(in_race_time), formatTime(getDifference(raceName, currentCheckpointIndex)))
            else
                checkpointMessage = "Checkpoint reached"
            end
            if races[raceName].displaySpeed then
                checkpointMessage = checkpointMessage .. string.format("\nSpeed: %.2f Mph", math.abs(be:getObjectVelocityXYZ(data.subjectID) * speedUnit))
            end
            displayMessage(checkpointMessage, 7)
            displayAssets(data)
        else
            print(string.format("Checkpoint mismatch. Expected: %s, Got: %d", tostring(nextCheckpoint), check))
            local missedCheckpoints
            if mAltRoute then
                local altCheckpoints = races[raceName].altRoute.altCheckpoints
                local expectedIndex = nil
                local actualIndex = nil
                for i, cp in ipairs(altCheckpoints) do
                    if cp == nextCheckpoint then
                        expectedIndex = i
                    end
                    if cp == check then
                        actualIndex = i
                    end
                    if expectedIndex and actualIndex then
                        break
                    end
                end
                print(string.format("Alt route: expectedIndex: %s, actualIndex: %s", tostring(expectedIndex), tostring(actualIndex)))
                missedCheckpoints = actualIndex and expectedIndex and (actualIndex - expectedIndex) or 0
            else
                missedCheckpoints = check - nextCheckpoint
            end
            
            print(string.format("Missed checkpoints: %d", missedCheckpoints))
            
            if missedCheckpoints > 0 then
                local message = string.format(
                    "You missed %d checkpoint(s). Turn around and go back to checkpoint %d.", missedCheckpoints,
                    nextCheckpoint)
                displayMessage(message, 10)
            elseif missedCheckpoints < 0 then
                print("Warning: Negative missed checkpoints. This shouldn't happen.")
            end
        end
    else
        print(string.format("Checkpoint ignored. mActiveRace (%s) != raceName (%s)", tostring(mActiveRace), raceName))
    end
end

local function exitCheckpoint(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if data.event == "enter" and mActiveRace then
        setActiveLight(mActiveRace, "red")
        mActiveRace = nil
        timerActive = false
        mAltRoute = nil
        mHotlap = nil
        currCheckpoint = nil
        mSplitTimes = {}
        activeAssets:hideAllAssets()
        displayMessage("You exited the race zone, Race cancelled", 3)
    end
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

local function manageZone(data)
    -- This function manages the race zone using a BeamNgTrigger.
    -- The trigger should cover the entire race as a bounding box.
    -- The trigger must be named in the format of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    if data.event == "exit" then
        if mActiveRace == raceName then
            mActiveRace = nil
            timerActive = false
            mAltRoute = nil
            mHotlap = nil
            currCheckpoint = nil
            mSplitTimes = {}
            displayMessage("You exited the race zone, Race cancelled", 2)
            setActiveLight(raceName, "red")
        end
    end
end

local motivationalMessages = {
    -- Enthusiastic
    "Give it your all!",
    "Time to shine!",
    "Let's set a new record!",
    "It's go time!",
    
    -- Funny
    "Try not to hit any trees this time!",
    "Remember, the brake is the other pedal!",
    "First one to the finish line gets a cookie!",
    "Drive like you stole it... wait, you didn't, right?",
    
    -- Passive-aggressive
    "Try to keep it on the track this time, okay?",
    "Let's see if you've improved since last time...",
    "Maybe today you'll actually finish the race?",
    "I'm sure you'll do better than your last attempt. It can't get worse, right?",
    
    -- Encouraging
    "Believe in yourself, you've got this!",
    "Today could be your personal best!",
    "Focus and breathe, you're ready for this!",
    "Every second counts, make them all yours!",
    
    -- Challenging
    "Think you can handle this? Prove it!",
    "Show us what you're really made of!",
    "This track has beaten you before. Not today!",
    "Time to separate the rookies from the pros!",
    
    -- Quirky
    "May the downforce be with you!",
    "Remember: turn left to go left, right to go right!",
    "Gravity is just a suggestion, right?",
    "If in doubt, flat out! (Results may vary)",
    
    -- Intense
    "Push it to the limit!",
    "Leave nothing on the table!",
    "Drive like your life depends on it!",
    "It's now or never!"
}

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

-- Green light trigger
local function Greenlight(data)
    print("Greenlight function called with data:")

    if be:getPlayerVehicleID(0) ~= data.subjectID then
        print("Greenlight: Player vehicle ID mismatch")
        return
    end

    local raceName = getActivityName(data)


    if currCheckpoint then
        if currCheckpoint + 1 == races[raceName].checkpoints then
            displayAssets(data)
            playCheckpointSound()
            print("Greenlight: Final checkpoint reached")
            timerActive = false
            local reward = payoutRace(data)
            print("Greenlight: Race payout =" .. reward)
            currCheckpoint = nil
            mSplitTimes = {}
            mActiveRace = raceName
            in_race_time = 0
            timerActive = true
            if races[raceName].hotlap then
                mHotlap = raceName
                print("Greenlight: Hotlap started for" .. raceName)
            end
            return
        else
            exitCheckpoint(data)
        end
    end

    if data.event == "enter" and staged == raceName then
        displayAssets(data)
        timerActive = true
        in_race_time = 0
        mActiveRace = raceName
        print("Greenlight: Race started for" .. raceName)
        print("Greenlight: in_race_time =" .. in_race_time)
        print("Greenlight: mActiveRace =" .. mActiveRace)
        displayMessage(getStartMessage(raceName), 5)
        setActiveLight(raceName, "green")
    else
        setActiveLight(raceName, "red")
    end
end

local function displayStagedMessage(race, times)
    local message

    if times.bestTime and times.bestTime > race.bestTime then
        local potentialReward = raceReward(race.bestTime, race.reward, times.bestTime)  -- Calculate potential reward
        message = string.format(
            "Staged for %s.\nYour Best Time: %s\nBeat your time to win more than $%.2f!",
            race.label,
            formatTime(times.bestTime or 0),
            potentialReward
        )
    else
        message = string.format(
            "Staged for %s.\nYour Best Time: %s\nTarget Time: %s \n(Achieve this to earn a reward of $%.2f and 1 Bonus Star)",
            race.label,
            formatTime(times.bestTime or 0),
            formatTime(race.bestTime or 0),
            race.reward or 0
        )
    end

    if race.hotlap then
        local hotlapPotentialReward = raceReward(race.hotlap, race.reward, times.hotlapTime)  -- Calculate potential reward for hotlap
        message = message .. string.format("\nHotlap: Your Best: %s | Target: %s \n(Beat this to win more than $%.2f)",
            formatTime(times.hotlapTime or 0),
            formatTime(race.hotlap or 0),
            hotlapPotentialReward
        )
    end

    if race.altRoute then
        message = message .. "\n\nAlternative Route:"
        if times.altRoute then
            message = message .. string.format(" Your Best: %s", formatTime(times.altRoute.bestTime or 0))
        end
        local altRoutePotentialReward = raceReward(race.altRoute.bestTime, race.altRoute.reward, times.altRoute.bestTime)  -- Calculate potential reward for alt route
        message = message .. string.format(" | Target: %s \n(Beat this to win more than $%.2f and 1 Bonus Star)",
            formatTime(race.altRoute.bestTime or 0),
            altRoutePotentialReward
        )
        
        if race.altRoute.hotlap then
            local altHotlapPotentialReward = raceReward(race.altRoute.hotlap, race.altRoute.reward, times.altRoute.hotlapTime)  -- Calculate potential reward for alt route hotlap
            message = message .. string.format("\nAlt Route Hotlap: Your Best: %s | Target: %s \n(Beat this to win more than $%.2f)",
                formatTime((times.altRoute and times.altRoute.hotlapTime) or 0),
                formatTime(race.altRoute.hotlap or 0),
                altHotlapPotentialReward
            )
        end
    end

    message = message .. "\n\n**Note: All rewards are cut by 50% if they are below your best time.**"
    displayMessage(message, 10)
end
-- Yellow light trigger
local function Yellowlight(data)
    print("Yellowlight function called with data:")

    if be:getPlayerVehicleID(0) ~= data.subjectID then
        print("Yellowlight: Player vehicle ID mismatch")
        return
    end

    local raceName = getActivityName(data)

    if data.event == "enter" then
        print("Yellowlight: Enter event triggered")
        local vehicleSpeed = math.abs(be:getObjectVelocityXYZ(data.subjectID)) * speedUnit
        print("Yellowlight: Vehicle speed =" .. vehicleSpeed)

        if vehicleSpeed > 5 then
            if mActiveRace ~= raceName then
                local message = "You are too fast to stage.\n" .. "Please back up and slow down to stage."
                displayMessage(message, 2)
            end
            staged = nil
        else
            if raceName == "drag" then
                initDisplays()
                resetDisplays()
            end
            print("Yellowlight: Vehicle speed acceptable for staging")
            loadLeaderboard()
            print("Yellowlight: Leaderboard loaded")
            staged = raceName
            print("Yellowlight: staged set to" .. raceName)

            local race = races[raceName]
            if not leaderboard[raceName] then
                leaderboard[raceName] = {}
                print("Yellowlight: Created new leaderboard entry for" .. raceName)
            end
            displayStagedMessage(race, leaderboard[raceName])
            setActiveLight(raceName, "yellow")
        end
    elseif data.event == "exit" then
        staged = nil
        if not mActiveRace then
            ui_message("You exited the staging zone", 4, "info", "info")
            setActiveLight(raceName, "red")
        end
    end
end

-- Finishline
local function Finishline(data)
    -- This function handles the finish line trigger using a BeamNgTrigger.
    -- The trigger should be after the finish line.
    -- The trigger must be named in the fsormat of "raceName_identifier".
    --
    -- Parameters:
    --   data (table): The data containing the event information.
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    local raceName = getActivityName(data)
    if data.event == "enter" and mActiveRace == raceName then
        playCheckpointSound()
        if currCheckpoint then
            if currCheckpoint + 1 == races[raceName].checkpoints then
                timerActive = false
                currCheckpoint = nil
                local reward = payoutRace(data)
                if raceName == "drag" then
                    local activityType = getActivityType(data)
                    local side = string.sub(activityType, -1)  -- This gets the last character of the string
                    updateDisplay(side, in_race_time, be:getObjectVelocityXYZ(data.subjectID) * speedUnit)
                end
                mSplitTimes = {}
                mActiveRace = nil
                in_race_time = 0
                return
            end
        else
            timerActive = false
            local reward = payoutRace(data)
        end
    else
        setActiveLight(raceName, "red")
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
    if timerActive == true then
        in_race_time = in_race_time + dtSim
    else
        in_race_time = 0
    end
end

M.displayMessage = displayMessage
M.Finishline = Finishline
M.Greenlight = Greenlight
M.Yellowlight = Yellowlight

M.onUpdate = onUpdate

M.payoutRace = payoutRace
M.raceReward = raceReward
M.manageZone = manageZone
M.checkpoint = checkpoint
M.loadLeaderboard = loadLeaderboard
M.saveLeaderboard = saveLeaderboard
M.isCareerModeActive = isCareerModeActive
M.exitCheckpoint = exitCheckpoint
M.routeInfo = routeInfo

return M