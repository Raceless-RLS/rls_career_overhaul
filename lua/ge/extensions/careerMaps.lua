local M = {}

local compatibleMaps = {
    ["west_coast_usa"] = "West Coast USA"
}

local function retrieveCompatibleMaps()
    compatibleMaps = {
        ["west_coast_usa"] = "West Coast USA"
    }
    extensions.hook("onGetMaps")
end

local function returnCompatibleMap(maps)
    for map, mapName in pairs(maps) do
        if not compatibleMaps[map] then
            compatibleMaps[map] = mapName
        end
    end
end

local function getCompatibleMaps()
    return compatibleMaps
end

local function getOtherAvailableMaps()
    local maps = {}
    local currentMap = getCurrentLevelIdentifier()
    for map, mapName in pairs(compatibleMaps) do
        if map ~= currentMap then
            maps[map] = mapName
        end
    end
    return maps
end

local function enableMapSwitching()
    guihooks.trigger('ChangeState', {state = 'switchMap', params = {maps = getOtherAvailableMaps()}})
end

M.onExtensionLoaded = retrieveCompatibleMaps
M.onModActivated = retrieveCompatibleMaps
M.onModDeactivated = retrieveCompatibleMaps

M.returnCompatibleMap = returnCompatibleMap
M.getCompatibleMaps = getCompatibleMaps
M.getOtherAvailableMaps = getOtherAvailableMaps

return M

