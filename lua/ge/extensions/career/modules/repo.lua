-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- Dependencies
M.dependencies = {
  'career_career',
  'util_configListGenerator',
  'gameplay_parking',
}

-- Require necessary modules
local configListGenerator = require('util.configListGenerator')
local parking = require('gameplay.parking')
local career_career = require('career.career')

-- Function to spawn a random vehicle at the nearest parking spot
local function spawnVehicleAtParkingSpot()
  print('[repo] spawnVehicleAtParkingSpot() called')

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

  -- Generate eligible vehicle configurations
  local eligibleVehicles = configListGenerator.getEligibleVehicles(false, false)
  if not eligibleVehicles or #eligibleVehicles == 0 then
    print('[repo] Error: No eligible vehicles found.')
    return
  end
  print('[repo] Total eligible vehicles: ' .. tostring(#eligibleVehicles))

  -- Select an ETK 800 series vehicle
  local vehicleModel = 'etk800' -- ETK 800 series model key
  local vehicleConfigs = {}
  for _, vehicleInfo in ipairs(eligibleVehicles) do
    if vehicleInfo.model_key == vehicleModel then
      table.insert(vehicleConfigs, vehicleInfo)
    end
  end

  if #vehicleConfigs == 0 then
    print('[repo] Error: No eligible ETK 800 vehicles found.')
    return
  end
  print('[repo] Total ETK 800 configurations: ' .. tostring(#vehicleConfigs))

  local randomVehicleInfo = vehicleConfigs[math.random(#vehicleConfigs)]
  local vehicleConfig = randomVehicleInfo.key
  print('[repo] Selected vehicle config: ' .. vehicleConfig)

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
  local newVeh = core_vehicles.spawnNewVehicle(vehicleModel, spawnOptions)
  if not newVeh then
    print('[repo] Error: Failed to spawn vehicle.')
    return
  end

  print('[repo] Vehicle spawned with ID: ' .. tostring(newVeh:getID()))

  -- Ensure the parking brake is released
  print('[repo] Releasing parking brake on spawned vehicle.')
  newVeh:queueLuaCommand('input.event("parkingbrake", 0, "FILTER_DI", nil, nil, nil, nil)')

  -- Turn off the ignition to prevent driving
  print('[repo] Turning off ignition on spawned vehicle.')
  newVeh:queueLuaCommand('electrics.setIgnitionLevel(0)')

  -- Mark the spot as occupied
  nearestSpot.vehicle = newVeh:getID()
  print('[repo] Marked parking spot as occupied.')

  -- Display the custom message to the player
  ui_message("New Repo Job Available!\nSomeone missed a payment on their ETK 800.\nPick it up for a reward.", 10, "info", "info")
  print('[repo] Displayed message to the player.')
end

-- Export the function
M.spawnVehicleAtParkingSpot = spawnVehicleAtParkingSpot

return M