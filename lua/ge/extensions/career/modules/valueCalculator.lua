-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local lossPerKmRelative = 0.0000025
local scrapValueRelative = 0.5

-- vehicle damage related variables
local repairTimePerPart = 20 -- amount of seconds needed to repair one part
local brokenPartsThreshold = 3 -- a vehicle is considered to need repair after x broken parts
local minimumCarValue = 500
local minimumCarValueRelativeToNew = 0.05

local function getVehicleMileage(vehicle)
  for slot, partName in pairs(vehicle.config.parts) do
    if partName == vehicle.config.mainPartName then
      if vehicle.partConditions and vehicle.partConditions[partName] then
      return vehicle.partConditions[partName]["odometer"]
      else
        if not vehicle.partConditions then
          vehicle.partConditions = {}
        end
        vehicle.partConditions[partName] = {odometer = 0}
        return 0
      end
    end
  end
  return 0 -- Return a default value if main part is not found
end

local function getVehicleMileageById(inventoryId)
  return getVehicleMileage(career_modules_inventory.getVehicles()[inventoryId])
end


local function getDepreciation(year, power)
  local powerFactor = power / 300
  local depreciation = 1
  local isSlowCar = power < 275

  for i = 1, year do
    if i == 1 then
      depreciation = depreciation * (1 - 0.05 * (1 / powerFactor))  -- 15% depreciation for the first year
    elseif i == 2 then
      depreciation = depreciation * (1 - 0.10 * (1 / powerFactor))  -- 10% depreciation for the second year
    elseif i <= 12 then
      depreciation = depreciation * (1 - 0.05 * math.exp(-0.15 * (i - 2)) * (1 / powerFactor))  -- Adjusted exponential decay for the next 10 years
    elseif i <= 20 then
      depreciation = depreciation * (1 + 0.01 * math.exp(0.03 * (i - 12)) * (1.15 * powerFactor))  -- Slower exponential growth from year 13 to 20
    elseif i <= 30 then
      depreciation = depreciation * (1 + 0.015 * math.exp(0.01 * (i - 20)) * (1.2 * powerFactor))  -- Adjusted exponential growth from year 21 to 30
    else
      depreciation = depreciation * (1 - 0.01 * math.exp(-0.05 * (i - 30)) * (1 / powerFactor))  -- Slow exponential decay after year 30
    end

    -- Additional depreciation for slow cars
    if isSlowCar then
      depreciation = depreciation * 0.975  -- Additional 2% depreciation per year for cars with less than 250 HP
    end
  end

  return depreciation
end

local function getValueByAge(value, age, power)
  if power == nil then
    power = 300
  end
  if value == nil then
    value = 10000
  end
  return value * getDepreciation(age, power)
end

local function getAdjustedVehicleBaseValue(value, vehicleCondition)
  local valueByAge = getValueByAge(value, vehicleCondition.age)
  local scrapValue = valueByAge * scrapValueRelative
  local valueLossFromMileage = valueByAge * vehicleCondition.mileage/1000 * lossPerKmRelative
  local valueTemp = math.max(0, valueByAge - valueLossFromMileage)
  return math.max(valueTemp, scrapValue)
end

local function getPartDifference(originalParts, newParts, changedSlots)
  local addedParts = {}
  local removedParts = {}
  for slotName, oldPart in pairs(originalParts) do
    local newPart = newParts[slotName]
    if newPart ~= oldPart.name then
      if oldPart.name ~= "" then
        -- part was removed
        removedParts[slotName] = oldPart.name
      end
      if newPart ~= "" then
        -- part was added
        addedParts[slotName] = newPart
      end
    end
  end

  for slotName, newPart in pairs(newParts) do
    local oldPart = originalParts[slotName]
    if newPart ~= "" then
      if not oldPart then
        -- part was added
        addedParts[slotName] = newPart
      end

      -- using part condition to see if there was another of the same part installed
      if changedSlots[slotName] and oldPart and newPart == oldPart.name then
        addedParts[slotName] = newPart
        removedParts[slotName] = originalParts[slotName]
      end
    end
  end

  return addedParts, removedParts
end

local function getDepreciatedPartValue(value, mileage)
  if mileage < 50 then
    return value
  end

  local quickCut = 0.75
  
  local milesOver50   = mileage - 50
  local thousands     = milesOver50 / 1500
  local slowFactor    = math.pow(0.99, thousands)

  local rawValue = value * quickCut * slowFactor

  local minFraction = 0.10
  local minValue    = value * minFraction

  return math.max(rawValue, minValue)
end

local function getPartValue(part)
  local mileage   = part.partCondition and part.partCondition.odometer / 1609.344 or 0 -- convert to miles
  local baseValue = part.value or 0
  
  return getDepreciatedPartValue(baseValue, mileage)
end

-- for now every damaged part needs to be replaced
local function getDamagedParts(vehInfo)
  local damagedParts = {
    partsToBeReplaced = {}
  }
  for partName, info in pairs(vehInfo.partConditions) do
    if info.integrityValue and info.integrityValue == 0 then
      for slotName, partName2 in pairs(vehInfo.config.parts) do
        if partName2 == partName then
          local part = career_modules_partInventory.getPart(vehInfo.id, slotName)
          table.insert(damagedParts.partsToBeReplaced, part)
          break
        end
      end
    end
  end

  return damagedParts
end

local function getRepairDetails(invVehInfo)
  local details = {
    price = 0,
    repairTime = 0
  }

  local damagedParts = getDamagedParts(invVehInfo)
  for _, part in pairs(damagedParts.partsToBeReplaced) do
    local price = part.value or 700
    details.price = details.price + price * 0.6-- lower the price a bit..
    details.repairTime = details.repairTime + repairTimePerPart
  end

  return details
end

-- IMPORTANT the pc file of a config does not contain the correct list of parts in the vehicle. there might be old unused slots/parts there and there might be slots/parts missing that are in the vehicle
-- the empty strings in the pc file are important, because otherwise the game will use the default part

local function getTableSize(t)
  local count = 0
  for _ in pairs(t) do
      count = count + 1
  end
  return count
end

local function getVehicleValue(configBaseValue, vehicle, ignoreDamage)
  local mileage = getVehicleMileage(vehicle)

  local newParts = vehicle.config.parts
  local originalParts = vehicle.originalParts
  local changedSlots = vehicle.changedSlots

  local addedParts, removedParts = getPartDifference(originalParts, newParts, changedSlots)
  local sumPartValues = 0
  for slot, partName in pairs(originalParts) do
    local part = career_modules_partInventory.getPart(vehicle.id, slot)
    if part and not removedParts[slot] then
      sumPartValues = sumPartValues + getPartValue(part)
    end
  end
  local adjustedBaseValue = getAdjustedVehicleBaseValue(configBaseValue, {mileage = mileage, age = 2023 - (vehicle.year or 2023)})
  for slot, partName in pairs(addedParts) do
    local part = career_modules_partInventory.getPart(vehicle.id, slot)
    if part then
      sumPartValues = sumPartValues + 0.90 * getPartValue(part)
      adjustedBaseValue = adjustedBaseValue + 0.90 * getPartValue(part)
    end
  end
  for slot, partName in pairs(removedParts) do
    local part = {value = vehicle.originalParts[slot].value, year = vehicle.year, partCondition = {odometer = mileage}} -- use vehicle mileage to calculate the value of the removed part
    adjustedBaseValue = adjustedBaseValue - getPartValue(part)
  end

  local repairDetails = getRepairDetails(vehicle)
  if ignoreDamage then
    repairDetails.price = 0
  end
  
  local value = math.max(adjustedBaseValue, sumPartValues)

  if (getTableSize(originalParts) / 2) < (getTableSize(removedParts)) then
    value = math.max(sumPartValues, 0)
  end
  return value
end

local function getInventoryVehicleValue(inventoryId, ignoreDamage)
  local vehicle = career_modules_inventory.getVehicles()[inventoryId]
  if not vehicle then return end
  return math.max(getVehicleValue(vehicle.configBaseValue, vehicle, ignoreDamage), 0)
end

local function getNumberOfBrokenParts(partConditions)
  local counter = 0
  for partName, info in pairs(partConditions) do
    if info.integrityValue and info.integrityValue == 0 then
      counter = counter + 1
    end
  end
  return counter
end

local function partConditionsNeedRepair(partConditions)
  return getNumberOfBrokenParts(partConditions) >= brokenPartsThreshold
end

local function getBrokenPartsThreshold()
  return brokenPartsThreshold
end

M.getPartDifference = getPartDifference

M.getInventoryVehicleValue = getInventoryVehicleValue
M.getPartValue = getPartValue
M.getDepreciatedPartValue = getDepreciatedPartValue
M.getAdjustedVehicleBaseValue = getAdjustedVehicleBaseValue
M.getVehicleMileageById = getVehicleMileageById
M.getBrokenPartsThreshold = getBrokenPartsThreshold

-- Vehicle damage related API
M.getRepairDetails = getRepairDetails
M.getNumberOfBrokenParts = getNumberOfBrokenParts
M.partConditionsNeedRepair = partConditionsNeedRepair
return M