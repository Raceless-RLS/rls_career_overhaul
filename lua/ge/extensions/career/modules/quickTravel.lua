-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local routePlanner = require('gameplay/route/route')()

local basePrice = 50
local pricePerM = 0.16

local function getDistanceToPoint(pos)
  routePlanner:setupPath(getPlayerVehicle(0):getPosition(), pos)
  return routePlanner.path[1].distToTarget
end

local function getPriceForQuickTravel(pos)
  local distance = getDistanceToPoint(pos)
  if distance < 300 then
    return basePrice
  end
  return basePrice + round(distance * pricePerM * 100) / 100
end

local function turnTowardsPos(pos)
  core_vehicleBridge.requestValue(getPlayerVehicle(0), function()
    gameplay_walk.setRot(pos - getPlayerVehicle(0):getPosition())
  end , 'ping')
end

local function quickTravelToPos(pos, useWalkingMode, reasonString)
  local price = getPriceForQuickTravel(pos)
  if career_modules_playerAttributes.getAttributeValue("money") < price then return end
  if useWalkingMode then
    gameplay_walk.setWalkingMode(true)
    spawn.safeTeleport(getPlayerVehicle(0), pos)
    turnTowardsPos(pos)
  end
  -- TODO if we want to quicktravel with the vehicle, then we need to set the partcondition reset point first
  career_modules_playerAttributes.addAttributes({money=-price}, {tags={"quickTravel","buying"}, label=(reasonString or "Paid for Quicktraveling")})
end

local function quickTravelToGarage(garage)
  local pos, rot = freeroam_facilities.getGaragePosRot(garage)
  quickTravelToPos(pos, true, "Took a taxi to your garage")
end

local function getPriceForQuickTravelToGarage(garage)
  local pos, rot = freeroam_facilities.getGaragePosRot(garage)
  return getPriceForQuickTravel(pos)
end

M.quickTravelToPos = quickTravelToPos
M.quickTravelToGarage = quickTravelToGarage
M.getPriceForQuickTravel = getPriceForQuickTravel
M.getPriceForQuickTravelToGarage = getPriceForQuickTravelToGarage

return M