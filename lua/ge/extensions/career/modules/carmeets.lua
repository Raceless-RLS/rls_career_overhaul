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
local meetTimeWindow = 0.01 -- Time window to trigger meet
local lastUpdateCheck = 0
local updateInterval = 30 -- Check every 30 seconds

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
end

-- Function to get all carmeet configurations
local function getCarMeetVehicles()
    local vehicles = {}
    local eligibleVehicles = util_configListGenerator.getEligibleVehicles(false, false)
    
    -- Create a filter for carmeet vehicles
    local carmeetFilter = {
        whiteList = {
            ["Config Type"] = {"CarmeetRLS"}
        }
    }
    
    -- Get random vehicle infos using the carmeet filter
    local randomVehicleInfos = util_configListGenerator.getRandomVehicleInfos(
        {filter = carmeetFilter},
        100,
        eligibleVehicles,
        "Population"
    )
    
    -- Store the vehicle infos directly
    for _, vehicleInfo in ipairs(randomVehicleInfos) do
        local pcPath = '/vehicles/' .. vehicleInfo.model_key .. '/configurations/' .. vehicleInfo.key .. '.pc'
        table.insert(vehicles, {
            model = vehicleInfo.model_key,
            config = pcPath
        })
        print("Found carmeet config: " .. vehicleInfo.model_key .. " - " .. pcPath)
    end
    
    print("Total carmeet configs found: " .. #vehicles)
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
        -- Turn off engine
        core_vehicleBridge.executeAction(vehicle, 'setIgnitionLevel', 0)
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

    -- Debug print
    print("Found " .. tableSize(locations) .. " meet locations")
    for name, data in pairs(locations) do
        print("Meet: " .. name)
        print("  Parking spots: " .. tableSize(data.parkingSpots))
        print("  Tags: " .. table.concat(data.tags or {}, ", "))
        -- Additional debug to see exact meet name
        print("  Exact meet name: '" .. name .. "'")
    end

    return locations
end

local function onWorldReadyState(state)
    if state == 2 and careerActive then
        print("Loading carmeet locations")
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
    
    -- Additional debug
    print("Looking for meet: '" .. meetName .. "'")
    print("Available meets:")
    for name, _ in pairs(meets) do
        print("  '" .. name .. "'")
    end
    
    local meet = meets[meetName]
    if not meet then
        print("Car meet location not found: " .. meetName)
        return
    end
    
    -- Calculate spots based on stored attendance level
    local maxSpots = #meet.parkingSpots - 1  -- Reserve one spot for player
    local spotCount
    print("attendanceLevel: " .. attendanceLevel)
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

-- Add cleanup function to module exports
M.cleanupPreviousMeet = cleanupPreviousMeet
M.onInit = onInit
M.getCarMeetLocations = getCarMeetLocations
M.onWorldReadyState = onWorldReadyState
M.startCarMeet = startCarMeet

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
        time = meetStartTime,
        location = selectedMeet.name,
        type = "Showcase"
    }

    return meetData
end

local function rsvpToMeet(level)
    -- Convert string level to number
    attendanceLevel = attendanceLevels[level] or 2  -- default to MEDIUM (2) if invalid
    print("attendanceLevel: " .. attendanceLevel)
    rsvpData = meetData
    meetData = nil
end

local function decline()
    rsvpData = nil
    meetData = nil
end

-- Function to check if it's time to start the meet
local function checkMeetStart()
    if not rsvpData then return end

    local currentTime = scenetree.tod and scenetree.tod.time or 0
    local timeUntilMeet = math.abs(currentTime - meetStartTime)

    if timeUntilMeet <= meetTimeWindow then
        -- Get the meet location data
        local meet = carmeetLocations[rsvpData.location]
        if meet then
            -- Set marker to guide player to the meet
            core_groundMarkers.setPath(meet.pos)
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

-- Add new functions to module exports while keeping existing ones
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