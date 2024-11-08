-- Load core modules first
reloadUI()

extensions.unload("core_recoveryPrompt")
load("core/recoveryPrompt")
setExtensionUnloadMode("core/recoveryPrompt", "manual")

-- Load career next since many modules depend on it
load("career/career")
setExtensionUnloadMode("career/career", "manual")