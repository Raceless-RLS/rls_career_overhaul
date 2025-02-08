local M = {}

local marketplaceData = {}

local marketplaceFile = "career/rls_career/marketplace.json"

local customers = {}

local function onExtensionLoaded()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot or not savePath then return end
  
  marketplaceData = career_modules_inventory.loadMarketplaceData(savePath)
end

local function openMenu()
    guihooks.trigger('ChangeState', {state = 'marketplace'})
end

local function sendOffer(inventoryId, customer, price)
  local offer = {
    customer = customer,
    price = price
  }
  table.insert(marketplaceData[inventoryId], offer)
  dump(marketplaceData)
  guihooks.trigger("marketplaceUpdate", marketplaceData)
end

local function onSaveCurrentSaveSlot()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot or not savePath then return end

  if not marketplaceData then
    marketplaceData = {}
  end
  
  career_saveSystem.jsonWriteFileSafe(savePath .. "/" .. marketplaceFile, marketplaceData, true)
end

function M.onVehicleListingUpdate(data)
  if not marketplaceData then
    marketplaceData = {}
  end
  if data.forSale then
    marketplaceData[tonumber(data.inventoryId)] = {}
  else
    marketplaceData[tonumber(data.inventoryId)] = nil
  end
  guihooks.trigger("marketplaceUpdate", marketplaceData)
end

function M.requestInitialData()
  guihooks.trigger("marketplaceUpdate", marketplaceData)
end

function M.dumpMarketplaceData()
  dump(marketplaceData)
end

local function acceptOffer(inventoryId, customer)
  inventoryId = tonumber(inventoryId)
  local offers = marketplaceData[inventoryId]
  for _, offer in ipairs(offers) do
    if offer.customer == customer then
      career_modules_inventory.removeVehicleFromSale(inventoryId, offer.price)
      return
    end
  end
end

local function declineOffer(inventoryId, customer)
  local offers = marketplaceData[tonumber(inventoryId)]
  for _, offer in ipairs(offers) do
    if offer.customer == customer then
      table.remove(offers, _)
      guihooks.trigger("marketplaceUpdate", marketplaceData)
      return
    end
  end
end

M.openMenu = openMenu
M.onExtensionLoaded = onExtensionLoaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.sendOffer = sendOffer
M.acceptOffer = acceptOffer
M.declineOffer = declineOffer

return M
