local M = {}

local function listVehicleForSale(inventoryId)
  print("List vehicle for sale", inventoryId)
end

local function openMenu()
    guihooks.trigger('ChangeState', {state = 'marketplace'})
end

M.openMenu = openMenu
M.listVehicleForSale = listVehicleForSale

return M
