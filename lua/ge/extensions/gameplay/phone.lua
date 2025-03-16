local M = {}

local speedUnit = 2.2369362921

local isPhoneOpen = false
local updateTimer = 0
local updateInterval = 2.5

local function togglePhone(reason)
    ui_phone_time.clearTime()
    if isPhoneOpen then
        isPhoneOpen = false
        guihooks.trigger('closePhone')
    else
        local playerSpeed = math.abs(be:getObjectVelocityXYZ(be:getPlayerVehicleID(0))) * speedUnit
        if playerSpeed > 5 then
            if reason then
                ui_message(reason, 5, "info", "info")
            else
                ui_message("You must be stationary to open the phone.", 3, "info", "info")
            end
            return
        end
        isPhoneOpen = true
        if career_modules_taxi.isTaxiJobActive() then
            guihooks.trigger('ChangeState', {state = 'phone-taxi'})
        else
            guihooks.trigger('ChangeState', {state = 'phone-main'})
        end
    end
end

local function onExtensionLoaded()
    isPhoneOpen = false
    print("Phone extension loaded")
end

local function onUpdate(dt)
    updateTimer = updateTimer + dt
    if updateTimer > updateInterval then
        updateTimer = 0
        if isPhoneOpen then
            local playerSpeed = math.abs(be:getObjectVelocityXYZ(be:getPlayerVehicleID(0))) * speedUnit
            if playerSpeed > 5 then
                isPhoneOpen = false
                ui_message("Phone closed due to player movement.", 3, "info", "info")
                guihooks.trigger('closePhone')
            end
        end
    end
end


M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.togglePhone = togglePhone
M.isPhoneOpen = function()
    return isPhoneOpen
end

return M