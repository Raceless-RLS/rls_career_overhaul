local function loadExtensions()
    print("Starting extension loading sequence")
    
    if extensions.isExtensionLoaded("core_recoveryPrompt") then
        extensions.unload("core_recoveryPrompt")
    end
    extensions.load("core_recoveryPrompt")
    setExtensionUnloadMode("core_recoveryPrompt", "manual")

    if extensions.isExtensionLoaded("core_gameContext") then
        extensions.unload("core_gameContext")
    end
    extensions.load("core_gameContext")
    setExtensionUnloadMode("core_gameContext", "manual")

    if extensions.isExtensionLoaded("gameplay_traffic_vehicle") then
        extensions.unload("gameplay_traffic_vehicle")
    end
    extensions.load("gameplay_traffic_vehicle")
    setExtensionUnloadMode("gameplay_traffic_vehicle", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroam_init") then
        extensions.unload("gameplay_events_freeroam_init")
    end
    extensions.load("gameplay_events_freeroam_init")
    setExtensionUnloadMode("gameplay_events_freeroam_init", "manual")

    if extensions.isExtensionLoaded("career_saveSystem") then
        extensions.unload("career_saveSystem")
    end
    extensions.load("career_saveSystem")
    setExtensionUnloadMode("career_saveSystem", "manual")

    if extensions.isExtensionLoaded("career_career") then
        extensions.unload("career_career")
    end
    extensions.load("career_career")
    setExtensionUnloadMode("career_career", "manual")

    if extensions.isExtensionLoaded("gameplay_phone") then
        extensions.unload("gameplay_phone")
    end
    extensions.load("gameplay_phone")
    setExtensionUnloadMode("gameplay_phone", "manual")

    if extensions.isExtensionLoaded("freeroam_facilities") then
        extensions.unload("freeroam_facilities")
    end
    extensions.load("freeroam_facilities")
    setExtensionUnloadMode("freeroam_facilities", "manual")

    if extensions.isExtensionLoaded("gameplay_repo") then
        extensions.unload("gameplay_repo")
    end
    extensions.load("gameplay_repo")
    setExtensionUnloadMode("gameplay_repo", "manual")
end

if extensions.isExtensionLoaded("careerMaps") then
    extensions.unload("careerMaps")
end
extensions.load("careerMaps")
setExtensionUnloadMode("careerMaps", "manual")

if extensions.isExtensionLoaded("util_richPresence") then
    extensions.unload("util_richPresence")
end
extensions.load("util_richPresence")
setExtensionUnloadMode("util_richPresence", "manual")

if extensions.isExtensionLoaded("freeroam_generateLights") then
    extensions.unload("freeroam_generateLights")
end
extensions.load("freeroam_generateLights")
setExtensionUnloadMode("freeroam_generateLights", "manual")

if extensions.isExtensionLoaded("editor_lightGenerationEditor") then
    extensions.unload("editor_lightGenerationEditor")
end
extensions.load("editor_lightGenerationEditor")
setExtensionUnloadMode("editor_lightGenerationEditor", "manual")

if not core_gamestate.state or core_gamestate.state.state ~= "career" then
    loadExtensions()
end

if extensions.isExtensionLoaded("UIloader") then
    extensions.unload("UIloader")
end
extensions.load("UIloader")
setExtensionUnloadMode("UIloader", "manual")