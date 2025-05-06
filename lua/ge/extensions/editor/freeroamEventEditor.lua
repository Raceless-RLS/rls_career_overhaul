-- World Editor Freeroam Event Creator

-- TODO:
-- Sectioned editor (Rewards, Race Type, Checkpoints, Triggers)
-- Reward Calculator 
-- Alt Route Handling
-- Custom Checkpoint Editor (ProcessRoad will need to be updated to support this)
-- More color styling to show what needs to be done
-- Button color coding to show active trigger placement
-- Confirmation box when deleting a race

local M = {}
local logTag = 'editor_freeroamEventEditor' -- this is used for logging as a tag
local im = ui_imgui -- shortcut for imgui
local toolWindowName = "editor_freeroamEventEditor_window"

local processRoad = require('gameplay/events/freeroam/processRoad')
local checkpointManager = require('gameplay/events/freeroam/checkpointManager')
local races = {}
local currentRaceName = nil
local modified = false
local raceTypes = {"motorsport", "drift", "drag", "offroad", "rally"}
local levelTriggers = {}
local levelDecalRoads = {}
local pendingTriggerType = nil
local pendingTriggerRace = nil
local pendingTriggerName = nil
local showTriggerPlacementHelp = false
local showingRaceCheckpoints = false

local lookingForRoad = false

-- Template for new race
local raceTemplate = {
  bestTime = 60,
  reward = 1000,
  label = "New Race",
  checkpointRoad = nil,
  type = {"motorsport"}
}

-- Function to create a new race
local function createNewRace()
  local newRaceName = "race_" .. os.time()
  races[newRaceName] = deepcopy(raceTemplate)
  races[newRaceName].label = "New Race"
  currentRaceName = newRaceName
  modified = true
  log('I', logTag, "Created new race: " .. newRaceName)
  return newRaceName
end

-- Function to load race data from file
local function loadRaceData()
  local level = getCurrentLevelIdentifier()
  if not level then return end
  
  local filePath = "levels/" .. level .. "/race_data.json"
  local raceData = jsonReadFile(filePath) or {races = {}}
  races = raceData.races or {}
  modified = false

  for raceName, race in pairs(races) do
    for _, rType in ipairs(race.type) do
      if not tableContains(raceTypes, rType) then
        table.insert(raceTypes, rType)
      end
    end
  end
  
  log('I', logTag, "Loaded race data for level: " .. level)
end

-- Function to save race data to file
local function saveRaceData()
  local level = getCurrentLevelIdentifier()
  if not level then 
    log('E', logTag, "No level loaded!")
    return 
  end
  
  local filePath = "levels/" .. level .. "/race_data.json"
  local raceData = {races = races}
  jsonWriteFile(filePath, raceData, true)
  modified = false
  log('I', logTag, "Saved race data to: " .. filePath)
end

-- Function to create new empty race data
local function createNewRaceData()
  races = {}
  currentRaceName = nil
  modified = true
  log('I', logTag, "Created new race data")
end

-- Count the number of entries in a table
local function countTableEntries(t)
  local count = 0
  if t then
    for _ in pairs(t) do count = count + 1 end
  end
  return count
end

local function showRaceCheckpoints()
  if not currentRaceName then return end
  dump(races[currentRaceName])

  local checkpoints, altCheckpoints = processRoad.getCheckpoints(races[currentRaceName])
  checkpointManager.createCheckpoints(checkpoints, altCheckpoints)
end

local function removeRaceCheckpoints()
  checkpointManager.removeCheckpoints()
  processRoad.reset()
end

-- Function to find all triggers and decal roads in the level
local function findLevelObjects()
  -- Find all triggers and decal roads
  levelTriggers = {}
  levelDecalRoads = {}
  
  -- The correct way to iterate through objects in BeamNG
  local missionGroup = scenetree.findObject("MissionGroup")
  if not missionGroup then return end
  
  -- Recursive function to search for objects
  local function searchObjects(group)
    for i, objName in ipairs(group:getObjects()) do
      local obj = scenetree.findObject(objName)
      if obj then
        if obj:getClassName() == "BeamNGTrigger" then
          table.insert(levelTriggers, obj:getName())
        elseif obj:getClassName() == "DecalRoad" then
          table.insert(levelDecalRoads, obj:getName())
        end
        -- If this is a group, search inside it
        if obj:getClassName() == "SimGroup" then
          searchObjects(obj)
        end
      end
    end
  end
  
  searchObjects(missionGroup)
end

local function findDecalRoads()
  levelDecalRoads = {}
  local missionGroup = scenetree.findObject("MissionGroup")
  if not missionGroup then return end

  local function searchObjects(group)
    for i, objName in ipairs(group:getObjects()) do
      local obj = scenetree.findObject(objName)
      if obj then
        if obj:getClassName() == "DecalRoad" then
          table.insert(levelDecalRoads, obj:getName())
        end
        -- If this is a group, search inside it
        if obj:getClassName() == "SimGroup" then
          searchObjects(obj)
        end
      end
    end
  end
  
  searchObjects(missionGroup)

  log('I', logTag, "Found " .. #levelDecalRoads .. " decal roads")
end

-- Function to create a trigger with a specific name (used as callback)
local function createTriggerWithName(instance)
  if instance and pendingTriggerName then
    instance:setName(pendingTriggerName)
    log('I', logTag, "Created trigger with name: " .. pendingTriggerName)
    
    -- Add to levelTriggers list if it exists
    if levelTriggers then
      table.insert(levelTriggers, pendingTriggerName)
    end
    
    -- Clear pending name
    pendingTriggerName = nil
  end
end

-- Our custom object placement system
local function triggerPlacementUpdate()
  if not pendingTriggerType or not pendingTriggerRace then return end
  
  -- Get ray from camera to mouse position
  local res = getCameraMouseRay()
  
  -- Cast ray against scene
  local hit = cameraMouseRayCast(true)

  local pos = vec3(worldEditorCppApi.snapPositionToGrid(hit.pos))
  local lineWidth = editor.getPreference("gizmos.general.lineThicknessScale") * 4
  debugDrawer:drawLineInstance((pos - vec3(2, 0, 0)), (pos + vec3(2, 0, 0)), lineWidth, ColorF(1, 0, 0, 1))
  debugDrawer:drawLineInstance((pos - vec3(0, 2, 0)), (pos + vec3(0, 2, 0)), lineWidth, ColorF(0, 1, 0, 1))
  debugDrawer:drawLineInstance((pos - vec3(0, 0, 2)), (pos + vec3(0, 0, 2)), lineWidth, ColorF(0, 0, 1, 1))
  
  -- Create object on mouse click
  if im.IsMouseClicked(0) and editor.isViewportHovered() then
    -- Create the trigger name based on type and race
    local prefix
    if pendingTriggerType == "start" then
      prefix = "fre_start_"
    elseif pendingTriggerType == "staging" then
      prefix = "fre_staging_"
    elseif pendingTriggerType == "finish" then
      prefix = "fre_finish_"
    end
    
    local triggerName = prefix .. pendingTriggerRace
    
    -- Create the trigger object
    local obj = worldEditorCppApi.createObject("BeamNGTrigger")
    if obj then
      -- Set name and register
      obj:setName(triggerName)
      obj:registerObject("")
      
      -- Position at hit location
      obj:setPosition(pos)
      
      -- Get appropriate parent
      local parent = scenetree.MissionGroup
      local selection = editor.selection
      if selection and selection.object and #selection.object > 0 then
        local sel = scenetree.findObjectById(selection.object[1])
        if sel and sel:isSubClassOf("SimGroup") then
          parent = sel
        elseif sel then
          local group = sel:getGroup()
          if group and group:getName() ~= "MissionCleanup" then
            parent = group
          end
        end
      end
      
      -- Add to parent
      if parent then
        parent:addObject(obj)
      end
      
      -- Select the new trigger
      editor.selectObjectById(obj:getID())
      
      -- Add to level triggers list
      if levelTriggers then
        table.insert(levelTriggers, triggerName)
      end
      
      -- Log creation
      log('I', logTag, "Created new trigger: " .. triggerName)
      
      -- Clear pending state
      pendingTriggerType = nil
      pendingTriggerRace = nil
      showTriggerPlacementHelp = false
    end
  end
end

-- Function to initiate trigger creation
local function createOrSelectTrigger(triggerType, raceName)
  if not raceName then return end
  
  -- Trigger prefix based on type
  local prefix
  if triggerType == "start" then
    prefix = "fre_start_"
  elseif triggerType == "staging" then
    prefix = "fre_staging_"
  elseif triggerType == "finish" then
    prefix = "fre_finish_"
  end
  
  local triggerName = prefix .. raceName
  
  -- Check if the trigger already exists
  local existingTrigger = scenetree.findObject(triggerName)
  
  if existingTrigger then
    -- Select the existing trigger
    editor.selectObjectById(existingTrigger:getID())
    log('I', logTag, "Selected trigger: " .. triggerName)
  else
    -- Set pending state for custom placement
    pendingTriggerType = triggerType
    pendingTriggerRace = raceName
    showTriggerPlacementHelp = true
    log('I', logTag, "Ready to place " .. triggerType .. " trigger for race: " .. raceName)
    editor.showNotification("Click on the map to place " .. triggerType .. " trigger")
  end
end

-- Helper function to get the currently selected parent object
local function getCurrentSelectedParent()
  if editor.selection and editor.selection.object and #editor.selection.object > 0 then
    local obj = scenetree.findObjectById(editor.selection.object[1])
    if obj and (obj:getClassName() == "SimGroup" or obj:isSubClassOf("SimGroup")) then
      return obj
    end
    if obj then
      local group = obj:getGroup()
      if group and group:getName() ~= "MissionCleanup" then
        return group
      end
    end
  end
  -- Default to MissionGroup
  return scenetree.MissionGroup
end

local function tableIndexOf(table, value)
  for i, v in ipairs(table) do
    if v == value then
      return i
    end
  end
end

-- Function to check if a race is complete
local function isRaceComplete(raceName, race)
  -- Check for required components
  local hasCheckpointRoad = race.checkpointRoad ~= nil and race.checkpointRoad ~= ""
  
  -- Check for triggers
  local hasStartTrigger = scenetree.findObject("fre_start_" .. raceName) ~= nil
  local hasStagingTrigger = scenetree.findObject("fre_staging_" .. raceName) ~= nil
  
  -- Point-to-point specific requirements
  if not race.hotlap then
    local hasFinishTrigger = scenetree.findObject("fre_finish_" .. raceName) ~= nil
    return hasCheckpointRoad and hasStartTrigger and hasStagingTrigger and hasFinishTrigger
  else
    return hasCheckpointRoad and hasStartTrigger and hasStagingTrigger
  end
end

-- Helper function to get missing components list
local function getMissingComponents(raceName, race)
  local missing = {}
  
  if not race.checkpointRoad or race.checkpointRoad == "" then
    table.insert(missing, "Checkpoint road")
  end
  
  if not scenetree.findObject("fre_start_" .. raceName) then
    table.insert(missing, "Start trigger")
  end
  
  if not scenetree.findObject("fre_staging_" .. raceName) then
    table.insert(missing, "Staging trigger")
  end
  
  if not race.hotlap then
    if not scenetree.findObject("fre_finish_" .. raceName) then
      table.insert(missing, "Finish trigger")
    end
  end
  
  return missing
end

-- Main editor GUI function
local function onEditorGui()
  if not editor.isWindowVisible(toolWindowName) then return end
  
  if editor.beginWindow(toolWindowName, "Freeroam Event Editor", im.WindowFlags_MenuBar) then
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
          createNewRaceData()
        end
        if im.MenuItem1("Load...") then
          loadRaceData()
        end
        if im.MenuItem1("Save") then
          saveRaceData()
        end
        im.EndMenu()
      end
      im.EndMenuBar()
    end

    if modified then
        im.TextColored(im.ImVec4(1, 1, 0, 1), "Modified (unsaved)")
    end
    
    im.Text("Current Level: " .. level)
    
    -- Create new race button
    if im.Button("Create New Race", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
      createNewRace()
    end
    
    im.Separator()
    
    -- Display races count
    local raceCount = countTableEntries(races)
    im.Text("Races (" .. raceCount .. "):")
    
    -- Display each race with a simpler UI
    for raceName, race in pairs(races) do
      local complete = isRaceComplete(raceName, race)    
      
      if not complete then
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0.8, 0.2, 0.2, 1.0))
        im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0.9, 0.3, 0.3, 1.0))
        im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(1.0, 0.4, 0.4, 1.0))
      end

      if im.Button(raceName .. ": " .. (race.label or "Unnamed") .. "##" .. raceName) then
        currentRaceName = raceName
        if showingRaceCheckpoints then
            removeRaceCheckpoints()
        end
      end
      
      if not complete then
        im.PopStyleColor(3)  
        -- Show tooltip with missing components
        if im.IsItemHovered() then
          im.BeginTooltip()
          im.Text("Incomplete race! Missing:")
          local missing = getMissingComponents(raceName, race)
          for _, component in ipairs(missing) do
            im.BulletText(component)
          end
          im.EndTooltip()
        end
      end
    end
    
    im.Separator()
    
    -- Edit the currently selected race
    if currentRaceName and races[currentRaceName] then
      local race = races[currentRaceName]
      im.Text("Editing Race: " .. currentRaceName)

      im.Separator()
      local changed = false
      
      -- Edit Race ID directly
      im.PushID1(currentRaceName .. "_id")
      local raceNameBuf = im.ArrayChar(128, currentRaceName)
      if im.InputText("Race ID", raceNameBuf, 128, im.InputTextFlags_EnterReturnsTrue) then
        local newRaceName = ffi.string(raceNameBuf)
        if newRaceName ~= currentRaceName and newRaceName ~= "" and not races[newRaceName] then
          -- First, check for and rename any associated triggers
          local prefixes = {"fre_start_", "fre_staging_", "fre_finish_"}
          
          for _, prefix in ipairs(prefixes) do
            local oldTriggerName = prefix .. currentRaceName
            local newTriggerName = prefix .. newRaceName
            
            -- Find the trigger with old name
            local trigger = scenetree.findObject(oldTriggerName)
            if trigger then
              -- Rename the trigger
              trigger:setName(newTriggerName)
              
              -- Update levelTriggers list if we have it
              if levelTriggers then
                for i, name in ipairs(levelTriggers) do
                  if name == oldTriggerName then
                    levelTriggers[i] = newTriggerName
                    break
                  end
                end
              end
              
              log('I', logTag, "Renamed trigger from " .. oldTriggerName .. " to " .. newTriggerName)
            end
          end
          
          -- Now proceed with race renaming
          -- Create copy of race data with new name
          races[newRaceName] = deepcopy(race)
          -- Remove old race data
          races[currentRaceName] = nil
          -- Update current race name
          currentRaceName = newRaceName
          changed = true
          
          -- Log the changes
          log('I', logTag, "Renamed race from " .. currentRaceName .. " to " .. newRaceName)
        end
      end
      im.PopID()
      
      -- Edit Race Label
      local raceLabel = im.ArrayChar(128, race.label or "")
      if im.InputText("Race Label", raceLabel) then
        race.label = ffi.string(raceLabel)
        changed = true
      end
      
      -- Best Time
      local bestTime = im.FloatPtr(race.bestTime or 60)
      if im.InputFloat("Best Time (seconds)", bestTime, 1, 5, "%.1f") then
        race.bestTime = bestTime[0]
        changed = true
      end
      
      -- Reward
      local reward = im.IntPtr(race.reward or 1000)
      if im.InputInt("Reward ($)", reward, 100, 1000) then
        race.reward = reward[0]
        changed = true
      end
      
      -- Apex Offset
      local hasApexOffset = im.BoolPtr(race.apexOffset ~= nil)
      if im.Checkbox("Use Apex Offset", hasApexOffset) then
        if hasApexOffset[0] then
          race.apexOffset = 1.0
        else
          race.apexOffset = nil
        end
        changed = true
      end
      
      if hasApexOffset[0] then
        local apexOffset = im.FloatPtr(race.apexOffset or 1.0)
        if im.InputFloat("Apex Offset (Nodes)", apexOffset, 0.1, 1.0, "%.1f") then
          race.apexOffset = apexOffset[0]
          changed = true
        end
      end
      
      -- Running Start
      local runningStart = im.BoolPtr(race.runningStart ~= false) -- Default to true
      if im.Checkbox("Running Start", runningStart) then
        race.runningStart = runningStart[0]
        changed = true
      end
      
      -- Updated Race Type section (replace the existing Race Type section in the editor)
      im.Text("Race Type:")

      local customType = im.ArrayChar(128, "")
      if im.InputText("Custom Type", customType, 128, im.InputTextFlags_EnterReturnsTrue) then
        table.insert(raceTypes, ffi.string(customType))
        table.insert(race.type, ffi.string(customType))
        changed = true
      end

      for _, rType in ipairs(race.type) do
        if not tableContains(raceTypes, rType) then
          table.insert(raceTypes, rType)
        end
      end

      for _, rType in ipairs(raceTypes) do
        -- Initialize type if it doesn't exist
        if not race.type then race.type = {"motorsport"} end
        
        local isSelected = im.BoolPtr(tableContains(race.type, rType))
        local changed = false
        
        if im.Checkbox(rType, isSelected) then
          if isSelected[0] then
            if not tableContains(race.type, rType) then
              table.insert(race.type, rType)
              changed = true
            end
          else
            if tableContains(race.type, rType) then
              table.remove(race.type, tableIndexOf(race.type, rType))
              changed = true
            end
          end
        end
        if changed then
          modified = true
        end
      end
      
      -- Checkpoint Road
      im.Text("Checkpoint Road:")
      local loopSelected = im.IntPtr(race.hotlap and 1 or 2)
      
      if im.RadioButton2("Looped", loopSelected, im.Int(1)) then
        race.hotlap = race.hotlap or (race.bestTime * 0.9)
        changed = true
      end
      
      im.SameLine()
      
      if im.RadioButton2("Point-to-Point", loopSelected, im.Int(2)) then
        race.hotlap = nil
        changed = true
      end

      if race.looped == true then
        local hotlap = im.FloatPtr(race.hotlap or (race.bestTime * 0.9))
        if not race.hotlap then
            race.hotlap = hotlap[0]
        end
        if im.InputFloat("Hotlap Time (seconds)", hotlap, 1, 5, "%.1f") then
          race.hotlap = hotlap[0]
          changed = true
        end
      end
      
      -- Road selection
      if im.BeginCombo("Select Road##main", race.checkpointRoad or "Choose a road") then
        if race.checkpointRoad and not tableContains(levelDecalRoads, race.checkpointRoad) then
            race.checkpointRoad = nil
        end
        lookingForRoad = true
        for _, roadName in ipairs(levelDecalRoads) do
          if roadName == "" then
            goto continue
          end
          if im.Selectable1(roadName) then
            race.checkpointRoad = roadName
            changed = true
          end
          ::continue::
        end
        im.EndCombo()
      else
        lookingForRoad = false
      end

      if im.Button("Show Checkpoints", im.ImVec2(im.GetContentRegionAvailWidth()/2, 0)) then
        showingRaceCheckpoints = true
        showRaceCheckpoints()
      end
      im.SameLine()
      if im.Button("Hide Checkpoints", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        showingRaceCheckpoints = false
        removeRaceCheckpoints()
      end
      
      -- Trigger buttons with status indication
      im.Separator()
      im.Text("Race Triggers:")
      
      -- Function to check if trigger exists
      local function triggerExists(prefix, raceName)
        return scenetree.findObject(prefix .. raceName) ~= nil
      end

      -- Start trigger
      local startExists = triggerExists("fre_start_", currentRaceName)
      local buttonText = startExists and "Select Start Trigger" or "Create Start Trigger"
      if pendingTriggerType == "start" and pendingTriggerRace == currentRaceName then
        buttonText = "Cancel Start Trigger Placement"
      end
      if im.Button(buttonText) then
        if pendingTriggerType == "start" and pendingTriggerRace == currentRaceName then
          -- Cancel placement
          pendingTriggerType = nil
          pendingTriggerRace = nil
          showTriggerPlacementHelp = false
        else
          createOrSelectTrigger("start", currentRaceName)
        end
      end

      im.SameLine()

      -- Staging trigger
      local stagingExists = triggerExists("fre_staging_", currentRaceName)
      buttonText = stagingExists and "Select Staging Trigger" or "Create Staging Trigger"
      if pendingTriggerType == "staging" and pendingTriggerRace == currentRaceName then
        buttonText = "Cancel Staging Trigger Placement"
      end
      if im.Button(buttonText) then
        if pendingTriggerType == "staging" and pendingTriggerRace == currentRaceName then
          -- Cancel placement
          pendingTriggerType = nil
          pendingTriggerRace = nil
          showTriggerPlacementHelp = false
        else
          createOrSelectTrigger("staging", currentRaceName)
        end
      end

      -- Finish trigger (only for point-to-point races)
      if not race.hotlap then
        im.SameLine()
        local finishExists = triggerExists("fre_finish_", currentRaceName)
        buttonText = finishExists and "Select Finish Trigger" or "Create Finish Trigger"
        if pendingTriggerType == "finish" and pendingTriggerRace == currentRaceName then
          buttonText = "Cancel Finish Trigger Placement"
        end
        if im.Button(buttonText) then
          if pendingTriggerType == "finish" and pendingTriggerRace == currentRaceName then
            -- Cancel placement
            pendingTriggerType = nil
            pendingTriggerRace = nil
            showTriggerPlacementHelp = false
          else
            createOrSelectTrigger("finish", currentRaceName)
          end
        end
      end
      
      -- Show help text if placing trigger
      if showTriggerPlacementHelp then
        im.TextColored(im.ImVec4(1, 1, 0, 1), "Click on the map to place the trigger")
      end
      
      -- Delete race button
      im.Separator()
      if im.Button("Delete Race", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
        races[currentRaceName] = nil
        currentRaceName = nil
        changed = true
      end
      
      if changed then
        modified = true
      end
    end
    
    if modified then
      im.TextColored(im.ImVec4(1, 1, 0, 1), "Modified (unsaved)")
    end
    
    editor.endWindow()
  end
end

-- Helper function to check if a value exists in a table
local function tableContains(table, val)
  if not table then return false end
  for _, v in ipairs(table) do
    if v == val then return true end
  end
  return false
end

-- Called when editor activates this tool
local function onActivate()
  log('I', logTag, "Freeroam Event Editor activated")
  findLevelObjects()
end

-- Window menu item callback
local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

-- Called when editor initializes
local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(600, 600))
  editor.addWindowMenuItem("Freeroam Event Editor", onWindowMenuItem)
  log('I', logTag, "Freeroam Event Editor initialized")
  loadRaceData()
  findLevelObjects()
end

local internal_onEditorUpdate = 5
local internal_onEditorUpdate_counter = 0

-- Add onEditorUpdate function for our trigger placement
local function onEditorUpdate(dt)
  if pendingTriggerType and pendingTriggerRace then
    triggerPlacementUpdate()
  end
  internal_onEditorUpdate_counter = internal_onEditorUpdate_counter + dt
  if internal_onEditorUpdate_counter > internal_onEditorUpdate then
    internal_onEditorUpdate_counter = 0
    if lookingForRoad then
      internal_onEditorUpdate = 5
      findDecalRoads()
    else
      internal_onEditorUpdate = 10
      findDecalRoads()
    end

    for raceName, race in pairs(races) do
      if race.checkpointRoad and not tableContains(levelDecalRoads, race.checkpointRoad) then
        race.checkpointRoad = nil
      end
    end
  end
end

-- Module exports (keep onEditorMouseDown since we might need it later)
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onWindowMenuItem = onWindowMenuItem
M.onActivate = onActivate
M.onUpdate = onEditorUpdate

return M 