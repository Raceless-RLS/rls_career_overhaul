local M = {}

local roadNodes = {}
local altRoadNodes = {}

-- Constants for road nodes
local checkpoints = {}
local altCheckpoints = {}

local STRAIGHT_THRESHOLD = math.rad(10) -- Angle threshold for straight segments
local HAIRPIN_THRESHOLD = math.rad(120) -- Angle threshold for hairpin turns
local MIN_SEGMENT_LENGTH = 20 -- Minimum length for a segment in meters
local MAX_TURN_MERGE_ANGLE = math.rad(20) -- Maximum angle difference to merge turns
local MIN_CHECKPOINT_DISTANCE = 90 -- Minimum distance between checkpoints
local CURVATURE_WINDOW = 3 -- Number of nodes to consider on each side for curvature calculation

local MAX_MERGE_DISTANCE = 50
local END_SEARCH_RANGE = 0.2

-- Player off road constants
local MAX_DISTANCE_FROM_PATH = 10 -- meters
local ALERT_COOLDOWN = 3 -- seconds
local WRONG_DIRECTION_THRESHOLD = 0.5 -- cosine of angle
local lastAlertTime = 0
local nextNodeIndex = 2
local exitCountdown = 0
local exitCountdownStart = 5
local lastCountdownTime = 0

local STATIONARY_TIMEOUT = 10
local lastMovementTime = nil
local lastCountdownUpdate = nil
local remainingTime = STATIONARY_TIMEOUT

local activeRace = nil

local function calculateDistance(node1, node2)
    if not node1 or not node2 then
        --print("Warning: Nil node encountered in calculateDistance")
        return 0
    end
    local dx, dy = node2.x - node1.x, node2.y - node1.y
    return math.sqrt(dx * dx + dy * dy)
end

local function calculateAngle(node1, node2, node3)
    if not node1 or not node2 or not node3 then
        --print("Warning: Nil node encountered in calculateAngle")
        return 0, "straight"
    end
    local vec1 = {
        x = node2.x - node1.x,
        y = node2.y - node1.y
    }
    local vec2 = {
        x = node3.x - node2.x,
        y = node3.y - node2.y
    }
    local angle = math.atan2(vec2.y, vec2.x) - math.atan2(vec1.y, vec1.x)

    -- Normalize angle to be between -pi and pi
    if angle > math.pi then
        angle = angle - 2 * math.pi
    elseif angle < -math.pi then
        angle = angle + 2 * math.pi
    end

    local degrees = math.deg(angle)
    local direction = "straight"
    if degrees > 1 then
        direction = "left"
    elseif degrees < -1 then
        direction = "right"
    end

    return angle, direction, degrees
end

local function calculateCurvature(nodes, index)
    local sum = 0
    local count = 0
    for i = math.max(1, index - CURVATURE_WINDOW), math.min(#nodes - 2, index + CURVATURE_WINDOW) do
        sum = sum + math.abs(calculateAngle(nodes[i], nodes[i + 1], nodes[i + 2]))
        count = count + 1
    end
    return sum / count
end

local function findApex(nodes, startIndex, endIndex)
    local maxCurvature = 0
    local apexIndex = startIndex
    for i = startIndex, endIndex do
        local prevNode = nodes[math.max(1, i - 1)]
        local currNode = nodes[i]
        local nextNode = nodes[math.min(#nodes, i + 1)]
        local angle, _, _ = calculateAngle(prevNode, currNode, nextNode)
        local curvature = math.abs(angle)
        if curvature > maxCurvature then
            maxCurvature = curvature
            apexIndex = i
        end
    end
    local apexOffset = activeRace.apexOffset or 0
    apexOffset = activeRace.reverse and -apexOffset or apexOffset
    apexIndex = nodes[apexIndex + apexOffset] and apexIndex + apexOffset or #nodes
    return apexIndex
end

local function processRoadNodes(mainNodes, altNodes)
    if not altNodes then
        altNodes = {}
    end

    local function processRoute(nodes, isAlt)
        print("Processing route with " .. #nodes .. " nodes")
        local segments = {}
        local checkpoints = {}
        local currentSegment = {
            startIndex = 1,
            type = "straight",
            totalAngle = 0,
            length = 0,
            direction = nil
        }
        local startIndex = isAlt and 3 or 1 -- Start from the 3rd node for alternative route

        local function addCheckpoint(startIndex, endIndex, type, direction)
            local apexIndex = findApex(nodes, startIndex, endIndex)
            local roadWidth = 20
        
            -- Function to check if position already exists in checkpoints
            local function isDuplicatePosition(newPos)
                for _, checkpoint in ipairs(checkpoints) do
                    if checkpoint.pos.x == newPos.x and checkpoint.pos.y == newPos.y and checkpoint.pos.z == newPos.z then
                        --print("Duplicate checkpoint position found, skipping...")
                        return true
                    end
                end
                return false
            end
        
            -- Check for existing checkpoints with same direction
            if #checkpoints > 0 then
                local lastCheckpoint = checkpoints[#checkpoints]
                if lastCheckpoint.direction == direction then
                    local distance = calculateDistance(nodes[lastCheckpoint.index], nodes[apexIndex])
                    if distance < MIN_CHECKPOINT_DISTANCE then
                        if calculateCurvature(nodes, apexIndex) > calculateCurvature(nodes, lastCheckpoint.index) then
                            -- Check if new position is duplicate before updating
                            if not isDuplicatePosition(nodes[apexIndex]) then
                                checkpoints[#checkpoints] = {
                                    pos = nodes[apexIndex],
                                    type = type,
                                    index = apexIndex,
                                    direction = direction,
                                    width = nodes[apexIndex].width and nodes[apexIndex].width * 1.25 or roadWidth
                                }
                            end
                        end
                        return
                    end
                end
            end
        
            -- Check if new position is duplicate before inserting
            if not isDuplicatePosition(nodes[apexIndex]) then
                table.insert(checkpoints, {
                    pos = nodes[apexIndex],
                    type = type,
                    index = apexIndex,
                    direction = direction,
                    width = nodes[apexIndex].width and nodes[apexIndex].width * 1.25 or roadWidth
                })
                --print((isAlt and "Alt " or "") .. "Checkpoint added: Type: " .. type .. ", Index: " .. apexIndex ..
                --          ", Direction: " .. direction .. ", Width: " .. roadWidth)
            end
        end

        local function addStraightCheckpoints()
            if #checkpoints < 2 then return end
            
            local newCheckpoints = {}
            
            -- Function to insert checkpoint between two existing ones
            local function insertMiddleCheckpoint(cp1, cp2)
                -- Calculate the distance between checkpoints
                local distance = calculateDistance(cp1.pos, cp2.pos)
                
                if distance > 450 then
                    -- Find the middle node index
                    local middleIndex = math.floor((cp1.index + cp2.index) / 2)
                    
                    -- Create new checkpoint at middle position
                    table.insert(newCheckpoints, {
                        pos = nodes[middleIndex],
                        type = "straight",
                        index = middleIndex,
                        direction = "straight",
                        width = nodes[middleIndex].width and nodes[middleIndex].width * 1.25 or 20
                    })
                end
            end
            
            -- First pass: collect all new checkpoints needed
            for i = 1, #checkpoints - 1 do
                insertMiddleCheckpoint(checkpoints[i], checkpoints[i + 1])
            end
            
            -- If it's a loop, check between last and first checkpoint
            if isLoop then
                insertMiddleCheckpoint(checkpoints[#checkpoints], checkpoints[1])
            end
            
            -- Second pass: insert all new checkpoints into the main checkpoints table
            -- Sort them by their index to maintain proper order
            for _, newCp in ipairs(newCheckpoints) do
                local insertIndex = 1
                while insertIndex <= #checkpoints and checkpoints[insertIndex].index < newCp.index do
                    insertIndex = insertIndex + 1
                end
                table.insert(checkpoints, insertIndex, newCp)
            end
        end

        local function finishSegment(endIndex)
            if currentSegment.length >= MIN_SEGMENT_LENGTH then
                table.insert(segments, currentSegment)
                if currentSegment.type == "turn" or currentSegment.type == "hairpin" then
                    addCheckpoint(currentSegment.startIndex, endIndex, currentSegment.type, currentSegment.direction)
                end
            end
        end

        for i = startIndex + 1, #nodes - 1 do
            local angle = calculateAngle(nodes[i - 1], nodes[i], nodes[i + 1])
            currentSegment.totalAngle = currentSegment.totalAngle + angle
            currentSegment.length = currentSegment.length + calculateDistance(nodes[i - 1], nodes[i])

            if math.abs(angle) > STRAIGHT_THRESHOLD then
                local newDirection = angle > 0 and "left" or "right"
                if currentSegment.type == "straight" then
                    finishSegment(i - 1)
                    currentSegment = {
                        startIndex = i - 1,
                        type = "turn",
                        direction = newDirection,
                        totalAngle = angle,
                        length = 0
                    }
                elseif currentSegment.type == "turn" then
                    if currentSegment.direction ~= newDirection then
                        finishSegment(i - 1)
                        currentSegment = {
                            startIndex = i - 1,
                            type = "turn",
                            direction = newDirection,
                            totalAngle = angle,
                            length = 0
                        }
                    elseif math.abs(currentSegment.totalAngle - angle) > MAX_TURN_MERGE_ANGLE then
                        addCheckpoint(currentSegment.startIndex, i, "turn", newDirection)
                        currentSegment.totalAngle = angle
                        currentSegment.startIndex = i
                    end
                end
            elseif currentSegment.type == "turn" and currentSegment.length >= MIN_SEGMENT_LENGTH then
                finishSegment(i - 1)
                currentSegment = {
                    startIndex = i - 1,
                    type = "straight",
                    totalAngle = 0,
                    length = 0,
                    direction = nil
                }
            end

            if math.abs(currentSegment.totalAngle) > HAIRPIN_THRESHOLD then
                currentSegment.type = "hairpin"
                finishSegment(i)
                currentSegment = {
                    startIndex = i,
                    type = "straight",
                    totalAngle = 0,
                    length = 0,
                    direction = nil
                }
            end
        end

        finishSegment(#nodes)

        -- addStraightCheckpoints()

        return checkpoints
    end

    local mainCheckpoints = processRoute(mainNodes, false)
    local altCheckpoints = altNodes and processRoute(altNodes, true) or nil

    -- Adjust the last checkpoint if it's too close to the first one (for both routes)
    local function adjustLastCheckpoint(checkpoints, nodes)
        if #checkpoints >= 2 then
            local firstCheckpoint = checkpoints[1]
            local lastCheckpoint = checkpoints[#checkpoints]
            local distance = calculateDistance(firstCheckpoint.pos, lastCheckpoint.pos)

            if distance < MIN_CHECKPOINT_DISTANCE then
                --print("Adjusting last checkpoint: too close to first checkpoint")

                local newLastIndex = lastCheckpoint.index
                while newLastIndex > 1 and calculateDistance(nodes[newLastIndex], firstCheckpoint.pos) <
                    MIN_CHECKPOINT_DISTANCE do
                    newLastIndex = newLastIndex - 1
                end

                if newLastIndex > 1 and newLastIndex ~= lastCheckpoint.index then
                    lastCheckpoint.pos = nodes[newLastIndex]
                    lastCheckpoint.index = newLastIndex
                    --print("Last checkpoint moved to index: " .. newLastIndex)
                else
                    --print("Could not find a suitable position for the last checkpoint")
                end
            end
        end
    end

    adjustLastCheckpoint(mainCheckpoints, mainNodes)
    if altCheckpoints then
        adjustLastCheckpoint(altCheckpoints, altNodes)
    end

    return mainCheckpoints, altCheckpoints
end

local function getRoad(roadName)
    local road = scenetree.findObject(roadName)
    if road and road:getClassName() == "DecalRoad" then
        return road
    else
        --print("Error: Road '" .. roadName .. "' not found or is not a DecalRoad")
        return nil
    end
end

local function getRoadNodes(roadName)
    local road = scenetree.findObject(roadName)
    local nodeTable = road:getNodesTable()
    if road and road:getClassName() ~= "DecalRoad" then
        return
    end

    if not road then
        return
    end

    local nodeCount = road:getNodeCount()
    
    local roadNodes = {}
    for i = 0, nodeCount - 1 do
        local pos = road:getNodePosition(i)
        table.insert(roadNodes, {
            x = pos.x,
            y = pos.y,
            z = pos.z,
            width = nodeTable[i+1][2]
        })
    end
    return roadNodes
end

local function findClosestEndPoints(nodes1, nodes2)
    local connections = {}
    local searchRange1 = math.floor(#nodes1 * END_SEARCH_RANGE)
    local searchRange2 = math.floor(#nodes2 * END_SEARCH_RANGE)

    local function checkConnection(start1, end1, start2, end2, isStart1, isStart2)
        local minDist = math.huge
        local bestIndex1, bestIndex2

        for i = start1, end1, start1 < end1 and 1 or -1 do
            for j = start2, end2, start2 < end2 and 1 or -1 do
                local dist = calculateDistance(nodes1[i], nodes2[j])
                if dist < minDist then
                    minDist = dist
                    bestIndex1, bestIndex2 = i, j
                end
            end
        end

        if minDist <= MAX_MERGE_DISTANCE then
            table.insert(connections, {
                index1 = bestIndex1,
                index2 = bestIndex2,
                distance = minDist,
                isStart1 = isStart1,
                isStart2 = isStart2
            })
        end
    end

    -- Check all combinations
    checkConnection(1, searchRange1, 1, searchRange2, true, true)
    checkConnection(1, searchRange1, #nodes2, #nodes2 - searchRange2 + 1, true, false)
    checkConnection(#nodes1, #nodes1 - searchRange1 + 1, 1, searchRange2, false, true)
    checkConnection(#nodes1, #nodes1 - searchRange1 + 1, #nodes2, #nodes2 - searchRange2 + 1, false, false)

    table.sort(connections, function(a, b)
        return a.distance < b.distance
    end)
    return connections
end

local function mergeRoads(road1, road2)
    local nodes1 = getRoadNodes(road1)
    local nodes2 = getRoadNodes(road2)

    local connections = findClosestEndPoints(nodes1, nodes2)

    if #connections == 0 then
        --print("Roads cannot be merged: no close endpoints found")
        return nil
    end

    local mergedNodes = {}
    local junctions = {}

    local function createJunction(node1, node2)
        return {
            x = (node1.x + node2.x) / 2,
            y = (node1.y + node2.y) / 2,
            z = (node1.z + node2.z) / 2,
            isJunction = true
        }
    end

    local function addJunction(junction)
        table.insert(junctions, junction)
        table.insert(mergedNodes, junction)
    end

    local conn1, conn2 = connections[1], connections[2]

    -- Determine if we need to reverse one of the roads
    local reverseRoad1 = false
    local reverseRoad2 = false
    if conn1.isStart1 == conn1.isStart2 then
        if #nodes1 < #nodes2 then
            reverseRoad1 = true
        else
            reverseRoad2 = true
        end
    end

    -- Determine the range for each road
    local start1 = math.min(conn1.index1, conn2.index1)
    local end1 = math.max(conn1.index1, conn2.index1)
    local start2 = math.min(conn1.index2, conn2.index2)
    local end2 = math.max(conn1.index2, conn2.index2)

    -- Add first junction
    addJunction(createJunction(nodes1[conn1.index1], nodes2[conn1.index2]))

    -- Add nodes from road1
    if reverseRoad1 then
        for i = end1, start1, -1 do
            table.insert(mergedNodes, nodes1[i])
        end
    else
        for i = start1, end1 do
            table.insert(mergedNodes, nodes1[i])
        end
    end

    -- Add second junction
    addJunction(createJunction(nodes1[conn2.index1], nodes2[conn2.index2]))

    -- Add nodes from road2
    if reverseRoad2 then
        for i = end2, start2, -1 do
            table.insert(mergedNodes, nodes2[i])
        end
    else
        for i = start2, end2 do
            table.insert(mergedNodes, nodes2[i])
        end
    end
    
    return mergedNodes
end

local function vec3FromTable(t)
    return vec3(t.x, t.y, t.z)
end

local function distanceToLineSegment(point, lineStart, lineEnd)
    local lineVec = vec3FromTable(lineEnd) - vec3FromTable(lineStart)
    local pointVec = point - vec3FromTable(lineStart)
    local lineLength = lineVec:length()

    if lineLength < 0.001 then -- Check if line segment is too short
        return pointVec:length(), 0
    end

    local t = pointVec:dot(lineVec) / (lineLength * lineLength)
    t = math.max(0, math.min(1, t))

    local projection = vec3FromTable(lineStart) + lineVec * t

    return (point - projection):length(), t
end

local function findNearestNode(vehiclePos, nodes)
    if not nodes then
        return nil, nil
    end
    local nearestIndex = 1
    local minDistance = math.huge
    for i, node in ipairs(nodes) do
        local distance = (vehiclePos - vec3FromTable(node)):length()
        if distance < minDistance then
            minDistance = distance
            nearestIndex = i
        end
    end
    return nearestIndex, minDistance
end

local function checkPlayerOnRoad()
    local playerVehicle = be:getPlayerVehicle(0)
    if not playerVehicle then
        return false
    end

    local vehiclePos = playerVehicle:getPosition()
    local vehicleVel = playerVehicle:getVelocity()
    local currentTime = os.time()

    if vehicleVel:length() < 0.5 then -- Very low speed threshold
        local currentTime = os.time()
        
        if not lastMovementTime then
            lastMovementTime = currentTime
            lastCountdownUpdate = currentTime
            remainingTime = STATIONARY_TIMEOUT
        else
            local timeStopped = currentTime - lastMovementTime
            
            -- Update countdown every second
            if currentTime - lastCountdownUpdate >= 1 then
                remainingTime = STATIONARY_TIMEOUT - timeStopped
                lastCountdownUpdate = currentTime
                
                if remainingTime > 0 then
                    ui_message("Warning: Move your vehicle! Race ends in " .. remainingTime .. " seconds!", 2, "info")
                end
            end
            
            -- End race when time runs out
            if timeStopped >= STATIONARY_TIMEOUT then
                return false
            end
        end
    else
        -- Reset timers when vehicle is moving
        lastMovementTime = nil
        lastCountdownUpdate = nil
        remainingTime = STATIONARY_TIMEOUT
    end

    -- Check both main and alt routes
    local mainNearestIndex, mainDistance = findNearestNode(vehiclePos, roadNodes)
    local altNearestIndex, altDistance = findNearestNode(vehiclePos, altRoadNodes)

    if not mainNearestIndex and not mainDistance then
        return true
    end
    if not altNearestIndex and not altDistance then
        altDistance = 1000000
    end

    local useAltRoute = altDistance < mainDistance
    local currentNodes = useAltRoute and altRoadNodes or roadNodes
    local nearestNodeIndex = useAltRoute and altNearestIndex or mainNearestIndex

    local currentNode = currentNodes[nearestNodeIndex]
    local nextNodeIndex = (nearestNodeIndex % #currentNodes) + 1
    local prevNodeIndex = ((nearestNodeIndex - 2) % #currentNodes) + 1
    local nextNode = currentNodes[nextNodeIndex]
    local prevNode = currentNodes[prevNodeIndex]


    local distanceFromPath, t = distanceToLineSegment(vehiclePos, currentNode, nextNode)
    -- Check if we need to consider the previous or next segment
    if t < 0.1 then
        local prevDistance, prevT = distanceToLineSegment(vehiclePos, prevNode, currentNode)
        if prevDistance < distanceFromPath then
            distanceFromPath = prevDistance
            t = prevT
        end
    elseif t > 0.9 then
        local nextNextNode = currentNodes[(nextNodeIndex % #currentNodes) + 1]
        local nextDistance, nextT = distanceToLineSegment(vehiclePos, nextNode, nextNextNode)
        if nextDistance < distanceFromPath then
            distanceFromPath = nextDistance
            t = nextT
        end
    end

    -- Improved wrong direction detection
    local isWrongDirection = false
    if vehicleVel:length() > 1 then -- Only check direction if the vehicle is moving
        local playerDirection = vehicleVel:normalized()
        local forwardDirection = (vec3FromTable(nextNode) - vec3FromTable(currentNode)):normalized()
        local backwardDirection = (vec3FromTable(prevNode) - vec3FromTable(currentNode)):normalized()
        local forwardDot = playerDirection:dot(forwardDirection)
        local backwardDot = playerDirection:dot(backwardDirection)
        isWrongDirection = forwardDot < WRONG_DIRECTION_THRESHOLD and backwardDot < WRONG_DIRECTION_THRESHOLD
    end


    local currentTime = os.time()
    if distanceFromPath > (MAX_DISTANCE_FROM_PATH + 25) then
        if exitCountdown == 0 then
            exitCountdown = exitCountdownStart
            ui_message("Warning: You are exiting the event! " .. exitCountdown .. " seconds to return!", 3, "info")
            lastCountdownTime = currentTime
        elseif currentTime - lastCountdownTime >= 1 then
            exitCountdown = exitCountdown - 1
            lastCountdownTime = currentTime
            if exitCountdown > 0 then
                ui_message("Exiting event in " .. exitCountdown .. " seconds!", 2, "info")
            else
                ui_message("Event exited!", 3, "info")
                return false
            end
        end
    elseif isWrongDirection then
        if currentTime - lastAlertTime > ALERT_COOLDOWN then
            --ui_message("Warning: You're going the wrong way!", 3, "info")
            lastAlertTime = currentTime
        end
        -- Note: We're not returning false here, allowing the player to continue even if going the wrong way
    else
        if exitCountdown > 0 then
            exitCountdown = 0
            ui_message("Back on track!", 2, "info")
        end
    end

    return true
end

local function isLoop()
    if #roadNodes < 3 then
        return false
    end

    local firstNode = roadNodes[1]
    local lastNode = roadNodes[#roadNodes]

    -- Define a small threshold for floating-point comparisons
    local threshold = MAX_MERGE_DISTANCE

    -- Check if the first and last nodes are close enough to be considered the same point
    local isLoop = math.abs(firstNode.x - lastNode.x) < threshold and math.abs(firstNode.y - lastNode.y) < threshold and
                       math.abs(firstNode.z - lastNode.z) < threshold
    return isLoop
end

local function flipCheckpoints(originalCheckpoints)
    if not originalCheckpoints or #originalCheckpoints == 0 then
        return nil
    end
    
    local flipped = {}
    for i = #originalCheckpoints, 1, -1 do
        local cp = originalCheckpoints[i]
        local newDirection = "straight"
        
        -- Invert turn directions
        if cp.direction == "left" then
            newDirection = "right"
        elseif cp.direction == "right" then
            newDirection = "left"
        end
        
        table.insert(flipped, {
            pos = cp.pos,
            type = cp.type,
            index = cp.index,
            direction = newDirection,
            width = cp.width
        })
    end
    return flipped
end

local function getCheckpoints(race)
    MIN_CHECKPOINT_DISTANCE = race.minCheckpointDistance or 90
    if race.checkpointRoad then
        -- Clear existing nodes and checkpoints
        roadNodes = nil
        altRoadNodes = nil
        checkpoints = nil
        altCheckpoints = nil
        activeRace = race
        -- Load main route nodes
        if type(race.checkpointRoad) == "table" then
            roadNodes = mergeRoads(race.checkpointRoad[1], race.checkpointRoad[2])
        else
            roadNodes = getRoadNodes(race.checkpointRoad)
        end

        -- Check for alternative route
        if race.altRoute and race.altRoute.checkpointRoad then
            altRoadNodes = getRoadNodes(race.altRoute.checkpointRoad)
            checkpoints, altCheckpoints = processRoadNodes(roadNodes, altRoadNodes)
        else
            checkpoints = processRoadNodes(roadNodes)
            altCheckpoints = nil
        end

        -- Add direction flip logic
        if race.reverse then
            print("Flipping checkpoints")
            checkpoints = flipCheckpoints(checkpoints)
            if altCheckpoints then
                altCheckpoints = flipCheckpoints(altCheckpoints)
            end
        end
        
        return checkpoints, altCheckpoints
    end
    return nil, nil
end

local function reset()
    roadNodes = nil
    altRoadNodes = nil
    checkpoints = nil
    altCheckpoints = nil
    activeRace = nil
end

local function onInit()
    print("Initializing Road Processing")
end

M.getCheckpoints = getCheckpoints
M.isLoop = isLoop
M.reset = reset
M.checkPlayerOnRoad = checkPlayerOnRoad
M.onInit = onInit

return M