local M = {}
M.dependencies = {"career_career"}

-- Store the original module
local originalCareerCareer = career_career

print("RLS Career Overhaul: activateCareer function overridden")

-- Load your mod's career.lua file
local myCareerPath = "ge.extensions.career.career"
local myCareer = require(myCareerPath)

-- Replace the entire module with your implementation
career_career = myCareer

-- If you need to keep some original functionality:setmetatable(career_career, {__index = originalCareerCareer})

print("RLS Career Overhaul: Career module replaced with custom implementation")

M.career_career = career_career
M.customActivateCareer = customActivateCareer
return M