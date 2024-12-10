-- Load core modules after the delay
if extensions.isExtensionLoaded("core_recoveryPrompt") then
    extensions.unload("core_recoveryPrompt")
    load("core/recoveryPrompt")
else
    load("core/recoveryPrompt")
end
setExtensionUnloadMode("core_recoveryPrompt", "manual")

-- Load career modules
if extensions.isExtensionLoaded("career/career") then
    extensions.unload("career/career")
    load("career/career")
else
    load("career/career")
end
setExtensionUnloadMode("career/career", "manual")

if extensions.isExtensionLoaded("gameplay_events_freeroamEvents") then
    extensions.unload("gameplay_events_freeroamEvents")
    load("gameplay_events_freeroamEvents")
else
    load("gameplay_events_freeroamEvents")
end
setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")

if extensions.isExtensionLoaded("UIloader") then
    extensions.unload("UIloader")
    load("UIloader")
else
    load("UIloader")
end
setExtensionUnloadMode("UIloader", "manual")