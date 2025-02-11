local M = {}

local leaderboardFile = "career/races_leaderboard.json"
local leaderboard = {}

local level

local function loadLeaderboard()
    if not career_career or not career_career.isActive() then
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

local function saveLeaderboard(currentSavePath)
    local file = currentSavePath .. '/' .. leaderboardFile
    local file = io.open(file, "w")
    file:write(jsonEncode(leaderboard))
    file:close()
end

local function isBestTime(entry)
    level = getCurrentLevelIdentifier()
    if not leaderboard[level] then
        leaderboard[level] = {}
        return true

    end
    local leaderboardEntry = leaderboard[level][entry.raceName]
    if not leaderboardEntry then
        return true
    end
    local time, driftScore
    if entry.isAltRoute then
        if entry.isHotlap then
            time = leaderboardEntry.altRoute.hotlapTime
            driftScore = leaderboardEntry.altRoute.driftScore or 0
        else
            time = leaderboardEntry.altRoute.time
            driftScore = leaderboardEntry.altRoute.driftScore or 0

        end
    else
        if entry.isHotlap then
            time = leaderboardEntry.hotlapTime
            driftScore = leaderboardEntry.driftScore or 0
        else
            time = leaderboardEntry.time
            driftScore = leaderboardEntry.driftScore or 0
        end
    end
    if entry.driftScore and entry.driftScore > 0 then
        return entry.driftScore > driftScore
    end
    if time == nil then return true end
    return entry.time < time
end


local function addLeaderboardEntry(entry)
    if career_career and career_career.isActive() then
        career_modules_inventory.saveFRETimeToVehicle(entry.raceLabel, entry.inventoryId, entry.time, entry.driftScore)
    end
    if isBestTime(entry) then
        local raceName = entry.raceName

        leaderboard[level] = leaderboard[level] or {}
        leaderboard[level][raceName] = leaderboard[level][raceName] or {}
        if entry.isAltRoute then
            leaderboard[level][raceName].altRoute = leaderboard[level][raceName].altRoute or {}
            if entry.isHotlap then
                leaderboard[level][raceName].altRoute.hotlapSplitTimes = entry.splitTimes
                leaderboard[level][raceName].altRoute.hotlapTime = entry.time
                leaderboard[level][raceName].altRoute.driftScore = entry.driftScore
            else
                leaderboard[level][raceName].altRoute.splitTimes = entry.splitTimes
                leaderboard[level][raceName].altRoute.time = entry.time
                leaderboard[level][raceName].altRoute.driftScore = entry.driftScore

            end   
        else
            if entry.isHotlap then
                leaderboard[level][raceName].hotlapSplitTimes = entry.splitTimes
                leaderboard[level][raceName].hotlapTime = entry.time
                leaderboard[level][raceName].driftScore = entry.driftScore
            else
                leaderboard[level][raceName].splitTimes = entry.splitTimes
                leaderboard[level][raceName].time = entry.time
                leaderboard[level][raceName].driftScore = entry.driftScore
            end
        end
        return true
    end
    return false
end

local function onInit()
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

local function getTimes(raceName, checkpointsHit, altRoute)
    local leaderboardEntry = leaderboard[level][raceName]
    if not leaderboardEntry or (altRoute and not leaderboardEntry.altRoute) then
        return nil
    end
    return altRoute and leaderboardEntry.altRoute.splitTimes[checkpointsHit] or leaderboardEntry.splitTimes[checkpointsHit]
end

local function getLeaderboardEntry(raceName)
    if not leaderboard[level] then
        return nil
    end
    return leaderboard[level][raceName]
end

M.onInit = onInit
M.onWorldReadyState = onWorldReadyState

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.addLeaderboardEntry = addLeaderboardEntry

M.isBestTime = isBestTime
M.getTimes = getTimes
M.getLeaderboardEntry = getLeaderboardEntry

return M