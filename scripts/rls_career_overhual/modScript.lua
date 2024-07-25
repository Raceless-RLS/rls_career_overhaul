local M = {}
M.dependencies = {"career_career"}

print("RLS Career Overhaul: activateCareer function overridden")

-- Load your mod's career.lua file
local myCareerPath = "ge.extensions.career.career"
local myCareer = require(myCareerPath)

local myBranchPath = "ge.extensions.career.branches"
local myBranch = require(myBranchPath)

local myTrafficPath = "ge.extensions.gameplay.traffic.vehicle"
local myTraffic = require(myTrafficPath)

-- Replace the entire module with your implementation
career_career = myCareer
career_branches = myBranch
gameplay_traffic_vehicle = myTraffic

print("RLS Career Overhaul: Career module replaced with custom implementation")

M.career_career = career_career
M.career_branches = career_branches
M.customActivateCareer = customActivateCareer
M.gameplay_traffic_vehicle = gameplay_traffic_vehicle
return M