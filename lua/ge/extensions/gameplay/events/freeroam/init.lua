local M = {}

M.onInit = function()
    print("Initializing Freeroam Events")

    setExtensionUnloadMode("gameplay_events_freeroam_checkpointManager", "manual")

    setExtensionUnloadMode("gameplay_events_freeroam_activeAssets", "manual")

    setExtensionUnloadMode("gameplay_events_freeroam_processRoad", "manual")

    setExtensionUnloadMode("gameplay_events_freeroam_leaderboardManager", "manual")

    setExtensionUnloadMode("gameplay_events_freeroam_utils", "manual")

    setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")
    print("Freeroam Events Initialized")
end

return M