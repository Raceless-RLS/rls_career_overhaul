-- Load core modules first
extensions.unload("core_recoveryPrompt")
load("core/recoveryPrompt")
setExtensionUnloadMode("core/recoveryPrompt", "manual")

-- Load career next since many modules depend on it
load("career/career")
setExtensionUnloadMode("career/career", "manual")

-- Then load other modules
load("gameplay/events/freeroamEvents")
setExtensionUnloadMode("gameplay/events/freeroamEvents", "manual")

load("freeroam/freeroam")
setExtensionUnloadMode("freeroam/freeroam", "manual")

load("freeroam/facilities")
setExtensionUnloadMode("freeroam/facilities", "manual")

load("gameplay/markers/walkingMarkers")
setExtensionUnloadMode("gameplay/markers/walkingMarkers", "manual")