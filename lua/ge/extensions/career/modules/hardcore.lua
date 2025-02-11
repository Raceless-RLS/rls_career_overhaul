local M = {}

local isHardcoreMode = false
local infoFile = "info.json"

local saveFile = "hardcore.json"
local saveData = {}

local function onCareerActive(active)
    if not active then return false end
    -- load from saveslot
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    saveData = savePath and jsonReadFile(savePath .. "/career/rls_career/" .. saveFile) or {}
  
    if not next(saveData) then
        saveData = {
            hardcoreMode = career_career.hardcoreMode
        }
    end
    isHardcoreMode = saveData.hardcoreMode
end

local function onSaveCurrentSaveSlot(currentSavePath)
    career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/rls_career/" .. saveFile, saveData, true)
  end

M.enableHardcoreMode = function(enabled)
    isHardcoreMode = enabled
end

M.isHardcoreMode = function()
    return isHardcoreMode or false
end

--[[
M.onPlayerAttributesChanged = function(change, reason)
    if isHardcoreMode then
        local isReward = false
        for attributeName, value in pairs(change) do
            if value > 0 then
                isReward = true
            end
        end
        if isReward then
            ui_message("Hardcore mode is enabled, all rewards are halved.", 10, "info", "info")
        end
    end

end
]]

M.onCareerActive = onCareerActive
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

return M