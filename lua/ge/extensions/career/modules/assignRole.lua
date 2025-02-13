local M = {}

local dependencies = {'career_career', 'career_modules_inventory'}

local assignmentData = nil
local vehiclePresent = nil

local function canPay()
    local certificationPrice = {
        money = {
            amount = assignmentData.cost,
            canBeNegative = false
        }
    }
    return career_modules_payment.canPay(certificationPrice)
end

local function startCertification()
    guihooks.trigger('ChangeState', {
        state = 'play',
        params = {}
    })
    local inventoryId = career_modules_inventory.getCurrentVehicle()
    if inventoryId then
        if not canPay() then
            ui_message("You do not have enough funds to certify your vehicle", 10, "error", "info")
            return
        end
        local certificationPrice = {
            money = {amount = assignmentData.cost, canBeNegative = false}
        }
        career_modules_payment.pay(certificationPrice, {
            label = "Certification fee",
            tags = {"certification", string.lower(assignmentData.type)}
        })
        career_modules_inventory.setVehicleRole(inventoryId, string.lower(assignmentData.type))
        career_modules_inventory.delayVehicleAccess(inventoryId, assignmentData.time, string.format("%s_certification", assignmentData.type))
        core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setFreeze', true)
        vehiclePresent = be:getPlayerVehicle(0)
    end
end

local function onBeamNGTrigger(data)
    if data.subjectID ~= be:getPlayerVehicleID(0) then
        return
    end
    if gameplay_walk.isWalking() then
        return
    end

    if not data.triggerName:find("policeAssignment") then
        return
    end
    assignmentData = {
        time = 14400,
        cost = 10000,
        type = "Police"
    }

    if data.event == "enter" then
        local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(data.subjectID)
        if inventoryId then
            if career_modules_inventory.getVehicleRole(inventoryId) ~= string.lower(assignmentData.type) then
                guihooks.trigger('ChangeState', {
                    state = 'roleAssignment'
                })
            end
        end
    elseif data.event == "exit" then
        guihooks.trigger('ChangeState', {
            state = 'play',
            params = {}
        })
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

local function requestAssignmentData()
    return assignmentData
end

M.canPay = canPay
M.startCertification = startCertification
M.onBeamNGTrigger = onBeamNGTrigger
M.onUpdate = onUpdate
M.requestAssignmentData = requestAssignmentData

return M
