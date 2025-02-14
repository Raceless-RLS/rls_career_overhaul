local M = {}

M.dependencies = {'career_career', 'gameplay_sites_sitesManager', 'util_configListGenerator', 'gameplay_traffic', 'career_saveSystem'}

local carmeetLocations = {}
local carMeetVehicles = {}
local spawnedMeetVehicles = {} -- Track currently spawned vehicles
local usedConfigs = {} -- Track configs used in current meet

local meetData = nil
local attendanceLevel = 1
-- Add new variables for time management
local saveFile = "carmeets.json"
local lastGenerationTime = 0
local generationInterval = 1800 -- 30 minutes in seconds
local rsvpData = nil
local meetStartTime = 0.417 -- 10 PM
local meetTimes = {0.417, 0.771, 0.188, 0.243}
local meetTimeWindow = 0.01 -- Time window to trigger meet
local lastUpdateCheck = 0
local updateInterval = 5 -- Check every 5 seconds

-- Add new variables for tracking active meet and player arrival
local activeMeet = nil
local playerHasArrived = false
local playerSpot = nil
local MEET_CLEANUP_DISTANCE = 100
local MEET_LEAVE_TIMER = 60
local MEET_LEAVE_INTERVAL = 3.5
local meetArrivalTime = nil
local vehicleDispersed = false
local lastVehicleLeaveTime = 0
local vehiclesToLeave = {}

local attendanceLevels = {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3
}

local function loadCarMeetData()
    if not career_career.isActive() then return end
    local _, currentSavePath = career_saveSystem.getCurrentSaveSlot()
    if not currentSavePath then return end
    
    local filePath = currentSavePath .. "/career/rls_career/" .. saveFile
    local data = jsonReadFile(filePath)
    
    if data then
        lastGenerationTime = data.lastGenerationTime or 0
        rsvpData = data.rsvpData
    end
end

-- Function to cleanup previous meet vehicles
local function cleanupPreviousMeet()
    for _, vehId in ipairs(spawnedMeetVehicles) do
        gameplay_traffic.removeTraffic(vehId)
        local veh = be:getObjectByID(vehId)
        if veh then
            veh:delete()
        end
    end
    spawnedMeetVehicles = {}
    core_groundMarkers.resetAll()
    activeMeet = nil  -- Clear active meet
    playerHasArrived = false  -- Reset arrival flag
    playerSpot = nil
    meetArrivalTime = nil
    lastVehicleLeaveTime = 0
end

-- Function to get all carmeet configurations
local function getCarMeetVehicles()
    local vehicles = {}
    local eligibleVehicles = util_configListGenerator.getEligibleVehicles(false, false)
    
    -- First get CarmeetRLS configs
    local carmeetFilter = {
        whiteList = {
            ["Config Type"] = {"CarmeetRLS"}
        }
    }
    
    local carmeetVehicleInfos = util_configListGenerator.getRandomVehicleInfos(
        {filter = carmeetFilter},
        100,
        eligibleVehicles,
        "Population"
    )

    -- Then get additional custom configs
    local customFilter = {
        whiteList = {
            ["Config Type"] = {"Custom"},
            ["Body Style"] = {"Sedan", "Hatchback", "SUV", "Coupe"}
        }
    }
    
    local customVehicleInfos = util_configListGenerator.getRandomVehicleInfos(
        {filter = customFilter},
        100,
        eligibleVehicles,
        "Population"
    )

    -- Combine both sets of vehicle infos
    local function addVehicleInfos(vehicleInfos)
        for _, vehicleInfo in ipairs(vehicleInfos) do
            local pcPath = '/vehicles/' .. vehicleInfo.model_key .. '/configurations/' .. vehicleInfo.key .. '.pc'
            table.insert(vehicles, {
                model = vehicleInfo.model_key,
                config = pcPath
            })
        end
    end

    addVehicleInfos(carmeetVehicleInfos)
    addVehicleInfos(customVehicleInfos)
    
    return vehicles
end

-- Function to get a random vehicle config
local function getRandomVehicle()
    if #carMeetVehicles == 0 then 
        carMeetVehicles = getCarMeetVehicles()
        if #carMeetVehicles == 0 then
            print("No carmeet vehicles found")
            return nil
        end
    end
    
    -- Create a list of available (unused) vehicles
    local availableVehicles = {}
    for _, vehicle in ipairs(carMeetVehicles) do
        if not usedConfigs[vehicle.config] then
            table.insert(availableVehicles, vehicle)
        end
    end
    
    -- Check if we have any available vehicles left
    if #availableVehicles == 0 then
        print("No unused vehicle configs available")
        return nil
    end
    
    -- Select random vehicle config from available vehicles
    local vehicle = availableVehicles[math.random(#availableVehicles)]
    -- Mark this config as used
    usedConfigs[vehicle.config] = true
    
    print("Selected vehicle: " .. vehicle.model .. " with config: " .. vehicle.config)
    return vehicle.model, vehicle.config
end

-- Update the spawn function to use the specific config
local function spawnVehicleAtSpot(spot)
    local vehicleName, configPath = getRandomVehicle()
    if not vehicleName then return nil end
    
    local options = {
        config = configPath,
        autoEnterVehicle = false,
        autoFlip = true,
        pos = vec3(spot.pos),
        rot = quat(spot.rot)
    }
    
    print("Spawning vehicle: " .. vehicleName .. " with config: " .. configPath)
    local vehicle = core_vehicles.spawnNewVehicle(vehicleName, options)
    
    if vehicle then
        -- Add vehicle to traffic system but mark it as non-AI
        gameplay_traffic.insertTraffic(vehicle:getID(), true)
        -- Set vehicle as non-player-usable
        vehicle.playerUsable = false
        -- Turn on headlights directly through electrics
        vehicle:queueLuaCommand('electrics.setLightsState(1)')
        -- Turn off engine
        vehicle:queueLuaCommand('electrics.setIgnitionLevel(1)')
        -- Add to tracked vehicles
        table.insert(spawnedMeetVehicles, vehicle:getID())
    end
    
    return vehicle
end

local function onInit()
    print("Carmeets module initialized")
end

local function getCarMeetLocations()
    local locations = {}
    
    -- Get the carmeet sites file
    local sitePath = gameplay_sites_sitesManager.getCurrentLevelSitesFileByName('carmeet')
    if not sitePath then 
        print("No carmeet sites file found")
        return locations 
    end
    
    local siteData = gameplay_sites_sitesManager.loadSites(sitePath)
    if not siteData then 
        print("Could not load carmeet sites data")
        return locations 
    end

    -- First, process all zones (meet locations)
    for _, zone in ipairs(siteData.zones.sorted) do
        local meetName = zone.name
        -- Store using the zone name as key, not the tag
        locations[meetName] = {
            zone = zone,
            parkingSpots = {},
            position = vec3(zone.top.pos),
            tags = zone.customFields.sortedTags
        }

        -- Find parking spots that have this zone's tag
        for _, spot in ipairs(siteData.parkingSpots.sorted) do
            for _, tag in ipairs(spot.customFields.sortedTags) do
                if tag == meetName then
                    table.insert(locations[meetName].parkingSpots, spot)
                end
            end
        end
    end

    carmeetLocations = locations

    return locations
end

local function onWorldReadyState(state)
    if state == 2 and careerActive then
        carmeetLocations = getCarMeetLocations()
        loadCarMeetData()
    end
end

local function startCarMeet(meetName)
    -- Clear used configs at the start of each meet
    usedConfigs = {}
    
    -- Cleanup any previous meet vehicles
    cleanupPreviousMeet()
    
    -- Rest of the existing startCarMeet function
    local meets = (not carmeetLocations or next(carmeetLocations) == nil) and getCarMeetLocations() or carmeetLocations
    
    local meet = meets[meetName]
    if not meet then
        print("Car meet location not found: " .. meetName)
        return
    end
    
    -- Set the active meet and reset player arrival flag
    activeMeet = meet
    playerHasArrived = false
    -- Calculate spots based on stored attendance level
    local maxSpots = #meet.parkingSpots - 1  -- Reserve one spot for player
    local spotCount
    if attendanceLevel == 1 then -- LOW
        spotCount = 2
    elseif attendanceLevel == 2 then -- MEDIUM
        spotCount = math.floor(maxSpots / 2)
    elseif attendanceLevel == 3 then -- HIGH (3)
        spotCount = maxSpots
    end
    
    local spawnedVehicles = {}
    
    -- Create a copy of parking spots array to randomly select from
    local availableSpots = deepcopy(meet.parkingSpots)

    playerSpot = gameplay_sites_sitesManager.getBestParkingSpotForVehicleFromList(be:getPlayerVehicleID(0), availableSpots)
    -- Remove the player's spot from available spots
    for i, spot in ipairs(availableSpots) do
        if spot == playerSpot then
            table.remove(availableSpots, i)
            break
        end
    end

    -- Set navigation to the player's parking spot
    local options = {
        color = {1, 0.4, 0}, -- Orange color for car meet markers
        step = 4,            -- Marker spacing
        renderDecals = true
    }
    core_groundMarkers.setPath(playerSpot.pos, options)
    
    -- Spawn vehicles in random spots
    for i = 1, spotCount do
        -- Select a random spot from remaining spots
        local randomIndex = math.random(#availableSpots)
        local spot = availableSpots[randomIndex]
        
        -- Remove the used spot from available spots
        table.remove(availableSpots, randomIndex)
        
        -- Spawn the vehicle
        local vehicle = spawnVehicleAtSpot(spot)
        if vehicle then
            table.insert(spawnedVehicles, vehicle)
        end
    end
    
    return spawnedVehicles
end

-- Add new functions for meet generation and RSVP
local function shouldGenerateNewMeet()
    local currentTime = os.time()
    return (currentTime - lastGenerationTime) >= generationInterval
end

local function checkAvailableMeets()
    if not shouldGenerateNewMeet() then
        return meetData
    end

    -- Get all meet locations
    local meets = (not carmeetLocations or next(carmeetLocations) == nil) and getCarMeetLocations() or carmeetLocations
    if not meets or tableSize(meets) == 0 then
        return nil
    end

    -- Convert meets table to array for random selection
    local meetArray = {}
    for name, data in pairs(meets) do
        table.insert(meetArray, {name = name, data = data})
    end

    -- Select random meet
    local selectedMeet = meetArray[math.random(#meetArray)]
    
    -- Update generation time
    lastGenerationTime = os.time()

    -- Return meet data
    meetData = {
        time = meetTimes[math.random(#meetTimes)],
        location = selectedMeet.name,
        type = "Showcase"
    }

    return meetData
end

local function rsvpToMeet(level)
    -- Convert string level to number
    attendanceLevel = attendanceLevels[level] or 2  -- default to MEDIUM (2) if invalid
    rsvpData = meetData
    meetData = nil
end

local function decline()
    rsvpData = nil
    meetData = nil
    core_groundMarkers.resetAll()
    activeMeet = nil
    playerHasArrived = false
end

-- Function to check if it's time to start the meet
local function checkMeetStart()
    if not rsvpData then return end

    local currentTime = scenetree.tod and scenetree.tod.time or 0
    local timeUntilMeet = math.abs(currentTime - rsvpData.time)

    if timeUntilMeet <= meetTimeWindow then
        -- Get the meet location data
        local meet = carmeetLocations[rsvpData.location]
        if meet then
            -- Start the meet
            ui_message("Car meet starting at " .. rsvpData.location, 10, "info", "info")
            startCarMeet(rsvpData.location)
        end
        -- Clear RSVP data after starting
        rsvpData = nil
    end
end

-- Throttled update function
local function onUpdate(dtReal, dtSim, dtRaw)
    if not career_career.isActive() then return end
    
    local currentTime = os.time()
    if currentTime - lastUpdateCheck >= updateInterval then
        lastUpdateCheck = currentTime
        checkMeetStart()
        
        -- Check if player has arrived at active meet
        if activeMeet and not playerHasArrived then
            local playerVeh = be:getPlayerVehicle(0)
            if playerVeh and (playerVeh:getPosition() - playerSpot.pos):length() < 10 then
                local reputation = math.floor(math.random() * 100) / 10
                if career_modules_hardcore.isHardcoreMode() then
                    reputation = reputation / 2
                end

                ui_message("Welcome to the car meet!\nCommunity liked your car!\nVehicle value increased by " .. reputation .. "%", 10, "info", "info")
                local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(be:getPlayerVehicleID(0))
                if inventoryId then
                    career_modules_inventory.addMeetReputation(inventoryId, reputation)
                end
                core_groundMarkers.resetAll()
                playerHasArrived = true
                career_saveSystem.saveCurrent()
            end
        elseif activeMeet and playerHasArrived then
            if not meetArrivalTime then
                meetArrivalTime = os.time()
            end
            
            if os.time() - meetArrivalTime > MEET_LEAVE_TIMER and not gameplay_walk.isWalking() then
                -- Initialize vehicle departure if not started
                if #vehiclesToLeave == 0 and not vehicleDispersed then
                    ui_message("Car meet is over, vehicles starting to leave!", 10, "info", "info")
                    vehiclesToLeave = {}
                    for _, vehID in ipairs(spawnedMeetVehicles) do
                        table.insert(vehiclesToLeave, vehID)
                    end
                    for _, vehID in ipairs(vehiclesToLeave) do
                        local veh = be:getObjectByID(vehID)
                        veh:queueLuaCommand('for k, v in pairs(controller.getControllersByType("advancedCouplerControl")) do v.tryAttachGroupImpulse() end')
                    end
                    lastVehicleLeaveTime = currentTime
                end
                
                -- Check if it's time for next vehicle to leave
                if #vehiclesToLeave > 0 and currentTime - lastVehicleLeaveTime >= MEET_LEAVE_INTERVAL then
                    local vehID = table.remove(vehiclesToLeave, 1)
                    local veh = be:getObjectByID(vehID)
                    if veh then
                        -- Close all latches before leaving
                        veh:queueLuaCommand('ai.setMode("traffic")')
                        veh:queueLuaCommand('ai.setSpeedMode("off")')
                    end
                    lastVehicleLeaveTime = currentTime
                end
                
                -- When all vehicles have left
                if #vehiclesToLeave == 0 and not vehicleDispersed then
                    ui_message("Car meet is over, Thanks for coming!", 10, "info", "info")
                    activeMeet = nil
                    playerHasArrived = false
                    playerSpot = nil
                    vehicleDispersed = true
                end
            end
        elseif vehicleDispersed then
            local playerVeh = be:getPlayerVehicle(0)
            for i, vehID in ipairs(spawnedMeetVehicles) do
                local veh = be:getObjectByID(vehID)
                if veh then
                    local distance = (playerVeh:getPosition() - veh:getPosition()):length()
                    if distance > MEET_CLEANUP_DISTANCE then
                        table.remove(spawnedMeetVehicles, i)
                        gameplay_traffic.removeTraffic(vehID)
                        veh:delete()
                    end
                else
                    table.remove(spawnedMeetVehicles, i)
                end
            end
            if #spawnedMeetVehicles == 0 then
                vehicleDispersed = false
                cleanupPreviousMeet()
            end
        end
    end
end

-- Save/Load functions using career save system
local function onSaveCurrentSaveSlot(currentSavePath)
    if not currentSavePath then return end

    local dirPath = currentSavePath .. "/career/rls_career"
    if not FS:directoryExists(dirPath) then
        FS:directoryCreate(dirPath)
    end

    local data = {
        lastGenerationTime = lastGenerationTime,
        rsvpData = rsvpData
    }
    career_saveSystem.jsonWriteFileSafe(dirPath .. "/" .. saveFile, data, true)
end

local function openMenu()
    guihooks.trigger('ChangeState', {state = 'carMeets'})
end

local function closeMenu()
    career_career.closeAllMenus()
end

M.onInit = onInit
M.getCarMeetLocations = getCarMeetLocations
M.onWorldReadyState = onWorldReadyState
M.startCarMeet = startCarMeet
M.cleanupPreviousMeet = cleanupPreviousMeet
M.checkAvailableMeets = checkAvailableMeets
M.rsvpToMeet = rsvpToMeet
M.onUpdate = onUpdate
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.openMenu = openMenu
M.decline = decline
M.closeMenu = closeMenu

return M