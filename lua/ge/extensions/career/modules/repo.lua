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
local freeroam_facilities = require('freeroam.facilities')
local gameplay_sites_sitesManager = require('gameplay.sites.sitesManager')
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
            --print('[repo] Vehicle with ID ' .. tostring(self.vehicleId) .. ' has been removed.')
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
    --print('[repo] VehicleRepoJob instance has been destroyed.')
end

function VehicleRepoJob:generateJob() -- Call this to generate a new job
    -- Start the coroutine for job generation
    self.jobCoroutine = coroutine.create(function()
        self:initializePlayerVehicle()
        for i = 1, 25 do
            coroutine.yield()
        end

        self:findParkingSpots()
        for i = 1, 25 do
            coroutine.yield()
        end

        self:selectDealership()
        for i = 1, 25 do
            coroutine.yield()
        end

        self:determineDeliverySpot()
        for i = 1, 25 do
            coroutine.yield()
        end

        self:filterValidSpots()
        for i = 1, 25 do
            coroutine.yield()
        end
        self:selectRandomSpot()
        for i = 1, 25 do
            coroutine.yield()
        end
        self:generateVehicleConfig()
        for i = 1, 25 do
            coroutine.yield()
        end
        local playerVelocity = be:getPlayerVehicle(0):getVelocity():length()
        while not self.spawnedVehicle and playerVelocity <= 1 do
            coroutine.yield()
            playerVelocity = be:getPlayerVehicle(0):getVelocity():length()
        end
        if not self.spawnedVehicle then
            self:spawnVehicle()
            self.spawnedVehicle = true
        end
    end)
end

function VehicleRepoJob:initializePlayerVehicle()
    --print('[repo] Initializing player vehicle...')
    local playerVehicle = be:getPlayerVehicle(0)
    self.repoVehicle = playerVehicle
    if not playerVehicle then
        --print('[repo] Error: Player vehicle not found.')
        return
    end
    self.playerPos = playerVehicle:getPosition()
    --print('[repo] Player position: ' .. tostring(self.playerPos))
end

function VehicleRepoJob:findParkingSpots()
    --print('[repo] Finding parking spots...')
    self.parkingSpots = parking.getParkingSpots()
    if not self.parkingSpots or not self.parkingSpots.objects then
        --print('[repo] Error: Parking spots not available.')
        return
    end
    --print('[repo] Total parking spots: ' .. tostring(#self.parkingSpots.objects))
end

function VehicleRepoJob:selectDealership()
    --print('[repo] Selecting dealership...')
    local facilities = freeroam_facilities.getFacilities(getCurrentLevelIdentifier())
    local dealerships = facilities.dealerships
    if not dealerships or #dealerships == 0 then
        --print('[repo] Error: No dealerships found.')
        return
    end
    self.selectedDealership = dealerships[math.random(#dealerships)]
    --print('[repo] Selected dealership: ' .. self.selectedDealership.name)
end

function VehicleRepoJob:determineDeliverySpot()
    --print('[repo] Determining delivery spot...')
    self.deliverySpot = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(nil,
        freeroam_facilities.getParkingSpotsForFacility(self.selectedDealership))
end

function VehicleRepoJob:filterValidSpots()
    --print('[repo] Filtering valid parking spots...')
    self.validSpots = {}
    for _, spot in pairs(self.parkingSpots.objects) do
        if spot.pos and not spot.vehicle then
            local distanceFromPlayer = (spot.pos - self.playerPos):length()
            local distanceFromDestination = (spot.pos - self.deliverySpot.pos):length()
            if distanceFromPlayer >= 300 and distanceFromDestination >= 600 then
                table.insert(self.validSpots, spot)
            end
        end
    end

    if #self.validSpots == 0 then
        --print('[repo] Warning: No valid parking spots found.')
        return
    end
end

function VehicleRepoJob:selectRandomSpot()
    --print('[repo] Selecting random parking spot...')
    self.nearestSpot = self.validSpots[math.random(#self.validSpots)]
    --print('[repo] Selected parking spot at position: ' .. tostring(self.nearestSpot.pos))
end

function VehicleRepoJob:generateVehicleConfig()
    --print('[repo] Generating vehicle configuration...')
    local eligibleVehicles = configListGenerator.getEligibleVehicles(false, false)
    local randomVehicleInfos = configListGenerator.getRandomVehicleInfos(self.selectedDealership, 1, eligibleVehicles,
        "adjustedPopulation")
    if not randomVehicleInfos or #randomVehicleInfos == 0 then
        --print('[repo] Error: No vehicles could be generated for the selected dealership.')
        return
    end

    self.randomVehicleInfo = randomVehicleInfos[1]
    self.vehicleConfig = self.randomVehicleInfo.key
    --print('[repo] Selected vehicle config: ' .. self.vehicleConfig)

    local years = self.randomVehicleInfo.Years or self.randomVehicleInfo.aggregates.Years
    self.randomVehicleInfo.year = years and math.random(years.min, years.max) or 2023

    local filter = self.randomVehicleInfo.filter
    if filter.whiteList and filter.whiteList.Mileage then
        self.randomVehicleInfo.Mileage = math.random(filter.whiteList.Mileage.min, filter.whiteList.Mileage.max)
    else
        self.randomVehicleInfo.Mileage = 0
    end

    self.vehicleValue = valueCalculator.getAdjustedVehicleBaseValue(self.randomVehicleInfo.Value, {
        mileage = self.randomVehicleInfo.Mileage,
        age = 2023 - self.randomVehicleInfo.year
    })
    --print('[repo] Vehicle value: ' .. tostring(self.vehicleValue))
end

function VehicleRepoJob:spawnVehicle()
    --print('[repo] Spawning vehicle...')
    local spawnOptions = {}
    spawnOptions.config = self.vehicleConfig
    spawnOptions.autoEnterVehicle = false
    spawnOptions.pos = self.nearestSpot.pos
    spawnOptions.rot = self.nearestSpot.rot or quat(0, 0, 0, 1)
    spawnOptions.cling = true
    spawnOptions.paint = {
        baseColor = {math.random(), math.random(), math.random(), 1},
        metallic = false
    }
    spawnOptions.electrics = {
        parkingbrake = 0
    }

    local newVeh = core_vehicles.spawnNewVehicle(self.randomVehicleInfo.model_key, spawnOptions)
    if not newVeh then
        --print('[repo] Error: Failed to spawn vehicle.')
        return
    end

    --print('[repo] Vehicle spawned with ID: ' .. tostring(newVeh:getID()))
    --print('[repo] Selected dealership: ' .. self.selectedDealership.name)
    --print('[repo] Vehicle value: ' .. tostring(self.vehicleValue))

    self.vehicleId = newVeh:getID()
    self.vehicleValue = self.vehicleValue
    self.pickupSpot = self.nearestSpot.pos
    self.monitoring = true

    core_groundMarkers.setPath(self.nearestSpot.pos)
    self.totalDistance = core_groundMarkers.getPathLength()

    --print('[repo] Total distance: ' .. tostring(self.totalDistance))

    self.vehInfo = self.randomVehicleInfo
    ui_message("New Repo Job Available!\nSomeone missed a payment on their \n" .. self.randomVehicleInfo.Brand .. " " ..
                   self.randomVehicleInfo.Name .. ".\nPick it up for a reward.", 10, "info", "info")
    --print('[repo] Displayed message to the player.')
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
    if self.jobCoroutine and coroutine.status(self.jobCoroutine) ~= "dead" then
        local success, message = coroutine.resume(self.jobCoroutine)
        if not success then
            --print('[repo] Error in job coroutine: ' .. message)
            self.jobCoroutine = nil
        end
    end

    if self.completed then
        local playerPos = be:getPlayerVehicle(0):getPosition()
        local vehicle = be:getObjectByID(self.vehicleId)
        local vehiclePos = vehicle:getPosition()

        if (playerPos - vehiclePos):length() >= 15 then
            self:destroy()
        end
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
        if distance > 90 and distance < 100 then
            ui_message("You have driven too far from the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nPlease return it to the parking spot.", 10, "info", "info")
        elseif distance > 100 then
            if not self.countdown then
                self.countdown = 10
            else
                ui_message("You have " .. math.floor(self.countdown) .. " seconds to return the  " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 1, "info", "info")
                self.countdown = self.countdown - dtSim
                if self.countdown <= 0 then
                    ui_message("Someone else has picked up the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 10, "info", "info")
                    self:destroy()
                    return
                end
            end
        else
            if self.countdown then
                ui_message("You have returned to the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 3, "info", "info")
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
            ui_message("You've Dropped Off a " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nYou have been paid $" .. tostring(reward) .. ".", 15, "info", "info")
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
            --print('[repo] Vehicle moved more than 25 meters from repo vehicle. Ignition turned off.')
        end
    end

    if distance <= 15 and not self.jobStartTime then
        local velocity = vehicle:getVelocity():length()
        if velocity > 2 then
            self.jobStartTime = os.time()
            core_groundMarkers.setPath(self.deliverySpot.pos)
            self.totalDistance = self.totalDistance + core_groundMarkers.getPathLength()
            --print('[repo] Total distance: ' .. tostring(self.totalDistance))
            --print('[repo] Vehicle is moving. Path set to delivery spot.')
        end
    end
end

-- Export the class
M.VehicleRepoJob = VehicleRepoJob

return M
