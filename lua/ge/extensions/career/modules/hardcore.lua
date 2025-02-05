local M = {}

local isHardcoreMode = false
local infoFile = "info.json"

local saveFile = "hardcore.json"
local saveData = {}

local function onCareerActive(active)
    if not active then return false end
    -- load from saveslot
    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    saveData = savePath and jsonReadFile(savePath .. saveFile) or {}
  
    if not next(saveData) then
        saveData = {
            freshStart = true,
            hardcoreMode = career_career.hardcoreMode
        }
    end
    print("Extension loaded. Hardcore mode: " .. tostring(career_career.hardcoreMode))
    isHardcoreMode = saveData.hardcoreMode
end

local function onSaveCurrentSaveSlot(currentSavePath)
    saveData.freshStart = false
    career_saveSystem.jsonWriteFileSafe(currentSavePath .. saveFile, saveData, true)
  end

M.enableHardcoreMode = function(enabled)
    isHardcoreMode = enabled
end

M.isHardcoreMode = function()
    return isHardcoreMode
end

M.onCareerActive = onCareerActive
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

return M
