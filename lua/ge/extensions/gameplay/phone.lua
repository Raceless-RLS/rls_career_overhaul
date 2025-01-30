local M = {}

local isPhoneOpen = false

local function togglePhone()
    if isPhoneOpen then
        isPhoneOpen = false
        guihooks.trigger('closePhone')
    else
        isPhoneOpen = true
        guihooks.trigger('ChangeState', {state = 'phone-main'})
    end
end

local function onExtensionLoaded()
    isPhoneOpen = false
    print("Phone extension loaded")
end

M.onExtensionLoaded = onExtensionLoaded
M.togglePhone = togglePhone

return M