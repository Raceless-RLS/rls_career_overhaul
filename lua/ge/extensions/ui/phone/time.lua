local M = {}

local time = 0

local function formatTime(time)
    local total_minutes = time * 1440
    local hours = math.floor(total_minutes / 60)
    local minutes = math.floor(total_minutes % 60)
    
    -- Convert to 12-hour format
    local period = hours < 12 and "PM" or "AM"
    local twelve_hour = hours % 12
    twelve_hour = twelve_hour == 0 and 12 or twelve_hour  -- Handle 0 as 12
    
    return string.format("%d:%02d %s", twelve_hour, minutes, period)
end

local function onUpdate()
    if scenetree.tod and formatTime(scenetree.tod.time) ~= time then
        time = formatTime(scenetree.tod.time)
        guihooks.trigger("phone_time_update", time)
    end
end

local function onExtensionLoaded()
    time = formatTime(scenetree.tod.time)
    guihooks.trigger("phone_time_update", time)
end

local function clearTime()
    time = nil
end

M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded
M.clearTime = clearTime

return M