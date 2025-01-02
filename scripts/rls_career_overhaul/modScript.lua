local function loadExtensions()
    print("Starting extension loading sequence")
    
    if extensions.isExtensionLoaded("core_recoveryPrompt") then
        extensions.unload("core_recoveryPrompt")
    end
    load("core/recoveryPrompt")
    setExtensionUnloadMode("core_recoveryPrompt", "manual")

    if extensions.isExtensionLoaded("career/career") then
        extensions.unload("career/career")
    end
    load("career/career")
    setExtensionUnloadMode("career/career", "manual")

    if extensions.isExtensionLoaded("UIloader") then
        extensions.unload("UIloader")
    end
    load("UIloader")
    setExtensionUnloadMode("UIloader", "manual")

    if extensions.isExtensionLoaded("gameplay_events_freeroamEvents") then
        extensions.unload("gameplay_events_freeroamEvents")
    end
    load("gameplay_events_freeroamEvents")
    setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")
end

if not core_gamestate.state or core_gamestate.state.state ~= "career" then
    loadExtensions()
end