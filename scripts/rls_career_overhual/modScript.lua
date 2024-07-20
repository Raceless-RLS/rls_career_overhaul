local M = {}
M.dependencies = {"career_career"}

-- Store the original module
local originalCareerCareer = career_career

-- Load your mod's career.lua file
local myCareerPath = "ge.extensions.career.career"
local myCareer = require(myCareerPath)

-- Replace the entire module with your implementation
career_career = myCareer

-- If you need to keep some original functionality:
setmetatable(career_career, {__index = originalCareerCareer})

print("RLS Career Overhaul: Career module replaced with custom implementation")

local function reloadEverything()
    -- Reload Lua scripts
    extensions.refresh()
    
    -- Reload mods
    core_modmanager.initDB()
    
    -- Refresh UI
    guihooks.trigger('RefreshUI')
    
    -- Force update of game state
    core_gamestate.setGameState(core_gamestate.state.state, core_gamestate.state.mode)
    
    print("RLS Career Overhaul: Reloaded")
end

return M