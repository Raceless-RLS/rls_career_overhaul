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

local function getHrMin(seconds)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    minutes = minutes - (hours * 60)
    return hours .. " hours and " .. minutes .. " minutes"
end

local function rentalReward()
    local reward = math.floor((vehicleValue * 0.25) * (rentalTime / (480 * 60)))
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
    career_modules_inventory.addMovieRental(inventoryId)

    local reward = rentalReward()
    if career_modules_hardcore.isHardcoreMode() then
        reward = reward / 2
    end
    career_modules_payment.reward({
        money = {
            amount = reward
        }
    }, {
        label = "You rented your vehicle!"
    })
    ui_message("You rented your vehicle for: " .. getHrMin(rentalTime) .. " for total of " .. reward .. "!", 10, "info", "info")
    print("You rented your vehicle for: " .. getHrMin(rentalTime) .. " for total of " .. reward .. "!")
end

local function onBeamNGTrigger(data)
    if be:getPlayerVehicleID(0) ~= data.subjectID or data.event == "exit" then
        return
    end
    if gameplay_walk.isWalking() or gameplay_taxi.isTaxiJobActive() then
        return
    end

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
            rentalTime = math.random(60, 480) * 60
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
            message = "Lens Flare Studios will rent your vehicle for " .. getHrMin(rentalTime) .. ", paying you " ..
                          formatMoney(rentalReward()) .. ". proceed to "
            ui_message(message, 10, "info", "info")
            print(message)
        else
            ui_message("The value of your vehicle is too low, come back with a vehicle worth at least $100,000.", 10, "info", "info")
        end
    end
end

local function onUpdate(dtReal, dtSim, dtRaw)
    if isParked then
        local vehiclePosition = getObjectByID(stagedRental):getPosition()
        local playerPosition = be:getPlayerVehicle(0):getPosition()
        if (playerPosition - vehiclePosition):length() >= 15 then
            career_modules_inventory.removeVehicleObject(career_modules_inventory.getInventoryIdFromVehicleId(
                stagedRental))
            stagedRental = nil
            isParked = nil
            career_saveSystem.saveCurrent()
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
    if frequency and frequency < 60 then
        frequency = frequency + dtSim
    else
        isRented = false
        for index, value in ipairs(availableStudios) do
            if value ~= true then
                local timeToAccess = career_modules_inventory.getVehicleTimeToAccess(value)
                if not timeToAccess or timeToAccess <= 0 then
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
