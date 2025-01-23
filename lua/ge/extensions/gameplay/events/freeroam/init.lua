local M = {}

M.onInit = function()
    print("Initializing Freeroam Events")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_checkpointManager") then
        extensions.unload("gameplay_events_freeroam_checkpointManager")
    end
    extensions.load("gameplay_events_freeroam_checkpointManager")
    setExtensionUnloadMode("gameplay_events_freeroam_checkpointManager", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_activeAssets") then
        extensions.unload("gameplay_events_freeroam_activeAssets")
    end
    extensions.load("gameplay_events_freeroam_activeAssets")
    setExtensionUnloadMode("gameplay_events_freeroam_activeAssets", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_processRoad") then
        extensions.unload("gameplay_events_freeroam_processRoad")
    end
    extensions.load("gameplay_events_freeroam_processRoad")
    setExtensionUnloadMode("gameplay_events_freeroam_processRoad", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_leaderboardManager") then
        extensions.unload("gameplay_events_freeroam_leaderboardManager")
    end
    extensions.load("gameplay_events_freeroam_leaderboardManager")
    setExtensionUnloadMode("gameplay_events_freeroam_leaderboardManager", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_utils") then
        extensions.unload("gameplay_events_freeroam_utils")
    end
    extensions.load("gameplay_events_freeroam_utils")
    setExtensionUnloadMode("gameplay_events_freeroam_utils", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroamEvents") then
        extensions.unload("gameplay_events_freeroamEvents")
    end
    extensions.load("gameplay_events_freeroamEvents")
    setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")
    print("Freeroam Events Initialized")
end

return M