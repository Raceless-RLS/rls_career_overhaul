local M = {}

local isPhoneOpen = false

local function togglePhone()
    if isPhoneOpen then
        isPhoneOpen = false
        guihooks.trigger('closePhone')
    else
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

M.onExtensionLoaded = onExtensionLoaded
M.togglePhone = togglePhone
M.isPhoneOpen = function()
    return isPhoneOpen
end

return M