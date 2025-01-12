local M = {}

M.dependencies = {'career_career', 'gameplay_sites_sitesManager'}

local carmeetLocations = {}

-- List of vehicles that can appear at car meets
local carMeetVehicles = {
    'covet',
    'pessima',
    'sunburst',
    'vivace',
    'barstow',
    'moonhawk'
    -- Add more vehicles as needed
}

-- Function to get a random vehicle from the list
local function getRandomVehicle()
    return carMeetVehicles[math.random(#carMeetVehicles)]
end

-- Function to spawn a vehicle at a parking spot
local function spawnVehicleAtSpot(spot)
    local vehicleName = getRandomVehicle()
    local pos = vec3(spot.pos)
    local rot = quat(spot.rot)
    
    -- Spawn the vehicle using the spawn manager
    local options = {
        config = nil, -- Random config
        paint = nil,  -- Random paint
        autoEnterVehicle = false,
        autoFlip = true
    }
    
    local vehicle = spawn.spawnVehicle(vehicleName, options, pos, rot)
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

M.onInit = onInit
M.getCarMeetLocations = getCarMeetLocations
M.onWorldReadyState = onWorldReadyState
M.startCarMeet = startCarMeet

return M