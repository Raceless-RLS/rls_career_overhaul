-- World Editor Light Generation Editor

local M = {}
local logTag = 'editor_lightGenerationEditor'
local im = ui_imgui
local toolWindowName = "editor_lightGenerationEditor_window"

local lightData = {}
local currentLightName = nil
local currentPointIndex = 1
local modified = false
local linkedObjects = {}
local defaultLightPoint = {
  positionOffset = vec3(0, 0, 0),
  color = vec3(1, 0.839, 0.4), -- Default yellow color (255, 214, 102 converted to 0-1)
  radius = 5,
  brightness = 1,
  name = "StreetLight",
  type = "PointLight"
}

-- Cache for found lights
local cachedLights = {}
local lastCacheTime = 0
local cacheTimeout = 30 -- seconds before refreshing cache

-- Add this at the top of the file with other global variables
local originalLightData = {}

-- Add these near the top of the file
local persistentLightLinks = {}  -- This won't expire like the cache

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

local function getObjectFileName(obj)
  if obj:getClassName() == "TSStatic" then
    return lastAfterSlash(obj:getModelFile())
  elseif obj:getClassName() == "Prefab" then
    return lastAfterSlash(obj:getField("fileName", 0))
  else
    return obj:getName()
  end
end

local function findObjectByFileName(fileName)
  -- Iterate through all objects and check if any has matching filename
  if linkedObjects[fileName] then
    return linkedObjects[fileName]
  end
  local allObjects = scenetree.getAllObjects()
  for _, objName in ipairs(allObjects) do
    local obj = scenetree.findObject(objName)
    if obj and getObjectFileName(obj) == fileName then
      linkedObjects[fileName] = obj
      return obj
    end
  end
  return nil
end

-- Function to load light data from file
local function loadLightData()
  local level = getCurrentLevelIdentifier()
  if not level then return end
  
  local filePath = "levels/" .. level .. "/light_data.json"
  lightData = jsonReadFile(filePath) or {}
  -- Store a deep copy of the loaded data as original values
  originalLightData = deepcopy(lightData)
  modified = false
  
  log('I', logTag, "Loaded light data for level: " .. level)
end

-- Function to save light data to file
local function saveLightData()
  local level = getCurrentLevelIdentifier()
  if not level then 
    log('E', logTag, "No level loaded!")
    return 
  end
  
  local filePath = "levels/" .. level .. "/light_data.json"
  jsonWriteFile(filePath, lightData, true)
  -- Update the original values to match what was just saved
  originalLightData = deepcopy(lightData)
  modified = false
  log('I', logTag, "Saved light data to: " .. filePath)
end

-- Function to get current selection
local function getCurrentSelection()
  if editor.selection and editor.selection.object and #editor.selection.object > 0 then
    return scenetree.findObjectById(editor.selection.object[1])
  end
  return nil
end

-- Function to clear preview
local function clearPreview()
  local generatedLights = scenetree.findObject("GeneratedLights")
  if generatedLights then
    generatedLights:delete()
  end
  log('I', logTag, "Cleared light preview")
end

-- Function to preview lights
local function previewLights()
  clearPreview()
  extensions.freeroam_generateLights.generateLights(true)
  log('I', logTag, "Previewing lights")
end

-- Count the number of entries in a table
local function countTableEntries(t)
  local count = 0
  if t then
    for _ in pairs(t) do count = count + 1 end
  end
  return count
end

-- Function to calculate expected light position
local function calculateLightPosition(obj, pointData)
  if not obj or not pointData or not pointData.positionOffset then return nil end
  
  local pos = obj:getPosition()
  local transform = obj:getTransform()
  local scale = obj:getScale()
  local offset = vec3(pointData.positionOffset.x, pointData.positionOffset.y, pointData.positionOffset.z)
  
  -- Use the transform matrix to rotate the offset
  local rotatedOffset = transform:mulV(offset)
  
  -- Apply scale
  local scaledOffset
  if type(scale) == "cdata" then
    scaledOffset = vec3(rotatedOffset.x * scale.x, rotatedOffset.y * scale.y, rotatedOffset.z * scale.z)
  else
    scaledOffset = rotatedOffset * scale
  end
  
  return pos + scaledOffset
end

-- Function to update specific light property in the scene
local function updateLightPropertyInScene(lightInfo, property, value)
  if not lightInfo or not lightInfo.id then return end
  
  local lightObj = scenetree.findObjectById(lightInfo.id)
  if not lightObj then return end
  
  if property == "color" then
    lightObj:setField('color', 0, string.format("%f %f %f %f", 
      value.x, value.y, value.z, 1.0))
  elseif property == "radius" then
    local obj = findObjectByFileName(currentLightName)
    if obj then
      local scale = obj:getScale()
      local scaledRadius = value
      if type(scale) == "cdata" then
        scaledRadius = value * ((scale.x + scale.y + scale.z) / 3)
      else
        scaledRadius = value * scale
      end
      lightObj:setField('radius', 0, tostring(scaledRadius))
    else
      lightObj:setField('radius', 0, tostring(value))
    end
  elseif property == "brightness" then
    lightObj:setField('brightness', 0, tostring(value))
  elseif property == "positionOffset" then
    local obj = findObjectByFileName(currentLightName)
    if obj then
      local newPos = calculateLightPosition(obj, {positionOffset = value})
      if newPos then
        lightObj:setPosition(newPos)
      end
    end
  elseif property == "innerAngle" then
    lightObj:setField('innerAngle', 0, tostring(value))
  elseif property == "outerAngle" then
    lightObj:setField('outerAngle', 0, tostring(value))
  end
end

-- Function to update a light property and propagate only that change to scene
local function updateLightProperty(point, propertyName, value)
  point[propertyName] = value
  modified = true
  
  -- Update only this property in the scene
  local matchingLights = findLightsForCurrentDefinition()
  for _, lightInfo in ipairs(matchingLights) do
    if lightInfo.pointIndex == currentPointIndex then
      updateLightPropertyInScene(lightInfo, propertyName, value)
      break
    end
  end
end

-- Function to update light properties in the scene (keep for compatibility but replace usage)
local function updateLightInScene(lightInfo, point, propertyName)
  if not lightInfo or not lightInfo.id or not point then return end
  
  local lightObj = scenetree.findObjectById(lightInfo.id)
  if not lightObj then return end
  
  -- Update color
  if point.color and (propertyName == "color" or propertyName == nil) then
    updateLightPropertyInScene(lightInfo, "color", point.color)
  end
  
  -- Update radius
  if point.radius and (propertyName == "radius" or propertyName == nil) then
    updateLightPropertyInScene(lightInfo, "radius", point.radius)
  end
  
  -- Update brightness
  if point.brightness and (propertyName == "brightness" or propertyName == nil) then
    updateLightPropertyInScene(lightInfo, "brightness", point.brightness)
  end
  
  -- Update position based on offset
  if point.positionOffset and (propertyName == "positionOffset" or propertyName == nil) then
    updateLightPropertyInScene(lightInfo, "positionOffset", point.positionOffset)
  end
  
  -- For spot lights, update additional properties
  if point.type == "SpotLight" then
    if point.innerAngle and (propertyName == "innerAngle" or propertyName == nil) then
      updateLightPropertyInScene(lightInfo, "innerAngle", point.innerAngle)
    end
    if point.outerAngle and (propertyName == "outerAngle" or propertyName == nil) then
      updateLightPropertyInScene(lightInfo, "outerAngle", point.outerAngle)
    end
  end
end

-- Function to invalidate the cache (call when lights are regenerated)
local function invalidateLightCache()
  cachedLights = {}
  lastCacheTime = 0
end

-- Function to update light data from object
local function updateLightDataFromObject(lightInfo)
  if not lightInfo or not lightInfo.id or not lightInfo.pointIndex then return end
  if not currentLightName or not lightData[currentLightName] then return end
  
  local lightObj = scenetree.findObjectById(lightInfo.id)
  if not lightObj then return end
  
  local light = lightData[currentLightName]
  local pointIndex = lightInfo.pointIndex
  local point = light[pointIndex]
  if not point then return end
  
  local obj = findObjectByFileName(currentLightName)
  if not obj then return end
  
  -- Calculate the offset from the parent object
  local objPos = obj:getPosition()
  local lightPos = lightObj:getPosition()
  local offset = lightPos - objPos
  
  -- Transform offset to local space
  dump(obj:getTransform())
  local transform = obj:getTransform():inverse()
  local localOffset = transform:mulV(offset)
  
  -- Account for scale
  local scale = obj:getScale()
  if type(scale) == "cdata" then
    localOffset.x = localOffset.x / scale.x
    localOffset.y = localOffset.y / scale.y
    localOffset.z = localOffset.z / scale.z
  else
    localOffset = localOffset / scale
  end
  
  -- Update position offset
  point.positionOffset.x = localOffset.x
  point.positionOffset.y = localOffset.y
  point.positionOffset.z = localOffset.z
  
  -- Update other properties from the light object
  local colorStr = lightObj:getField('color', 0)
  if colorStr then
    local r, g, b = string.match(colorStr, "([%d%.]+) ([%d%.]+) ([%d%.]+)")
    if r and g and b then
      point.color.x = tonumber(r)
      point.color.y = tonumber(g)
      point.color.z = tonumber(b)
    end
  end
  
  local radius = lightObj:getField('radius', 0)
  if radius then
    -- Adjust for scale
    if type(scale) == "cdata" then
      point.radius = tonumber(radius) / ((scale.x + scale.y + scale.z) / 3)
    else
      point.radius = tonumber(radius) / scale
    end
  end
  
  local brightness = lightObj:getField('brightness', 0)
  if brightness then
    point.brightness = tonumber(brightness)
  end
  
  modified = true
  
  -- Invalidate cache since we've modified the light data
  invalidateLightCache()
end

-- Automatically update light data if there's a discrepancy
local function autoUpdateIfNeeded(lightInfo, point)
  if not lightInfo or not lightInfo.distance then return false end
  
  -- If distance isn't exactly 0, there's a discrepancy
  if lightInfo.distance > 0.001 then
    updateLightDataFromObject(lightInfo)
    return true
  end
  return false
end

-- Function to find lights corresponding to the current definition
local function findLightsForCurrentDefinition()
  local currentTime = os.time()
  
  -- Check if we have a valid cached result that's not expired
  if currentLightName and 
     cachedLights[currentLightName] and 
     (currentTime - lastCacheTime) < cacheTimeout then
    
    -- Verify the cached lights still exist by ID
    local validResults = {}
    for _, lightInfo in ipairs(cachedLights[currentLightName]) do
      if lightInfo.id then
        local obj = scenetree.findObjectById(lightInfo.id)
        if obj then
          -- Light still exists, keep it in the valid results
          table.insert(validResults, lightInfo)
        end
      end
    end
    
    if #validResults > 0 then
      return validResults
    end
  end
  
  -- If we have persistent links for this light definition, use them
  if currentLightName and persistentLightLinks[currentLightName] then
    local validLinks = {}
    for _, linkInfo in ipairs(persistentLightLinks[currentLightName]) do
      local obj = scenetree.findObjectById(linkInfo.id)
      if obj then
        -- Copy the link to the validLinks
        table.insert(validLinks, linkInfo)
      end
    end
    
    -- If we found valid persistent links, use them and update the cache
    if #validLinks > 0 then
      cachedLights[currentLightName] = validLinks
      lastCacheTime = currentTime
      return validLinks
    end
  end
  
  -- Cache is invalid or expired, rebuild it
  local results = {}
  if not currentLightName or not lightData[currentLightName] then return results end
  
  -- Find the object that the light definition is for
  local obj = findObjectByFileName(currentLightName)
  if not obj then return results end
  
  -- Find all light objects in the scene
  local allLights = {}
  local searchTypes = {"PointLight", "SpotLight"}
  
  for _, lightType in ipairs(searchTypes) do
    local lights = scenetree.findClassObjects(lightType)
    for _, lightObj in ipairs(lights) do
      table.insert(allLights, lightObj)
    end
  end
  
  -- For each light in the definition, find the closest matching light in the scene
  local light = lightData[currentLightName]
  for i, pointData in ipairs(light) do
    local expectedPos = calculateLightPosition(obj, pointData)
    if expectedPos then
      -- First check if we have a persistent link for this point
      local persistentLight = nil
      if persistentLightLinks[currentLightName] then
        for _, linkInfo in ipairs(persistentLightLinks[currentLightName]) do
          if linkInfo.pointIndex == i then
            local obj = scenetree.findObjectById(linkInfo.id)
            if obj then
              persistentLight = {
                obj = obj,
                id = linkInfo.id,
                pointIndex = i,
                name = obj:getName(),
                distance = 0  -- Trust our persistent link
              }
              break
            end
          end
        end
      end
      
      -- If we found a persistent link, use it
      if persistentLight then
        table.insert(results, persistentLight)
      else
        -- Otherwise find the closest matching light
        local closestLight = nil
        local closestDist = 1.0 -- Maximum distance to consider (adjust as needed)
        
        for _, lightName in ipairs(allLights) do
          local lightObj = scenetree.findObject(lightName)

          -- Check if the light type matches
          if lightObj and lightObj:getClassName() == pointData.type then
            local lightPos = lightObj:getPosition()
            local dist = (lightPos - expectedPos):length()
            
            if dist < closestDist then
              closestDist = dist
              closestLight = lightObj
            end
          end
        end
        
        if closestLight then
          table.insert(results, {
            obj = closestLight,
            id = closestLight:getId(), -- Store the ID for future reference
            pointIndex = i,
            name = closestLight:getName(),
            distance = closestDist
          })
          
          -- Remove from all lights to prevent double matching
          for j, lightObj in ipairs(allLights) do
            if lightObj == closestLight then
              table.remove(allLights, j)
              break
            end
          end
        end
      end
    end
  end
  
  -- Cache the results
  cachedLights[currentLightName] = results
  lastCacheTime = currentTime
  
  return results
end

-- Function to select a light in the editor
local function selectLight(light)
  if light and light.id then
    editor.selectObjectById(light.id)
  end
end

-- Function to automatically update when editor selection changes
local function onEditorObjectSelectionChanged()
  local selectedObj = getCurrentSelection()
  if not selectedObj then return end
  
  -- Check if this object has a light definition
  local objName = getObjectFileName(selectedObj)
  if lightData[objName] then
    currentLightName = objName
  end
  
  -- If this is a light object, see if it matches our current light
  if selectedObj:getClassName() == "PointLight" or selectedObj:getClassName() == "SpotLight" then
    if currentLightName and lightData[currentLightName] then
      local matchingLights = findLightsForCurrentDefinition()
      
      for _, lightInfo in ipairs(matchingLights) do
        if lightInfo.id == selectedObj:getId() then
          -- Found a matching light - select its point in the UI
          currentPointIndex = lightInfo.pointIndex
          break
        end
      end
    end
  end
end

-- Function to create a default light point
local function createDefaultLightPoint(name, type)
  local newPoint = {
    name = name,
    type = type,
    positionOffset = vec3(0, 0, 0),
    color = vec3(1.0, 0.839, 0.4),
    radius = 5.0,
    brightness = 1.0
  }
  
  -- Add SpotLight-specific properties
  if type == "SpotLight" then
    newPoint.innerAngle = 30.0
    newPoint.outerAngle = 45.0
  end
  
  return newPoint
end

-- Abstract common light creation logic into a helper function
local function createLightObject(pointData, objPos)
  local lightObj = createObject(pointData.type)
  if lightObj then
    lightObj:setPosition(objPos)
    lightObj:registerObject(pointData.name)
    
    -- Set common properties
    lightObj:setField('color', 0, string.format("%f %f %f %f", 
      pointData.color.x, pointData.color.y, pointData.color.z, 1.0))
    lightObj:setField('radius', 0, tostring(pointData.radius))
    lightObj:setField('brightness', 0, tostring(pointData.brightness))
    
    -- Set SpotLight-specific properties
    if pointData.type == "SpotLight" then
      if pointData.innerAngle then lightObj:setField('innerAngle', 0, tostring(pointData.innerAngle)) end
      if pointData.outerAngle then lightObj:setField('outerAngle', 0, tostring(pointData.outerAngle)) end
    end
    
    scenetree.findObject("MissionGroup"):add(lightObj)
    return lightObj
  end
  return nil
end

-- Function to create light point and update persistent links
local function createAndLinkLight(objName, pointData, selectedObj, pointIndex)
  local lightObj = createLightObject(pointData, selectedObj:getPosition())
  if not lightObj then return nil end
  
  -- Store in permanent links array
  if not persistentLightLinks[objName] then
    persistentLightLinks[objName] = {}
  end
  
  -- Create a persistent link that won't expire
  table.insert(persistentLightLinks[objName], {
    id = lightObj:getId(),
    pointIndex = pointIndex,
    name = lightObj:getName()
  })
  
  -- Also update the regular cache
  if not cachedLights[objName] then
    cachedLights[objName] = {}
  end
  
  -- Directly link the light to the definition in the cache
  table.insert(cachedLights[objName], {
    obj = lightObj,
    id = lightObj:getId(),
    pointIndex = pointIndex,
    name = lightObj:getName(),
    distance = 0 -- Perfect match since we just created it
  })
  
  -- Update the cache time
  lastCacheTime = os.time()
  
  return lightObj
end

-- Helper function to update a property and propagate changes to scene
local function updateLightProperty(point, propertyName, value)
  point[propertyName] = value
  modified = true
  
  -- Update only this property in the scene
  local matchingLights = findLightsForCurrentDefinition()
  for _, lightInfo in ipairs(matchingLights) do
    if lightInfo.pointIndex == currentPointIndex then
      updateLightPropertyInScene(lightInfo, propertyName, value)
      break
    end
  end
end

-- Function to handle common UI patterns for light property controls
local function addPropertyControl(point, propertyName, controlFunc)
  local changed, newValue = controlFunc(point[propertyName])
  if changed then
    updateLightProperty(point, propertyName, newValue)
  end
  return changed
end

-- Main editor GUI function
local function onEditorGui()
  if not editor.isWindowVisible(toolWindowName) then return end
  
  if editor.beginWindow(toolWindowName, "Light Generation Editor", im.WindowFlags_MenuBar) then
    local level = getCurrentLevelIdentifier()
    if not level then
      im.Text("No level loaded!")
      editor.endWindow()
      return
    end
    
    -- Menu Bar
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        if im.MenuItem1("New") then
          lightData = {}
          currentLightName = nil
          modified = true
        end
        if im.MenuItem1("Load...") then
          loadLightData()
        end
        if im.MenuItem1("Save") then
          saveLightData()
        end
        im.EndMenu()
      end
      im.EndMenuBar()
    end

    if modified then
      im.TextColored(im.ImVec4(1, 1, 0, 1), "Modified (unsaved)")
    end
    
    im.Text("Current Level: " .. level)
    
    -- Section for creating a new light based on selected object
    im.Separator()
    im.Text("Create New Light Definition:")
    
    local selectedObj = getCurrentSelection()
    if not selectedObj then
      im.TextColored(im.ImVec4(1, 0.5, 0.5, 1), "Please select an object first!")
    else
      local objName = getObjectFileName(selectedObj)
      im.Text("Selected Object: " .. objName)
      im.Text("Class: " .. selectedObj:getClassName())
      
      if im.Button("Create Light Definition for Selected Object", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        if objName ~= "" and not lightData[objName] then
          -- Initialize the light definition
          lightData[objName] = {}
          
          -- Add a default point light to the definition
          local defaultPoint = createDefaultLightPoint("PointLight_1", "PointLight")
          table.insert(lightData[objName], defaultPoint)
          
          currentLightName = objName
          currentPointIndex = 1
          modified = true
          
          -- Create and link light object in the scene
          local lightObj = createAndLinkLight(objName, defaultPoint, selectedObj, 1)
          if lightObj then
            -- Select the light in the editor
            editor.selectObjectById(lightObj:getId())
            log('I', logTag, "Created and linked new light object in scene")
          end
          
          log('I', logTag, "Created new light definition for: " .. objName)
        else
          editor.showNotification("Object name already exists or is invalid!")
        end
      end
    end
    
    im.Separator()
    
    -- List of existing lights
    local lightCount = countTableEntries(lightData)
    im.Text("Light Definitions (" .. lightCount .. "):")
    
    for lightName, light in pairs(lightData) do
      local isSelected = (currentLightName == lightName)
      if isSelected then
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0.2, 0.6, 0.8, 1.0))
      end
      
      -- Check if the object still exists
      local objExists = findObjectByFileName(lightName) ~= nil
      local displayName = lightName
      
      if not objExists then
        displayName = displayName .. " (Object Missing)"
        if isSelected then 
          im.PopStyleColor()
          im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8, 0.2, 0.2, 1.0))
        end
      end
      
      if im.Button(displayName .. "##" .. lightName, im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        currentLightName = lightName
        
        -- Select the object in the editor too
        local obj = findObjectByFileName(lightName)
        if obj then
          editor.selectObjectById(obj:getId())
        end
      end
      
      if isSelected then
        im.PopStyleColor()
      end
    end
    
    im.Separator()
    
    -- Edit the currently selected light
    if currentLightName and lightData[currentLightName] then
      local light = lightData[currentLightName]
      im.Text("Editing Light: " .. currentLightName)
      
      -- Ensure the lightData has an array for light points
      if not light[1] then
        light[1] = {}
      end
      
      -- Show object information
      local obj = findObjectByFileName(currentLightName)
      if obj then
        im.Text("Object exists in scene")
        im.Text("Class: " .. obj:getClassName())
      else
        im.TextColored(im.ImVec4(1, 0.5, 0.5, 1), "Warning: Object not found in scene!")
      end
      
      im.Separator()
      im.Text("Light Points:")
      
      -- Show number of light points
      local pointCount = #light
      im.Text("Points: " .. pointCount)
      
      -- Buttons to add new light points
      if im.Button("Add New Point Light", im.ImVec2(im.GetContentRegionAvailWidth()/2, 0)) then
        local newPoint = createDefaultLightPoint("PointLight_" .. (#light + 1), "PointLight")
        table.insert(light, newPoint)
        currentPointIndex = #light
        modified = true
        
        local lightObj = createAndLinkLight(currentLightName, newPoint, selectedObj, currentPointIndex)
        if lightObj then
          editor.selectObjectById(lightObj:getId())
        end
      end
      
      im.SameLine()
      
      if im.Button("Add New Spot Light", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        local newPoint = createDefaultLightPoint("SpotLight_" .. (#light + 1), "SpotLight")
        table.insert(light, newPoint)
        currentPointIndex = #light
        modified = true
        
        local lightObj = createAndLinkLight(currentLightName, newPoint, selectedObj, currentPointIndex)
        if lightObj then
          editor.selectObjectById(lightObj:getId())
        end
      end
      
      -- Point selector
      if pointCount > 0 then
        local selectedPoint = im.IntPtr(currentPointIndex)
        if im.SliderInt("Select Point", selectedPoint, 1, pointCount) then
          currentPointIndex = selectedPoint[0]
        end
        
        -- Find corresponding light in scene
        local matchingLights = findLightsForCurrentDefinition()
        local currentPointLight = nil
        
        for _, lightInfo in ipairs(matchingLights) do
          if lightInfo.pointIndex == currentPointIndex then
            currentPointLight = lightInfo
            break
          end
        end
        
        -- Add button to manually refresh light cache
        if im.Button("Refresh Light Detection", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
          invalidateLightCache()
        end
        
        -- Add information about the found light
        if currentPointLight then
          im.TextColored(im.ImVec4(0.2, 1.0, 0.2, 1), "Found matching light: " .. currentPointLight.name)
          im.Text("Light ID: " .. tostring(currentPointLight.id))
          
          if im.Button("Select Light in Scene", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            selectLight(currentPointLight)
          end
          
          -- Add button to update data from the light in scene
          if im.Button("Update from Scene Light", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            updateLightDataFromObject(currentPointLight)
          end
        else
          im.TextColored(im.ImVec4(1, 0.5, 0.5, 1), "Light not found in scene (preview first)")
        end
        
        -- Edit the selected point
        local point = light[currentPointIndex]
        if point then
          im.Separator()
          im.Text("Editing Point " .. currentPointIndex)
          
          -- Light name
          local lightPointName = im.ArrayChar(128, point.name or "Light")
          if im.InputText("Point Name", lightPointName, 128) then
            point.name = ffi.string(lightPointName)
            modified = true
          end
          
          -- Light type
          local lightTypes = {"PointLight", "SpotLight"}
          local currentTypeIndex = 1
          for i, typeName in ipairs(lightTypes) do
            if point.type == typeName then
              currentTypeIndex = i
              break
            end
          end
          local typeIndex = im.IntPtr(currentTypeIndex)
          
          if im.BeginCombo("Light Type", lightTypes[typeIndex[0]]) then
            for i, typeName in ipairs(lightTypes) do
              if im.Selectable1(typeName, i == typeIndex[0]) then
                typeIndex[0] = i
                point.type = lightTypes[i]
                modified = true
              end
            end
            im.EndCombo()
          end
          
          -- Handle position offset controls
          im.Text("Position Offset:")
          local posChanged = false
          
          -- Create a helper to handle all three position components
          local function handlePosComponent(component, label)
            local value = im.FloatPtr(point.positionOffset[component] or 0)
            if im.InputFloat(label, value, 0.1, 0.5) then
              point.positionOffset[component] = value[0]
              return true
            end
            return false
          end
          
          posChanged = handlePosComponent("x", "X Offset") or posChanged
          posChanged = handlePosComponent("y", "Y Offset") or posChanged  
          posChanged = handlePosComponent("z", "Z Offset") or posChanged
          
          if posChanged then
            modified = true
            -- Update scene light
            local matchingLights = findLightsForCurrentDefinition()
            for _, lightInfo in ipairs(matchingLights) do
              if lightInfo.pointIndex == currentPointIndex then
                updateLightInScene(lightInfo, point, "positionOffset")
                break
              end
            end
          end
          
          -- Light color using RGB sliders with preview
          if not point.color then
            point.color = vec3(1.0, 0.839, 0.4)
          end
          
          im.Text("Light Color:")
          
          -- Create individual float pointers
          local r = im.FloatPtr(point.color.x)
          local g = im.FloatPtr(point.color.y)
          local b = im.FloatPtr(point.color.z)
          
          -- Manually create an array for ColorEdit3
          local colorArray = im.ArrayFloat(3)
          colorArray[0] = r[0]
          colorArray[1] = g[0]
          colorArray[2] = b[0]
          
          -- Use ColorEdit3 with the proper float pointer
          local colorFlags = bit.bor(im.ColorEditFlags_DisplayRGB)
          local colorChanged = im.ColorEdit3("##lightcolor", colorArray, colorFlags)
          
          -- Update the color values if changed
          if colorChanged then
            point.color.x = colorArray[0]
            point.color.y = colorArray[1]
            point.color.z = colorArray[2]
            modified = true
            
            -- Update the actual light in the scene
            local matchingLights = findLightsForCurrentDefinition()
            for _, lightInfo in ipairs(matchingLights) do
              if lightInfo.pointIndex == currentPointIndex then
                updateLightInScene(lightInfo, point, "color")
                break
              end
            end
          end
          
          -- Add a reset button to set a default color
          im.SameLine()
          if im.Button("Reset") then
            point.color.x = 1.0
            point.color.y = 0.839
            point.color.z = 0.4
            modified = true
          end
          
          -- Light radius with simplified property handling
          local radius = im.FloatPtr(point.radius or 5.0)
          if im.InputFloat("Radius", radius, 0.5, 2.0) then
            updateLightProperty(point, "radius", radius[0])
          end
          
          -- Light brightness with simplified property handling
          local brightness = im.FloatPtr(point.brightness or 1.0)
          if im.SliderFloat("Brightness", brightness, 0.1, 5.0) then
            updateLightProperty(point, "brightness", brightness[0])
          end
          
          -- SpotLight-specific properties with simplified handling
          if point.type == "SpotLight" then
            -- Initialize default values if not set
            if not point.innerAngle then point.innerAngle = 30.0 end
            if not point.outerAngle then point.outerAngle = 45.0 end
            
            local innerAngle = im.FloatPtr(point.innerAngle)
            if im.SliderFloat("Inner Angle", innerAngle, 0.0, 90.0) then
              updateLightProperty(point, "innerAngle", innerAngle[0])
            end
            
            local outerAngle = im.FloatPtr(point.outerAngle)
            if im.SliderFloat("Outer Angle", outerAngle, innerAngle[0], 90.0) then
              updateLightProperty(point, "outerAngle", outerAngle[0])
            end
          end
          
          -- Delete light point button
          if im.Button("Delete This Light Point", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            -- Find and delete the actual light object first
            local matchingLights = findLightsForCurrentDefinition()
            for _, lightInfo in ipairs(matchingLights) do
              if lightInfo.pointIndex == currentPointIndex then
                -- Found the light object - delete it from the scene
                local lightObj = scenetree.findObjectById(lightInfo.id)
                if lightObj then
                  lightObj:delete()
                  log('I', logTag, "Deleted light object from scene: " .. lightInfo.name)
                end
                
                -- Remove from persistent links if exists
                if persistentLightLinks[currentLightName] then
                  for i, linkInfo in ipairs(persistentLightLinks[currentLightName]) do
                    if linkInfo.pointIndex == currentPointIndex then
                      table.remove(persistentLightLinks[currentLightName], i)
                      break
                    end
                  end
                end
                
                -- Also clear from cached lights
                if cachedLights[currentLightName] then
                  for i, cachedInfo in ipairs(cachedLights[currentLightName]) do
                    if cachedInfo.pointIndex == currentPointIndex then
                      table.remove(cachedLights[currentLightName], i)
                      break
                    end
                  end
                end
                
                break
              end
            end
            
            -- Fix the pointIndex references for remaining lights
            if persistentLightLinks[currentLightName] then
              for _, linkInfo in ipairs(persistentLightLinks[currentLightName]) do
                if linkInfo.pointIndex > currentPointIndex then
                  linkInfo.pointIndex = linkInfo.pointIndex - 1
                end
              end
            end
            
            if cachedLights[currentLightName] then
              for _, cachedInfo in ipairs(cachedLights[currentLightName]) do
                if cachedInfo.pointIndex > currentPointIndex then
                  cachedInfo.pointIndex = cachedInfo.pointIndex - 1
                end
              end
            end
            
            -- Now remove the light point from the data
            table.remove(light, currentPointIndex)
            if currentPointIndex > #light then
              currentPointIndex = math.max(1, #light)
            end
            
            modified = true
          end
        end
      end
      
      im.Separator()
      
      -- Delete light button
      if im.Button("Delete Light Definition", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        lightData[currentLightName] = nil
        currentLightName = nil
        modified = true
      end
    end

    if lightCount > 0 then
      
      im.Separator()
      
      -- Preview buttons
      if im.Button("Preview Lights", im.ImVec2(im.GetContentRegionAvailWidth()/2, 0)) then
        saveLightData() -- Save first
        previewLights()
      end
      
      im.SameLine()
      
      if im.Button("Clear Preview", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        clearPreview()
      end
    end
    
    editor.endWindow()
  end
end

-- Called when editor activates this tool
local function onActivate()
  log('I', logTag, "Light Generation Editor activated")
  loadLightData()
end

-- Window menu item callback
local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

-- Called when editor initializes
local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(600, 600))
  editor.addWindowMenuItem("Light Generation Editor", onWindowMenuItem)
  log('I', logTag, "Light Generation Editor initialized")
  loadLightData()
end

-- Function that runs when this extension is unloaded
local function onExtensionUnloaded()
  if modified then
    log('I', logTag, "Saving light data before unloading")
    saveLightData()
  end
  clearPreview()
end

-- Module exports
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onWindowMenuItem = onWindowMenuItem
M.onActivate = onActivate
M.onExtensionUnloaded = onExtensionUnloaded
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged

return M
