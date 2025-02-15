local M = {}


M.dependencies = {'career_career'}

local function switchMap(levelName)
    local currentLevel = getCurrentLevelIdentifier()
    if currentLevel == levelName then return end
    career_career.switchCareerLevel(levelName)
end

local function isOverhaulAddonActive(levelName)
    local mods = core_modmanager.getMods()
    for modName, modData in pairs(mods) do
        local OverhaulAddon = "rls_career_overhaul_" .. levelName
        print(OverhaulAddon)
        print(modName:lower():find(OverhaulAddon))
        if modName:lower():find(OverhaulAddon) and modData.active then
            return true
        end
    end
    return false
end

local function setLevelGate(levelName)
    local isOverhaulAddonActive = isOverhaulAddonActive(levelName)
    print("isOverhaulAddonActive" .. levelName .. " " .. tostring(isOverhaulAddonActive))
    local gate = scenetree.findObject("switchTo_" .. levelName)
    if gate then
        gate:setHidden(not isOverhaulAddonActive)
        local index = 1
        while scenetree.findObject("gateBlock" .. levelName .. index) do
            print("gateBlock" .. levelName .. index)
            local block = scenetree.findObject("gateBlock" .. levelName .. index)
            if block then
                block:setField('collisionType', 0, 'None')
                block:setHidden(isOverhaulAddonActive)
            end
            index = index + 1
        end
    end
end

local function onWorldReadyState(state)
    if state == 2 and getCurrentLevelIdentifier() == "west_coast_usa" then
        setLevelGate("italy")
    end
end

local function onSetupInventoryFinished()
    if getCurrentLevelIdentifier() == "west_coast_usa" then
        setLevelGate("italy")
    end
end

local function onBeamNGTrigger(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID then
        return
    end
    if gameplay_walk.isWalking() then return end
    if career_career.isActive() and not career_modules_inventory.getInventoryIdFromVehicleId(data.subjectID) then return end
    if data.event ~= "exit" then
        return
    end
    local triggerName = data.triggerName
    
    if triggerName:match("^switchTo_") then
        local levelName = triggerName:sub(10)
        switchMap(levelName)
        return
    elseif triggerName:match("^setGate_") then
        local levelName = triggerName:sub(9)
        setLevelGate(levelName)
    end
end

M.onBeamNGTrigger = onBeamNGTrigger
M.onSetupInventoryFinished = onSetupInventoryFinished
M.onWorldReadyState = onWorldReadyState

return M