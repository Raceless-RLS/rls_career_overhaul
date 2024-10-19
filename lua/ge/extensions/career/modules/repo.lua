-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- Dependencies
M.dependencies = {
  'career_career',
  'util_configListGenerator',
  'gameplay_parking',
  'freeroam_facilities',
  'gameplay_sites_sitesManager',
  'gameplay_walk',
  'core_groundMarkers',
  'career_modules_valueCalculator',
}

-- Require necessary modules
local configListGenerator = require('util.configListGenerator')
local parking = require('gameplay.parking')
local career_career = require('career.career')
local freeroam_facilities = require('freeroam.facilities')
local gameplay_sites_sitesManager = require('gameplay.sites.sitesManager')
local gameplay_walk = require('gameplay.walk')
local valueCalculator = require('career.modules.valueCalculator')

local VehicleRepoJob = {}
VehicleRepoJob.__index = VehicleRepoJob

function VehicleRepoJob:new()
  local self = setmetatable({}, VehicleRepoJob)
  self.vehicleId = nil
  self.vehicleValue = nil
  self.pickupSpot = nil
  self.deliverySpot = nil
  self.jobStartTime = nil
  self.monitoring = false
  self.selectedDealership = nil
  return self
end

function VehicleRepoJob:destroy()
    if self.vehicleId then
      local vehicle = be:getObjectByID(self.vehicleId)
      if vehicle then
        vehicle:delete()
        print('[repo] Vehicle with ID ' .. tostring(self.vehicleId) .. ' has been removed.')
      end
    end
  
    -- Clear all data associated with this job
    self.vehicleId = nil
    self.vehicleValue = nil
    self.pickupSpot = nil
    self.deliverySpot = nil
    self.jobStartTime = nil
    self.monitoring = false
    self.selectedDealership = nil
  print('[repo] VehicleRepoJob instance has been destroyed.')
end

function VehicleRepoJob:generateJob()
  self:spawnVehicle()
end

function VehicleRepoJob:spawnVehicle()
  print('[repo] spawnVehicle() called')

  -- Get the player's current vehicle and position
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then
    print('[repo] Error: Player vehicle not found.')
    return
  end
  local playerPos = playerVehicle:getPosition()
  print('[repo] Player position: ' .. tostring(playerPos))

  -- Get available parking spots
  local parkingSpots = parking.getParkingSpots()
  if not parkingSpots or not parkingSpots.objects then
    print('[repo] Error: Parking spots not available.')
    return
  end
  print('[repo] Total parking spots: ' .. tostring(#parkingSpots.objects))

  -- Find the nearest parking spot that is not occupied
  local nearestSpot = nil
  local shortestDistance = math.huge
  for _, spot in pairs(parkingSpots.objects) do
    if spot.pos and not spot.vehicle then
      local distance = (spot.pos - playerPos):length()
      if distance < shortestDistance then
        nearestSpot = spot
        shortestDistance = distance
      end
    end
  end

  if not nearestSpot then
    print('[repo] Warning: No available parking spots found.')
    return
  end

  print('[repo] Nearest parking spot found at distance: ' .. tostring(shortestDistance))
  print('[repo] Parking spot position: ' .. tostring(nearestSpot.pos))

  -- Get all dealerships and select one randomly
  local facilities = freeroam_facilities.getFacilities(getCurrentLevelIdentifier())
  local dealerships = facilities.dealerships
  if not dealerships or #dealerships == 0 then
    print('[repo] Error: No dealerships found.')
    return
  end
  self.selectedDealership = dealerships[math.random(#dealerships)]
  print('[repo] Selected dealership: ' .. self.selectedDealership.name)

  -- Generate a random vehicle configuration based on the dealership's filters
  local eligibleVehicles = configListGenerator.getEligibleVehicles(false, false)
  local randomVehicleInfos = configListGenerator.getRandomVehicleInfos(self.selectedDealership, 1, eligibleVehicles, "adjustedPopulation")
  if not randomVehicleInfos or #randomVehicleInfos == 0 then
    print('[repo] Error: No vehicles could be generated for the selected dealership.')
    return
  end

  local randomVehicleInfo = randomVehicleInfos[1]
  local vehicleConfig = randomVehicleInfo.key
  print('[repo] Selected vehicle config: ' .. vehicleConfig)

  -- Ensure the year and mileage are set
  local years = randomVehicleInfo.Years or randomVehicleInfo.aggregates.Years
  randomVehicleInfo.year = years and math.random(years.min, years.max) or 2023

  local filter = randomVehicleInfo.filter
  if filter.whiteList and filter.whiteList.Mileage then
    randomVehicleInfo.Mileage = math.random(filter.whiteList.Mileage.min, filter.whiteList.Mileage.max)
  else
    randomVehicleInfo.Mileage = 0
  end

  -- Calculate the vehicle's value
  local vehicleValue = valueCalculator.getAdjustedVehicleBaseValue(randomVehicleInfo.Value, {
    mileage = randomVehicleInfo.Mileage,
    age = 2023 - randomVehicleInfo.year
  })
  print('[repo] Vehicle value: ' .. tostring(vehicleValue))

  -- Prepare the spawn options
  local spawnOptions = {}
  spawnOptions.config = vehicleConfig
  spawnOptions.autoEnterVehicle = false
  spawnOptions.pos = nearestSpot.pos
  spawnOptions.rot = nearestSpot.rot or quat(0, 0, 0, 1)
  spawnOptions.cling = true
  spawnOptions.paint = {
    baseColor = { math.random(), math.random(), math.random(), 1 },
    metallic = false,
  }
  -- Ensure parking brake is off when vehicle spawns
  spawnOptions.electrics = {
    parkingbrake = 0,
  }

  print('[repo] Spawning vehicle at position: ' .. tostring(spawnOptions.pos))
  local newVeh = core_vehicles.spawnNewVehicle(randomVehicleInfo.model_key, spawnOptions)
  if not newVeh then
    print('[repo] Error: Failed to spawn vehicle.')
    return
  end

  print('[repo] Vehicle spawned with ID: ' .. tostring(newVeh:getID()))
  print('[repo] Selected dealership: ' .. self.selectedDealership.name)
  print('[repo] Vehicle value: ' .. tostring(vehicleValue))

  -- Save vehicle data for later use
  self.vehicleId = newVeh:getID()
  self.vehicleValue = vehicleValue
  self.pickupSpot = nearestSpot.pos
  self.deliverySpot = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(newVeh:getID(), freeroam_facilities.getParkingSpotsForFacility(self.selectedDealership))
  self.monitoring = true

  -- Set initial path to the parking spot
  core_groundMarkers.setPath(nearestSpot.pos)

  -- Turn off the parking brake
  newVeh:queueLuaCommand('input.event("parkingbrake", 0, "FILTER_DI", nil, nil, nil, nil)')

  -- Display the custom message to the player
  ui_message("New Repo Job Available!\nSomeone missed a payment on their \n" .. randomVehicleInfo.Brand .. " " .. randomVehicleInfo.Name .. ".\nPick it up for a reward.", 10, "info", "info")
  print('[repo] Displayed message to the player.')
end



function VehicleRepoJob:onUpdate()
  if not self.monitoring or not self.vehicleId then return end

  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then return end

  local playerPos = playerVehicle:getPosition()
  local vehicle = be:getObjectByID(self.vehicleId)
  if not vehicle then return end

  local vehiclePos = vehicle:getPosition()
  local distance = (vehiclePos - playerPos):length()

  if distance <= 10 and not self.jobStartTime then
    self.jobStartTime = os.time()
    print('[repo] Job started at time: ' .. tostring(self.jobStartTime))
  end

  if distance <= 10 then
    local velocity = vehicle:getVelocity():length()
    print("velocity" .. velocity)
    if velocity > 1 then
      self.monitoring = false
      core_groundMarkers.setPath(self.deliverySpot.pos)
      ui_message('Please Deliver the Vehicle to ' .. self.selectedDealership.name, 10, "info", "info")
    end
  end
end

-- Export the class
M.VehicleRepoJob = VehicleRepoJob

return M