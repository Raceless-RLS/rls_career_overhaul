local M = {}

local dependencies = {'career_career', 'career_modules_inventory'}

local certificationPrice = {
    money = {
        amount = 10000,
        canBeNegative = false
    }
}

local vehiclePresent = nil

local function canPay()
    return career_modules_payment.canPay(certificationPrice)
end

local function startCertification()
    guihooks.trigger('ChangeState', {state = 'play', params = {}})
    local inventoryId = career_modules_inventory.getCurrentVehicle()
    if inventoryId then
        if not canPay() then
            ui_message("You do not have enough funds to certify your vehicle", 10, "error", "info")
            return
        end
        career_modules_payment.pay(certificationPrice, {
            label = "Certification fee",
            tags = {"certification", "police"}
        })
        career_modules_inventory.setVehicleRole(inventoryId, "police")
        career_modules_inventory.delayVehicleAccess(inventoryId, 14400, "certification")
        core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setFreeze', true)
        vehiclePresent = be:getPlayerVehicle(0)
    end
end

local function onBeamNGTrigger(data)
    if data.subjectID ~= be:getPlayerVehicleID(0) then return end
    if gameplay_walk.isWalking() then return end

    if data.triggerName ~= "policeAssignment" then return end

    if data.event == "enter" then
        ui_message("Entering police assignment", 10, "info", "info")
        local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(data.subjectID)
        if inventoryId then
            if career_modules_inventory.getVehicleRole(inventoryId) ~= "police" then
                guihooks.trigger('ChangeState', {state = 'policeAssignment'})
            end
        end
    elseif data.event == "exit" then
        guihooks.trigger('ChangeState', {state = 'play', params = {}})
    end
end

local function onUpdate()
    if vehiclePresent then
        local vehiclePosition = vehiclePresent:getPosition()
        local playerPosition = be:getPlayerVehicle(0):getPosition()
        if (playerPosition - vehiclePosition):length() >= 25 then
            career_modules_inventory.removeVehicleObject(career_modules_inventory.getInventoryIdFromVehicleId(
                vehiclePresent:getID()))
            vehiclePresent = nil
            career_saveSystem.saveCurrent()
        end
    end
end

M.canPay = canPay
M.startCertification = startCertification
M.onBeamNGTrigger = onBeamNGTrigger
M.onUpdate = onUpdate

return M
