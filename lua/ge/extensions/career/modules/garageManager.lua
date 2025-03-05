local M = {}
M.dependencies = { 'career_career', 'career_saveSystem', 'freeroam_facilities' }

local purchasedGarages = {}
local discoveredGarages = {}
local garageToPurchase = nil
local saveFile = "purchasedGarages.json"

local garageSize = {}

local function savePurchasedGarages(currentSavePath)
  if not currentSavePath then
    local slot, path = career_saveSystem.getCurrentSaveSlot()
    currentSavePath = path
    if not currentSavePath then return end
  end

  local dirPath = currentSavePath .. "/career/rls_career"
  if not FS:directoryExists(dirPath) then
    FS:directoryCreate(dirPath)
  end
  
  local data = {
    garages    = purchasedGarages,
    discovered = discoveredGarages
  }
  career_saveSystem.jsonWriteFileSafe(dirPath .. "/" .. saveFile, data, true)
  print("Saved Garage Data to: " .. dirPath .. "/" .. saveFile)
end

local function onSaveCurrentSaveSlot(currentSavePath)
  -- This is the correct handler that will save to the new autosave
  print("Saving Garage Data to: " .. currentSavePath .. "/career/rls_career/" .. saveFile)
  savePurchasedGarages(currentSavePath)
end

local function isPurchasedGarage(garageId)
  return purchasedGarages[garageId] or false
end

local function isDiscoveredGarage(garageId)
  return discoveredGarages[garageId] or false
end

local function reloadRecoveryPrompt()
  if core_recoveryPrompt then
    core_recoveryPrompt.addTowingButtons()
    core_recoveryPrompt.addTaxiButtons()
  end
end

local function buildGarageSizes()
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  
  if garages then
    for _, garage in pairs(garages) do
      if purchasedGarages[garage.id] then
        garageSize[tostring(garage.id)] = (math.ceil(garage.capacity / (career_modules_hardcore.isHardcoreMode() and 2 or 1)) or 0)
      end
    end
  end
  dump(garageSize)
end

local function addPurchasedGarage(garageId)
  if purchasedGarages == {} then
    print("Showing non-tutorial welcome splashscreen")
    career_modules_linearTutorial.showNonTutorialWelcomeSplashscreen()
  end
  print("Adding purchased garage: " .. garageId)
  purchasedGarages[garageId] = true
  discoveredGarages[garageId] = true
  reloadRecoveryPrompt()
  buildGarageSizes()
end

local function addDiscoveredGarage(garageId)
  if not discoveredGarages[garageId] then
    local garages = freeroam_facilities.getFacilitiesByType("garage")
    local garage = garages[garageId]
    if garage and garage.defaultPrice == 0 then
      purchasedGarages[garageId] = true
    end
    discoveredGarages[garageId] = true
    reloadRecoveryPrompt()
  end
end

local function purchaseDefaultGarage()
  if career_career.hardcoreMode or career_modules_hardcore.isHardcoreMode() then return end
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  if not garages or #garages == 0 then return end  -- Return if no garages
  for _, garage in ipairs(garages) do
    if garage.starterGarage then
      addPurchasedGarage(garage.id)
      return
    end
  end
end

local function loadPurchasedGarages()
  if not career_career.isActive() then return end
  local _, currentSavePath = career_saveSystem.getCurrentSaveSlot()
  if not currentSavePath then return end
  
  local filePath = currentSavePath .. "/career/rls_career/" .. saveFile
  local data = jsonReadFile(filePath) or {}
  purchasedGarages = data.garages or {}
  discoveredGarages = data.discovered or {}
  -- Check general data
  if career_career.hardcoreMode then
    purchasedGarages = {}
    discoveredGarages = {}
  end
  reloadRecoveryPrompt()
end

local function getFreeSlots()
  local totalCapacity = 0
  for garage, owned in pairs(purchasedGarages) do
    if not owned then goto continue end
    local value = 0
    if M.isGarageSpace(garage, value) then 
      totalCapacity = totalCapacity + value
    end
    ::continue::
  end  
  return totalCapacity
end

local function fillGarages()
  local vehicles = career_modules_inventory.getVehicles()
  for id, vehicle in pairs(vehicles) do
    if not vehicle.location then
      career_modules_inventory.moveVehicleToGarage(id)
    end
  end
end

local function onCareerModulesActivated()
  loadPurchasedGarages()
end

local function showPurchaseGaragePrompt(garageId)
  if not career_career.isActive() then return end
  garageToPurchase = freeroam_facilities.getFacility("garage", garageId)
  guihooks.trigger('ChangeState', {state = 'purchase-garage'})
end

local function requestGarageData()
  local garage = garageToPurchase
  if garage then
    if translateLanguage(garage.name, garage.name, true) then
      garage.name = translateLanguage(garage.name, garage.name, true)
    end
    local garageData = {
      name = garage.name,
      price = garage.defaultPrice,
      capacity = math.ceil(garage.capacity / (career_modules_hardcore.isHardcoreMode() and 2 or 1))
    }
    return garageData
  end
  return nil
end

local function canPay()
  if not garageToPurchase then return false end
  price = { money = { amount = garageToPurchase.defaultPrice, canBeNegative = false } }
  for currency, info in pairs(price) do
    if not info.canBeNegative and career_modules_playerAttributes.getAttributeValue(currency) < info.amount then
      return false
    end
  end
  return true
end

local function buyGarage()
  if garageToPurchase then
    local price = garageToPurchase.defaultPrice
    price = { money = { amount = price, canBeNegative = false } }
    local success = career_modules_payment.pay(price, { label = "Purchased " .. garageToPurchase.name })
    if success then
      addPurchasedGarage(garageToPurchase.id)
    end
    garageToPurchase = nil
  end
end

local function cancelGaragePurchase()
  guihooks.trigger('ChangeState', {state = 'play'})
  garageToPurchase = nil
end

local function isGarageSpace(garage, value)
  if not garageSize[garage] then
      return 0
  end -- No size for garage
  local vehicles = career_modules_inventory.getVehicles()
  local storedLocation = {}
  for id, vehicle in pairs(vehicles) do -- Builds stored location table
      if vehicle.location then
          if not storedLocation[vehicle.location] then
              storedLocation[vehicle.location] = {}
          end
          table.insert(storedLocation[vehicle.location], id) -- Adds vehicle to location
      end
  end

  local carsInGarage
  if not storedLocation[garage] then
    carsInGarage = 0
  else
    carsInGarage = #storedLocation[garage]
  end
  value = garageSize[garage] - carsInGarage
  return (garageSize[garage] - carsInGarage) > 0
end

local function getNextAvailableSpace()
  for garage, owned in pairs(purchasedGarages) do
    if not owned then goto continue end
    if isGarageSpace(garage) then 
      return garage
    end
    ::continue::
  end
  return nil
end

local function onWorldReadyState(state)
  if state == 2 and career_career.isActive() then
    buildGarageSizes()
    fillGarages()
  end
end

M.onExtensionLoaded = function()
  if career_career.isActive() then
    buildGarageSizes()
    fillGarages()
  end
end

M.onWorldReadyState = onWorldReadyState

M.purchaseDefaultGarage = purchaseDefaultGarage

M.showPurchaseGaragePrompt = showPurchaseGaragePrompt
M.requestGarageData = requestGarageData
M.canPay = canPay
M.buyGarage = buyGarage
M.cancelGaragePurchase = cancelGaragePurchase

M.getFreeSlots = getFreeSlots
M.onCareerModulesActivated = onCareerModulesActivated
M.isPurchasedGarage = isPurchasedGarage
M.addPurchasedGarage = addPurchasedGarage
M.addDiscoveredGarage = addDiscoveredGarage
M.isDiscoveredGarage = isDiscoveredGarage
M.loadPurchasedGarages = loadPurchasedGarages
M.savePurchasedGarages = savePurchasedGarages
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot

-- Localization
M.isGarageSpace = isGarageSpace
M.getNextAvailableSpace = getNextAvailableSpace
M.buildGarageSizes = buildGarageSizes
M.fillGarages = fillGarages

return M