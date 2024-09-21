-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local lossPerKmRelative = 0.0000025
local scrapValueRelative = 0.05

local function getVehicleMileage(vehicle)
  for slot, partName in pairs(vehicle.config.parts) do
    if partName == vehicle.config.mainPartName then
      return vehicle.partConditions[partName]["odometer"]
    end
  end
end

local function getVehicleMileageById(inventoryId)
  return getVehicleMileage(career_modules_inventory.getVehicles()[inventoryId])
end

local depreciationByYear = {-0.20, -0.15, -0.10, -0.10, -0.07, -0.06, -0.05, -0.05, -0.04, -0.04, -0.03, -0.03, -0.02, -0.02, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.01, -0.005, 0.0, 0.0, 0.005, 0.005, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.012, 0.012, 0.012, 0.012, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.015, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.020, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025, 0.025}

local function getValueByAge(value, age)
  local tempValue = value
  for i=1, age do
    tempValue = tempValue + tempValue * (depreciationByYear[i] or 0)
  end
  return tempValue
end

local function getAdjustedVehicleBaseValue(value, vehicleCondition)
  local valueByAge = getValueByAge(value, vehicleCondition.age)
  local scrapValue = valueByAge * scrapValueRelative
  local valueLossFromMileage = valueByAge * vehicleCondition.mileage/1000 * lossPerKmRelative
  local valueTemp = math.max(0, valueByAge - valueLossFromMileage)
  return valueTemp + scrapValue
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
      sumPartValues = sumPartValues + 0.5 * getPartValue(part)
    end
  end

  for slot, partName in pairs(removedParts) do
    local part = {value = vehicle.originalParts[slot].value, year = vehicle.year, partCondition = {odometer = mileage}} -- use vehicle mileage to calculate the value of the removed part
    sumPartValues = sumPartValues - 0.5 * getPartValue(part)
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
M.getPartValue = getPartValue
M.getAdjustedVehicleBaseValue = getAdjustedVehicleBaseValue
M.getVehicleMileageById = getVehicleMileageById

return M