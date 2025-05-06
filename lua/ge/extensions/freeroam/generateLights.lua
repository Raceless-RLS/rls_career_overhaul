local M = {}

local lightRegistry = {}
local forest = nil
local forestData = nil
local currentLevel = nil

local lightCount = {}
local lightData = nil


local function lastAfterSlash(s)
    local lastPos
    local i = 1
    while true do
      local st, en = string.find(s, "/", i, true)
      if not st then break end
      lastPos = en
      i = en + 1
    end
    if lastPos then
      return string.sub(s, lastPos + 1)
    else
      return s
    end
end

local function clearData()
    lightRegistry = {}
    lightData = nil
    forest = nil
    forestData = nil
end

local function getLightData()
    local level = "levels/" .. getCurrentLevelIdentifier() .. "/light_data.json"
    lightData = jsonReadFile(level)
    forest = core_forest.getForestObject()
    forestData = forest:getData()
end

local function registerLight(light)
    table.insert(lightRegistry, light)
end

local function getLightsInForest()
    if not forestData then
        forest = core_forest.getForestObject()
        forestData = forest:getData()
    end
    for _, item in ipairs(forestData:getItems()) do
        local shape = item:getData():getShapeFile()
        for key, value in pairs(lightData) do
            if lastAfterSlash(shape) == key then
                print("Found " .. key .. " at pos: " .. tostring(item:getPosition()))
                registerLight({obj = item, data = value})
            end
        end
    end
end

local function getLightsFromSceneTree()
    local missionGroup = scenetree.findObject("MissionGroup")
    if not missionGroup then
        return
    end

    -- Recursive function to search for objects
    local function searchObjects(group)
        for i, objName in ipairs(group:getObjects()) do
            local obj = scenetree.findObject(objName)
            if obj then
                if obj:getClassName() == "SimGroup" then
                    searchObjects(obj)
                elseif obj.getClassName and obj:getClassName() == "TSStatic" then
                    for key, value in pairs(lightData) do
                        if lastAfterSlash(obj:getModelFile()) == key then
                            registerLight({obj = obj, data = value})
                            print("Found " .. key .. " at pos: " .. tostring(obj:getPosition()))
                        end
                    end
                end
            end
        end
    end

    searchObjects(missionGroup)
end

local function getAllLights()
    getLightsInForest()
    getLightsFromSceneTree()
end

local function getLightOffset(light, pointNum)
    local pos = light.obj:getPosition()
    local transform = light.obj:getTransform()
    local scale = light.obj:getScale()
    local offset = vec3(light.data[pointNum].positionOffset.x, light.data[pointNum].positionOffset.y, light.data[pointNum].positionOffset.z)
    
    -- Use the transform matrix to rotate the offset
    -- The matrix's mulV function multiplies a vector to apply rotation
    local rotatedOffset = transform:mulV(offset)

    local scaledOffset
    if type(scale) == "cdata" then
        scaledOffset = vec3(rotatedOffset.x * scale.x, rotatedOffset.y * scale.y, rotatedOffset.z * scale.z)
    else
        scaledOffset = rotatedOffset * scale
    end
    
    return scaledOffset
end

local function generateLights(reloadLights)
    if reloadLights then
        clearData()
        getLightData()
        getAllLights()
    end
    print("Generating lights...")

    lightCount = {}
    
    -- Create main folder for all generated lights
    local generatedLightsGroup = createObject('SimGroup')
    generatedLightsGroup:registerObject('GeneratedLights')
    
    -- Add the lights group to MissionGroup
    local missionGroup = scenetree.findObject("MissionGroup")
    if missionGroup then
        missionGroup:add(generatedLightsGroup)
    else
        print("Warning: MissionGroup not found, lights may not appear correctly")
    end
    
    for lampIndex, light in ipairs(lightRegistry) do
        local pos = light.obj:getPosition()
        
        -- Create a subgroup for this lamp's lights
        local lightGroup = createObject('SimGroup')
        lightGroup:registerObject('LightGroup_' .. lampIndex)
        generatedLightsGroup:add(lightGroup)
        
        -- Create 7 point lights for each lamp
        for i, data in ipairs(light.data) do
            local offset = getLightOffset(light, i)
            local lightPos = pos + offset
            
            -- Create a PointLight object
            local pointLight = createObject(data.type)
            
            -- Set properties based on comments
            -- RGBA 255, 214, 102, 255 (convert to 0-1 range for BeamNG)
            pointLight:setField('color', 0, string.format("%f %f %f %f", 
                data.color.x, data.color.y, data.color.z, 1))
            
            -- Set properties based on light type
            local scale = light.obj:getScale()
            if type(scale) == "cdata" then
                pointLight:setField('radius', 0, data.radius * (scale.x + scale.y + scale.z) / 3)
            else
                pointLight:setField('radius', 0, data.radius * scale)
            end
            pointLight:setField('brightness', 0, data.brightness)

            lightCount[data.name] = (lightCount[data.name] or 0) + 1
            pointLight:registerObject(data.name .. '_' .. lightCount[data.name])
            print("Created point light " .. i .. " at " .. tostring(lightPos))
            
            -- Set position
            pointLight:setPosition(lightPos)
            
            -- Add to the lamp's group
            lightGroup:add(pointLight)
        end
    end
    for key, value in pairs(lightCount) do
        print("Created " .. key .. " " .. value .. " times")
    end
end

local function onExtensionLoaded()
    currentLevel = getCurrentLevelIdentifier()
    if currentLevel then
        getLightData()
        getAllLights()
    end
    print("Light Generation Module Loaded")
end

local function onWorldReadyState(state)
    if state == 2 and currentLevel ~= getCurrentLevelIdentifier() then
        currentLevel = getCurrentLevelIdentifier()
        clearData()
        getLightData()
        getAllLights()
    end
end


M.onExtensionLoaded = onExtensionLoaded
M.onWorldReadyState = onWorldReadyState
M.getAllLights = getAllLights
M.generateLights = generateLights

return M