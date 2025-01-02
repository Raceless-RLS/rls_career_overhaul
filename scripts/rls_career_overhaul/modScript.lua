-- Store career state before unloading
local wasCareerActive = false
local previousSaveSlot = nil

-- Check if we were in career mode before Lua reset
local gameState = core_gamestate.state
if gameState and gameState.state == "career" then
    print("Detected previous career state from game state")
    wasCareerActive = true
    previousSaveSlot = career_saveSystem.getCurrentSaveSlot()
    print("Found previous save slot:" .. tostring(previousSaveSlot))
end

-- Register extension loaded callback before loading extensions
local function onExtensionLoaded(name)
    if name == "career/career" and wasCareerActive and previousSaveSlot then
        print("Career extension loaded, attempting to reload career with save slot:" .. tostring(previousSaveSlot))
        career_career.createOrLoadCareerAndStart(previousSaveSlot)
    end
end

-- Register the callback
extensions.hookAny("onExtensionLoaded", onExtensionLoaded)

if extensions.isExtensionLoaded("career/career") then
    extensions.unload("career/career")
    load("career/career")
else
    load("career/career")
end
setExtensionUnloadMode("career/career", "manual")

if extensions.isExtensionLoaded("UIloader") then
    extensions.unload("UIloader")
    load("UIloader")
else
    load("UIloader")
end
setExtensionUnloadMode("UIloader", "manual")

if extensions.isExtensionLoaded("gameplay_events_freeroamEvents") then
    extensions.unload("gameplay_events_freeroamEvents")
    load("gameplay_events_freeroamEvents")
else
    load("gameplay_events_freeroamEvents")
end
setExtensionUnloadMode("gameplay_events_freeroamEvents", "manual")

if extensions.isExtensionLoaded("core_recoveryPrompt") then
    extensions.unload("core_recoveryPrompt")
    load("core/recoveryPrompt")
else
    load("core/recoveryPrompt")
end
setExtensionUnloadMode("core_recoveryPrompt", "manual")