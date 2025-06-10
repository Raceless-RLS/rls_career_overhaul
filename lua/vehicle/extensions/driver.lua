local M = {}

local destination = nil

local drivability = 0
local dirMult = 10000
local penaltyAboveCutoff = 1000
local penaltyBelowCutoff = 100000
local wZ = 1

local function onExtensionLoaded()
    if not mapmgr.mapData then
        mapmgr.requestMap()
    end
end

local function goToTarget(speedMode)
    local path = mapmgr.getPointToPointPath(
        obj:getPosition(),
        destination,
        drivability,
        dirMult,
        penaltyAboveCutoff,
        penaltyBelowCutoff,
        wZ
    )
    table.remove(path, 1)
    ai.setPath(path)
    ai.driveUsingPathWithTraffic({
        wpTargetList = path,
        routeSpeedMode = 'legal'
    })
    ai.setParameters({
        trafficWaitTime = 0.05,
        lookAheadKv = 0.005,
        awarenessForceCoef = 0.01, 
        driveStyle = "offroad"
    })
end

local function raceToTarget()
    local path = mapmgr.getPointToPointPath(
        obj:getPosition(),
        destination,
        drivability,
        dirMult,
        penaltyAboveCutoff,
        penaltyBelowCutoff,
        wZ
    )
    table.remove(path, 1)
    ai.setPath(path)
    ai.setMode("manual")
    ai.setAvoidCars("on")
    ai.setSpeedMode("off")
    ai.setSpeed(300)
    ai.driveInLane("off")
    ai.setParameters({
        lookAheadKv = 0.005,
        awarenessForceCoef = 0.005,
        driveStyle = "offroad"
    })
    ai.setRacing(true)
    ai.setAggression(10)
end

local function returnTargetPosition(target, race)
    print("returnTargetPosition: " .. tostring(target))
    destination = target
    if race then
        raceToTarget()
    else
        goToTarget()
    end
end

local function driveToTarget(drivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
    drivability = drivability or 0
    dirMult = dirMult or 10000
    penaltyAboveCutoff = penaltyAboveCutoff or 1000
    penaltyBelowCutoff = penaltyBelowCutoff or 100000
    wZ = wZ or 1

    obj:queueGameEngineLua([[
        local target = core_groundMarkers.getTargetPos()
        local obj = getObjectByID("]] .. obj:getID() .. [[")
        obj:queueLuaCommand("driver.returnTargetPosition(" .. serialize(target) .. ")")
    ]])
end

local function driveFastToTarget(drivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
    drivability = drivability or 0.1
    dirMult = dirMult or 1
    penaltyAboveCutoff = penaltyAboveCutoff or 1
    penaltyBelowCutoff = penaltyBelowCutoff or 1
    wZ = wZ or 1

    obj:queueGameEngineLua([[
        local target = core_groundMarkers.getTargetPos()
        local obj = getObjectByID("]] .. obj:getID() .. [[")
        obj:queueLuaCommand("driver.returnTargetPosition(" .. serialize(target) .. ", true)")
    ]])
end



M.driveToTarget = driveToTarget
M.driveFastToTarget = driveFastToTarget
M.returnTargetPosition = returnTargetPosition
M.onExtensionLoaded = onExtensionLoaded

return M