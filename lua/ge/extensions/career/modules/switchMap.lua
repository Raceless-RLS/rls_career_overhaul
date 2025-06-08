local M = {}


M.dependencies = {'career_career'}

local maps = {}

local function switchMap(levelName)
    local currentLevel = getCurrentLevelIdentifier()
    if currentLevel == levelName then return end
    gameplay_parking.resetAll()
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

local function setLevelGate(gateName)
    local availableMaps = careerMaps.getOtherAvailableMaps()
    if availableMaps[gateName] == {} then return end
    local gate = scenetree.findObject("switchTo_" .. gateName)
    if gate then
        gate:setHidden(false)
        local index = 1
        while scenetree.findObject("gateBlock" .. gateName .. index) do
            print("gateBlock" .. gateName .. index)
            local block = scenetree.findObject("gateBlock" .. gateName .. index)
            if block then
                block:setField('collisionType', 0, 'None')
                block:setHidden(true)
            end
            index = index + 1
        end
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
        simTimeAuthority.pause(true)
        guihooks.trigger('ChangeState', {state = 'level-switch'})
        return
    elseif triggerName:match("^setGate_") then
        local levelName = triggerName:sub(9)
        setLevelGate(levelName)
    end
end

local function loadMapData()
    if getCurrentLevelIdentifier() then
        local level = "levels/" .. getCurrentLevelIdentifier() .. "/map_data.json"
        local mapData = jsonReadFile(level)
        if mapData then
            maps = mapData.maps or {}
        end
        return deepcopy(maps)  
    end
    return {}
end

local function onWorldReadyState(state)
    if state == 2 then
        maps = loadMapData()
        if getCurrentLevelIdentifier() == "west_coast_usa" then
            setLevelGate("italy")
        end
    end
end

local function onExtensionLoaded()
    if getCurrentLevelIdentifier() then
        maps = loadMapData()
    end
    print("Switch Map Extension Loaded")
end

local function formatLevelGatePoi(level, levelName)
    if not careerMaps then return nil end

    local compatibleMaps = careerMaps.getCompatibleMaps()
    if not compatibleMaps[level] then return nil end

    local switchToObj = scenetree.findObject("switchTo_" .. level)
    local pos = switchToObj and switchToObj:getPosition() or nil
    
    if not pos then return nil end

    local levelIdentifier = getCurrentLevelIdentifier()
    local preview = "/levels/" .. levelIdentifier .. "/facilities/switchMap/" .. level .. ".jpg"

    return {
        id = level,
        data = {
            type = "travel",
            facility = {}
        },
        markerInfo = {
            bigmapMarker = {
                pos = pos,
                icon = "poi_fasttravel_round_orange_green",
                name = levelName,
                description = "Travel to " .. levelName,
                previews = {preview},
                thumbnail = preview
            }
        }
    }
end

function M.onGetRawPoiListForLevel(levelIdentifier, elements)
    for level, levelName in pairs(maps) do
        local poi = formatLevelGatePoi(level, levelName)
        if poi then
            table.insert(elements, poi)
        end
    end
end

M.switchMap = switchMap
M.onBeamNGTrigger = onBeamNGTrigger
M.onSetupInventoryFinished = onSetupInventoryFinished
M.onWorldReadyState = onWorldReadyState
M.onExtensionLoaded = onExtensionLoaded

return M