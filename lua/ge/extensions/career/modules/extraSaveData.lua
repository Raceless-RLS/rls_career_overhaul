local M = {}
M.dependencies = { 'career_career', 'career_saveSystem', 'freeroam_facilities' }

local purchasedGarages = {}
local saveFile = "purchasedGarages.json"

local function purchaseDefaultGarage()
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  if not garages or #garages == 0 then return end
  for _, garage in ipairs(garages) do
    if garage.defaultPrice == 0 then
      addPurchasedGarage(garage.id)
      return
    end
  end
end

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
    garages = purchasedGarages
  }
  career_saveSystem.jsonWriteFileSafe(dirPath .. "/" .. saveFile, data, true)
end

local function onSaveCurrentSaveSlotAsyncStart()
  savePurchasedGarages()
end

local function isPurchasedGarage(garageId)
  return purchasedGarages[garageId] or false
end

local function addPurchasedGarage(garageId)
  purchasedGarages[garageId] = true
  savePurchasedGarages()
end

local function loadPurchasedGarages()
  if not career_career.isActive() then return end
  local _, currentSavePath = career_saveSystem.getCurrentSaveSlot()
  if not currentSavePath then return end
  
  local filePath = currentSavePath .. "/career/rls_career/" .. saveFile
  local data = jsonReadFile(filePath) or {}
  purchasedGarages = data.garages or {}
  if #purchasedGarages == 0 then
    purchaseDefaultGarage()
  end
end

local function onCareerModulesActivated()
  loadPurchasedGarages()
end

M.onCareerModulesActivated = onCareerModulesActivated
M.isPurchasedGarage = isPurchasedGarage
M.addPurchasedGarage = addPurchasedGarage
M.loadPurchasedGarages = loadPurchasedGarages
M.savePurchasedGarages = savePurchasedGarages
M.onSaveCurrentSaveSlotAsyncStart = onSaveCurrentSaveSlotAsyncStart

return M