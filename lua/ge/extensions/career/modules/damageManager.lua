local M = {}

local dependencies = {'career_career', 'career_modules_inventory'}

local function getSpawnedVehicles()
    local inventoryIdToVehId = career_modules_inventory.getMapInventoryIdToVehId()
    local spawnedVehicles = {}
    for inventoryId, vehId in pairs(inventoryIdToVehId) do
        spawnedVehicles[inventoryId] = true
    end
    return spawnedVehicles
end

local function getDamagedVehicles()
    local spawnedVehicles = getSpawnedVehicles()
    local damagedVehicles = {}
    for inventoryId, _ in pairs(spawnedVehicles) do
        local vehicle = career_modules_inventory.getVehicles()[inventoryId]
        if vehicle then
            local damage = career_modules_valueCalculator.getNumberOfBrokenParts(vehicle.partConditions)
            if damage > 0 then
                damagedVehicles[inventoryId] = true
            end
        end
    end

    return damagedVehicles
end

local function GetVehicleSaveFile(inventoryId)
    local slot, path = career_saveSystem.getCurrentSaveSlot()
    local currentSavePath = path
    if not currentSavePath then return end

    local saveFile = currentSavePath .. "/career/vehicles/damage/" .. inventoryId .. "_damageState.json"
    return saveFile
end

function M.deleteVehicleDelayed(vehId)
    core_jobsystem.create(function(job)
        job.sleep(0.5)
        local object = be:getObjectByID(vehId)
        object:delete()
    end)
end

function M.saveDamageState(inventoryId, saveFile, removeVehicle)
    if not saveFile then
        saveFile = GetVehicleSaveFile(inventoryId)
    end
    print("Checking damage state for vehicle " .. inventoryId .. " to " .. saveFile)
    local vehicle = career_modules_inventory.getVehicles()[inventoryId]
    local spawnedVehicles = career_modules_inventory.getMapInventoryIdToVehId()
    if vehicle and spawnedVehicles[inventoryId] then
        local damage = career_modules_valueCalculator.getNumberOfBrokenParts(vehicle.partConditions)
        if damage > 0 then
            print("Saving damage state for vehicle " .. inventoryId .. " to " .. saveFile)
            local vehId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
            local object = be:getObjectByID(vehId)
            if removeVehicle then
                object:queueLuaCommand("beamstate.save(\"" .. saveFile .. "\"); obj:queueGameEngineLua('career_modules_damageManager.deleteVehicleDelayed(" .. vehId .. ")');")
            else
                object:queueLuaCommand("beamstate.save(\"" .. saveFile .. "\");")
            end
        else
            print("No damage state to save for vehicle " .. inventoryId)
            FS:removeFile(saveFile)
        end
    end
end

function M.loadDamageState(inventoryId)
    print("Loading damage state for vehicle " .. inventoryId)
    local saveFile = GetVehicleSaveFile(inventoryId)
    local object = be:getObjectByID(career_modules_inventory.getVehicleIdFromInventoryId(inventoryId))
    object:queueLuaCommand("beamstate.load(\"" .. saveFile .. "\");")
end

function M.clearDamageState(inventoryId)
    local saveFile = GetVehicleSaveFile(inventoryId)
    FS:removeFile(saveFile)
end

function M.repairPartsAndReloadState(inventoryId, partsToRepair)
    if not inventoryId then
        log('E', 'damageManager.repairParts', 'No inventoryId provided.')
        return
    end
    if not partsToRepair or #partsToRepair == 0 then
        log('W', 'damageManager.repairParts', 'No partsToRepair specified for inventoryId: ' .. inventoryId .. '. No action taken.')
        return
    end

    local vehId = career_modules_inventory.getVehicleIdFromInventoryId(inventoryId)
    if not vehId then
        log('E', 'damageManager.repairParts', 'Could not find vehicleId for inventoryId: ' .. inventoryId)
        return
    end

    local object = be:getObjectByID(vehId)
    if not object then
        log('E', 'damageManager.repairParts', 'Could not find vehicle object for vehId: ' .. vehId)
        return
    end

    local _, savePathBase = career_saveSystem.getCurrentSaveSlot()
    if not savePathBase then
        log('E', 'damageManager.repairParts', 'Could not retrieve current save path.')
        return
    end

    local tempSaveDir = savePathBase .. "/career/vehicles/damage/"
    FS:createPath(tempSaveDir)
    local tempSaveFile = tempSaveDir .. "temp_" .. inventoryId .. "_damageState.json"
    
    local serializedPartsToRepair = serialize(partsToRepair)
    if not serializedPartsToRepair then
        log('E', 'damageManager.repairParts', 'Failed to serialize partsToRepair table.')
        return
    end

    log('I', 'damageManager.repairParts', 'Attempting to repair parts for vehicle ' .. inventoryId .. '. Temp file: ' .. tempSaveFile)
    
    local command = string.format(
        "extensions.load('individualRepair') " ..
        "if individualRepair and individualRepair.saveVehicleStateSelectiveRepair and individualRepair.loadVehicleStateSelectiveRepair then " ..
        "  individualRepair.saveVehicleStateSelectiveRepair('%s', %s); " ..
        "  individualRepair.loadVehicleStateSelectiveRepair('%s'); " ..
        "  -- Consider os.remove('%s') here for the temp file " ..
        "else " ..
        "  log('E', 'vehicle.repairParts', 'individualRepair module or its functions not found.'); " ..
        "end",
        tempSaveFile:gsub("\\", "/"), 
        serializedPartsToRepair,
        tempSaveFile:gsub("\\", "/"),
        tempSaveFile:gsub("\\", "/") -- For os.remove
    )

    object:queueLuaCommand(command)
end

M.getSpawnedVehicles = getSpawnedVehicles
M.getDamagedVehicles = getDamagedVehicles
return M