local M = {}

M.dependencies = {'career_career', 'gameplay_sites_sitesManager', 'util_configListGenerator'}

local carmeetLocations = {}
local carMeetVehicles = {}
local spawnedMeetVehicles = {} -- Track currently spawned vehicles

-- Function to cleanup previous meet vehicles
local function cleanupPreviousMeet()
    for _, vehId in ipairs(spawnedMeetVehicles) do
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
    
    -- Select random vehicle config
    local vehicle = carMeetVehicles[math.random(#carMeetVehicles)]
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
    
    -- Set vehicle properties
    if vehicle then
        -- Disable entering vehicle
        vehicle:setDynDataFieldbyName("lockLevel", 0, "full")
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
    end
end

local function startCarMeet(meetName)
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
    
    local spawnedVehicles = {}
    local spotCount = math.min(4, #meet.parkingSpots) -- Spawn up to 4 vehicles
    
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

return M