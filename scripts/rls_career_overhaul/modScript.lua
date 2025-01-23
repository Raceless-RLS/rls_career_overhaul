local function loadFRE() -- Loads all associated extensions for freeroam events
    if extensions.isExtensionLoaded("gameplay_events_freeroam_checkpointManager") then
        extensions.unload("gameplay_events_freeroam_checkpointManager")
    end
    load("gameplay_events_freeroam_checkpointManager")
    setExtensionUnloadMode("gameplay_events_freeroam_checkpointManager", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_activeAssets") then
        extensions.unload("gameplay_events_freeroam_activeAssets")
    end
    load("gameplay_events_freeroam_activeAssets")
    setExtensionUnloadMode("gameplay_events_freeroam_activeAssets", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_leaderboardManager") then
        extensions.unload("gameplay_events_freeroam_leaderboardManager")
    end
    load("gameplay_events_freeroam_leaderboardManager")
    setExtensionUnloadMode("gameplay_events_freeroam_leaderboardManager", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_processRoad") then
        extensions.unload("gameplay_events_freeroam_processRoad")
    end
    load("gameplay_events_freeroam_processRoad")
    setExtensionUnloadMode("gameplay_events_freeroam_processRoad", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroamEvents") then
        extensions.unload("gameplay_events_freeroamEvents")
    end
    load("gameplay_events_freeroamEvents")
    setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")
end

local function loadExtensions()
    print("Starting extension loading sequence")
    
    if extensions.isExtensionLoaded("core_recoveryPrompt") then
        extensions.unload("core_recoveryPrompt")
    end
    load("core_recoveryPrompt")
    setExtensionUnloadMode("core_recoveryPrompt", "manual")

    loadFRE()

    if extensions.isExtensionLoaded("career_career") then
        extensions.unload("career_career")
    end
    load("career_career")
    setExtensionUnloadMode("career_career", "manual")

    if extensions.isExtensionLoaded("UIloader") then
        extensions.unload("UIloader")
    end
    load("UIloader")
    setExtensionUnloadMode("UIloader", "manual")
end

if not core_gamestate.state or core_gamestate.state.state ~= "career" then
    loadExtensions()
end