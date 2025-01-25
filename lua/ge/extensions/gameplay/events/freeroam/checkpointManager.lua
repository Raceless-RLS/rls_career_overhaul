local M = {}

local checkpoints = {}
local altCheckpoints = {}
local raceName = nil
local isLoop = false
local mAltRoute = nil
local activeCheckpoints = {}

local race

local function createCheckpoint(index, isAlt)
    local checkpoint
    if isAlt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if not checkpoint then
        --print("Error: No checkpoint data found for index " .. index)
        return
    end

    if not checkpoint.width then
        checkpoint.width = 30
    end

    local position = vec3(checkpoint.pos.x, checkpoint.pos.y, checkpoint.pos.z)
    local radius = checkpoint.width / 2 -- Assuming width is diameter

    local triggerRadius = radius * 0.9 -- 90% of the marker radius for the trigger

    checkpoint.object = createObject('BeamNGTrigger')
    checkpoint.object:setPosition(position)
    checkpoint.object:setScale(vec3(triggerRadius, triggerRadius, triggerRadius))
    checkpoint.object.triggerType = 0 -- Use 0 for Sphere type

    -- Naming the trigger according to the new scheme
    local triggerName
    if isAlt then
        triggerName = string.format("fre_checkpoint_%s_alt_%d", raceName, index)
    else
        triggerName = string.format("fre_checkpoint_%s_%d", raceName, index)
    end

    if scenetree.findObject(triggerName) then
        local existingTrigger = scenetree.findObject(triggerName)
        existingTrigger:delete()
    end
    checkpoint.object:registerObject(triggerName)

    --print("Checkpoint " .. index .. " created at: " .. tostring(position) .. " with radius: " .. radius)
    return checkpoint
end

local function createCheckpointMarker(index, alt)
    local checkpoint = alt and altCheckpoints[index] or checkpoints[index]
    if not checkpoint then
        --print("No checkpoint data for index " .. index)
        return
    end

    local marker = createObject('TSStatic')
    marker.shapeName = "art/shapes/interface/checkpoint_marker.dae"

    marker:setPosRot(checkpoint.pos.x, checkpoint.pos.y, checkpoint.pos.z, 0, 0, 0, 0)

    marker.scale = vec3(checkpoint.width / 2, checkpoint.width / 2, checkpoint.width)
    marker.useInstanceRenderData = true
    marker.instanceColor = ColorF(1, 0, 0, 0.5):asLinear4F() -- Default to red

    local markerName = (alt and "alt_" or "") .. "checkpoint_" .. index .. "_marker"
    if scenetree.findObject(markerName) then
        local existingMarker = scenetree.findObject(markerName)
        existingMarker:delete()
    end
    marker:registerObject(markerName)

    checkpoint.marker = marker
    table.insert(activeCheckpoints, checkpoint)
    return checkpoint
end

local function removeCheckpointMarker(index, alt)
    local checkpoint = {}
    if alt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if checkpoint and checkpoint.marker then
        checkpoint.marker:delete()
        checkpoint.marker = nil
    end
    return checkpoint
end

local function removeCheckpoint(index, alt)
    local checkpoint = {}
    if alt then
        checkpoint = altCheckpoints[index]
    else
        checkpoint = checkpoints[index]
    end
    if checkpoint then
        if checkpoint.object then
            checkpoint.object:delete()
            checkpoint.object = nil
        end
        if checkpoint.marker then
            checkpoint.marker:delete()
            checkpoint.marker = nil
        end
        --print("Checkpoint " .. index .. " removed")
    end
    return checkpoint
end

local function createCheckpoints(check, altCheck)
    checkpoints = check
    altCheckpoints = altCheck
    for i = 1, #checkpoints do
        removeCheckpoint(i)
    end
    for i = 1, #checkpoints do
        --print("Creating checkpoint " .. i)
        createCheckpoint(i)
    end

    if altCheckpoints then
        for i = 1, #altCheckpoints do
            removeCheckpoint(i, true)
        end
        for i = 1, #altCheckpoints do
            createCheckpoint(i, true)
        end
    end
end

local function resetActiveCheckpoints()
    local checkpoint
    for i = 1, #activeCheckpoints do
        checkpoint = activeCheckpoints[i]
        if checkpoint then
            checkpoint.marker:delete()
            checkpoint.marker = nil
        end
    end
    activeCheckpoints = {}
end

local function enableCheckpoint(checkpointIndex, alt)
    print("Enabling checkpoint " .. checkpointIndex)
    resetActiveCheckpoints()
    local ALT = {alt, alt}
    local index = {checkpointIndex, checkpointIndex + 1}
    if isLoop then
        index = {index[1] % #checkpoints + 1, index[2] % #checkpoints + 1}
    else
        index = {index[1] + 1, index[2] + 1}
    end
    for i = 1, 2 do
        if ALT[i] then
            if #altCheckpoints < index[i] then
                index[i] = race.altRoute.mergeCheckpoints[2] + ((index[i] - 1) - #altCheckpoints)
                ALT[i] = false
            end
        end
    end
    dump(index)
    local currentExpectedCheckpoint = index[1]
    local checkpoint = {}
    if ALT[1] then
        checkpoint = altCheckpoints[index[1]]
    else
        checkpoint = checkpoints[index[1]]
    end
    local nextCheckpoint = nil
    local checkpointCount = ALT[2] and #altCheckpoints or #checkpoints
    if checkpointCount > 1 then
        if ALT[2] then
            nextCheckpoint = altCheckpoints[index[2]]
        else
            nextCheckpoint = checkpoints[index[2]]
        end
    end

    if checkpoint then
        if not checkpoint.marker then
            checkpoint = createCheckpointMarker(index[1], ALT[1])
        end
        if not ALT[1] then
            checkpoint.marker.instanceColor = ColorF(0, 1, 0, 0.7):asLinear4F() -- Green
        else
            checkpoint.marker.instanceColor = ColorF(0, 0, 1, 0.7):asLinear4F() -- Blue
        end

        if race.altRoute and altCheckpoints and race.altRoute.mergeCheckpoints[1] == index[1] then
            if not altCheckpoints[1].marker then
                local altCheckpoint = createCheckpointMarker(1, true)
                altCheckpoint.marker.instanceColor = ColorF(0, 0, 1, 0.7):asLinear4F() -- Blue
            end
        end

        if nextCheckpoint then
            if not nextCheckpoint.marker then
                nextCheckpoint = createCheckpointMarker(index[2], ALT[2])
            end
            nextCheckpoint.marker.instanceColor = ColorF(1, 0, 0, 0.5):asLinear4F() -- Red
        end
    end
    print("Current expected checkpoint: " .. currentExpectedCheckpoint)
    return currentExpectedCheckpoint
end

local function removeCheckpoints()
    local function removeCheckpointList(checkpointList)
        if not checkpointList or #checkpointList == 0 then
            return
        end

        for i = 1, #checkpointList do
            local checkpoint = checkpointList[i]
            if checkpoint then
                -- Remove the checkpoint object
                if checkpoint.object then
                    checkpoint.object:delete()
                    checkpoint.object = nil
                end

                -- Remove the checkpoint marker
                if checkpoint.marker then
                    checkpoint.marker:delete()
                    checkpoint.marker = nil
                end
            end
        end

        -- Clear the checkpoint list
        for i = 1, #checkpointList do
            checkpointList[i] = nil
        end
    end

    resetActiveCheckpoints()

    -- Remove main checkpoints
    removeCheckpointList(checkpoints)

    -- Remove alternative checkpoints
    removeCheckpointList(altCheckpoints)

    -- Reset the checkpoint tables
    checkpoints = {}
    altCheckpoints = {}
    race = nil
    mAltRoute = nil
end

local function calculateTotalCheckpoints()
    local mainCount = #checkpoints
    local altCount = altCheckpoints and #altCheckpoints or 0
    local mergePoints = race.altRoute and race.altRoute.mergeCheckpoints or {0, 0}

    -- If the player is on the alt route, adjust total checkpoints accordingly
    local total
    if mAltRoute then
        total = altCount + (mainCount - mergePoints[2] + mergePoints[1])
    else
        total = mainCount
    end

    return total
end

local function setAltRoute(altRoute)
    mAltRoute = altRoute
end

local function setRace(inputRace, inputRaceName)
    race = inputRace
    raceName = inputRaceName
end

local function onInit()
    print("Initializing Checkpoint Manager")
end

M.onInit = onInit
M.createCheckpoints = createCheckpoints
M.enableCheckpoint = enableCheckpoint
M.removeCheckpoints = removeCheckpoints
M.setAltRoute = setAltRoute
M.setRace = setRace
M.calculateTotalCheckpoints = calculateTotalCheckpoints

return M