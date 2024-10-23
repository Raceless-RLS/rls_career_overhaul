local M = {}

M.dependencies = {'career_career', 'career_modules_inventory', 'career_modules_payment',
                  'career_modules_valueCalculator'}

local stagedRental = nil
local vehicleValue = 0
local rentalTime = 0
local availableStudios = {true, true, true}
local isRented
local frequency = 0
local isStopped
local isParked

-- ui start menu
-- cancel when you move away from preStage
-- ui pop up instead of print log
-- Price formula 
-- random time range

-- make 3 triggers with names 1,2,3
-- math random for 1,2,3

local function printTable(t, indent)
    -- This function prints all parts of a table with labels.
    -- It recursively prints nested tables with indentation.
    --
    -- Parameters:
    --   t (table): The table to print.
    --   indent (number, optional): The current level of indentation. Defaults to 0.
    indent = indent or 0
    local indentStr = string.rep("  ", indent)

    for k, v in pairs(t) do
        if type(v) == "table" then
            print(indentStr .. tostring(k) .. ":")
            printTable(v, indent + 1)
        else
            print(indentStr .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

local function rentalReward()
    local reward = math.floor((vehicleValue * 0.05) * (rentalTime / (30 * 60)))
    ui_message("vehicle rented for: " .. rentalTime / 60 .. " minutes for total of " .. reward .. "!", 10, "info", "info")
    print("vehicle rented for: " .. rentalTime /60 .. " minutes for total of " .. reward .. "!")
    return reward
end

local function formatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = formatted:gsub("^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then
            break
        end
    end
    formatted = "$" .. formatted
    return formatted
end

local function startRental()
    local inventoryId = career_modules_inventory.getCurrentVehicle()
    print("inventory id" .. inventoryId or "none")
    career_modules_inventory.delayVehicleAccess(inventoryId, rentalTime, "rented")
    career_saveSystem.saveCurrent()
    --  extensions.core_vehicles.spawnNewVehicle("unicycle", {removeTraffic = false})
    local reward = rentalReward()
    career_modules_payment.reward({
        money = {
            amount = reward
        }
    }, {
        label = "You rented your vehicle!"
    })

end

local function onBeamNGTrigger(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID or data.event == "exit" then
        return
    end
    if gameplay_walk.isWalking() then
        return
    end
    printTable(data)

    local match = string.match(data.triggerName, "movieRental%d")

    if match then
        local studioStage = tonumber(string.match(data.triggerName, "%d+"))
        if stagedRental == data.subjectID then
            local inventoryId = career_modules_inventory.getCurrentVehicle()
            isStopped = true
            isRented = true
            availableStudios[studioStage] = inventoryId
            local trigger = scenetree.findObject("movieRental" .. studioStage)
            if trigger then
                trigger:setHidden(true)
            end
        end
    elseif data.triggerName == "preStageRental" and (not stagedRental or (data.subjectID ~= stagedRental)) then
        local inventoryId = career_modules_inventory.getCurrentVehicle()
        if not inventoryId then
            return
        end
        local value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
        if value and value > 100000 then
            local studioStage
            local message
            rentalTime = math.random(15, 60) * 60
            vehicleValue = value
            for index, value in ipairs(availableStudios) do
                if value == true then
                    studioStage = index
                    break
                end
            end
            if not studioStage then
                ui_message("All movie studios are in use.", 10, "info", "info")
                return
            end
            stagedRental = data.subjectID
            local trigger = scenetree.findObject("movieRental" .. studioStage)
            if trigger then
                trigger:setHidden(false)
                core_groundMarkers.setPath(trigger:getPosition())
            end
            message = "Lens Flare Studios will rent your vehicle for " .. rentalTime / 60 .. " minutes, paying you " ..
                          formatMoney(rentalReward()) .. ". proceed to "
            ui_message(message, 10, "info", "info")
            print(message)
        else
            ui_message("you're care value is too low, come back with a car worth over $100,000.", 10, "info", "info")
        end
    end
end

local function onUpdate(dtReal, dtSim, dtRaw)
    if isParked then
        local vehiclePosition = be:getObjectByID(stagedRental):getPosition()
        local playerPosition = be:getPlayerVehicle(0):getPosition()
        if (playerPosition - vehiclePosition):length() >= 15 then
            career_modules_inventory.removeVehicleObject(career_modules_inventory.getInventoryIdFromVehicleId(
                stagedRental))
            stagedRental = nil
            isParked = nil
        end
    end
    if isStopped then
        if stagedRental ~= be:getPlayerVehicleID(0) then
            return
        end
        local playerVelocity = be:getPlayerVehicle(0):getVelocity():length()
        print(playerVelocity)
        if playerVelocity < 1 then
            startRental()
            core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setFreeze', true)
            isStopped = false
            isParked = true
        end
    end
    if not isRented then
        return
    end
    if frequency < 60 then
        frequency = frequency + dtSim
    else
        isRented = false
        for index, value in ipairs(availableStudios) do
            if value ~= true then
                local timeToAccess = career_modules_inventory.getVehicleTimeToAccess(value)
                print(index)
                print(timeToAccess)
                if timeToAccess <= 0 then
                    availableStudios[index] = true
                else
                    isRented = true
                end
            end
        end
        frequency = 0
    end
end

M.onBeamNGTrigger = onBeamNGTrigger
M.startRental = startRental
M.onUpdate = onUpdate

return M
