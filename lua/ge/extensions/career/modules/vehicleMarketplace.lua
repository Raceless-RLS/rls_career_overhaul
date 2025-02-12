local M = {}

local marketplaceData = {}

local marketplaceFile = "career/rls_career/marketplace.json"
local utils = require('gameplay/events/freeroam/utils')

local interestedCustomers = {}

local globalVehicleData = {}

local lastOfferTime = {}

local offerInterval = {}

local function racesToLabels(races)

  local raceLabels = {}
  for id, race in pairs(races) do
    raceLabels[race.label] = {time = race.bestTime, types = race.type, driftScore = race.driftGoal}
    if race.hotlap then
      raceLabels[race.label .. " (Hotlap)"] = {time = race.hotlap, types = race.type, driftScore = race.driftGoal}
    end
    if race.altRoute then
      raceLabels[race.altRoute.label] = {time = race.altRoute.bestTime, types = race.type, driftScore = race.altRoute.driftGoal}
      if race.altRoute.hotlap then
        raceLabels[race.altRoute.label .. " (Hotlap)"] = {time = race.altRoute.hotlap, types = race.type, driftScore = race.altRoute.driftGoal}
      end
    end
  end
  return raceLabels
end

local function sumInterest(interestedCustomers)
  local sum = 0
  for _, interest in ipairs(interestedCustomers) do
    sum = sum + interest.interest
  end
  return sum
end

local function setOfferInterval(inventoryId)
  inventoryId = tonumber(inventoryId)
  lastOfferTime[inventoryId] = 0
  interestedCustomers[inventoryId] = M.getInterestedCustomers(inventoryId)
  local interestSum = sumInterest(interestedCustomers[inventoryId])
  local minInterval = 60 * (career_modules_hardcore.isHardcoreMode() and 2 or 1)
  local maxInterval = 450 * (career_modules_hardcore.isHardcoreMode() and 2 or 1)
  local maxInterestSum = 75

  local normalizedInterestSum = math.min(interestSum / maxInterestSum, 1)

  print(string.format("Interest Percentage: %0.1f", normalizedInterestSum * 100) .. "%")

  -- Inverse relationship: fewer customers = longer intervals
  local calculatedInterval = maxInterval - ((maxInterval - minInterval) * normalizedInterestSum)

  local intervalRandomness = 0.3
  local randomOffset = calculatedInterval * intervalRandomness * (2 * math.random() - 1)
  offerInterval[inventoryId] = math.min(maxInterval, math.max(minInterval, calculatedInterval + randomOffset))
  print("offerInterval: " .. offerInterval[inventoryId])
end

local function initializeMarketplaceData()
  for inventoryId, offers in pairs(marketplaceData) do
    setOfferInterval(inventoryId)
  end
end

local function onExtensionLoaded()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()

  if not saveSlot or not savePath then return end
  
  marketplaceData = career_modules_inventory.loadMarketplaceData(savePath)
  initializeMarketplaceData()
end

local function openMenu()
    guihooks.trigger('ChangeState', {state = 'marketplace'})
end

local function sendOffer(inventoryId, customer, price)
  -- Check for existing offer from this customer
  for _, offer in ipairs(marketplaceData[tostring(inventoryId)]) do
    if offer.customer == customer then
      -- Update existing offer price
      offer.price = price
      guihooks.trigger("marketplaceUpdate", marketplaceData)
      return
    end
  end
  
  -- No existing offer found, add new one
  local offer = {
    customer = customer,
    price = price
  }
  table.insert(marketplaceData[tostring(inventoryId)], offer)
  guihooks.trigger("marketplaceUpdate", marketplaceData)
end

local function getTableSize(t)
  local count = 0
  for _ in pairs(t) do
      count = count + 1
  end
  return count
end

local function FREtoPerformanceValue(races, raceLabels, FRETimes)
  local performanceValues = {}
  if not FRETimes then return {} end
  for label, time in pairs(FRETimes) do
    local raceDetails = raceLabels and raceLabels[label] or {}
    if not raceDetails or not raceDetails.types then goto continue end
    for _, type in ipairs(raceDetails.types) do
      if not performanceValues[type] then
        performanceValues[type] = {}
      end
      if type == "drift" then
        table.insert(performanceValues[type], {label = label, performance = time / raceDetails.driftScore})
      else
        table.insert(performanceValues[type], {label = label, performance = raceDetails.time / time})
      end
    end
    ::continue::
  end
  return performanceValues
end

local function pullVehicleData(inventoryId)
  if not globalVehicleData[inventoryId] then
    local veh = career_modules_inventory.getVehicles()[inventoryId]
    if not veh then return end
    
    local FRETimes = veh.FRETimes
    local value = career_modules_valueCalculator.getInventoryVehicleValue(inventoryId)
    local power = 0
    local weight = 0
    local torque = 0
    local powerPerWeight = 0
    local mileage = (veh.mileage and veh.mileage or 0) / 1609.34

    if veh.certifications then
      power = string.format("%d", veh.certifications.power)
      weight = string.format("%d", veh.certifications.weight)
      torque = string.format("%d", veh.certifications.torque)
      powerPerWeight = string.format("%0.3f", power / weight)
    end

    local newParts = veh.config.parts
    local originalParts = veh.originalParts
    local changedSlots = veh.changedSlots

    local addedParts, removedParts = career_modules_valueCalculator.getPartDifference(originalParts, newParts, changedSlots)
    
    local races = utils.loadRaceData() or {}
    if races == {} then return end
    local raceLabels = racesToLabels(races)

    local vehicleData = {
      performanceValues = FREtoPerformanceValue(races, raceLabels, FRETimes),
      value = value or 0,
      power = power or 0,
      weight = weight or 0,
      torque = torque or 0,
      powerPerWeight = powerPerWeight or 0,
      mileage = mileage or 0,
      rep = veh.meetReputation or 0,
      year = veh.year or 0,
      arrests = veh.arrests or 0,
      tickets = veh.tickets or 0,
      evades = veh.evades or 0,
      accidents = veh.accidents or 0,
      movieRentals = veh.movieRentals or 0,
      repos = veh.repos or 0,
      taxiDropoffs = veh.taxiDropoffs or 0,

      numAddedParts = getTableSize(addedParts),
      numRemovedParts = getTableSize(removedParts)
    }

    globalVehicleData[inventoryId] = vehicleData
  end

  return globalVehicleData[inventoryId]
end

local function getInterestedCustomers(inventoryId)
  local vehicleData = pullVehicleData(tonumber(inventoryId))
  return career_modules_marketplaceCustomers.getInterestedCustomers(vehicleData)
end

local function onSaveCurrentSaveSlot(currentSavePath)
  if not marketplaceData then
    marketplaceData = {}
  end
  career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/" .. marketplaceFile, marketplaceData, true)
end

function M.onVehicleListingUpdate(data)
  if not marketplaceData then
    marketplaceData = {}
  end
  if data.forSale then
    setOfferInterval(data.inventoryId)
  else
    marketplaceData[tostring(data.inventoryId)] = nil
    lastOfferTime[tonumber(data.inventoryId)] = nil
    offerInterval[tonumber(data.inventoryId)] = nil
    interestedCustomers[tonumber(data.inventoryId)] = nil
    globalVehicleData[tonumber(data.inventoryId)] = nil
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
  local offers = marketplaceData[tostring(inventoryId)]
  for _, offer in ipairs(offers) do
    if offer.customer == customer then
      career_modules_inventory.removeVehicleFromSale(tonumber(inventoryId), offer.price)
      return
    end
  end
end

local function declineOffer(inventoryId, customer)
  local offers = marketplaceData[tostring(inventoryId)]
  for _, offer in ipairs(offers) do
    if offer.customer == customer then
      table.remove(offers, _)

      guihooks.trigger("marketplaceUpdate", marketplaceData)
      return
    end
  end
end

local function generateOffer(inventoryId)
  inventoryId = tonumber(inventoryId)
  if not interestedCustomers[inventoryId] then
    interestedCustomers[inventoryId] = getInterestedCustomers(inventoryId)
  end
  local customerList = interestedCustomers[inventoryId]

  if not customerList or #customerList == 0 then
    return nil -- No interested customers
  end

  local selectedCustomerIndex = math.random(1, #customerList)
  local selectedCustomer = customerList[selectedCustomerIndex]

  local offerRange = selectedCustomer.offerRange
  local interest = selectedCustomer.interest

  -- Calculate offer price based on offer range and interest
  local range = offerRange.max - offerRange.min
  local interestFactor = interest -- Use interest directly as a factor
  local randomValue = math.random() -- Random value between 0 and 1
  local offerValue = offerRange.min + range * (randomValue * (1 - interestFactor) + interestFactor)

  -- Ensure offer is within range (though it should be already)
  offerValue = math.max(offerRange.min, math.min(offerRange.max, offerValue))

  -- Format the price to 2 decimal places (optional)
  offerValue = math.floor(offerValue * 100) / 100

  local vehicleValue = pullVehicleData(inventoryId).value

  local offer = {
    customer = selectedCustomer.name,
    price = offerValue * vehicleValue
  }

  return offer
end

local function onUpdate(dt)
  if not marketplaceData then return end

  for inventoryId, _ in pairs(marketplaceData) do
    inventoryId = tonumber(inventoryId)
    if not lastOfferTime[inventoryId] then
      lastOfferTime[inventoryId] = 0
    end

    lastOfferTime[inventoryId] = lastOfferTime[inventoryId] + dt

    if offerInterval[inventoryId] and lastOfferTime[inventoryId] >= offerInterval[inventoryId] then
      local offer = generateOffer(inventoryId)
      if offer then
        sendOffer(inventoryId, offer.customer, offer.price)
      end
      setOfferInterval(inventoryId)
    end
  end

end


M.racesToLabels = racesToLabels
M.openMenu = openMenu
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.sendOffer = sendOffer

M.acceptOffer = acceptOffer
M.declineOffer = declineOffer
M.pullVehicleData = pullVehicleData
M.getInterestedCustomers = getInterestedCustomers
M.generateOffer = generateOffer

return M
