local M = {}


M.dependencies = {'career_career'}

local function switchMap(levelName)
    local currentLevel = getCurrentLevelIdentifier()
    if currentLevel == levelName then return end
    career_career.switchCareerLevel(levelName)
end


local function onBeamNGTrigger(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if gameplay_walk.isWalking() then return end
    if career_career.isActive() and not career_modules_inventory.getInventoryIdFromVehicleId(data.subjectID) then return end

    local triggerName = data.triggerName
    
    if not triggerName:match("^switchTo_") then
        return
    end

    local levelName = triggerName:sub(10)
    switchMap(levelName)
end

M.onBeamNGTrigger = onBeamNGTrigger

return M