local function loadExtensions()
    print("Starting extension loading sequence")
    
    setExtensionUnloadMode("core_recoveryPrompt", "manual")
    extensions.unload("core_recoveryPrompt")

    setExtensionUnloadMode("core_gameContext", "manual")

    setExtensionUnloadMode("gameplay_events_freeroam_init", "manual")

    setExtensionUnloadMode("career_career", "manual")
    extensions.unload("career_career")

    setExtensionUnloadMode("gameplay_phone", "manual")

    setExtensionUnloadMode("freeroam_facilities", "manual")

    setExtensionUnloadMode("gameplay_repo", "manual")

    setExtensionUnloadMode("gameplay_taxi", "manual")
end

setExtensionUnloadMode("careerMaps", "manual")


if not core_gamestate.state or core_gamestate.state.state ~= "career" then
    loadExtensions()
end

setExtensionUnloadMode("UIloader", "manual")
extensions.unload("UIloader")

loadManualUnloadExtensions()