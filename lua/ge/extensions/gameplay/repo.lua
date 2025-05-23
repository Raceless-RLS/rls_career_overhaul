-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- Dependencies
M.dependencies = {
    'util_configListGenerator', 'gameplay_parking', 
    'freeroam_facilities', 'gameplay_sites_sitesManager'
}

-- Require necessary modules
local configListGenerator = require('util.configListGenerator')
local parking = require('gameplay.parking')
local freeroam_facilities = require('freeroam.facilities')
local gameplay_sites_sitesManager = require('gameplay.sites.sitesManager')
local marker


-- Create a single repo job instance for the whole module
local repoJobInstance = nil

local function createMarker(position)
    if not marker then
        marker = createObject('TSStatic')
        marker.shapeName = "art/shapes/interface/checkpoint_marker.dae"
        marker.scale = vec3(4, 4, 4)
        marker.useInstanceRenderData = true
        marker.instanceColor = ColorF(0, 0.8, 0.2, 0.7):asLinear4F() 
        marker:setPosition(position)
        marker:registerObject("repo_delivery_marker")
    end
end

local VehicleRepoJob = {}
VehicleRepoJob.__index = VehicleRepoJob

-- Constructor for VehicleRepoJob
function VehicleRepoJob:new()
    local instance = setmetatable({}, VehicleRepoJob)
    instance.vehicleId = nil
    instance.vehicleValue = nil
    instance.pickupLocation = nil
    instance.deliveryLocation = nil
    instance.jobStartTime = nil
    instance.isMonitoring = false
    instance.selectedDealership = nil
    instance.isJobStarted = false
    instance.returnCountdown = nil
    instance.totalDistanceTraveled = 0
    instance.spawnedVehicle = false
    instance.isCompleted = false
    if core_groundMarkers then
        core_groundMarkers.resetAll()
    end
    return instance
end

-- Destroy the current job and clean up resources
function VehicleRepoJob:destroy()
    if self.vehicleId then
        local vehicle = getObjectByID(self.vehicleId)
        if vehicle then
            vehicle:delete()
        end
    end

    -- Add marker cleanup
    if marker then
        marker:unregisterObject()
        marker:delete()
        marker = nil
    end

    -- Reset all job-related data
    self.vehicleId = nil
    self.vehicleValue = nil
    self.pickupLocation = nil
    self.deliveryLocation = nil
    self.jobStartTime = nil
    self.isMonitoring = false
    self.selectedDealership = nil
    self.isJobStarted = false
    self.returnCountdown = nil
    self.totalDistanceTraveled = 0
    self.spawnedVehicle = false
    self.isCompleted = false
    self.reward = nil
    if core_groundMarkers then
        core_groundMarkers.resetAll()
    end
end

-- Generate a new repo job
function VehicleRepoJob:generateJob()
    
    -- Start the coroutine for job generation
    self.jobCoroutine = coroutine.create(function()
        -- Initialize player vehicle and yield to allow other processes
        self:initializePlayerVehicle()
        for i = 1, 5 do coroutine.yield() end

        -- Find parking spots and yield
        self:findParkingSpots()
        for i = 1, 5 do coroutine.yield() end

        -- Select a dealership and yield
        self:selectDealership()
        for i = 1, 5 do coroutine.yield() end

        -- Determine delivery location and yield
        self:determineDeliveryLocation() 
        for i = 1, 5 do coroutine.yield() end

        -- Filter valid parking spots and yield
        self:filterValidSpots()
        for i = 1, 5 do coroutine.yield() end

        -- Select a random valid parking spot and yield
        self:selectRandomSpot()
        for i = 1, 5 do coroutine.yield() end

        -- Generate vehicle configuration and yield
        self:generateVehicleConfig()
        for i = 1, 5 do coroutine.yield() end

        -- Wait for player vehicle to be stationary before spawning
        local playerVelocity = be:getPlayerVehicle(0):getVelocity():length()
        while not self.spawnedVehicle and playerVelocity > 1 do
            coroutine.yield()
            playerVelocity = be:getPlayerVehicle(0):getVelocity():length()
        end

        -- Spawn the vehicle
        if not self.spawnedVehicle then
            self:spawnVehicle()
            self.spawnedVehicle = true
        end
    end)
end

-- Initialize the player's vehicle
function VehicleRepoJob:initializePlayerVehicle()
    local playerVehicle = be:getPlayerVehicle(0)
    self.repoVehicle = playerVehicle
    if not playerVehicle then
        return
    end
    self.playerPosition = playerVehicle:getPosition()
end

-- Find available parking spots
function VehicleRepoJob:findParkingSpots()
    -- Get fresh sites data for current level
    local sitePath = gameplay_sites_sitesManager.getCurrentLevelSitesFileByName('city')
    if sitePath then
        local siteData = gameplay_sites_sitesManager.loadSites(sitePath, true, true) -- force reload
        self.parkingSpots = siteData and siteData.parkingSpots
    end
    
    -- Fallback to parking module if no sites data
    if not self.parkingSpots then
        self.parkingSpots = parking.getParkingSpots()
        log("W", "repo", "Using parking module fallback for spots")
    end

    if not self.parkingSpots or not self.parkingSpots.objects then
        log("E", "repo", "No parking spots found!")
        return
    end
end

-- Select a random dealership
function VehicleRepoJob:selectDealership()
    local facilities = freeroam_facilities.getFacilities(getCurrentLevelIdentifier())
    local dealerships = facilities.dealerships
    if not dealerships or #dealerships == 0 then
        return
    end
    self.selectedDealership = dealerships[math.random(#dealerships)]
end

-- Determine the delivery location
function VehicleRepoJob:determineDeliveryLocation()
    self.deliveryLocation = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(nil,
        freeroam_facilities.getParkingSpotsForFacility(self.selectedDealership))
end

-- Filter valid parking spots based on distance criteria
function VehicleRepoJob:filterValidSpots()
    self.validSpots = {}
    for _, spot in pairs(self.parkingSpots.objects) do
        if spot.pos and not spot.vehicle then
            local distanceFromPlayer = (spot.pos - self.playerPosition):length()
            local distanceFromDestination = (spot.pos - self.deliveryLocation.pos):length()
            if distanceFromPlayer >= 300 and distanceFromDestination >= 600 then
                table.insert(self.validSpots, spot)
            end
        end
    end
end

-- Select a random valid parking spot
function VehicleRepoJob:selectRandomSpot()
    if #self.validSpots == 0 then
        return
    end
    self.selectedSpot = self.validSpots[math.random(#self.validSpots)]
end

-- Generate vehicle configuration
function VehicleRepoJob:generateVehicleConfig()
    local eligibleVehicles = configListGenerator.getEligibleVehicles(false, false)
    local randomVehicleInfos = configListGenerator.getRandomVehicleInfos(self.selectedDealership, 1, eligibleVehicles, "adjustedPopulation")
    if not randomVehicleInfos or #randomVehicleInfos == 0 then
        return
    end

    self.randomVehicleInfo = randomVehicleInfos[1]
    self.vehicleConfig = self.randomVehicleInfo.key

    local years = self.randomVehicleInfo.Years or self.randomVehicleInfo.aggregates.Years
    self.randomVehicleInfo.year = years and math.random(years.min, years.max) or 2023

    local filter = self.randomVehicleInfo.filter
    if filter.whiteList and filter.whiteList.Mileage then
        self.randomVehicleInfo.Mileage = math.random(filter.whiteList.Mileage.min, filter.whiteList.Mileage.max)
    else
        self.randomVehicleInfo.Mileage = 0
    end

    if career_career.isActive() then
        self.vehicleValue = career_modules_valueCalculator.getAdjustedVehicleBaseValue(self.randomVehicleInfo.Value, {
            mileage = self.randomVehicleInfo.Mileage,
            age = 2025 - self.randomVehicleInfo.year
        })
    end

    local data = {
        state = "picking_up",
        vehicle = self.randomVehicleInfo,
        deliveryLocation = self.selectedDealership and self.selectedDealership.name or "",
        distanceToDestination = self.deliveryLocation and (self.vehicleId and 
            (getObjectByID(self.vehicleId):getPosition() - self.deliveryLocation.pos):length() or 0) or 0,
        totalDistance = self.totalDistanceTraveled or 0
    }
    guihooks.trigger('updateRepoState', data)
end

-- Spawn the vehicle at the selected spot
function VehicleRepoJob:spawnVehicle()
    local spawnOptions = {
        config = self.vehicleConfig,
        autoEnterVehicle = false,
        pos = self.selectedSpot.pos,
        rot = self.selectedSpot.rot or quat(0, 0, 0, 1),
        cling = true,
        paint = {
            baseColor = {math.random(), math.random(), math.random(), 1},
            metallic = false
        },
        electrics = {
            parkingbrake = 0
        }
    }

    local newVehicle = core_vehicles.spawnNewVehicle(self.randomVehicleInfo.model_key, spawnOptions)
    if not newVehicle then
        return
    end

    self.vehicleId = newVehicle:getID()
    self.pickupLocation = self.selectedSpot.pos
    self.isMonitoring = true

    core_groundMarkers.setPath(self.selectedSpot.pos)
    self.totalDistanceTraveled = core_groundMarkers.getPathLength()

    self.vehInfo = self.randomVehicleInfo
    ui_message("New Repo Job Available!\nSomeone missed a payment on their \n" .. self.randomVehicleInfo.Brand .. " " ..
                   self.randomVehicleInfo.Name .. ".\nPick it up for a reward.", 10, "New Job", "info")
end

-- Handle vehicle switch events
function VehicleRepoJob:onVehicleSwitched(oldId, newId)
    self.repoVehicle = getObjectByID(newId)
    self.repoVehicleID = newId
    if not self.isJobStarted then
        self:destroy()
        self:generateJob()
    end
end

-- Calculate the reward for completing the job
function VehicleRepoJob:calculateReward()
    if not career_career.isActive() then
        return nil
    end
    local distanceMultiplier = self.totalDistanceTraveled * 2
    local timeMultiplier = (self.totalDistanceTraveled / ((os.time() - self.jobStartTime) * 10))
    local reward = math.floor((((5 * math.sqrt(self.vehicleValue or 1000)) + distanceMultiplier) * timeMultiplier)/ 4)
    reward = reward * 1.25 + 1000
    if career_modules_hardcore.isHardcoreMode() then
        reward = reward * 0.4
    end
    return reward
end

-- Update function called every frame
function VehicleRepoJob:onUpdate(dtReal, dtSim, dtRaw) 
    -- Add timer for distance checks
    if not self.updateTimer then self.updateTimer = 0 end
    self.updateTimer = self.updateTimer + dtSim
    
    if self.jobCoroutine and coroutine.status(self.jobCoroutine) ~= "dead" then
        local success, message = coroutine.resume(self.jobCoroutine)
        if not success then
            self.jobCoroutine = nil
        end
    end

    if not self.isMonitoring or not self.vehicleId then
        return
    end

    -- Only do distance checks once per second
    if self.updateTimer < 1 then
        return
    end

    -- Reset timer after checks
    self.updateTimer = 0

    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then
        return
    end

    local playerPos = playerVehicle:getPosition()
    local vehicle = getObjectByID(self.vehicleId)
    if not vehicle then
        return
    end

    local vehiclePos = vehicle:getPosition()
    local repoPos
    local distance
    if not getObjectByID(self.repoVehicleID) then
        self.repoVehicleID = nil
        self.repoVehicle = nil
        if self.vehicleId then
            local vehicle = getObjectByID(self.vehicleId)
            if vehicle then
                vehicle:delete()
            end
        end
        if core_groundMarkers then
            core_groundMarkers.resetAll()
        end
        ui_message("Your Repo Vehicle has been removed.\nYou have lost your job.", 10, "info", "info")
        self:destroy()
        return
    else
        repoPos = self.repoVehicle:getPosition()
        distance = (vehiclePos - repoPos):length()
    end

    if not self.isJobStarted then
        if distance <= 20 then
            self.isJobStarted = true
            ui_message("Pick up the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nPlease drive it to " .. self.selectedDealership.name .. ".", 10, "info", "info")
            vehicle:queueLuaCommand('input.event("parkingbrake", 1, "FILTER_DI", nil, nil, nil, nil)')
            
            -- First insert the vehicle into traffic system
            gameplay_traffic.insertTraffic(self.vehicleId, true) -- true means ignore AI control
            
            -- Now we can get and modify the traffic vehicle
            local trafficVehicle = gameplay_traffic.getTrafficData()[self.vehicleId]
            if trafficVehicle then
                trafficVehicle:setRole("empty")
                print("Set vehicle role to empty")
            else
                print("No traffic vehicle found")
            end            
            createMarker(self.deliveryLocation.pos)
            core_groundMarkers.setPath(self.deliveryLocation.pos)
        end
        local repoDistance = (playerPos - repoPos):length()
        if repoDistance > 90 and repoDistance < 100 then
            ui_message("You have driven too far from Your Repo Vehicle.\nPlease return to it.", 10, "info", "info")
        elseif repoDistance > 100 then
            if not self.returnCountdown then
                self.returnCountdown = 10
            else
                ui_message("You have " .. math.floor(self.returnCountdown) .. " seconds to return to your Repo Vehicle.", 1, "info", "info")
                self.returnCountdown = self.returnCountdown - 1 -- Changed from dtSim to 1 since we're updating once per second
                if self.returnCountdown <= 0 then
                    ui_message("Someone else has picked up the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 10, "info", "info")
                    self:destroy()
                    return
                end
            end
        else
            if self.returnCountdown then
                ui_message("You have returned to your Repo Vehicle.", 3, "info", "info")
                self.returnCountdown = nil
                local vehiclePos = vehicle:getPosition()
                core_groundMarkers.setPath(vehiclePos)
                self.isJobStarted = false
            end
        end
    else
        if distance > 90 and distance < 100 then
            ui_message("You have driven too far from the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nPlease return it to the parking spot.", 10, "info", "info")
        elseif distance > 100 then
            if not self.returnCountdown then
                self.returnCountdown = 10
            else
                ui_message("You have " .. math.floor(self.returnCountdown) .. " seconds to return the  " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 1, "info", "info")
                self.returnCountdown = self.returnCountdown - 1 -- Changed from dtSim to 1 since we're updating once per second
                if self.returnCountdown <= 0 then
                    ui_message("Someone else has picked up the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 10, "info", "info")
                    self:destroy()
                    return
                end
            end
        else
            if self.returnCountdown then
                ui_message("You have returned to the " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".", 3, "info", "info")
                self.returnCountdown = nil
                local vehiclePos = vehicle:getPosition()
                core_groundMarkers.setPath(vehiclePos)
                self.isJobStarted = false
            end
        end
    end

    if self.jobStartTime then
        local distanceFromDestination = (vehiclePos - self.deliveryLocation.pos):length()
        local velocity = vehicle:getVelocity():length()
        if distanceFromDestination <= 3 and velocity <= 1 then
            core_jobsystem.create(function(job)
                ui_fadeScreen.cycle(0.5, 0.5, 0.5)
                job.sleep(0.5)
                local reward = self:calculateReward()
                local rewardText = "You've Dropped Off a " ..  self.vehInfo.Brand .. " " .. self.vehInfo.Name .. "."
                if reward then
                    rewardText = rewardText .. "\nYou have been paid $" .. tostring(reward)
                end
                           
                -- Add safety check for marker
                if marker then
                    marker:delete()
                    marker = nil
                end
            
                if career_career.isActive() then
                    career_modules_payment.reward({
                        money = { amount = reward },
                        beamXP = { amount = math.floor(reward / 20) },
                        labourer = { amount = math.floor(reward / 20) }
                    }, {
                        label = "You've Dropped Off a " .. self.vehInfo.Brand .. " " .. self.vehInfo.Name .. ".\nYou have been paid $" .. reward,
                        tags = {"gameplay", "reward", "laborer"}
                    }, true)
                    career_saveSystem.saveCurrent()
                    career_modules_inventory.addRepossession(career_modules_inventory.getInventoryIdFromVehicleId(self.repoVehicleID))
                end
            
                self.isJobStarted = false
                self.isMonitoring = false
            
                -- Add safety check for vehicle
                local vehicle = getObjectByID(self.vehicleId)
                if vehicle then
                    core_vehicleBridge.executeAction(vehicle, 'setFreeze', true)
                end
                if self.vehicleId then
                    local vehicle = getObjectByID(self.vehicleId)
                    if vehicle then
                        vehicle:delete()
                    end
                    self.vehicleId = nil
                end
                self.isCompleted = true
                self.reward = reward
                ui_message(rewardText, 15, "Job Completed", "info")
            end, 1, self)
        elseif distanceFromDestination <= 10 then
            ui_message("You've arrived at the dealership.\nPlease return the vehicle to the parking spot.", 10, "info", "info")
        else
            if self.deliveryLocation then
                print("Delivery location: " .. tostring(self.deliveryLocation.pos))
                if core_groundMarkers then
                    print("Core ground markers target pos: " .. tostring(core_groundMarkers.getTargetPos()))
                else
                    print("Core ground markers not found")
                end
            end
            if self.deliveryLocation.pos ~= nil and (not core_groundMarkers.getTargetPos() or core_groundMarkers.getTargetPos() ~= self.deliveryLocation.pos) then
                core_groundMarkers.setPath(self.deliveryLocation.pos)
            end
        end
    end

    if self.jobStartTime and playerVehicle:getID() == self.vehicleId then
        if distance > 50 then
            vehicle:queueLuaCommand([[
            if electrics.values.ignition then
              electrics.setIgnitionLevel(0)
            end
          ]])
        end
    end

    if distance <= 15 and not self.jobStartTime then
        local velocity = vehicle:getVelocity():length()
        if velocity > 2 then
            self.jobStartTime = os.time()
            core_groundMarkers.setPath(self.deliveryLocation.pos)
            self.totalDistanceTraveled = self.totalDistanceTraveled + core_groundMarkers.getPathLength()
        end
    end
end

function VehicleRepoJob:completeJob()
    self:destroy()
end

-- Get the current repo job instance
function M.getRepoJobInstance()
    if not repoJobInstance then
        repoJobInstance = VehicleRepoJob:new()
    end
    return repoJobInstance
end

-- Generate a new repo job (called from playerDriving)
function M.generateJob()
    local instance = M.getRepoJobInstance()
    if not M.isRepoVehicle() then
        ui_message("You must be in a Repo Vehicle to generate a job.", 10, "info", "info")
        return
    end
    
    if instance and M.isRepoVehicle() then
        instance.repoVehicle = be:getPlayerVehicle(0)
        instance.repoVehicleID = be:getPlayerVehicle(0):getID()
        instance:generateJob()
    end
end

-- Update the repo job (called from playerDriving's onUpdate)
function M.onUpdate(dtReal, dtSim, dtRaw)
    local instance = M.getRepoJobInstance()
    if instance then
        instance:onUpdate(dtReal, dtSim, dtRaw)
    end
end

-- Check if the vehicle is a repo vehicle
function M.isRepoVehicle()
    local licenseText = core_vehicles.getVehicleLicenseText(be:getPlayerVehicle(0))
    return licenseText and licenseText:lower() == "repo"
end

function M.requestRepoState()
    local instance = M.getRepoJobInstance()
    if not instance then return end
    
    local state = "no_mission"
    if instance.isCompleted then
        state = "completed"
    elseif instance.isMonitoring then
        state = instance.isJobStarted and "dropping_off" or "picking_up"
    end
    
    local data = {
        state = state,
        vehicle = instance.randomVehicleInfo,
        deliveryLocation = instance.selectedDealership and instance.selectedDealership.name or "",
        distanceToDestination = instance.deliveryLocation and (instance.vehicleId and 
            (getObjectByID(instance.vehicleId):getPosition() - instance.deliveryLocation.pos):length() or 0) or 0,
        totalDistance = instance.totalDistanceTraveled or 0,
        reward = instance.reward or 0,
        isRepoVehicle = M.isRepoVehicle()
    }
    
    guihooks.trigger('updateRepoState', data)
end

function M.cancelJob()
    local instance = M.getRepoJobInstance()
    if instance then
        instance:destroy()
    end
end

function M.completeJob()
    local instance = M.getRepoJobInstance()
    if instance then
        instance:completeJob()
    end
end

-- Export the class
M.VehicleRepoJob = VehicleRepoJob

return M