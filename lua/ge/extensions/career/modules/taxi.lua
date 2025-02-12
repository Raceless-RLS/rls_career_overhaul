local M = {}
M.dependencies = {'career_career', 'gameplay_sites_sitesManager', 'freeroam_facilities'}

local dataToSend = {}

local core_groundMarkers = require('core/groundMarkers')

local cumulativeReward = 0
local fareStreak = 0

local distanceMultiplier = 4.5
local suggestedSpeed = 18

local parkingSpots = nil
local validPickupSpots = nil

local passengers = {}
local currentPassengerRating = 0
local currentPassengerType = "Standard"
local vehicleMultiplier = 0
local currentFare = nil
local availableSeats = nil
local updateTimer = 1
local timer = 0
local jobOfferTimer = 0
local state = "start"
local jobOfferInterval = math.random(5, 45)

local function findParkingSpots()
    local sitePath = gameplay_sites_sitesManager.getCurrentLevelSitesFileByName('city')
    if sitePath then
        local siteData = gameplay_sites_sitesManager.loadSites(sitePath, true, true)
        parkingSpots = siteData and siteData.parkingSpots
    end
end

-- New function to calculate seating capacity
local function calculateCapacity(vehicleId)
    local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehicleId)
    if not inventoryId then
        return 0
    end
    local seatingCapacity = career_modules_inventory.calculateSeatingCapacity(inventoryId)
    availableSeats = seatingCapacity - 1 -- Subtract the driver seat
    return availableSeats
end

local function findValidPickupSpots()
    local validPickupSpots = {}
    if not be:getPlayerVehicle(0) then return end
    local playerPos = be:getPlayerVehicle(0):getPosition()

    if not parkingSpots then
        findParkingSpots()
    end
    for _, spot in pairs(parkingSpots.objects) do
        if spot.pos and (spot.pos - playerPos):length() < 500 then
            table.insert(validPickupSpots, spot)
        end
    end
    return validPickupSpots
end

local function onEnterVehicleFinished()
    validPickupSpots = findParkingSpots()
end

local function startRide(fare)
    -- Calculate pickup path distance
    if not fare and not currentFare then
        print("No fare provided and no current fare")
        return
    end
    if not currentFare then
        currentFare = fare
    end

    currentFare.startTime = os.time()
    state = "pickup"
end

local function calculatePassengerCount()
    if availableSeats <= 0 then
        return 0
    end
    local weights = {}
    local total = 0

    -- Create weighted distribution (inverse relationship)
    for i = 1, availableSeats do
        weights[i] = (availableSeats - i + 1)
        total = total + weights[i]
    end

    local random = math.random(total)
    local cumulative = 0

    for i = 1, availableSeats do
        cumulative = cumulative + weights[i]
        if random <= cumulative then
            return i
        end
    end
    return 1 -- fallback
end

local function generateFareMultiplier()
    -- Create weighted fare tiers
    local fareWeights = {{
        min = 0.5,
        max = 0.8,
        weight = 3
    }, -- 30% chance
    {
        min = 0.8,
        max = 1.2,
        weight = 5
    }, -- 50% chance (average)
    {
        min = 1.2,
        max = 1.5,
        weight = 2
    } -- 20% chance
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

local function generateValueMultiplier()
    local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(be:getPlayerVehicle(0):getID())
    if not inventoryId then
        return 0
    end
    vehicleMultiplier = (career_modules_valueCalculator.getInventoryVehicleValue(inventoryId) / 30000) ^ 0.5
    vehicleMultiplier = string.format("%.1f", vehicleMultiplier)
    return vehicleMultiplier
end

local function generateJob()
    -- Find nearby pickup spots (within 300m)
    validPickupSpots = findValidPickupSpots()
    if not validPickupSpots or #validPickupSpots == 0 then
        print("No nearby pickup locations found!")
        return false
    end

    -- Select random pickup spot
    local pickupSpot = validPickupSpots[math.random(#validPickupSpots)]

    -- Find valid dropoff spots (min 600m from pickup)
    local dropoffSpots = {}
    local minDistance = 600
    for _, spot in pairs(parkingSpots.objects) do
        if spot ~= pickupSpot and pickupSpot.pos:distance(spot.pos) >= minDistance then
            table.insert(dropoffSpots, spot)
        end
    end

    -- Fallback if no valid dropoff spots found
    if #dropoffSpots == 0 then
        local randomDir = vec3(math.random() - 0.5, math.random() - 0.5, 0):normalized()
        local destPos = pickupSpot.pos + randomDir * math.random(600, 2000)
        dropoffSpots = {{
            pos = destPos,
            name = "Random Location"
        }}
    end

    -- Select random dropoff spot
    local dropoffSpot = dropoffSpots[math.random(#dropoffSpots)]

    -- Calculate passenger count
    if not availableSeats or availableSeats == 0 then
        calculateCapacity(be:getPlayerVehicle(0):getID())
    end

    local valueMultiplier = generateValueMultiplier()

    local passengerCount = calculatePassengerCount()

    local fareMultiplier = generateFareMultiplier()

    local baseFare = fareMultiplier * 100 * (passengerCount ^ 0.5) * valueMultiplier * distanceMultiplier

    if career_modules_hardcore.isHardcoreMode() then
        baseFare = baseFare * 0.66
    end

    -- Create fare details
    local fare = {
        pickup = {
            pos = pickupSpot.pos
        },
        destination = {
            pos = dropoffSpot.pos
        },
        baseFare = baseFare,
        passengers = passengerCount,
        passengerRating = string.format("%.1f", (fareMultiplier / 1.5) * 5)
    }
    currentFare = fare
    return fare
end

local function calculateSpeedFactor()
    if not currentFare then
        return 0
    end
    local elapsedTime = os.difftime(os.time(), currentFare.startTime)
    local actualSpeed = currentFare.totalDistance / elapsedTime

    return (actualSpeed - suggestedSpeed) / suggestedSpeed
end

local function completeRide()
    if not currentFare then
        return
    end

    local elapsedTime = os.difftime(os.time(), currentFare.startTime)
    local speedFactor = calculateSpeedFactor()

    fareStreak = fareStreak + 1

    -- Base payment calculation using actual path distance
    local basePayment = currentFare.baseFare * (currentFare.totalDistance / 1000) * (fareStreak ^ 0.75)

    local finalPayment = basePayment * (1 + speedFactor)

    cumulativeReward = cumulativeReward + finalPayment

    currentFare.totalFare = string.format("%.2f", finalPayment)
    currentFare.timeMultiplier = string.format("%.1f", 1 + speedFactor)
    currentFare.totalDistance = string.format("%.2f", currentFare.totalDistance / 1000)

    state = "complete"
    if not gameplay_phone.isPhoneOpen() then
        print("Phone is not open, opening phone")
        gameplay_phone.togglePhone("You completed a taxi fare! Open the phone to view your earnings.")
    end

    dataToSend = {
        state = state,
        currentFare = currentFare,
        availableSeats = availableSeats,
        vehicleMultiplier = vehicleMultiplier,
        cumulativeReward = cumulativeReward,
        fareStreak = fareStreak
    }
    guihooks.trigger('updateTaxiState', dataToSend)
    --dump(dataToSend)

    local label = string.format("Taxi fare (%d passengers): $%d\nDistance: %.2fkm | %s: x %.2f", currentFare.passengers,
        currentFare.totalFare, currentFare.totalDistance, speedFactor > 0 and "Speed Bonus" or "Time Penalty",
        currentFare.timeMultiplier)

    if career_modules_hardcore.isHardcoreMode() then
        label = label .. "\nHardcore mode is enabled, all rewards lowered."
    end

    career_modules_payment.reward({
        money = {
            amount = math.floor(finalPayment)
        },
        beamXP = {
            amount = math.floor(finalPayment / 10)
        }
    }, {
        label = label,
        tags = {"transport", "taxi"}
    }, true)

    career_modules_inventory.addTaxiDropoff(career_modules_inventory.getInventoryIdFromVehicleId(be:getPlayerVehicleID(0)), currentFare.passengers)
end

local function rejectJob()
    state = "ready"
    currentFare = nil
    core_groundMarkers.resetAll()
    fareStreak = 0
    jobOfferTimer = 0
    jobOfferInterval = math.random(5, 45)
    dataToSend = {}
end

local function stopTaxiJob()
    state = "start"
    currentFare = nil
    core_groundMarkers.resetAll()
    jobOfferTimer = 0
    jobOfferInterval = math.random(5, 45)
    cumulativeReward = 0
    fareStreak = 0
    dataToSend = {}
end

local function update(dt)
    timer = timer + dt
    if timer < updateTimer then
        return
    end
    timer = 0

    if currentFare and state == "pickup" then
        if core_groundMarkers.getPathLength() == 0 then
            core_groundMarkers.setPath(currentFare.pickup.pos)
            local pickupDistance = core_groundMarkers.getPathLength()
            currentFare.totalDistance = pickupDistance
        end

        local vehicle = be:getPlayerVehicle(0)
        local distToPickup = (vehicle:getPosition() - currentFare.pickup.pos):length()

        if distToPickup < 5 then
            state = "dropoff"
            core_groundMarkers.setPath(currentFare.destination.pos)
            local dropoffDistance = core_groundMarkers.getPathLength()
            currentFare.startTime = os.time() -- Reset timer for trip
            currentFare.totalDistance = currentFare.totalDistance + dropoffDistance
            dataToSend = {
                state = state,
                currentFare = currentFare,
                availableSeats = availableSeats,
                vehicleMultiplier = vehicleMultiplier,
                cumulativeReward = cumulativeReward,
                fareStreak = fareStreak
            }
            guihooks.trigger('updateTaxiState', dataToSend)
        end
    end

    if currentFare and state == "dropoff" then
        local vehicle = be:getPlayerVehicle(0)
        local destDist = core_groundMarkers.getPathLength()

        if destDist < 5 then

            completeRide()
        end
    end

    if state == "ready" then
        jobOfferTimer = jobOfferTimer + 1
        if jobOfferTimer >= jobOfferInterval then
            state = "accept"
            local newFare = generateJob()
            if not gameplay_phone.isPhoneOpen() then
                print("Phone is not open, opening phone")
                gameplay_phone.togglePhone("You have a new taxi fare! Open the phone to view the details.")
            end
            dataToSend = {
                state = state,
                currentFare = newFare,
                availableSeats = availableSeats,
                vehicleMultiplier = vehicleMultiplier,
                cumulativeReward = cumulativeReward,
                fareStreak = fareStreak
            }
            guihooks.trigger('updateTaxiState', dataToSend)

            jobOfferTimer = 0
            jobOfferInterval = math.random(5, 45)
        end
    end
end

local function prepareTaxiJob()
    calculateCapacity(be:getPlayerVehicle(0):getID())
    local multiplier = generateValueMultiplier()
    return {
        seats = availableSeats,
        multiplier = string.format("%.1f", multiplier)
    }
end

local function getTaxiJob()
    prepareTaxiJob()
    if not currentFare then
        startRide(generateJob())
    end
end

local function requestTaxiState()
    prepareTaxiJob()
    dataToSend = {
        state = state,
        currentFare = currentFare,
        availableSeats = availableSeats,
        vehicleMultiplier = vehicleMultiplier,
        cumulativeReward = cumulativeReward,
        fareStreak = fareStreak
    }
    guihooks.trigger('updateTaxiState', dataToSend)
end

local function setAvailable()
    state = "ready"
    jobOfferTimer = 0
    jobOfferInterval = math.random(5, 45)
    dataToSend = {}
    requestTaxiState()
end

function M.onVehicleSwitched()
    if gameplay_walk.isWalking() then
        state = "start"
        currentFare = nil
        core_groundMarkers.resetAll()
        jobOfferTimer = 0
        jobOfferInterval = math.random(5, 45)
        cumulativeReward = 0
        fareStreak = 0
        dataToSend = {
            state = state,
            currentFare = currentFare,
            availableSeats = availableSeats,
            vehicleMultiplier = vehicleMultiplier,
            cumulativeReward = cumulativeReward,
            fareStreak = fareStreak
        }
        guihooks.trigger('updateTaxiState', dataToSend)
    end
end

M.onEnterVehicleFinished = onEnterVehicleFinished
M.onUpdate = update

M.acceptJob = startRide
M.rejectJob = rejectJob
M.setAvailable = setAvailable
M.stopTaxiJob = stopTaxiJob

M.requestTaxiState = requestTaxiState
M.generateJob = generateJob
M.getTaxiJob = getTaxiJob
M.prepareTaxiJob = prepareTaxiJob

M.isTaxiJobActive = function()
    return state ~= "start"
end

return M
