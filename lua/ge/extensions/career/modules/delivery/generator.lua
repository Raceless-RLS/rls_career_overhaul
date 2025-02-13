-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"freeroam_facilities", "gameplay_sites_sitesManager", "util_configListGenerator"}
local im = ui_imgui
local dParcelManager, dCargoScreen, dGeneral, dGenerator, dProgress, dVehOfferManager, dParcelMods, dVehOfferManager
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
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
local minDeliveryDistance, maxDeliveryDistance = 150, math.huge

local hardcoreMultiplier = 1

-----------------------
-- Utility Functions --
-----------------------

local function randomFromList(list)
  arrayShuffle(list)
  return list[1] or nil
end

local function selectFacilityByLookupKeyByType(logisticType, typeLookupKey, originId)
  local validFacs = {}
  for _, fac in ipairs(facilities) do
    if fac.id ~= originId then
      if fac[typeLookupKey][logisticType] then
        table.insert(validFacs, fac)
      end
    end
  end
  return randomFromList(validFacs)
end

local function selectAccessPointByLookupKeyByType(accessPointsByName, logisticType, typeLookupKey)
  local validAps = {}
  for name, ap in pairs(accessPointsByName) do
    if ap[typeLookupKey] and ap[typeLookupKey][logisticType] then
      table.insert(validAps, ap)
    end
  end
  if not next(validAps) then
    log("E","","Could not find any access point with logisticType " .. logisticType .. " in this list via " .. typeLookupKey)
    for name, ap in pairs(accessPointsByName) do
      print(name .. " -> " .. dumps(ap[typeLookupKey]))
    end
    print(debug.tracesimple())
  end
  return randomFromList(validAps)
end
M.selectAccessPointByLookupKeyByType = selectAccessPointByLookupKeyByType

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
  else
    print("no location!")
    dump(loc)
    return nil
  end
end

local distanceCache = {}
local function getDistanceBetweenFacilities(loc1, loc2)
  if loc2.type == "facilityParkingspot" then
    local distanceKey = string.format("%s-%s-%s-%s", loc1.facId, loc1.psPath, loc2.facId, loc2.psPath)
    distanceCache[distanceKey] = distanceCache[distanceKey] or distanceBetween(getLocationCoordinates(loc1), getLocationCoordinates(loc2))
    return distanceCache[distanceKey]
  elseif loc2.type == "multi" then
    -- use median?
    local dists = {}
    local iHalf = 0
    for i, loc in ipairs(loc2.destinations) do
      dists[i] = M.getDistanceBetweenFacilities(loc1, loc)
      iHalf = math.ceil(i/2)
    end
    table.sort(dists)
    return dists[iHalf]
  end
end


-------------------------------------------------
-- Parcel Finalizing, Templates and Generation --
-------------------------------------------------

local parcelItemMoneyMultiplier = 1
local function getMoneyRewardForParcelItem(item, distance)
  local basePrice = math.sqrt(item.slots) / 4

  local distanceExp = 1.25 + math.sqrt(item.slots)/100
  local pricePerM = 2 + math.pow(item.weight, 0.53)
  --local modMultiplier = 1---0.9 + 0.1 * #item.modifiers
  --for _, mod in ipairs(item.modifiers) do
  --  modMultiplier = modMultiplier * (mod.moneyMultipler or 1)
  --end

  -- cleanup
  return ((basePrice) + math.pow(distance/1000, distanceExp) * pricePerM) * hardcoreMultiplier * parcelItemMoneyMultiplier --[[* modMultiplier]], basePrice, pricePerM

end

local function finalizeParcelItemDistanceAndRewards(item)
  if item.rewards then return end
  local distance = getDistanceBetweenFacilities(item.origin, item.destination)

  local baseXP = 0.25
  if item.slots >= 32 then baseXP = baseXP + 0.5 end
  if item.slots >= 64 then baseXP = baseXP + 0.5 end
  if item.slots >= 128 then baseXP = baseXP + 0.5 end

  item.data.originalDistance = distance
  local template = deepcopy(M.getParcelTemplateById(item.templateId))
  item.modifiers = dParcelMods.generateModifiers(item, template, distance)
  item.rewards = {
    money = getMoneyRewardForParcelItem(item, distance) * dProgress.getMoneyMultiplerForSkill('delivery'),
    beamXP = (baseXP + round(distance/800)) * hardcoreMultiplier,
    labourer = (baseXP + round(distance/800)) * hardcoreMultiplier,
    delivery = (baseXP + round(distance/800)) * hardcoreMultiplier
  }

  if item.organization then
    local organizationData = freeroam_organizations.getOrganization(item.organization)
    if organizationData then
      item.rewards[item.organization .. "Reputation"] = baseXP + round(distance/1400)
      item.rewards.money = item.rewards.money * organizationData.reputationLevels[organizationData.reputation.level+2].deliveryBonus.value
    end
  end
end
M.finalizeParcelItemDistanceAndRewards = finalizeParcelItemDistanceAndRewards


local parcelItemTemplates = nil
local parcelTemplatesById = {}
-- only contains true parcels!
local parcelTemplateIdsByLogisticType = {}
local function getDeliveryParcelTemplates()
  if not parcelItemTemplates then
    parcelItemTemplates = {}
    local levelInfo = core_levels.getLevelByName(getCurrentLevelIdentifier())
    local files = FS:findFiles("gameplay/delivery/", '*.deliveryParcels.json', -1, false, true)
    for _,file in ipairs(files) do
      for k, v in pairs(jsonReadFile(file) or {}) do
        local item = v
        item.id = k
        item.type = item.cargoType
        --item.logisticTypesLookup = tableValuesAsLookupDict(item.logisticTypes)
        item.logisticType = item.logisticTypes[1] -- fix from table to one elem!
        if not item.materialType then
          parcelTemplateIdsByLogisticType[item.logisticType] = parcelTemplateIdsByLogisticType[item.logisticType] or {}
          table.insert(parcelTemplateIdsByLogisticType[item.logisticType], item.id)
        end
        --item.generationChance = 1
        item.duplicationChanceSum = 0
        item.duplicationChance = item.duplicationChance or {1}
        for _, chance in ipairs(item.duplicationChance or {}) do
          item.duplicationChanceSum = item.duplicationChanceSum + chance
        end

        item.weight = item.weight or 0
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
        item.modChance.timed = item.modChance.timed or 0.2
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
  local offerExpiresAt = dGeneral.time() + template.offerDuration * (0.9+math.random()*0.2) + timeOffset
  local originFacility = M.getFacilityById(origin.facId)

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
    materialType = template.materialType,
    location = deepcopy(origin),
    origin = deepcopy(origin),
    destination = deepcopy(destination),
    generatorLabel = generatorLabel,
    weight = randomFromList(template.weight) * (math.random()*0.2 + 0.9),
    density = template.density,
    generatedAtTimestamp = dGeneral.time() + timeOffset,
    groupSeed = round(math.random()*1000000),
    automaticDropOff = true,
    organization = originFacility and originFacility.associatedOrganization
  }

  if template.materialType then
    local materialData = M.getMaterialsTemplatesById(template.materialType)
    item.weight = item.slots * materialData.density
  end

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
  local typeAmount = math.random(generator.min, generator.max)
  -- proceed only if items are to be generated.
  if typeAmount > 0 then
    local remainingAttempts = 10
    for i = 1, typeAmount do
      -- generate locations and template
      local template = getDeliveryItemTemplateFor(generator)

      if not template then
        log("E","","No Template! " .. dumps(generator.logisticTypesLookup))
        for _, item in ipairs(getDeliveryParcelTemplates()) do
          dump(item.id, item.logisticType)
        end
        goto continue
      else

        local origin, destination
        profilerPushEvent("Origin and Destination")
        if generator.type == "parcelProvider" then
          local originAp = selectAccessPointByLookupKeyByType(fac.accessPointsByName, template.logisticType, "logisticTypesProvidedLookup")
          if not originAp then
            log("E","","Could not find AP in facility " .. fac.id .. " with providing type " .. template.logisticType)
            goto continue
          end
          origin = {type = "facilityParkingspot", facId = fac.id, psPath = originAp.psPath}
          if generator.multiDestination then
            destination = {type = "multi", destinations = {}}
            --dump(typesLookup)
            for _, f in ipairs(facilities) do
              if f.id ~= fac.id then
                if f.logisticTypesReceivedLookup[template.logisticType] then
                  for name, ap in pairs(f.accessPointsByName) do
                    if ap.logisticTypesReceivedLookup[template.logisticType] then
                      table.insert(destination.destinations, {type = "facilityParkingspot", facId = f.id, psPath = s:getPath()})
                    end
                  end
                end
              end
            end
          else
            local destinationFac = selectFacilityByLookupKeyByType(template.logisticType, "logisticTypesReceivedLookup", fac.id)
            if not destinationFac then
              log("E","","Could not find facility with receiving type " .. template.logisticType)
              goto continue
            end
            local destinationAp = selectAccessPointByLookupKeyByType(destinationFac.accessPointsByName, template.logisticType, "logisticTypesReceivedLookup")
            if not destinationAp then
              log("E","","Could not find AP in facility " .. destinationFac.id .. " with receiving type " .. template.logisticType)
              goto continue
            end
            destination = {type = "facilityParkingspot", facId = destinationFac.id, psPath = destinationAp.psPath}
            if M.getDistanceBetweenFacilities(origin, destination) < minDeliveryDistance then
              origin = nil
              destination = nil
              goto continue
            end
          end
        elseif generator.type == "parcelReceiver" then
          local destinationAp = selectAccessPointByLookupKeyByType(fac.accessPointsByName, template.logisticType, "logisticTypesReceivedLookup")
          if not destinationAp then
            log("E","","Could not find AP in facility " .. fac.id .. " with receiving type " .. template.logisticType)
            goto continue
          end
          destination = {type = "facilityParkingspot", facId = fac.id, psPath = destinationAp.psPath}

          local originFac = selectFacilityByLookupKeyByType(template.logisticType, "logisticTypesProvidedLookup", fac.id)
          if not originFac then
            log("E","","Could not find facility with providing type " .. template.logisticType)
            goto continue
          end
          local originAp = selectAccessPointByLookupKeyByType(originFac.accessPointsByName, template.logisticType, "logisticTypesProvidedLookup")
          if not originAp then
            log("E","","Could not find AP in facility " .. fac.id .. " with providing type " .. template.logisticType)
            goto continue
          end
          origin = {type = "facilityParkingspot", facId = originFac.id, psPath = originAp.psPath}
          if M.getDistanceBetweenFacilities(origin, destination) < minDeliveryDistance then
            origin = nil
            destination = nil
            goto continue
          end

        end
        profilerPopEvent("Origin and Destination")
        local itemsGeneratedAmount = generateItemWithDuplicates(template, origin, destination, timeOffset, generator.name)
        typeAmount = typeAmount + (itemsGeneratedAmount - 1)
      end
      ::continue::
      remainingAttempts = remainingAttempts - 1
      if remainingAttempts <= 0 then
        log("D","","Could not generate items after 10 tries: " .. fac.id.. " -> " .. dumps(generator))
        return
      end
    end
  end
end


--------------------------------------------------
-- Vehicle Templates, Finalizing and Generation --
--------------------------------------------------

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
      money = (filter.baseReward + round(filter.rewardPerKm * distance/1000)) * hardcoreMultiplier,
      beamXP = (5 + round(distance/400)) * hardcoreMultiplier,
      labourer = (5 + round(distance/400)) * hardcoreMultiplier
    }

    if offer.data.type == "vehicle" then
      offer.rewards.money = offer.rewards.money * dProgress.getMoneyMultiplerForSkill('vehicleDelivery')
      offer.rewards.vehicleDelivery = (5 + round(distance/400)) * hardcoreMultiplier
    elseif offer.data.type == "trailer" then
      offer.rewards.money = offer.rewards.money * dProgress.getMoneyMultiplerForSkill('delivery')
      offer.rewards.delivery = (5 + round(distance/400)) * hardcoreMultiplier
    end
    if offer.organization then
      offer.rewards[offer.organization .. "Reputation"] = 5 + round(distance/4000) * hardcoreMultiplier
    end
  end
end
M.finalizeVehicleOffer = finalizeVehicleOffer


local testVehicleList
local function triggerVehicleOfferGenerator(fac, generator, timeOffset)

  local count = math.random(generator.min, generator.max)

  for  i = 1, count do
    local logisticType = randomFromList(generator.logisticTypes)

    local originAp = selectAccessPointByLookupKeyByType(fac.accessPointsByName, logisticType, "logisticTypesProvidedLookup")
    if not originAp then
      log("E","","Could not find AP in facility " .. fac.id .. " with providing type " .. logisticType)
      goto continue
    end
    local origin = {type = "facilityParkingspot", facId = fac.id, psPath = originAp.psPath}


    local destinationFac = selectFacilityByLookupKeyByType(logisticType, "logisticTypesReceivedLookup", fac.id)
    if not destinationFac then
      log("W","",string.format("Could not find target facility to deliver from %s with type %s", fac.id, logisticType))
      return
    end
    local destinationAp = selectAccessPointByLookupKeyByType(destinationFac.accessPointsByName, logisticType, "logisticTypesReceivedLookup")
    if not destinationAp then
      log("E","","Could not find AP in facility " .. destinationFac.id .. " with receiving type " .. logisticType)
      goto continue
    end

    local destination = {type = "facilityParkingspot", facId = destinationFac.id, psPath = destinationAp.psPath}
    local dropOff = deepcopy(destination)

    if M.getDistanceBetweenFacilities(origin, dropOff) < minDeliveryDistance then
      origin = nil
      dropOff = nil
      goto continue
    end

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

    local offerDuration = generator.interval * (math.random() * 0.8 + 0.8)
    if generator.offerDuration then
      offerDuration = math.random() * (generator.offerDuration.max - generator.offerDuration.min) + generator.offerDuration.min
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
      organization = fac and fac.associatedOrganization
    }
    dVehOfferManager.addOffer(item)
    ::continue::
  end
end

----------------------
-- Material generation --
----------------------
local materialTemplates = nil
local materialTemplatesById = {}
local function getMaterialsTemplates()
  if not materialTemplates then
    materialTemplates = {}
    local files = FS:findFiles("gameplay/delivery/", '*.deliveryMaterials.json', -1, false, true)
    for _,file in ipairs(files) do
      for id, data in pairs(jsonReadFile(file) or {}) do
        data.id = id
        table.insert(materialTemplates, data)
        materialTemplatesById[id] = data
      end
    end
  end
  return materialTemplates
end
M.getMaterialsTemplatesById = function(id) return materialTemplatesById[id] end

local function setupMaterialStorage(fac, generator)
  local vol = generator.capacity/2
  -- just to be sure... some semi-old save version saved it as numbers instead of tables...
  if fac.materialStorages[generator.materialType] and type(fac.materialStorages[generator.materialType]) == "table" then
    vol = fac.materialStorages[generator.materialType].storedVolume
  elseif fac.materialStorages[generator.materialType] and type(fac.materialStorages[generator.materialType]) == 'number' then
    vol = fac.materialStorages[generator.materialType] or vol
  end
  local storage = {
    id= fac.id.."-storage-"..generator.materialType,
    materialType = generator.materialType,
    capacity = generator.capacity,
    isProvider = generator.type == "materialProvider",
    isReceiver = generator.type == "materialReceiver",
    target = generator.target,
    storedVolume = vol,

  }
  if storage.storedVolume > storage.capacity then storage.storedVolume = storage.capacity end
  if storage.storedVolume < 0 then storage.storedVlume = 0 end

  fac.materialStorages[generator.materialType] = storage
end

local function finalizeMaterialDistances(fac)
  if fac.closestMaterialProviders then return end
  --[[
  -- Receivers looking for providers
  fac.closestMaterialProviders = {}
  local facLocation = {type = "facilityParkingspot", facId = fac.id, psPath = fac.dropOffSpots[1]:getPath()}
  for materialType, storage in pairs(fac.materialStorages) do
    if storage.isReceiver then
      fac.closestMaterialProviders[materialType] = {
        distance = math.huge,
        type = "facilityParkingspot",
        facId = nil,
        psPath = nil,
      }
      for _, otherFac in ipairs(facilities) do
        if otherFac.id ~= fac.id then
          if otherFac.logisticTypesProvidedLookup[materialType] then
            local otherLocation = {type = "facilityParkingspot", facId = otherFac.id, psPath = otherFac.pick UpSpots[1]:getPath()}
            local otherApName = otherFac.materialStorages[materialType] and otherFac.materialStorages[materialType].pickUpSpotName
            if otherApName then
              otherLocation.psPath = otherFac.accessPointsByName[otherApName].ps:getPath()
            end
            local dist = M.getDistanceBetweenFacilities(facLocation, otherLocation)
            if dist < fac.closestMaterialProviders[materialType].distance then
              fac.closestMaterialProviders[materialType] = {
                distance = dist,
                type = "facilityParkingspot",
                facId = otherLocation.facId,
                psPath = otherLocation.psPath,
              }
            end
          end
        end
      end
    end
  end

  -- providers looking for receivers (counting)
  fac.closestMaterialReceivers = {}
  if fac.pickUpSpots[1] then
    local facLocation = {type = "facilityParkingspot", facId = fac.id, psPath = fac.pickUpS pots[1]:getPath()}
    for materialType, storage in pairs(fac.materialStorages) do
      if storage.isProvider then
        fac.closestMaterialReceivers[materialType] = {
          locations = {},
          count = 0
        }
        for _, otherFac in ipairs(facilities) do
          if otherFac.id ~= fac.id then
            if otherFac.logisticTypesReceivedLookup[materialType] then
              M.finalizeMaterialDistances(otherFac)

              if otherFac.closestMaterialProviders[materialType] and otherFac.closestMaterialProviders[materialType].facId == fac.id then
                table.insert(fac.closestMaterialReceivers[materialType].locations, {
                    distance = dist,
                    facId = otherFac.id,
                    psPath = otherFac.dropOffSpots[1]:getPath(),
                  })
                fac.closestMaterialReceivers[materialType].count = fac.closestMaterialReceivers[materialType].count + 1
              end
            end
          end
        end
      end
    end
  end
  ]]
end

local function triggerMaterialGenerator(fac, generator, timeOffset)

  local storage = fac.materialStorages[generator.materialType]
  if not storage then
    log("E","","Missing storage! " .. fac.id .. dumps(generator.generatorLabel))
    return
  end

  local distToTarget = math.abs(storage.target - storage.storedVolume)

  local chanceToFlip = 1 - ((distToTarget / (generator.variance or generator.capacity / 2)) + 0.5)
  chanceToFlip = clamp(chanceToFlip, 0, 1)

  local changeVolume = generator.rate * sign(storage.target - storage.storedVolume)
  if changeVolume == 0 then changeVolume = generator.rate end

  storage._rate = (changeVolume * (1-chanceToFlip) - changeVolume * (chanceToFlip) ) / generator.interval
  storage._rateMax = generator.rate / generator.interval

  if math.random() <= chanceToFlip then
    changeVolume = changeVolume * -1
  end

  local rateRandomizer = math.random() * 0.25 + 1 - 0.25/2

  changeVolume = round(changeVolume * rateRandomizer)

  storage.storedVolume = storage.storedVolume + changeVolume
  if storage.storedVolume > storage.capacity then storage.storedVolume = storage.capacity end
  if storage.storedVolume < 0 then storage.storedVolume = 0 end

end


local function addMaterialAsParcelToContainer(con, storage, amount, sourceFacId, sourcePsPath)
  local materialType = storage.materialType
  local materialData = M.getMaterialsTemplatesById(materialType)
  --[[
  for _, cargo in ipairs(con.rawCargo) do
    if cargo.type == materialType and cargo.data.sourceFacId == sourceFacId then
      M.changeMaterialAmountInFacility(sourceFacId, materialType, -amount)
      cargo.slots = cargo.slots + amount
      cargo.weight = materialData.density * cargo.slots
      cargo.rewards.money = cargo.slots
      return
    end
  end]]

  -- source/destination locations
  local fac = facilitiesById[sourceFacId]
  local storageAp = selectAccessPointByLookupKeyByType(fac.accessPointsByName, storage.materialType, "logisticTypesProvidedLookup")
  sourcePsPath = storageAp and storageAp.psPath or sourcePsPath
  local origin = {type = "facilityParkingspot", facId = sourceFacId, psPath = sourcePsPath}
  local destination = {type = "multi", destinations = {}}
  --dump(typesLookup)
  for _, f in ipairs(facilities) do
    if f.id ~= fac.id and f.logisticTypesReceivedLookup[materialType] and f.materialStorages[materialType] then
      for _, apName in ipairs(tableKeysSorted(f.accessPointsByName)) do
        local ap = f.accessPointsByName[apName]
        if ap.logisticTypesReceivedLookup[materialType] then
          table.insert(destination.destinations, {type = "facilityParkingspot", facId = f.id, psPath = ap.ps:getPath()})
        end
      end
    end
  end
  if #destination.destinations == 1 then
    destination = destination.destinations[1]
  end

  local item = {
    templateId = -1,
    name = string.format("%s from %s",materialData.name, fac.name),
    type = materialData.type,
    slots = amount,
    materialType = materialType,
    merge = true,
    offerExpiresAt = math.huge,
    data = {
      delivered = false,
      originalDistance = 123,
      sourceFacId = sourceFacId
    },

    rewards = {
      money = amount * materialData.money,
    },
    modifiers = {},
    location = deepcopy(origin),
    origin = deepcopy(origin),
    destination = destination,
    generatorLabel = "addMaterialAsParcelToContainer",
    weight = amount * materialData.density,
    generatedAtTimestamp = dGeneral.time() ,
    groupSeed = round(math.random()*1000000),
    automaticDropOff = false,
    hiddenInFacility = true,
    sourceStorage = storage.id,
    organization = fac.associatedOrganization,
  }

  local label, desc = dParcelMods.getLabelAndShortDescription(materialData.type)
  table.insert(item.modifiers, {type = materialData.type, icon = dParcelMods.getModifierIcon(materialData.type), active = true, label = label, description = desc})

  groupId = groupId + 1
  item.groupId = groupId
  cargoId = cargoId + 1
  item.id = cargoId
  dParcelManager.addCargo(item, true)
  dParcelManager.addTransientMoveCargo(item.id, con.location)
  --dParcelManager.changeCargoLocation(item.id, deepcopy(con.location), true)
end

local function splitOffPartsFromMaterialCargo(cargo, otherPartSizes)
  local ret = {cargo}
  local materialData = M.getMaterialsTemplatesById(cargo.materialType)
  for i, size in ipairs(otherPartSizes or {}) do
    -- split material parcel
    local copy = deepcopy(cargo)
    groupId = groupId + 1
    copy.groupId = groupId
    cargoId = cargoId + 1
    copy.id = cargoId
    dParcelManager.addCargo(copy, true)

    -- copy slots/weight get set to what goes into storage
    copy.slots = size
    copy.weight = materialData.density * copy.slots
    copy.rewards.money = copy.slots * materialData.money * hardcoreMultiplier
    table.insert(ret, copy)

    cargo.slots = cargo.slots - size
    cargo.weight = materialData.density * cargo.slots
    cargo.rewards.money = cargo.slots * materialData.money * hardcoreMultiplier
  end
  return ret
end
M.splitOffPartsFromMaterialCargo = splitOffPartsFromMaterialCargo

local function moveMaterialToDestination(cargo, destination)
  local fac = facilitiesById[destination.facId]
  local storage = fac.materialStorages[cargo.materialType]

  if cargo.slots <= storage.capacity - storage.storedVolume then
    dParcelManager.changeCargoLocation(cargo.id, destination)
    return cargo, nil
  else

    local amountForTank = storage.capacity - storage.storedVolume
    local materialData = M.getMaterialsTemplatesById(cargo.materialType)

    -- split material parcel
    local copy = deepcopy(cargo)
    groupId = groupId + 1
    copy.groupId = groupId
    cargoId = cargoId + 1
    copy.id = cargoId
    dParcelManager.addCargo(copy, true)

    -- cargo slots/weight get reduced
    cargo.slots = cargo.slots - amountForTank
    cargo.weight = materialData.density * cargo.slots
    cargo.rewards.money = cargo.slots * materialData.money * hardcoreMultiplier

    -- copy slots/weight get set to what goes into storage
    copy.slots = amountForTank
    copy.weight = materialData.density * copy.slots
    copy.rewards.money = copy.slots * materialData.money * hardcoreMultiplier

    -- move copy to the destination
    dParcelManager.changeCargoLocation(cargo.id, destination)

    return copy, cargo
  end
end

local function changeMaterialAmountInFacility(facId, materialType, change)
  if not M.getFacilityById(facId) then return end
  local fac = M.getFacilityById(facId)
  if not fac.materialStorages or not fac.materialStorages[materialType] then return end

  local storage = fac.materialStorages[materialType]
  local facName = translateLanguage(fac.name, fac.name, true)
  log("I","",string.format("Moved %d %s from %s (%d -> %d)", change, materialType, facName, storage.storedVolume, storage.storedVolume + change))

  storage.storedVolume = storage.storedVolume + change
  if storage.storedVolume > storage.capacity then
    log("W","",string.format("Stored too much %s in %s (from %d, added %d, maximum %d) : %d too much", materialType, facName, storage.storedVolume-change, change, storage.capacity, storage.storedVolume+change-storage.capacity))

    storage.storedVolume = storage.capacity
  end
  if storage.storedVolume < 0 then
    log("W","",string.format("Took too much %s from %s (from %d, removed %d) : %d too much", materialType, facName, storage.storedVolume-change, -change, -change-storage.storedVolume))
    storage.storedVolume = 0
  end
end
M.changeMaterialAmountInFacility = changeMaterialAmountInFacility
M.moveMaterialToDestination = moveMaterialToDestination
M.addMaterialAsParcelToContainer = addMaterialAsParcelToContainer

M.finalizeMaterialDistances = finalizeMaterialDistances

local function finalizeMaterialDistanceRewards(item, destination)
  --(3+(max(0,($D24/2000)-1))) * (E$23/400)
  local distance = getDistanceBetweenFacilities(item.origin, destination)
  local xpAmount = round((3+math.max(0,(distance/2000)-1)) * (item.slots / 400)) * hardcoreMultiplier
  item.rewards.beamXP = xpAmount
  item.rewards.labourer = xpAmount
  item.rewards.delivery = xpAmount


  if item.organization then
    local organizationData = freeroam_organizations.getOrganization(item.organization)
    if organizationData then
      item.rewards[item.organization .. "Reputation"] = xpAmount
      item.rewards.money = item.rewards.money * organizationData.reputationLevels[organizationData.reputation.level+2].deliveryBonus.value * hardcoreMultiplier
    end
  end
end
M.finalizeMaterialDistanceRewards = finalizeMaterialDistanceRewards

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
  elseif generator.type == "materialProvider" or generator.type == "materialReceiver" then
    triggerMaterialGenerator(fac, generator, timeOffset)
  end

  profilerPopEvent("Generator: " .. generator.name)
end
M.triggerGenerator = triggerGenerator

local hasGeneratedThisFrame = false
local function triggerAllGenerators()
  if career_modules_hardcore.isHardcoreMode() then
    hardcoreMultiplier = 0.5
  end

  if hasGeneratedThisFrame then return end
  for _, fac in ipairs(facilities or {}) do
    for _, generator in ipairs(fac.logisticGenerators) do
      if generator.nextGenerationTimestamp - dGeneral.time() <= 0 then
        generator.nextGenerationTimestamp = dGeneral.time() + generator.interval
        M.triggerGenerator(fac, generator)
      end
    end
  end
  hasGeneratedThisFrame = true
end

local function onUpdate(dtReal, dtSim, dtRaw)
  hasGeneratedThisFrame = false
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
        match = match or item.logisticType == key
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

local mixable = {
  parcel = true,
  fluid = false,
  dryBulk = false
}
M.isMixable = function(type) return mixable[type] end

local generatorTypeToDirection = {
  parcelProvider = "providedSystemsLookup",
  parcelReceiver = "receivedSystemsLookup",
  vehOfferProvider = "providedSystemsLookup",
  trailerOfferProvider = "providedSystemsLookup",
  materialProvider = "providedSystemsLookup",
  materialReceiver = "receivedSystemsLookup",
}

local function logisticTypeToSystem(type, fac)
  if parcelTemplateIdsByLogisticType[type] and next(parcelTemplateIdsByLogisticType[type]) then
    return {parcelDelivery = true}
  end
  local materialData = M.getMaterialsTemplatesById(type)
  if materialData then
    if materialData.type == "fluid" then
      return {smallFluidDelivery = true, largeFluidDelivery = fac and (fac.materialStorages[type] ~= nil)}
    end
    if materialData.type == "dryBulk" then
      return {smallDryBulkDelivery = true, largeDryBulkDelivery = fac and (fac.materialStorages[type] ~= nil)}
    end
  end
  return {}
end

local function addLoanerSpotsToFacility(resTable, priorityKey, fac, sites, accessPointsByName)
  local loanerSpots = deepcopy(fac.manualAccessPoints or {})
  table.sort(loanerSpots, function(a,b) return (a[priorityKey] or 0) < (b[priorityKey] or 0) end)
  for _, psData in ipairs(loanerSpots) do
    if psData[priorityKey] then
      local psFound = false
      for _, sitesFromFile in ipairs(sites) do
        local ps = sitesFromFile.parkingSpots.byName[psData.psName]
        if ps then
          table.insert(resTable, ps)

          local ap = accessPointsByName[ps.name] or { ps = ps }
          ap.isLoanerVehicleSpot = true
          accessPointsByName[ps.name] = ap

          parkingSpotsByPath[ps:getPath()] = ps
          psFound = true
          break
        end
      end
      if not psFound then
        log("E","missing parking spot loaner: " .. tostring(accessPointsByName))
      end
    end
  end
end

local facilitiesSetup = false
local function setupFacilities(loadData)
  if not facilitiesSetup then
    for _, fac in ipairs(freeroam_facilities.getFacilitiesByType("deliveryProvider")) do
      --print("Loading " .. fac.id)
      --if fac.associatedOrganization then
      --print("     -> " .. fac.associatedOrganization)
      --end

      -- progress and genear fields

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
        },
        interacted = false
      }

      if loadData.facilities and loadData.facilities[fac.id] and loadData.facilities[fac.id].progress then
        fac.progress = loadData.facilities[fac.id].progress
        --dump(loadData.facilities[fac.id])
      end
      --print(fac.name .. " -> " .. dumpsz(fac.progress.interacted))

      fac.materialStorages = {}
      if loadData.facilities and loadData.facilities[fac.id] and loadData.facilities[fac.id].materialStorages then
        fac.materialStorages = loadData.facilities[fac.id].materialStorages
      end

      -- logistic types

      fac.logisticTypesProvided = fac.logisticTypesProvided or {}
      fac.logisticTypesReceived = fac.logisticTypesReceived or {}

      fac.logisticTypesProvidedLookup = tableValuesAsLookupDict(fac.logisticTypesProvided)
      fac.logisticTypesReceivedLookup = tableValuesAsLookupDict(fac.logisticTypesReceived)

      fac.providedSystemsLookup = {}
      fac.receivedSystemsLookup = {}

      fac.logisticMaxItems = fac.logisticMaxItems or -1
      fac.logisticGenerators = fac.logisticGenerators or {}

      local missing = false
      for i, generator in ipairs(fac.logisticGenerators) do
        generator.name = string.format("%s %d %s %d", fac.name, i, generator.type, generator.interval)
        generator.nextGenerationTimestamp = dGeneral.time() + (generator.interval) * math.random()

        -- load generator data, if provided
        if loadData.facilities and loadData.facilities[fac.id] and loadData.facilities[fac.id].logisticGenerators and loadData.facilities[fac.id].logisticGenerators[i] then
          generator.nextGenerationTimestamp = loadData.facilities[fac.id].logisticGenerators[i].nextGenerationTimestamp
        end

        -- setup logistic type lookup
        generator.logisticTypes = generator.logisticTypes or {}
        generator.logisticTypesLookup = tableValuesAsLookupDict(generator.logisticTypes)
        createGeneratorTemplateCache(generator)

        -- setup storages if this is a materials provider/receiver
        if generator.type == "materialProvider" or generator.type == "materialReceiver" then
          setupMaterialStorage(fac, generator)
        end

        -- validate provider/receiver lookup
        for _, logisticType in ipairs(generator.logisticTypes) do
          if generatorTypeToDirection[generator.type] == "providedSystemsLookup" then
            if not fac.logisticTypesProvidedLookup[logisticType] then
              fac.logisticTypesProvidedLookup[logisticType] = true
              missing = true
            end
          end
          if generatorTypeToDirection[generator.type] == "receivedSystemsLookup" then
            if not fac.logisticTypesReceivedLookup[logisticType] then
              fac.logisticTypesReceivedLookup[logisticType] = true
              missing = true
            end
          end
        end

        if generator.type == "vehOfferProvider" then
          fac.providedSystemsLookup.vehicleDelivery = true
        end
        if generator.type == "trailerOfferProvider" then
          fac.providedSystemsLookup.trailerDelivery = true
        end

        -- setup systems lookup
        --local dir = generatorTypeToDirection[generator.type]
        --local systems = generatorToSystem[generator.type](generator)
        --for sys, _ in pairs(systems) do
        --  fac[dir][sys] = true
        --end
      end

      if missing then
        log("E","",string.format("Fix Facility %s provided types: [\"%s\"]", fac.id, table.concat(tableKeysSorted(fac.logisticTypesProvidedLookup),'", "') )
          )
        log("E","",string.format("Fix Facility %s received types: [\"%s\"]", fac.id, table.concat(tableKeysSorted(fac.logisticTypesReceivedLookup),'", "') )
          )
      end


    -- parking spots
      local sites = {}

      local accessPointsByName = {}
      if type(fac.sitesFile) == "string" then
        table.insert(sites, gameplay_sites_sitesManager.loadSites(fac.sitesFile))
      else
        for _, sitesFile in ipairs(fac.sitesFile) do
          table.insert(sites, gameplay_sites_sitesManager.loadSites(sitesFile))
        end
      end

      fac.loanerTrailerSpots = {}
      addLoanerSpotsToFacility(fac.loanerTrailerSpots, "loanerTrailerPriority", fac, sites, accessPointsByName)

      fac.loanerNonTrailerSpots = {}
      addLoanerSpotsToFacility(fac.loanerNonTrailerSpots, "loanerNonTrailerPriority", fac, sites, accessPointsByName)

      for _, filter in ipairs(fac.multiDropOffSpotFilter or {}) do
        if type(filter) == "table" and filter.type == "byZone" then
          local zoneName = filter.zoneName
          local psFound = false
          for _, sitesFromFile in ipairs(sites) do
            local zone = sitesFromFile.zones.byName[zoneName]
            for _, ps in ipairs(sitesFromFile.parkingSpots.sorted) do
              if zone:containsPoint2D(ps.pos) then
                local ap = accessPointsByName[ps.name] or { ps = ps }
                ap.isDropOffSpot = true
                ap.logisticTypesReceivedLookup = deepcopy(fac.logisticTypesReceivedLookup)
                accessPointsByName[ps.name] = ap

                parkingSpotsByPath[ps:getPath()] = ps
                psFound = true
              end
            end
          end
          if not psFound then
            log("E","missing parking spot DropOff: " .. dumps(name))
          end
        end
      end

      -- manual access points
      for _, elem in ipairs(fac.manualAccessPoints or {}) do
        local psFound = false
        for _, sitesFromFile in ipairs(sites) do
          local ps = sitesFromFile.parkingSpots.byName[elem.psName]
          if ps then
            local ap = accessPointsByName[ps.name] or { ps = ps }

            ap.isInspectSpot = elem.isInspectSpot
            ap.logisticTypesReceivedLookup = elem.logisticTypesReceived and tableValuesAsLookupDict(elem.logisticTypesReceived) or deepcopy(fac.logisticTypesReceivedLookup)
            ap.logisticTypesProvidedLookup = elem.logisticTypesProvided and tableValuesAsLookupDict(elem.logisticTypesProvided) or deepcopy(fac.logisticTypesProvidedLookup)

            if elem.loanerNonTrailerPriority or elem.loanerTrailerPriority then
              fac.hasLoanerSpots = true
            end
            accessPointsByName[ps.name] = ap

            parkingSpotsByPath[ps:getPath()] = ps
            psFound = true
            break
          end
        end
        if not psFound then
          log("E","missing Manual parking spot: " .. elem.psName)
        end
      end
      -- mandatory fields / claenup

      for name, ap in pairs(accessPointsByName) do
        ap.name = name
        ap.facId = fac.id
        ap.psPath = ap.ps:getPath()
        ap.logisticTypesReceivedLookup = ap.logisticTypesReceivedLookup or {}
        ap.logisticTypesProvidedLookup = ap.logisticTypesProvidedLookup or {}
      end
      if not next(accessPointsByName) then
        log("E","","Facility " .. fac.id.. " has no access points!")
      end
      fac.accessPointsByName = accessPointsByName




      table.insert(facilities, fac)
      facilitiesById[fac.id] = fac
    end

    -- after all facilites have been loaded, add the systems provided lookup (requires all logistic types to have been parsed)
    local countProviders, countMixed, countReceivers = 0,0,0
    local allTypes = {}
    for _, fac in ipairs(facilities) do

      for _, type in ipairs(fac.logisticTypesProvided) do
        allTypes[type] = true
        for sys, en in pairs(logisticTypeToSystem(type, fac)) do
          if en then
            fac.providedSystemsLookup[sys] = true
          end
        end
      end
      for _, type in ipairs(fac.logisticTypesReceived) do
        allTypes[type] = true
        for sys, en in pairs(logisticTypeToSystem(type, fac)) do
          if en then
            fac.receivedSystemsLookup[sys] = true
          end
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
      --print(string.format("Facility: %s receives systems: %s", fac.name, table.concat(tableKeys(fac.receivedSystemsLookup),", " )))
    end
    for _, key in ipairs(tableKeysSorted(allTypes)) do
      --print(string.format("%s -> %s", key, dumps(logisticTypeToSystem(key))))
    end

    --debug the material rates in/out
    --[[
    local materialRatesProvided, materialRatesReceived = {}, {}
    for _, fac in ipairs(facilities) do
      for _, generator in ipairs(fac.logisticGenerators) do
        if generator.type == "materialProvider" then
          local rate = (generator.rate / generator.interval)
          materialRatesProvided[generator.materialType] = materialRatesProvided[generator.materialType] or {total = 0}
          materialRatesProvided[generator.materialType].total = materialRatesProvided[generator.materialType].total + rate
          materialRatesProvided[generator.materialType][fac.id] = (materialRatesProvided[generator.materialType][fac.id] or 0) + rate
        end
        if generator.type == "materialReceiver" then
          local rate = (generator.rate / generator.interval)
          materialRatesReceived[generator.materialType] = materialRatesReceived[generator.materialType] or {total = 0}
          materialRatesReceived[generator.materialType].total = materialRatesReceived[generator.materialType].total + rate
          materialRatesReceived[generator.materialType][fac.id] = (materialRatesReceived[generator.materialType][fac.id] or 0) + rate
        end
      end
    end
    for _, key in ipairs(tableKeysSorted(materialRatesProvided)) do
      print(key)
      print(string.format("Total IN: %0.2f/min", materialRatesProvided[key].total*60))
      for _, facId in ipairs(tableKeysSorted(materialRatesProvided[key])) do
        if facId ~= "total" then
          print(string.format(" - IN : %0.2f/min (%s)", materialRatesProvided[key][facId]*60, facId))
          print(string.format(" - real capacity: %d (%d min)",facilitiesById[facId].materialStorages[key].target, facilitiesById[facId].materialStorages[key].target / (materialRatesProvided[key][facId]*60)))
        end
      end
      print(string.format("Total OUT: %0.2f/min", materialRatesReceived[key].total*60))
      for _, facId in ipairs(tableKeysSorted(materialRatesReceived[key])) do
        if facId ~= "total" then
          print(string.format(" - OUT: %0.2f/min (%s)", materialRatesReceived[key][facId]*60, facId))
          print(string.format(" - real capacity: %d (%d min)",facilitiesById[facId].materialStorages[key].capacity - facilitiesById[facId].materialStorages[key].target, (facilitiesById[facId].materialStorages[key].capacity - facilitiesById[facId].materialStorages[key].target) / (materialRatesReceived[key][facId]*60)))
        end
      end
      print(" - - -")
    end
    ]]
    -- organization test
    --[[
    local orgToFacs = {}
    for _, fac in ipairs(facilities) do
      local orgKey = fac.associatedOrganization or "0none"
      orgToFacs[orgKey] = orgToFacs[orgKey] or {}
      table.insert(orgToFacs[orgKey], fac.id)
    end
    for _, orgId in ipairs(tableKeysSorted(orgToFacs)) do
      local org = freeroam_organizations.getOrganization(orgId)
      org = org or {name = "No Organization"}
      print(" - " .. org.name .. " ("..orgId..")")
      for _, facId in ipairs(orgToFacs[orgId]) do
        print("  - " .. facilitiesById[facId].name .. " ("..facId..")")
      end
    end
  ]]

    table.sort(facilities, function(a,b) return translateLanguage(a.name, a.name, true) < translateLanguage(b.name, b.name, true)end)

    log("I","",string.format("Setup Logistics Facilities: %d Facilities (%d only provide, %d mixed, %d only receive), %d Parking spots", #tableKeys(facilitiesById), countProviders, countMixed, countReceivers, #tableKeys(parkingSpotsByPath)))
    facilitiesSetup = true
  end
end

local function setup(loadData)
  getMaterialsTemplates()
  getDeliveryVehicleTemplates()
  setupFacilities(loadData)
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
          for i = 0, round(240/generator.interval) do
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
          for i = 0, round(1000/generator.interval) do
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
M.getFacilitiesForOrganizationId = function(orgId)
  local ret = {}
  for _, fac in ipairs(facilities) do
    if fac.associatedOrganization == orgId then
      table.insert(ret, {name = fac.name, id = fac.id})
    end
  end
  return ret
end
--M.getLogisticTypesLookup = function() return logisticTypesLookup end
M.getDistanceBetweenFacilities = getDistanceBetweenFacilities
M.getLocationCoordinates = getLocationCoordinates
M.distanceBetween = distanceBetween
M.triggerAllGenerators = triggerAllGenerators
return M