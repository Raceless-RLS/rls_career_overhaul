local M = {}

local dependencies = {'career_career', 'career_modules_inventory'}

local function onBeamNGTrigger(data)
    if data.subjectID ~= be:getPlayerVehicleID(0) then return end
    if gameplay_walk.isWalking() then return end

    if data.triggerName ~= "policeAssignment" then return end

    if data.event == "enter" then
        ui_message("Entering police assignment", 10, "info", "info")
        local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(data.subjectID)
        if inventoryId then
            if career_modules_inventory.getVehicleRole(inventoryId) ~= "police" then
                career_modules_inventory.setVehicleRole(inventoryId, "police")
            end
        end
    end
end

M.onBeamNGTrigger = onBeamNGTrigger

return M
