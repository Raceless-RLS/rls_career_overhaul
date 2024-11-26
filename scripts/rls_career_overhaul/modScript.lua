-- Load core modules after the delay
extensions.unload("core_recoveryPrompt")
load("core/recoveryPrompt")
setExtensionUnloadMode("core_recoveryPrompt", "manual")

-- Load career modules
load("career/career")
setExtensionUnloadMode("career/career", "manual")

load("gameplay_events_freeroamEvents")
setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")

load("UIloader")
setExtensionUnloadMode("UIloader", "manual")