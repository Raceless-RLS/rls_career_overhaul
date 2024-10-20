-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

-- Dependencies
M.dependencies = {'career_career', 'util_configListGenerator', 'gameplay_parking', 'freeroam_facilities',
                  'gameplay_sites_sitesManager', 'gameplay_walk', 'core_groundMarkers', 'career_modules_valueCalculator'}

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
    self.startedJob = false
    self.completed = false
    self.countdown = nil
    self.totalDistance = 0
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
    self.startedJob = false
    self.completed = false
    self.countdown = nil
    self.totalDistance = 0
    print('[repo] VehicleRepoJob instance has been destroyed.')
end

function VehicleRepoJob:generateJob()
    self:spawnVehicle()
end

function VehicleRepoJob:spawnVehicle()
    print('[repo] spawnVehicle() called')

    -- Get the player's current vehicle and position
    local playerVehicle = be:getPlayerVehicle(0)
    self.repoVehicle = playerVehicle
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

    -- Get all dealerships and select one randomly
    local facilities = freeroam_facilities.getFacilities(getCurrentLevelIdentifier())
    local dealerships = facilities.dealerships
    if not dealerships or #dealerships == 0 then
        print('[repo] Error: No dealerships found.')
        return
    end
    self.selectedDealership = dealerships[math.random(#dealerships)]
    print('[repo] Selected dealership: ' .. self.selectedDealership.name)

    -- Determine the delivery spot
    self.deliverySpot = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(nil,
        freeroam_facilities.getParkingSpotsForFacility(self.selectedDealership))

    -- Filter parking spots based on distance criteria
    local validSpots = {}
    for _, spot in pairs(parkingSpots.objects) do
        if spot.pos and not spot.vehicle then
            local distanceFromPlayer = (spot.pos - playerPos):length()
            local distanceFromDestination = (spot.pos - self.deliverySpot.pos):length()
            if distanceFromPlayer >= 300 and distanceFromDestination >= 600 then
                table.insert(validSpots, spot)
            end
        end
    end

    if #validSpots == 0 then
        print('[repo] Warning: No valid parking spots found.')
        return
    end

    -- Select a random valid parking spot
    local nearestSpot = validSpots[math.random(#validSpots)]
    print('[repo] Selected parking spot at position: ' .. tostring(nearestSpot.pos))

    -- Generate a random vehicle configuration based on the dealership's filters
    local eligibleVehicles = configListGenerator.getEligibleVehicles(false, false)
    local randomVehicleInfos = configListGenerator.getRandomVehicleInfos(self.selectedDealership, 1, eligibleVehicles,
        "adjustedPopulation")
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
        baseColor = {math.random(), math.random(), math.random(), 1},
        metallic = false
    }
    -- Ensure parking brake is off when vehicle spawns
    spawnOptions.electrics = {
        parkingbrake = 0
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
    self.monitoring = true

    -- Set initial path to the parking spot
    core_groundMarkers.setPath(nearestSpot.pos)
    self.totalDistance = core_groundMarkers.getPathLength()

    print('[repo] Total distance: ' .. tostring(self.totalDistance))

    self.vehInfo = randomVehicleInfo
    -- Display the custom message to the player
    ui_message("New Repo Job Available!\nSomeone missed a payment on their \n" .. randomVehicleInfo.Brand .. " " ..
                   randomVehicleInfo.Name .. ".\nPick it up for a reward.", 10, "info", "info")
    print('[repo] Displayed message to the player.')
end

function VehicleRepoJob:onVehicleSwitched(oldId, newId)
    if core_vehicles.getVehicleLicenseText(be:getObjectByID(newId)) == "repo" then
        self.repoVehicle = be:getObjectByID(newId)
        if not self.startedJob then
            self:destroy()
            self:generateJob()
        end
    end
end

function VehicleRepoJob:calculateReward()
    print('[repo] calculateReward() called')
    print('[repo] Total distance: ' .. tostring(self.totalDistance))
    print('[repo] Vehicle value: ' .. tostring(self.vehicleValue))
    print('[repo] Time taken: ' .. tostring(os.time() - self.jobStartTime))
    return math.floor(self.vehicleValue * 24) / 100
end

function VehicleRepoJob:onUpdate(dtReal, dtSim, dtRaw)
    if self.completed then
        self:destroy()
        return
    end

    if not self.monitoring or not self.vehicleId then
        return
    end

    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then
        return
    end

    local playerPos = playerVehicle:getPosition()
    local vehicle = be:getObjectByID(self.vehicleId)
    if not vehicle then
        return
    end

    local vehiclePos = vehicle:getPosition()
    local repoPos = self.repoVehicle:getPosition()
    local distance = (vehiclePos - repoPos):length()

    if not self.startedJob then
        if distance <= 20 then
            self.startedJob = true
            ui_message("Pick up the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nPlease drive it to " .. self.selectedDealership.name .. ".", 10, "info", "info")
            vehicle:queueLuaCommand('input.event("parkingbrake", 0, "FILTER_DI", nil, nil, nil, nil)')
            core_groundMarkers.setPath(self.deliverySpot.pos)
        end
    else
        if distance > 100 then
            if not self.countdown then
                self.countdown = 15
            else
                ui_message("You have " .. math.floor(self.countdown) .. " seconds to return the  " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 1, "info", "info")
                self.countdown = self.countdown - dtSim
                if self.countdown <= 0 then
                    self:destroy()
                    return
                end
            end
        else
            if self.countdown then
                ui_message("You have returned the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 3, "info", "info")
                self.countdown = nil
                local vehiclePos = vehicle:getPosition()
                core_groundMarkers.setPath(vehiclePos)
                self.startedJob = false
            end
        end
    end

    if self.jobStartTime then
        local distanceFromDestination = (vehiclePos - self.deliverySpot.pos):length()
        local velocity = vehicle:getVelocity():length()
        if distanceFromDestination <= 2 and velocity <= 1 then
            --Reward should be a combination of Vehicle Value, Time Taken, and Distance Traveled.
            local reward = self:calculateReward()
            ui_message("You've Dropped Off a " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nYou have been paid $" .. tostring(reward) .. ".", 10, "info", "info")
            career_modules_payment.reward({
                money = {
                    amount = reward
                },
                beamXP = {
                    amount = math.floor(reward / 20)
                },
                laborer = {
                    amount = math.floor(reward / 20)
                }
            }, {
                label = "You've Dropped Off a " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nYou have been paid $" .. reward,
                tags = {"gameplay", "reward", "laborer"}
            })
            career_saveSystem.saveCurrent()
            self.startedJob = false
            self.completed = true
            self.monitoring = false
            core_vehicleBridge.executeAction(vehicle, 'setFreeze', true)
        elseif distanceFromDestination <= 10 then
            ui_message("You've arrived at the dealership.\nPlease return the vehicle to the parking spot.", 10, "info", "info")
        end
    end

    
    if self.jobStartTime and playerVehicle:getID() == self.vehicleId then
        if distance > 25 then
            vehicle:queueLuaCommand([[
            if electrics.values.ignition then
              electrics.setIgnitionLevel(0)
            end
          ]])
            print('[repo] Vehicle moved more than 25 meters from repo vehicle. Ignition turned off.')
        end
    end

    if distance <= 15 and not self.jobStartTime then
        local velocity = vehicle:getVelocity():length()
        if velocity > 2 then
            self.jobStartTime = os.time()
            core_groundMarkers.setPath(self.deliverySpot.pos)
            self.totalDistance = self.totalDistance + core_groundMarkers.getPathLength()
            print('[repo] Total distance: ' .. tostring(self.totalDistance))
            print('[repo] Vehicle is moving. Path set to delivery spot.')
        end
    end
end

-- Export the class
M.VehicleRepoJob = VehicleRepoJob

return M
