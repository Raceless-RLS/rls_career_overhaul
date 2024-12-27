local M = {}
M.dependencies = { 'career_career', 'career_saveSystem', 'freeroam_facilities' }

local purchasedGarages = {}
local discoveredGarages = {}
local saveFile = "purchasedGarages.json"

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

local function addPurchasedGarage(garageId)
  if purchasedGarages == {} then
    print("Showing non-tutorial welcome splashscreen")
    career_modules_linearTutorial.showNonTutorialWelcomeSplashscreen()
  end
  purchasedGarages[garageId] = true
  discoveredGarages[garageId] = true
  savePurchasedGarages()
  reloadRecoveryPrompt()
end

local function addDiscoveredGarage(garageId)
  if not discoveredGarages[garageId] then
    local garages = freeroam_facilities.getFacilitiesByType("garage")
    local garage = garages[garageId]
    dump(garage)
    if garage and garage.defaultPrice == 0 then
      purchasedGarages[garageId] = true
    end
    discoveredGarages[garageId] = true
    savePurchasedGarages()
    reloadRecoveryPrompt()
  end
end

local function purchaseDefaultGarage()
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  if not garages or #garages == 0 then return end  -- Return if no garages
  for _, garage in ipairs(garages) do
    if garage.defaultPrice == 0 or garage.defaultPrice == nil then
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
  purchaseDefaultGarage()
  reloadRecoveryPrompt()
end

local function getTotalGarageCapacity()
  local totalCapacity = 0
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  
  if garages then
    for _, garage in pairs(garages) do
      if purchasedGarages[garage.id] then
        totalCapacity = totalCapacity + (garage.capacity or 0)
      end
    end
  end
  
  return totalCapacity
end

local function onCareerModulesActivated()
  loadPurchasedGarages()
end

local function onUpdate()
  if not career_career.isActive() then return end
  if purchasedGarages == {} or purchasedGarages == nil then
    purchaseDefaultGarage()
  end
end

M.getTotalGarageCapacity = getTotalGarageCapacity
M.onCareerModulesActivated = onCareerModulesActivated
M.isPurchasedGarage = isPurchasedGarage
M.addPurchasedGarage = addPurchasedGarage
M.addDiscoveredGarage = addDiscoveredGarage
M.isDiscoveredGarage = isDiscoveredGarage
M.loadPurchasedGarages = loadPurchasedGarages
M.savePurchasedGarages = savePurchasedGarages
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onUpdate = onUpdate

return M