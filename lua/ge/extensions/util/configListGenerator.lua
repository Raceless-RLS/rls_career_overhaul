-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local defaultNumberOfVehicles = 10

local function listFiltered(list, filterFunction)
  local filtered = {}
  for _, element in ipairs(list) do
    if filterFunction(element) then
      table.insert(filtered, element)
    end
  end
  return filtered
end

local function doesVehiclePassFiltersList(vehicleInfo, filters)
  for filterName, parameters in pairs(filters) do
    if filterName == "Years" then
      -- years, which have a min and max
      local vehicleYears = vehicleInfo.Years or vehicleInfo.aggregates.Years
      if not vehicleYears then return false end
      if parameters.min and (vehicleYears.min < parameters.min) or parameters.max and (vehicleYears.min > parameters.max) then
        return false
      end
    elseif filterName ~= "Mileage" then
      if parameters.min or parameters.max then
        -- generic number attribute
        local value = vehicleInfo[filterName] or (vehicleInfo.aggregates[filterName] and vehicleInfo.aggregates[filterName].min)
        if not value or type(value) ~= "number" then return false end
        if parameters.min and (value < parameters.min) or parameters.max and (value > parameters.max) then
          return false
        end
      else
        -- any other attribute that has a single value
        local passed = false
        for _, value in ipairs(parameters) do
          if vehicleInfo[filterName] == value or (vehicleInfo.aggregates[filterName] and vehicleInfo.aggregates[filterName][value]) then
            passed = true
          end
        end
        if not passed then return false end
      end
    end
  end
  return true
end

local function doesVehiclePassFilter(vehicleInfo, filter)
  if filter.whiteList and not doesVehiclePassFiltersList(vehicleInfo, filter.whiteList) then
    return false
  end
  if filter.blackList and doesVehiclePassFiltersList(vehicleInfo, filter.blackList) then
    return false
  end
  return true
end

local function chooseFromListBasedOnValue(list, popKey)
  -- Add all pops together
  local totalPop = 0
  for _, element in ipairs(list) do
    totalPop = totalPop + (element[popKey] or 1)
  end

  if totalPop <= 0 then
    return list[math.random(#list)]
  end

  -- Choose one pop at random and count up until you reach it
  local chosenPop = math.random(totalPop)
  local popCounter = 0
  for _, element in ipairs(list) do
    popCounter = popCounter + (element[popKey] or 1)
    if popCounter >= chosenPop then
      return element
    end
  end
end

local function chooseRandomModel(configs, popAttribute)
  local modelPops = {}
  for index, config in ipairs(configs) do
    if not modelPops[config.model_key] then
      modelPops[config.model_key] = (config[popAttribute] or 1)
    else
      modelPops[config.model_key] = math.max(modelPops[config.model_key], (config[popAttribute] or 1))
    end
  end

  -- turn into sorted list
  local popList = {}
  for model_key, pop in pairs(modelPops) do
    table.insert(popList, {model_key = model_key, pop = pop})
  end
  table.sort(popList, function(a,b) return a.model_key < b.model_key end)

  local modelData = chooseFromListBasedOnValue(popList, "pop")
  if modelData then
    return modelData.model_key
  end
  return configs[1].model_key
end

local function chooseFilter(filters)
  -- Add index to each filter
  for index, filter in ipairs(filters) do
    filter.index = index
  end
  return chooseFromListBasedOnValue(filters, "probability")
end

local function chooseRandomConfig(configs, filter, popAttribute)
  -- Use the filter to filter the config list
  local filteredConfigList = listFiltered(configs,
  function(vehInfo)
    return doesVehiclePassFilter(vehInfo, filter)
  end)
  if tableIsEmpty(filteredConfigList) then return end

  -- Add index to each config
  for index, config in ipairs(configs) do
    config.index = index
  end

  local model_key = chooseRandomModel(filteredConfigList, popAttribute)
  local configsForModel = listFiltered(filteredConfigList,
  function(vehInfo)
    return vehInfo.model_key == model_key
  end)

  local config = chooseFromListBasedOnValue(configsForModel, popAttribute)
  if config then
    return config.index
  end
  return math.random(tableSize(filteredConfigList))
end

local function createAggregatedFilters(seller)
  local result = {}
  if seller.subFilters and not tableIsEmpty(seller.subFilters) then
    for _, subFilter in ipairs(seller.subFilters) do
      local aggregateFilter = deepcopy(seller.filter)
      tableMergeRecursive(aggregateFilter, subFilter)
      table.insert(result, aggregateFilter)
    end
  else
    table.insert(result, seller.filter)
  end

  return result
end

local function getEligibleVehicles(allowAuxiliaryVehicles, allowLoadedTrailers)
  local eligibleVehicles = {}
  local configData = deepcopy(core_vehicles.getConfigList())
  for _, vehicleInfo in pairs(configData.configs) do
    if vehicleInfo.aggregates.Type
    and not vehicleInfo.aggregates.Type.Prop
    and not vehicleInfo.aggregates.Type.Utility
    and not vehicleInfo.aggregates.Type.PropParked
    and not vehicleInfo.aggregates.Type.PropTraffic
    and (allowLoadedTrailers or not vehicleInfo.hasLoad)
    and vehicleInfo.Value
    and (allowAuxiliaryVehicles or not vehicleInfo.isAuxiliary) then
      vehicleInfo.Brand = vehicleInfo.aggregates.Brand and next(vehicleInfo.aggregates.Brand) or ""
      table.insert(eligibleVehicles, vehicleInfo)
    end
  end
  table.sort(eligibleVehicles, function(a,b) return a.model_key .. a.key < b.model_key .. b.key end)
  return eligibleVehicles
end

local function getRandomVehicleInfos(filterSet, numberOfVehicles, eligibleVehicles, popAttribute)
  popAttribute = popAttribute or "Population"
  eligibleVehicles = eligibleVehicles or getEligibleVehicles()
  numberOfVehicles = numberOfVehicles or defaultNumberOfVehicles
  local vehicleCount = 0

  local configs = deepcopy(eligibleVehicles)
  local filters = createAggregatedFilters(filterSet)

  local randomVehicleInfos = {}
  while vehicleCount < numberOfVehicles and not tableIsEmpty(configs) do
    -- Choose one of the filters
    local filter = chooseFilter(filters)
    local index = chooseRandomConfig(configs, filter, popAttribute)
    if not index then
      -- remove the filter that doesnt have any eligible vehicles
      table.remove(filters, filter.index)
      -- if there are no filters left, continue to the next filterSet
      if tableIsEmpty(filters) then
        break
      end
    else
      local randomVehicleInfo = deepcopy(configs[index])
      randomVehicleInfo.filter = filter
      table.insert(randomVehicleInfos, randomVehicleInfo)
      table.remove(configs, index)
      vehicleCount = vehicleCount + 1
    end
  end

  return randomVehicleInfos
end

M.getEligibleVehicles = getEligibleVehicles
M.getRandomVehicleInfos = getRandomVehicleInfos

return M