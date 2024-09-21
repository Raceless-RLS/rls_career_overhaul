-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local lossPerKmRelative = 0.0000025
local scrapValueRelative = 0.50

local function getVehicleMileage(vehicle)
  for slot, partName in pairs(vehicle.config.parts) do
    if partName == vehicle.config.mainPartName then
      return vehicle.partConditions[partName]["odometer"]
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

local function getPartValue(part)
  return getAdjustedVehicleBaseValue(part.value, {age = 2023 - part.year, mileage = part.partCondition["odometer"]})
end

-- IMPORTANT the pc file of a config does not contain the correct list of parts in the vehicle. there might be old unused slots/parts there and there might be slots/parts missing that are in the vehicle
-- the empty strings in the pc file are important, because otherwise the game will use the default part

local function getVehicleValue(configBaseValue, vehicle)
  local mileage = getVehicleMileage(vehicle)

  local newParts = vehicle.config.parts
  local originalParts = vehicle.originalParts
  local changedSlots = vehicle.changedSlots
  local addedParts, removedParts = getPartDifference(originalParts, newParts, changedSlots)
  local sumPartValues = 0
  for slot, partName in pairs(addedParts) do
    local part = career_modules_partInventory.getPart(vehicle.id, slot)
    if not part then
      log("E", "valueCalculator", "Couldnt find part " .. partName .. ", in slot " .. slot .. " of vehicle " .. vehicle.id)
    else
      sumPartValues = sumPartValues + 1.15 * getPartValue(part)
    end
  end

  for slot, partName in pairs(removedParts) do
    local part = {value = vehicle.originalParts[slot].value, year = vehicle.year, partCondition = {odometer = mileage}} -- use vehicle mileage to calculate the value of the removed part
    sumPartValues = sumPartValues -  1.15 * getPartValue(part)
  end

  local adjustedBaseValue = getAdjustedVehicleBaseValue(configBaseValue, {mileage = mileage, age = 2023 - (vehicle.year or 2023)})
  return adjustedBaseValue + sumPartValues
end

local function getInventoryVehicleValue(inventoryId)
  local vehicle = career_modules_inventory.getVehicles()[inventoryId]
  if not vehicle then return end
  return getVehicleValue(vehicle.configBaseValue, vehicle)
end

M.getPartDifference = getPartDifference

M.getInventoryVehicleValue = getInventoryVehicleValue
M.getVehicleValue = getVehicleValue
M.getPartValue = getPartValue
M.getAdjustedVehicleBaseValue = getAdjustedVehicleBaseValue
M.getVehicleMileageById = getVehicleMileageById

return M