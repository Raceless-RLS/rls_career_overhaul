-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"freeroam_facilities", "gameplay_sites_sitesManager", "career_modules_delivery_general", "util_configListGenerator"}
local im = ui_imgui
local dParcelManager, dCargoScreen, dGeneral, dGenerator, dPages, dProgress, dVehOfferManager, dParcelMods, dVehOfferManager
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dPages = career_modules_delivery_pages
  dProgress = career_modules_delivery_progress
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
  dParcelMods = career_modules_delivery_parcelMods
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
end

-- data holders
local facilities = {}
local facilitiesById = {}
local parkingSpotsByPath = {}

-- these IDs are used across the whole delivery system (shared by parcel, trailer, vehicle, materials)
local cargoId = 0
local groupId = 0

-- (Unused, TODO)
local minDeliveryDistance, maxDeliveryDistance = 300, math.huge

-----------------------
-- Utility Functions --
-----------------------

local function randomFromList(list)
  arrayShuffle(list)
  return list[1] or nil
end

local function selectFacilityByLookupKeyByType(typeLookup, typeLookupKey, originId)
  --dump("find from " .. originId)
  local validFacs = {}
  --dump(typesLookup)
  for _, fac in ipairs(facilities) do
    if fac.id ~= originId then
      local match = false
      --dump(fac.logisticTypeLookup)
      for key, _ in pairs(typeLookup) do
        match = match or fac[typeLookupKey][key]
      end
      if match then
        table.insert(validFacs, fac)
      end
    end
  end
  return randomFromList(validFacs)
end

local tmpVec = vec3()
local function distanceBetween(posA, posB)
  local name_a,_,distance_a = map.findClosestRoad(posA)
  local name_b,_,distance_b = map.findClosestRoad(posB)
  if not name_a or not name_b then return 1 end
  local path = map.getPath(name_a, name_b)
  local d = 0
  for i = 1, #path-1 do
    tmpVec:set(   map.getMap().nodes[path[i  ]].pos)
    tmpVec:setSub(map.getMap().nodes[path[i+1]].pos)
    d = d + tmpVec:length()
  end
  d = d + distance_a + distance_b
  return d
end

local function getLocationCoordinates(loc)
  if loc.type == "facilityParkingspot" then
    local ps = M.getParkingSpotByPath(loc.psPath)
    if ps then return ps.pos end
  elseif loc.type == "vehicle" then
    local veh = scenetree.findObjectById(loc.vehId)
    if veh then return veh:getPosition() end
  end
end

local distanceCache = {}
local function getDistanceBetweenFacilities(facility1, facility2)
  local distanceKey = string.format("%s-%s-%s-%s", facility1.facId, facility1.psPath, facility2.facId, facility2.psPath)
  distanceCache[distanceKey] = distanceCache[distanceKey] or distanceBetween(getLocationCoordinates(facility1), getLocationCoordinates(facility2))
  return distanceCache[distanceKey]
end


-------------------------------------------------
-- Parcel Finalizing, Templates and Generation --
-------------------------------------------------

local parcelItemMoneyMultiplier = 1
local function getMoneyRewardForParcelItem(item, distance)
  local basePrice = item.slots * 1.1 --math.sqrt(item.slots) / 1
  local distanceExp = distance / 50 --3 + math.sqrt(item.slots)/100
  local pricePerM = item.weight * 1.2 --7 + math.pow(item.weight, 0.9)
  local modMultiplier = 0.9 + 0.1 * #item.modifiers
  for _, mod in ipairs(item.modifiers) do
    modMultiplier = modMultiplier * (mod.moneyMultipler or 1)
  end

  return ((basePrice) + distanceExp + pricePerM * parcelItemMoneyMultiplier * modMultiplier)
end


local function finalizeParcelItemDistanceAndRewards(item)
  if item.rewards then return end
  local distance = getDistanceBetweenFacilities(item.origin, item.destination)

  item.data.originalDistance = distance
  local template = deepcopy(M.getParcelTemplateById(item.templateId))
  item.modifiers = dParcelMods.generateModifiers(item, template, distance)
  item.rewards = {
    money = getMoneyRewardForParcelItem(item, distance) * dProgress.getMoneyMultiplerForSystem('parcelDelivery'),
    beamXP = 15 + round(distance/1000),
    labourer = 15 + round(distance/1000),
    delivery = 15 + round(distance/1000)
  }
end
M.finalizeParcelItemDistanceAndRewards = finalizeParcelItemDistanceAndRewards


local parcelItemTemplates = nil
local parcelTemplatesById = {}
local function getDeliveryParcelTemplates()
  if not parcelItemTemplates then
    parcelItemTemplates = {}
    local levelInfo = core_levels.getLevelByName("west_coast_usa")
    local files = FS:findFiles("gameplay/delivery/", '*.deliveryParcels.json', -1, false, true)
    for _,file in ipairs(files) do
      for k, v in pairs(jsonReadFile(file) or {}) do
        local item = v
        item.id = k
        item.type = item.cargoType
        item.logisticTypesLookup = tableValuesAsLookupDict(item.logisticTypes)
        --item.generationChance = 1
        item.duplicationChanceSum = 0
        item.duplicationChance = item.duplicationChance or {1}
        for _, chance in ipairs(item.duplicationChance or {}) do
          item.duplicationChanceSum = item.duplicationChanceSum + chance
        end

        item.weight = item.weight or 10
        -- make weight into a table to pick random ones later
        if type(item.weight) ~= "table" then
          item.weight = {item.weight}
        end

        if type(item.slots) ~= "table" then
          item.slots = {item.slots}
        end
        table.sort(item.slots)
        item.minSlots = item.slots[1]
        item.maxSlots = item.slots[#item.slots]

        table.insert(parcelItemTemplates, item)
        parcelTemplatesById[item.id] = item
        item.modChance = item.modChance or {}
        item.modChance.timed = item.modChance.timed or 0
        item.modChance.fragile = item.modChance.fragile or 0
      end
    end
    log("I","",string.format("Loaded %d item templates from %d files.", #tableKeys(parcelItemTemplates), #files))
  end
  return parcelItemTemplates
end

local function getParcelTemplateById(templateId)
  return parcelTemplatesById[templateId]
end
M.getParcelTemplateById = getParcelTemplateById

local function getDeliveryItemTemplateFor(generator)
  local r = math.random() * generator.sumChance

  local sum = 0
  for _, item in ipairs(generator.validTemplates) do
    sum = sum + item.chance
    if sum >= r then
      return deepcopy(item.item)
    end
  end
end

local function getDuplicateAmount(template)
  if not template.duplicationChance then return 1 end

  local r = math.random() * template.duplicationChanceSum
  local sum = 0
  for amount, chance in ipairs(template.duplicationChance) do
    sum = sum + chance
    if sum >= r then
      return amount
    end
  end
end

local function generateItemWithDuplicates(template, origin, destination, timeOffset, generatorLabel)
  profilerPushEvent("Duplicate Item")
  local offerExpiresAt = dGeneral.time() + template.offerDuration --* (0.9+math.random()*0.2) + timeOffset

  local item = {
    templateId = template.id,
    name = randomFromList(template.names),
    type = template.cargoType,
    slots = randomFromList(template.slots),
    offerExpiresAt = offerExpiresAt,
    data = {
      delivered = false,
      --deliveryGameTime = 0
    },
    location = deepcopy(origin),
    origin = deepcopy(origin),
    destination = deepcopy(destination),
    generatorLabel = generatorLabel,
    weight = randomFromList(template.weight) * (math.random()*0.2 + 0.9),
    generatedAtTimestamp = dGeneral.time() + timeOffset,
    groupSeed = round(math.random()*1000000)
  }

  local duplicateAmount = getDuplicateAmount(template)
  groupId = groupId + 1
  for d = 1, duplicateAmount do
    local copy = deepcopy(item)
    cargoId = cargoId + 1
    copy.id = cargoId
    copy.groupId = groupId
    dParcelManager.addCargo(copy)
    --table.insert(allCargo, copy)
  end
  profilerPopEvent("Duplicate Item")
  return duplicateAmount
end

local function triggerParcelGenerator(fac, generator, timeOffset)
  -- how many new items should be generated?
  local typeAmount = math.random(5, 8)
  -- proceed only if items are to be generated.
  if typeAmount > 0 then
    local remainingAttempts = 100
    for i = 1, typeAmount do
      -- generate locations and template
      local template = getDeliveryItemTemplateFor(generator)

      if not template then
        -- log("E","","No Template! " .. dumps(generator.logisticTypesLookup))
        for _, item in ipairs(getDeliveryParcelTemplates()) do
          dump(item.id, item.logisticTypesLookup)
        end
        return
      else

        local origin, destination
        profilerPushEvent("Origin and Destination")
        if generator.type == "parcelProvider" then
          local originPs = randomFromList(fac.pickUpSpots)
          origin = {type = "facilityParkingspot", facId = fac.id, psPath = originPs:getPath()}

          local destinationFac = selectFacilityByLookupKeyByType(template.logisticTypesLookup, "logisticTypesReceivedLookup", fac.id)
          local destinationPs = randomFromList(destinationFac.dropOffSpots)
          destination = {type = "facilityParkingspot", facId = destinationFac.id, psPath = destinationPs:getPath()}
        elseif generator.type == "parcelReceiver" then
          local destinationPs = randomFromList(fac.dropOffSpots)
          destination = {type = "facilityParkingspot", facId = fac.id, psPath = destinationPs:getPath()}

          local originFac = selectFacilityByLookupKeyByType(template.logisticTypesLookup, "logisticTypesProvidedLookup", fac.id)
          local originPs = randomFromList(originFac.pickUpSpots)
          origin = {type = "facilityParkingspot", facId = originFac.id, psPath = originPs:getPath()}

        end
        profilerPopEvent("Origin and Destination")
        local itemsGeneratedAmount = generateItemWithDuplicates(template, origin, destination, timeOffset, generator.name)
        typeAmount = typeAmount + (itemsGeneratedAmount - 1)
      end
      remainingAttempts = remainingAttempts - 1
      if remainingAttempts <= 0 then
        -- log("E","","Could not generate items after 100 tries: " .. fac.id.. " -> " .. dumps(generator))
        return
      end
    end
  end
end


--------------------------------------
-- Vehicle Templates, Finalizing and Generation --
--------------------------------------

local eligibleVehicles
local vehicleFilterTemplates = nil
local vehicleFilterTemplatesById = {}
local function getDeliveryVehicleTemplates()
  if not vehicleFilterTemplates then
    vehicleFilterTemplates = {}
    local files = FS:findFiles("gameplay/delivery/", '*.deliveryVehicles.json', -1, false, true)
    eligibleVehicles = util_configListGenerator.getEligibleVehicles(false, true)
    for _,file in ipairs(files) do
      for id, filter in pairs(jsonReadFile(file) or {}) do
        filter.id = id

        filter.unlockTag = filter.unlockTag or nil
        table.insert(vehicleFilterTemplates, filter)
        vehicleFilterTemplatesById[id] = filter
      end
    end
  end
  return vehicleFilterTemplates
end

local function getRandomVehicleFromFilterByFilterId(filterId)
  getDeliveryVehicleTemplates()
  local filter = vehicleFilterTemplatesById[filterId]
  local infos = util_configListGenerator.getRandomVehicleInfos(filter, 1, eligibleVehicles)
  if next(infos) then
    return infos[1], (filter.filterName or "Vehicle")
  end
end

local function finalizeVehicleOffer(offer)

  -- finalize Vehicle
  if not offer.vehicle.model then
    local vehInfo, filterName = getRandomVehicleFromFilterByFilterId(offer.vehicle.filterId)

    offer.vehicle.model = vehInfo.model_key
    offer.vehicle.config = vehInfo.key
    if vehInfo.filter.whiteList.Mileage then
      offer.vehicle.mileage = randomGauss3()/3 * (vehInfo.filter.whiteList.Mileage.max - vehInfo.filter.whiteList.Mileage.min) + vehInfo.filter.whiteList.Mileage.min
    else
      offer.vehicle.mileage = 0
    end
    offer.vehicle.brand = vehInfo.Brand
    offer.vehicle.name = vehInfo.Name
    offer.vehicle.filterName = filterName
  end

  -- calculate distance over all offer locations
  if not offer.rewards then
    local lastLoc
    local distance = 0
    for i, loc in ipairs(offer.locations) do
      if lastLoc then
        distance = distance + getDistanceBetweenFacilities(lastLoc, loc)
      end
      lastLoc = loc
    end

    offer.data.originalDistance = distance

    local filter = vehicleFilterTemplatesById[offer.vehicle.filterId]

    offer.rewards = {
      money = filter.baseReward + round(filter.rewardPerKm * distance/1000),
      beamXP = 100 + round(distance/500),
      labourer = 100 + round(distance/500),
    }
    if offer.data.type == "vehicle" then
      offer.rewards.money = offer.rewards.money * dProgress.getMoneyMultiplerForSystem('vehicleDelivery')
      offer.rewards.vehicleDelivery = 5 + round(distance/500)
    elseif offer.data.type == "trailer" then
      offer.rewards.money = offer.rewards.money * dProgress.getMoneyMultiplerForSystem('trailerDelivery')
      offer.rewards.delivery = 5 + round(distance/500)
    end
  end
end
M.finalizeVehicleOffer = finalizeVehicleOffer


local testVehicleList
local function triggerVehicleOfferGenerator(fac, generator, timeOffset)
  local count = math.random(1, 3)

  for  i = 1, count do
    local originPs = randomFromList(fac.trailerSpots)
    local origin = {type = "facilityParkingspot", facId = fac.id, psPath = originPs:getPath()}

    local logisticType = randomFromList(generator.logisticTypes)
    local lookup = {}
    lookup[logisticType] = true

    local destinationFac = selectFacilityByLookupKeyByType(lookup, "logisticTypesReceivedLookup", fac.id)
    if not destinationFac then
      log("W","",string.format("Could not find target facility to deliver from %s with type %s", fac.id, logisticType))
      return
    end
    local destinationPs = randomFromList(destinationFac.dropOffSpots)
    if not destinationPs then
      dumpz(destinationFac.id)
      dump(destinationFac.dropOffSpots)
    end
    local destination = {type = "facilityParkingspot", facId = destinationFac.id, psPath = destinationPs:getPath()}
    local dropOffPs = destinationPs
    local dropOff = {type = "facilityParkingspot", facId = destinationFac.id, psPath = dropOffPs:getPath()}

    local vehType = vehicleFilterTemplatesById[generator.filter].type


    local task, type, name
    if vehType == "vehicle" then
      task = {
        type = "vehicleDropOff",
        destination = dropOff,
        dropOff = dropOff,
        lookupType = logisticType,
      }
      type = "vehicle"
      name = "Vehicle Transport"
    elseif vehType == "trailer" then
      task = {
        type = "trailerDropOff",
        destination = dropOff,
        dropOff = dropOff,
        lookupType = logisticType,
      }
      type = "trailer"
      name = "Trailer Transport"
    end

    local offerDuration = generator.interval
    if generator.offerDuration then
      offerDuration = 180
    end

    cargoId = cargoId + 1
    local item = {
      id = cargoId,
      name = name,

      task = task,

      vehicle = {
        filterId = generator.filter,
        unlockTag = vehicleFilterTemplatesById[generator.filter].unlockTag,
      },
      locations = {origin, dropOff},
      dropOffFacId = dropOff.facId,
      offerExpiresAt = dGeneral.time() + timeOffset + offerDuration,

      spawnLocation = deepcopy(origin),
      origin = origin,

      data = {
        type = type
      },

      generatorLabel = generator.name,
      generatedAtTimestamp = dGeneral.time() + timeOffset,
    }
    dVehOfferManager.addOffer(item)
  end
end


--------------------------------------
-- Generator ticking and triggering --
--------------------------------------

local function triggerGenerator(fac, generator, timeOffset)
  profilerPushEvent("Generator: " .. generator.name)
  timeOffset = timeOffset or 0
  if generator.type == "parcelProvider" or generator.type == "parcelReceiver" then
    triggerParcelGenerator(fac, generator, timeOffset)
  elseif generator.type == "vehOfferProvider" or generator.type == "trailerOfferProvider" then
    triggerVehicleOfferGenerator(fac, generator, timeOffset)
  end

  profilerPopEvent("Generator: " .. generator.name)
end
M.triggerGenerator = triggerGenerator



local timer = 0
local interval = 30  -- Interval in seconds


local function onUpdate(dtSim)
    timer = timer + dtSim
    if timer >= interval then
        timer = timer - interval  -- Reset timer
        -- Perform action when the timer expires (every 30 seconds)
 for _, fac in ipairs(facilities or {}) do
    for _, generator in ipairs(fac.logisticGenerators) do
        if generator.nextGenerationTimestamp - dGeneral.time() <= 0 then
           generator.nextGenerationTimestamp = dGeneral.time() + 30
        M.triggerGenerator(fac, generator)
        -- You can call any function or perform any desired action here
      end
    end
  end
end
end
M.onUpdate = onUpdate


----------------------------------
-- Facility and Generator Setup --
----------------------------------

local function createGeneratorTemplateCache(generator)
  if generator.type == "parcelProvider" or generator.type == "parcelReceiver" then
    generator.validTemplates = {}
    generator.sumChance = 0
    for _, item in ipairs(getDeliveryParcelTemplates()) do
      local match = false
      --dump(fac.logisticTypeLookup)
      for key, _ in pairs(generator.logisticTypesLookup) do
        match = match or item.logisticTypesLookup[key]
      end
      if generator.slotsMin and item.minSlots < generator.slotsMin then
        match = false
      end
      if generator.slotsMax and item.maxSlots > generator.slotsMax then
        match = false
      end
      if match then
        table.insert(generator.validTemplates, {item = item, chance = item.generationChance})
        generator.sumChance = generator.sumChance + item.generationChance
      end
    end
  end
  if generator.type == "vehicleProvider" then

  end
--[[
  print(generator.name)
  for _, item in ipairs(generator.validTemplates) do
--    print(string.format(" - %02d%% %s",100 * item.chance / generator.sumChance, item.item.id))
    for amount, amountChance in ipairs(item.item.duplicationChance) do
      print(string.format(" - %02d%% Group of %d %s (%s slots)",100 * item.chance / generator.sumChance * amountChance / item.item.duplicationChanceSum, amount, item.item.id, table.concat(item.item.slots, ", ")))
    end
  end
]]
end

local logisticTypeToSystem = {}
local generatorTypeToSystem = {
  parcelReceiver = "parcelDelivery",
  parcelProvider = "parcelDelivery",
  vehOfferProvider = "vehicleDelivery",
  trailerOfferProvider = "trailerDelivery",
}

local facilitiesSetup = false
local function setupFacilities(loadData)
  if not facilitiesSetup then
    logisticTypeToSystem = {}
    for _, fac in ipairs(freeroam_facilities.getFacilitiesByType("deliveryProvider")) do
      --print("Loading " .. fac.name)
      local sites = gameplay_sites_sitesManager.loadSites(fac.sitesFile)
      fac.pickUpSpots = {}
      for _, name in ipairs(fac.pickUpSpotNames) do
        local ps = sites.parkingSpots.byName[name]
        if ps then
          table.insert(fac.pickUpSpots, ps)
          parkingSpotsByPath[ps:getPath()] = ps
        else
          log("E","missing parking spot PickUp: " .. name)
        end
      end
      fac.dropOffSpots = {}
      for _, name in ipairs(fac.dropOffSpotNames) do
        if type(name) == "string" then
          local psFound = 0
          for _, ps in ipairs(sites.parkingSpots.sorted) do
            if ps.name == name then
              if ps then
                table.insert(fac.dropOffSpots, ps)
                parkingSpotsByPath[ps:getPath()] = ps
                psFound = psFound +1
              end
            end
          end
          if psFound == 0 then
            log("E","missing parking spot DropOff: " .. name)
          end
        else
          if type(name) == "table" and name.type == "byZone" then
            local zoneName = name.zoneName
            local zone = sites.zones.byName[zoneName]
            local psFound = 0
            for _, ps in ipairs(sites.parkingSpots.sorted) do
              if zone:containsPoint2D(ps.pos) then
                table.insert(fac.dropOffSpots, ps)
                parkingSpotsByPath[ps:getPath()] = ps
                psFound = psFound +1
              end
            end
            if psFound == 0 then
              log("E","missing parking spot DropOff: " .. dumps(name))
            end
          end
        end
      end
      fac.trailerSpots = {}
      for _, name in ipairs(fac.trailerSpotNames or {}) do
        local ps = sites.parkingSpots.byName[name]
        if ps then
          table.insert(fac.trailerSpots, ps)
          parkingSpotsByPath[ps:getPath()] = ps
        else
          log("E","missing parking spot Trailer: " .. name)
        end
      end

      fac.progress = {
        deliveredFromHere = {
          countByType = {
            parcel = 0,
            vehicle = 0,
            trailer = 0,
            material = 0,
          },
          moneySum = 0
        },
        deliveredToHere = {
          countByType = {
            parcel = 0,
            vehicle = 0,
            trailer = 0,
            material = 0,
          },
          moneySum = 0
        }
      }

      if loadData.facilities and loadData.facilities[fac.id] and loadData.facilities[fac.id].progress then
        fac.progress = loadData.facilities[fac.id].progress
      end
      fac.logisticTypesProvidedLookup = tableValuesAsLookupDict(fac.logisticTypesProvided)
      fac.logisticTypesReceivedLookup = tableValuesAsLookupDict(fac.logisticTypesReceived)

      fac.logisticMaxItems = fac.logisticMaxItems or -1
      fac.logisticGenerators = fac.logisticGenerators or {}
      local missing = false
      for i, generator in ipairs(fac.logisticGenerators) do
        generator.nextGenerationTimestamp = dGeneral.time() + 30
        if loadData.facilities and loadData.facilities[fac.id] and loadData.facilities[fac.id].logisticGenerators and loadData.facilities[fac.id].logisticGenerators[i] then
          generator.nextGenerationTimestamp = loadData.facilities[fac.id].logisticGenerators[i].nextGenerationTimestamp
        end
        generator.logisticTypes = generator.logisticTypes or {}

        local generatorSystem = generatorTypeToSystem[generator.type]
        if generatorSystem then
          for _, logisticType in ipairs(generator.logisticTypes) do
            logisticTypeToSystem[logisticType] = generatorSystem
            if generator.type == "parcelProvider" or generator.type == "vehOfferProvider" or generator.type == "trailerOfferProvider" then
              if not fac.logisticTypesProvidedLookup[logisticType] then
                fac.logisticTypesProvidedLookup[logisticType] = true
                missing = true
              end
            end
          end
        end
        generator.logisticTypesLookup = tableValuesAsLookupDict(generator.logisticTypes)
        generator.name = string.format("%s %d %s %d", fac.name, i, generator.type, generator.interval)
        createGeneratorTemplateCache(generator)
      end
      if missing then
        log("E","",string.format("Fix Facility %s provided types: [\"%s\"]", fac.id, table.concat(tableKeysSorted(fac.logisticTypesProvidedLookup),'", "') )
          )
      end


      table.insert(facilities, fac)
      facilitiesById[fac.id] = fac
    end

    -- after all facilites have been loaded, add the systems provided lookup (requires all logistic types to have been parsed)
    local countProviders, countMixed, countReceivers = 0,0,0
    for _, fac in ipairs(facilities) do
      fac.providedSystemsLookup = {}
      for _, type in ipairs(fac.logisticTypesProvided) do
        if logisticTypeToSystem[type] then
          fac.providedSystemsLookup[logisticTypeToSystem[type]] = true
        end
      end
      fac.receivedSystemsLookup = {}
      for _, type in ipairs(fac.logisticTypesReceived) do
        if logisticTypeToSystem[type] then
          fac.receivedSystemsLookup[logisticTypeToSystem[type]] = true
        end
      end
      if next(fac.providedSystemsLookup) and next (fac.receivedSystemsLookup) then
        countMixed = countMixed + 1
      elseif next(fac.providedSystemsLookup) then
        countProviders = countProviders + 1
      elseif next(fac.receivedSystemsLookup) then
        countReceivers = countReceivers + 1
      end
      --print(string.format("Facility: %s provides systems: %s", fac.name, table.concat(tableKeys(fac.providedSystemsLookup),", " )))
      --print(string.format("Facility: %s provides systems: %s", fac.name, table.concat(tableKeys(fac.receivedSystemsLookup),", " )))
    end

    table.sort(facilities, function(a,b) return translateLanguage(a.name, a.name, true) < translateLanguage(b.name, b.name, true)end)

    log("I","",string.format("Setup Logistics Facilities: %d Facilities (%d only provide, %d mixed, %d only receive), %d Parking spots", #tableKeys(facilitiesById), countProviders, countMixed, countReceivers, #tableKeys(parkingSpotsByPath)))
    facilitiesSetup = true
  end
end

local function setup(loadData)
  setupFacilities(loadData)
  getDeliveryVehicleTemplates()
  -- use the existing cargo if its there
  cargoId = 0
  if loadData.parcels and next(loadData.parcels) then
    log("I","","Loading Parcels from file... " .. #loadData.parcels)
    for _, cargo in ipairs(loadData.parcels) do
      cargoId = cargoId + 1
      cargo.id = cargoId
      dParcelManager.addCargo(cargo)
    end
    groupId = loadData.general.maxGroupId + 1
  else
    log("I","","Generating initial parcels...")
    -- otherwise, generate some new cargo
    for _,fac in ipairs(facilities) do
      for _, generator in ipairs(fac.logisticGenerators) do
        if generator.type == "parcelProvider" or generator.type == "parcelReceiver" then
          for i = 0, round(1800/30) do
            triggerGenerator(fac, generator, -generator.interval*i)
          end
        end
      end
    end
  end
  -- vehicle offers
  if loadData.vehicleOffers and next(loadData.vehicleOffers) then
    log("I","","Loading Vehicle Offers from file... " .. #loadData.vehicleOffers)
    for _, offer in ipairs(loadData.vehicleOffers) do
      cargoId = cargoId + 1
      offer.id = cargoId
      dVehOfferManager.addOffer(offer)
    end
  else
    log("I","","Generating initial Vehicle Offers...")
    for _,fac in ipairs(facilities) do
      for _, generator in ipairs(fac.logisticGenerators) do
        if generator.type == "vehOfferProvider" or generator.type == "trailerOfferProvider" then
          for i = 0, round(1800/30) do
            triggerGenerator(fac, generator, -generator.interval*i)
          end
        end
      end
    end
  end
end
M.setup = setup

---------------------------
-- Some Public Functions --
---------------------------

M.getFacilities = function() return facilities end
M.getFacilityById = function(id) return facilitiesById[id] end
M.getParkingSpotByPath = function(path) return parkingSpotsByPath[path] end
--M.getLogisticTypesLookup = function() return logisticTypesLookup end
M.getDistanceBetweenFacilities = getDistanceBetweenFacilities
M.getLocationCoordinates = getLocationCoordinates
M.distanceBetween = distanceBetween
return M