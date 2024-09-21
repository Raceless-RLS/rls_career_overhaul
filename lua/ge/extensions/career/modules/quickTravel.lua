-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local routePlanner = require('gameplay/route/route')()

local basePrice = 5
local pricePerM = 0.004

local function getDistanceToPoint(pos)
  routePlanner:setupPath(getPlayerVehicle(0):getPosition(), pos)
  return routePlanner.path[1].distToTarget
end

local function getPriceForQuickTravel(pos)
  local distance = getDistanceToPoint(pos)
  if distance < 300 then
    return 0, distance
  end
  return basePrice + round(distance * pricePerM * 100) / 100, distance
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

local function quickTravelToGarage(garagePoi)
  local garage = freeroam_facilities.getGarage(garagePoi.id)
  if not garage then return end
  local parkingSpots = freeroam_facilities.getParkingSpotsForFacility(garage)
  if parkingSpots[1] then
    quickTravelToPos(parkingSpots[1].pos, true, "Took a taxi to your garage")
  end
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