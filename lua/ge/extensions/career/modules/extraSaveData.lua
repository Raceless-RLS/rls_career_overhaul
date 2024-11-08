local M = {}
M.dependencies = { 'career_career', 'career_saveSystem', 'freeroam_facilities' }

local purchasedGarages = {}
local discoveredGarages = {}
local saveFile = "purchasedGarages.json"

local function savePurchasedGarages()
  if not career_career.isActive() then return end
  local _, currentSavePath = career_saveSystem.getCurrentSaveSlot()
  if not currentSavePath then return end

  -- Ensure directory exists
  local dirPath = currentSavePath .. "/career/rls_career"
  if not FS:directoryExists(dirPath) then
    FS:directoryCreate(dirPath)
  end

  local data = {
    garages = purchasedGarages,
    discovered = discoveredGarages
  }
  career_saveSystem.jsonWriteFileSafe(dirPath .. "/" .. saveFile, data, true)
end

local function onSaveCurrentSaveSlotAsyncStart()
  savePurchasedGarages()
end

local function isPurchasedGarage(garageId)
  return purchasedGarages[garageId] or false
end

local function isDiscoveredGarage(garageId)
  return discoveredGarages[garageId] or false
end

local function addPurchasedGarage(garageId)
  purchasedGarages[garageId] = true
  discoveredGarages[garageId] = true
  savePurchasedGarages()
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

    if core_recoveryPrompt then
      core_recoveryPrompt.addTowingButtons()
      core_recoveryPrompt.addTaxiButtons()
    end
  end
end

local function purchaseDefaultGarage()
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  if not garages or #garages == 0 then return end  -- Return if no garages
  for _, garage in ipairs(garages) do
    if garage.defaultPrice == 0 then
      addDiscoveredGarage(garage.id)
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
end

local function onCareerModulesActivated()
  loadPurchasedGarages()
end

local function onUpdate()
  if not career_career.isActive() then return end
  if purchasedGarages == {} then
    purchaseDefaultGarage()
  end
end

M.onCareerModulesActivated = onCareerModulesActivated
M.isPurchasedGarage = isPurchasedGarage
M.addPurchasedGarage = addPurchasedGarage
M.addDiscoveredGarage = addDiscoveredGarage
M.isDiscoveredGarage = isDiscoveredGarage
M.loadPurchasedGarages = loadPurchasedGarages
M.savePurchasedGarages = savePurchasedGarages
M.onSaveCurrentSaveSlotAsyncStart = onSaveCurrentSaveSlotAsyncStart
M.onUpdate = onUpdate

return M