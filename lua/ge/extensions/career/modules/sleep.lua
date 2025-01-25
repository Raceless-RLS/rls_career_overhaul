local M = {}

M.dependencies = {"career_career", "career_saveSystem"}

local saveFile = "time.json"

local originComputerId
local isSleeping = false
local sleepTime = 0
local careerActive = false

local function saveTimeData(currentSavePath)
    if not currentSavePath then
        local slot, path = career_saveSystem.getCurrentSaveSlot()
        currentSavePath = path
        if not currentSavePath then return end
    end

    local dirPath = currentSavePath .. "/career/rls_career"
    if not FS:directoryExists(dirPath) then
        FS:directoryCreate(dirPath)
    end

    local data = {
        time = scenetree.tod.time,
        play = scenetree.tod.play or false
    }
    career_saveSystem.jsonWriteFileSafe(dirPath .. "/" .. saveFile, data, true)
end

local function loadTimeData()
    if not career_career.isActive() then return end
    local _, currentSavePath = career_saveSystem.getCurrentSaveSlot()
    if not currentSavePath then return end
    
    local filePath = currentSavePath .. "/career/rls_career/" .. saveFile
    local data = jsonReadFile(filePath)
    
    if data then
        -- Apply saved values to tod
        if scenetree.tod and data.time ~= nil and data.play ~= nil then
            scenetree.tod.time = data.time
            scenetree.tod.play = data.play
        end
    end
end

local function getDayNightCycle()
    if scenetree.tod then
        return {play = scenetree.tod.play, time = scenetree.tod.time}
    end
    return {play = false, time = 0}
end

local function onCareerActive(active)
    careerActive = active
end

local function onWorldReadyState(state)
    if state == 2 and careerActive then
        print("Loading time data")
        loadTimeData()
    end
end

local function onSaveCurrentSaveSlot(currentSavePath)
    saveTimeData(currentSavePath)
end

local function openMenuFromComputer(computerId)
    originComputerId = computerId  -- Store the computer ID
    print("Open sleep menu from computer: " .. computerId)
    guihooks.trigger('ChangeState', {state = 'sleep-menu'})
end

local function closeMenu()
    if originComputerId then
        local computer = freeroam_facilities.getFacility("computer", originComputerId)
        career_modules_computer.openMenu(computer)
    else
        career_career.closeAllMenus()
    end
end

local function closeAllMenus()
    career_career.closeAllMenus()
end

local function toggleDayNightCycle(toggle)
    if scenetree.tod then
        scenetree.tod.play = toggle
    end
end

local function onComputerAddFunctions(menuData, computerFunctions)
    if not menuData.computerFacility.functions["sleep"] then
        return
    end

    local computerFunctionData = {
        id = "sleep",
        label = "Sleep",
        callback = function()
            openMenuFromComputer(menuData.computerFacility.id)
        end,
        order = 20
    }

    computerFunctions.general[computerFunctionData.id] = computerFunctionData
end

local function onScreenFadeState(state)
    if state == 2 and isSleeping then
        if scenetree.tod then
            scenetree.tod.time = sleepTime
        end
        
        local closestGarage = career_modules_inventory.getClosestGarage()
        local pos, _ = freeroam_facilities.getGaragePosRot(closestGarage)
        career_modules_playerDriving.showPosition(pos)
        
        isSleeping = false
    end
end

local function sleep(time)
    isSleeping = true
    sleepTime = time
    ui_fadeScreen.cycle(0.5, 0.5, 0.5)
end

M.openMenuFromComputer = openMenuFromComputer
M.onComputerAddFunctions = onComputerAddFunctions

M.sleep = sleep
M.getDayNightCycle = getDayNightCycle
M.toggleDayNightCycle = toggleDayNightCycle
M.closeMenu = closeMenu
M.closeAllMenus = closeAllMenus

M.onScreenFadeState = onScreenFadeState
M.onCareerActive = onCareerActive
M.onWorldReadyState = onWorldReadyState
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

return M
