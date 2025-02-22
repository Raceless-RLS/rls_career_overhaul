local M = {}

local compatibleMaps = {"west_coast_usa"}

local function retrieveCompatibleMaps()
    extensions.hook("onGetMaps")
end

local function returnCompatibleMap(map)
    if not compatibleMaps[map] then
        table.insert(compatibleMaps, map)
    end
end

local function getCompatibleMaps()
    return compatibleMaps
end

M.onExtensionLoaded = retrieveCompatibleMaps
M.returnCompatibleMap = returnCompatibleMap
M.getCompatibleMaps = getCompatibleMaps

return M

