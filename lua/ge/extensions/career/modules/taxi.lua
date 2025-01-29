local M = {}
M.dependencies = {'career_career', 'gameplay_sites_sitesManager', 'freeroam_facilities'}

local distanceMultiplier = 0.0009
local suggestedSpeed = 18

local TaxiJob = {}
TaxiJob.__index = TaxiJob

function TaxiJob:new()
    local instance = setmetatable({}, TaxiJob)
    instance.passengers = {}
    instance.currentFare = nil
    instance.availableSeats = 0
    instance.updateTimer = 1
    instance.timer = 0
    return instance
end

function TaxiJob:findParkingSpots()
    local sitePath = gameplay_sites_sitesManager.getCurrentLevelSitesFileByName('city')
    if sitePath then
        local siteData = gameplay_sites_sitesManager.loadSites(sitePath, true, true)
        self.parkingSpots = siteData and siteData.parkingSpots
    end
end

-- New function to calculate seating capacity
function TaxiJob:calculateCapacity(vehicleId)
    local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehicleId)
    if not inventoryId then return 0 end
    local seatingCapacity = career_modules_inventory.calculateSeatingCapacity(inventoryId)
    self.availableSeats = seatingCapacity - 1 -- Subtract the driver seat
end

function TaxiJob:findValidPickupSpots()
    self.validPickupSpots = {}
    local playerPos = be:getPlayerVehicle(0):getPosition()

    if not self.parkingSpots then self:findParkingSpots() end
    for _, spot in pairs(self.parkingSpots.objects) do
        if spot.pos and (spot.pos - playerPos):length() < 500 then
            table.insert(self.validPickupSpots, spot)
        end
    end
end

function TaxiJob:startRide(fare)
    -- Calculate pickup path distance
    core_groundMarkers.setPath(fare.pickup.pos)
    local pickupDistance = core_groundMarkers.getPathLength()
    
    self.currentFare = fare

    self.currentFare.startTime = os.time()
    self.currentFare.totalDistance = pickupDistance

    self.state = "enroute_to_pickup"
end

function TaxiJob:calculatePassengerCount()
    if self.availableSeats <= 0 then return 0 end
    local weights = {}
    local total = 0
    
    -- Create weighted distribution (inverse relationship)
    for i=1, self.availableSeats do
        weights[i] = (self.availableSeats - i + 1)
        total = total + weights[i]
    end

    local random = math.random(total)
    local cumulative = 0
    
    for i=1, self.availableSeats do
        cumulative = cumulative + weights[i]
        if random <= cumulative then
            return i
        end
    end
    return 1 -- fallback
end

function TaxiJob:generateFareMultiplier()
    -- Create weighted fare tiers
    local fareWeights = {
        {min = 0.5, max = 0.8, weight = 3},  -- 30% chance
        {min = 0.8, max = 1.2, weight = 5},  -- 50% chance (average)
        {min = 1.2, max = 1.5, weight = 2}   -- 20% chance
    }
    
    -- Calculate total weight
    local totalWeight = 0
    for _, tier in ipairs(fareWeights) do
        totalWeight = totalWeight + tier.weight
    end
    
    -- Select random tier
    local random = math.random(totalWeight)
    local currentWeight = 0
    local selectedTier
    
    for _, tier in ipairs(fareWeights) do
        currentWeight = currentWeight + tier.weight
        if random <= currentWeight then
            selectedTier = tier
            break
        end
    end
    
    -- Generate random multiplier within selected tier
    return math.random(selectedTier.min * 100, selectedTier.max * 100) / 100
end

function TaxiJob:generateJob()
    -- Find nearby pickup spots (within 300m)
    self:findValidPickupSpots()
    if not self.validPickupSpots or #self.validPickupSpots == 0 then
        ui_message("No nearby pickup locations found!", 5, "warning")
        return false
    end

    -- Select random pickup spot
    local pickupSpot = self.validPickupSpots[math.random(#self.validPickupSpots)]
    
    -- Find valid dropoff spots (min 600m from pickup)
    local dropoffSpots = {}
    local minDistance = 600
    for _, spot in pairs(self.parkingSpots.objects) do
        if spot ~= pickupSpot and pickupSpot.pos:distance(spot.pos) >= minDistance then
            table.insert(dropoffSpots, spot)
        end
    end

    -- Fallback if no valid dropoff spots found
    if #dropoffSpots == 0 then
        local randomDir = vec3(math.random()-0.5, math.random()-0.5, 0):normalized()
        local destPos = pickupSpot.pos + randomDir * math.random(600, 2000)
        dropoffSpots = { { pos = destPos, name = "Random Location" } }
    end

    -- Select random dropoff spot
    local dropoffSpot = dropoffSpots[math.random(#dropoffSpots)]
    
    -- Calculate passenger count
    self:calculateCapacity(be:getPlayerVehicle(0):getID())
    local passengerCount = self:calculatePassengerCount()

    local baseFare = self:generateFareMultiplier() * 100 * passengerCount
    
    -- Create fare details
    local fare = {
        pickup = pickupSpot,
        destination = dropoffSpot,
        baseFare = baseFare,
        passengers = passengerCount
    }

    local basePayment = baseFare * passengerCount * distanceMultiplier * 1000

    ui_message(string.format("New job: %d passengers waiting! Base fare per km: $%.2f", passengerCount, basePayment), 5, "info")

    return fare
end

function TaxiJob:calculateSpeedFactor()
    if not self.currentFare then return 0 end
    local elapsedTime = os.difftime(os.time(), self.currentFare.startTime)
    local actualSpeed = self.currentFare.totalDistance / elapsedTime
    
    return (actualSpeed - suggestedSpeed) / suggestedSpeed
end

function TaxiJob:completeRide()
    if not self.currentFare then return end
    
    local elapsedTime = os.difftime(os.time(), self.currentFare.startTime)
    local speedFactor = self:calculateSpeedFactor()
    
    -- Base payment calculation using actual path distance
    local basePayment = self.currentFare.baseFare * self.currentFare.passengers *
                       (self.currentFare.totalDistance * distanceMultiplier)
    
    -- Apply speed bonus or time penalty (mutually exclusive)
    local finalPayment = basePayment * (1 + speedFactor)
    
    local label = string.format("Taxi fare (%d passengers): $%d\nDistance: %.2fkm | %s: x %.2f",
        self.currentFare.passengers,
        math.floor(finalPayment),
        math.floor(self.currentFare.totalDistance),
        speedFactor > 0 and "Speed Bonus" or "Time Penalty",
        (1 + speedFactor)
    )
    
    career_modules_payment.reward({
        money = { amount = math.floor(finalPayment) },
        beamXP = { amount = math.floor(finalPayment / 10) }
    }, {
        label = label,
        tags = {"transport", "taxi"}
    })

    ui_message(label, 5, "Taxi", "info")
    
    self.currentFare = nil
    self.state = "available"
end

function TaxiJob:update(dt)
    self.timer = self.timer + dt
    if self.timer < self.updateTimer then return end
    self.timer = 0

    if self.currentFare and self.state == "enroute_to_pickup" then
        local vehicle = be:getPlayerVehicle(0)
        local distToPickup = (vehicle:getPosition() - self.currentFare.pickup.pos):length()
        
        if distToPickup < 5 then
            self.state = "passenger_loaded"
            core_groundMarkers.setPath(self.currentFare.destination.pos)
            local dropoffDistance = core_groundMarkers.getPathLength()
            self.currentFare.startTime = os.time() -- Reset timer for trip
            self.currentFare.totalDistance = self.currentFare.totalDistance + dropoffDistance
            ui_message("Passengers loaded! Drive to destination.", 5, "info")
        end
    end
    
    if self.currentFare and self.state == "passenger_loaded" then
        local vehicle = be:getPlayerVehicle(0)
        local destDist = core_groundMarkers.getPathLength()
        
        if destDist < 5 then
            self:completeRide()
            self = nil
        else
            ui_message(string.format(
                "Destination: %.2fkm remaining",
                math.floor(destDist * 100) / 100000
            ), 1, "info")
        end
    end
end

function M.showPhone()
    guihooks.trigger('ChangeState', {state = 'phone-main'})
end

function M.showPhoneMinimap()
    guihooks.trigger('ChangeState', {state = 'phone-minimap'})
end

local Job = nil

local function getTaxiJob()
    Job = TaxiJob:new()
    Job:startRide(Job:generateJob())
end

M.onUpdate = function(dt)
    if Job then Job:update(dt) end
end
M.getTaxiJob = getTaxiJob
M.TaxiJob = TaxiJob
return M 