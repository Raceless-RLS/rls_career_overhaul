local M = {}

local leaderboardFile = "career/rls_career/races_leaderboard.json"
local leaderboard = {}

local level

local function loadLeaderboard()
    if not career_career or not career_career.isActive() then
        return
    end
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    local file = savePath .. '/' .. leaderboardFile
    leaderboard = jsonReadFile(file)
end

local function saveLeaderboard(currentSavePath)
    career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/" .. leaderboardFile, leaderboard, true)
end

local function isBestTime(entry)
    level = getCurrentLevelIdentifier()
    local leaderboardEntry = leaderboard[level] or {}
    if not leaderboardEntry then
        return true
    end

    leaderboardEntry = leaderboardEntry[tostring(entry.inventoryId)] or {}
    if not leaderboardEntry then
        return true
    end

    leaderboardEntry = leaderboardEntry[entry.raceLabel] or {}
    if not leaderboardEntry then
        return true
    end

    if entry.driftScore and entry.driftScore > 0 then
        if not leaderboardEntry.driftScore then
            return true
        end
        return entry.driftScore > leaderboardEntry.driftScore
    end

    if not leaderboardEntry.time then
        return true
    end
    return entry.time < leaderboardEntry.time
end


local function addLeaderboardEntry(entry)
    level = getCurrentLevelIdentifier()
    local leaderboardEntry = leaderboard[level] or {}
    if career_career and career_career.isActive() then
        career_modules_inventory.saveFRETimeToVehicle(entry.raceLabel, entry.inventoryId, entry.time, entry.driftScore)
    end
    leaderboard[level][tostring(entry.inventoryId)] = leaderboard[level][tostring(entry.inventoryId)] or {}
    leaderboardEntry = leaderboard[level][tostring(entry.inventoryId)]
    if isBestTime(entry) then
        local raceLabel = entry.raceLabel
        leaderboardEntry[raceLabel] = leaderboardEntry[raceLabel] or {}
        leaderboardEntry[raceLabel].time = entry.time
        leaderboardEntry[raceLabel].splitTimes = entry.splitTimes
        leaderboardEntry[raceLabel].driftScore = entry.driftScore
        return true
    end
    return false
end

local function clearLeaderboardForVehicle(inventoryId)
    leaderboard[level][tostring(inventoryId)] = nil
end

local function onExtensionLoaded()
    print("Initializing Leaderboard Manager")
    level = getCurrentLevelIdentifier()
    if level then
        loadLeaderboard()
    end
end

local function onWorldReadyState(state)
    if state == 2 then
        level = getCurrentLevelIdentifier()
        loadLeaderboard()
    end
end

local function onSaveCurrentSaveSlot(currentSavePath)
    saveLeaderboard(currentSavePath)
end

local function getLeaderboardEntry(inventoryId, raceLabel)
    level = getCurrentLevelIdentifier()
    if not leaderboard[level] or not leaderboard[level][tostring(inventoryId)] then
        return {}
    end
    return leaderboard[level][tostring(inventoryId)][raceLabel]
end

local function onCareerActive(active)
    if active then
        loadLeaderboard()
    else
        leaderboard = {}
    end
end

M.onVehicleRemoved = clearLeaderboardForVehicle
M.onCareerActive = onCareerActive

M.onExtensionLoaded = onExtensionLoaded
M.onWorldReadyState = onWorldReadyState

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.addLeaderboardEntry = addLeaderboardEntry

M.isBestTime = isBestTime
M.getLeaderboardEntry = getLeaderboardEntry

return M