local M = {}
M.dependencies = {"career_career", "gameplay_missions"}

print("RLS Career Overhaul: activateCareer function overridden")

-- Load your mod's career.lua file
local myCareerPath = "ge.extensions.career.career"
local myCareer = require(myCareerPath)

--local myBranchPath = "ge.extensions.career.branches"
--local myBranch = require(myBranchPath)

local myProgressPath = "ge.extensions.gameplay.missions.progress"
local myProgress = require(myProgressPath)

-- Replace the entire module with your implementation
career_career = myCareer
--career_branches = myBranch
M.gameplay_missions_progress = myProgress

print("RLS Career Overhaul: Career module replaced with custom implementation")

M.career_career = career_career
--M.career_branches = career_branches
M.customActivateCareer = customActivateCareer
M.gameplay_missions_progress = gameplay_missions_progress
return M