-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {"core_vehicleBridge"}

local dParcelManager, dCargoScreen, dGeneral, dGenerator, dProgress, dVehOfferManager, dParcelMods, dVehicleTasks
local step
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dProgress = career_modules_delivery_progress
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
  dParcelMods = career_modules_delivery_parcelMods
  dVehicleTasks = career_modules_delivery_vehicleTasks
  step = util_stepHandler
end

local cardsById = {}
local cardId = 0

local function addCard(data)
  --data.cardId = cardId
  --cardId = cardId + 1
  local id = data.isFacilityCard and "F-" or "P-"
  if data.cardType == "parcelGroup" then
    id = id .. "pg-"..data.id
  elseif data.cardType == "storage" then
    id = id .. "st-"..data.id
  elseif data.cardType == 'vehicleOffer' then
    id = id .. "vo-"..data.id
  elseif data.cardType == "loaner" then
    id = id .."lo-"..data.id
  end
  data.cardId = id
  cardsById[data.cardId] = data
end
local cargoOverviewScreenOpen = false
local cargoOverviewTab = ""
local visibleBigMapIdsToCardIds = {}
M.isCargoScreenOpen = function() return cargoOverviewScreenOpen end
M.setCargoScreenTab = function(tab)
    --print("cargo tab -> " .. dumps(tab))
    cargoOverviewTab = tab
    --M.setVisibleIdsForBigMap()
    local visibleIds = {}
    local idx = 1
    for bmId, data in pairs(visibleBigMapIdsToCardIds) do
      for cardId, _ in pairs(data.cardIds) do 
        local card = cardsById[cardId]
        if card.filterTags[tab] or card.filterTags['myCargo'] then
          visibleIds[idx] = bmId
          idx = idx + 1
          goto continue
        end
      end

      ::continue::
    end
    freeroam_bigMapMode.setOnlyIdsVisible(visibleIds)
    gameplay_rawPois.clear()
    freeroam_bigMapMarkers.clearMarkers()
    freeroam_bigMapMarkers.setNextMarkersFullAlphaInstant()
end
M.getCargoScreenTab = function() return cargoOverviewTab end
local cargoScreenFacId, cargoScreenPsPath = nil, nil
local cargoOverviewScreenOpenedTime = -1
local cargoOverviewMaxTimeTimestamp = -1
local sentNewCargoNotificationAlready = false
-- how far back in time items should be shown
local pastDeliveryTimespan = 0

--temp table for calculations
local vehToLocationDistanceCache = {}

----------------------
-- Cargo Formatting --
----------------------

-- helper functions
local lowestIdSort = function(a,b) return a.ids[1] < b.ids[1] end
local idSort = function(a,b) return a.id < b.id end

-- formats a group of "identical" cargo (ie same name, destination, etc)
local function formatCargoGroup(group, playerCargoContainers, showFirstSeen)
  table.sort(group, idSort)
  local ret = {
    id = group[1].id,

    ids = {}, -- implicit count of included objects in this group

    name = group[1].name,
    loadedAtTimeStamp = group[1].loadedAtTimeStamp,

    originName = dParcelManager.getLocationLabelShort(group[1].origin),
    locationName = dParcelManager.getLocationLabelShort(group[1].location),
    destinationName = dParcelManager.getLocationLabelShort(group[1].destination),

    originNameLong = dParcelManager.getLocationLabelLong(group[1].origin),
    locationNameLong = dParcelManager.getLocationLabelLong(group[1].location),
    destinationNameLong = dParcelManager.getLocationLabelLong(group[1].destination),

    origin = group[1].origin,
    location = group[1].location,
    destination = group[1].destination,

    type = group[1].type,
    materialType = group[1].materialType,
    slots = group[1].slots,
    distance = group[1].data.originalDistance,
    rewardMoney = group[1].rewards.money,
    weight = group[1].weight,

    enabled = true, -- not needed in player view
    disableReason = {}, -- not needed in player view

    targetLocations = {},
    autoLoadLocations = {},
    remainingOfferTime = group[1].offerExpiresAt - dGeneral.time(),

    modifiers = {},

    automaticDropOff = group[1].automaticDropOff,
    _transientMove = group[1]._transientMove,
    hiddenInFacility = group[1].hiddenInFacility,

    route = {
      type = "navgraph",
      locations = {group[1].location, group[1].destination}
    },
    bigMapIds = {}

  }
  if group[1].destination.type ~= "multi" then
    ret.bigMapIds[string.format("delivery-parking-%s-%s", group[1].destination.facId, group[1].destination.psPath)] = true
  else
    for _, loc in ipairs(group[1].destination.destinations) do
      ret.bigMapIds[string.format("delivery-parking-%s-%s", loc.facId, loc.psPath)] = true
    end
  end

  if group[1]._transientMove then
    ret.bigMapIds = {}
    ret.bigMapIds[string.format("delivery-parking-%s-%s", group[1].location.facId, group[1].location.psPath)] = true
  end


  -- add all ids to the ret.
  for _, cargo in ipairs(group) do
    table.insert(ret.ids, cargo.id)
  end

  -- check if any cargo in the group is already reserved for movement.
  local transientMoveCounts = 0
  for _, cargo in ipairs(group) do
    transientMoveCounts = transientMoveCounts + (cargo._transientMove and 1 or 0)
  end
  ret.transientMoveCounts = transientMoveCounts

  -- update fields for "first seen" items
  if showFirstSeen then
    if group[1].firstSeen and (dGeneral.time() - group[1].firstSeen) < 3 then
      ret.showNewTimer = 3 - (dGeneral.time() - group[1].firstSeen)
    end
  end

  -- modifiers
  local modifierKeys = {}
  for _, mod in ipairs(group[1].modifiers) do
    local modData = dParcelMods.getModData(mod.type)
    if not modData.hidden then
      local modProp = {type = mod.type, icon = modData.icon, active = true, label = modData.label, description = modData.shortDescription, important = modData.important}
      table.insert(ret.modifiers, modProp)
      modifierKeys[mod.type] = true
      if mod.type == "timed" then
        ret.hasTimerMod = true
        ret.remainingTime = {}
        if ret.loadedAtTimeStamp then
          local expiredTime = dGeneral.time() - ret.loadedAtTimeStamp
          if expiredTime <= mod.timeUntilDelayed then
            ret.remainingTime = {
              type = "untilDelayed",
              time = mod.timeUntilDelayed - expiredTime,
              percent = (mod.timeUntilDelayed - expiredTime) / mod.timeUntilDelayed

            }
          elseif expiredTime <= mod.timeUntilLate then
            ret.remainingTime = {
              type = "untilLate",
              time = mod.timeUntilLate - expiredTime,
              percent = (mod.timeUntilLate - expiredTime) / (mod.timeUntilLate-mod.timeUntilDelayed)
            }
          else
            ret.remainingTime = {
              type = "late",
              percent = 0
            }
          end
        else
          ret.remainingTime = {
            type = "preLoad",
            time = mod.timeUntilDelayed,
          }
        end
      end
    end
  end


  -- if the item has the timed modifier, adjust remaining time
  --[[
  -- TODO: add warning for timed mods if late
  if modifierKeys.timed then
    -- bonus time for timed cargo is in the modifier.
    for _, mod in ipairs(ret.modifiers) do
      if mod.key == "timed" then
        if ret.loadedAtTimeStamp > (mod.bonusTime * -1) then
          ret.remainingOfferTime = ret.remainingOfferTime + mod.bonusTime
          mod.warning = true
        end
      end
    end
  end]]

  if not playerCargoContainers then
    return ret
  end

  -- if this item is expired, return early.
  if ret.remainingOfferTime <= 0 then
    ret.enabled = false
    ret.disableReason = {type = "expired"}
    return ret
  end

  -- if this item is locked because of progress, disable it.
  local lockedBecauseOfMods, minTier = dParcelMods.lockedBecauseOfMods(modifierKeys)
  ret.unlockInfo = {
    type = "minLevel", icon = "boxPickUp03", longLabel = string.format("Requires Skill 'Cargo Delivery' lvl %d", minTier), shortLabel = string.format("lvl %d", minTier)
  }
  if lockedBecauseOfMods then
    ret.enabled = false
    ret.disableReason = {
      type = "locked", icon = "boxPickUp03", level = minTier,
      label = string.format("Requires Skill 'Cargo Delivery' lvl %d", minTier)
    }
    return ret
  end

  -- calculate "possible targets" for moving this cargo group, based on player cargo containers
  local cargo = group[1]
  for _, con in ipairs(playerCargoContainers) do
    -- if this container has other cargo that does not match with the current cargo, skip container.
    if next(con.rawCargo) and cargo.type then
      local isMixable = dGenerator.isMixable(cargo.type)
      if not isMixable then
        for _, otherCargo in ipairs(con.rawCargo) do
          if otherCargo.type ~= cargo.type then
            goto continue
          end
        end
      end
    end
    -- figure out how many of these can go in at once
    if not con.cargoTypesLookup[group[1].type] then
      goto continue
    end

    local maxAmount = math.floor(con.freeCargoSlots / group[1].slots)
    if maxAmount > 0 then
      local elem = {
        enabled = con.freeCargoSlots >= group[1].slots,
        label = con.moveToLabel,
        location = con.location,
        maxAmount = maxAmount,
        selectedAmount = 0,
        containerVehicleInfo = {
          vehId = con.vehId,
          vehName = con.vehName,
          conName = con.name,
        },
        usedCargoSlots = con.usedCargoSlots,
        totalCargoSlots = con.totalCargoSlots,
      }

      -- check how many cargo in this group are already supposed to be going there
      for _, cargo in ipairs(group) do
        if cargo._transientMove then
          if dParcelManager.sameLocation(cargo._transientMove.targetLocation, con.location) then
            elem.maxAmount = elem.maxAmount + 1
            elem.selectedAmount = elem.selectedAmount + 1
            elem.usedCargoSlots = elem.usedCargoSlots - cargo.slots
            elem.enabled = true
          end
        end
      end

      table.insert(ret.targetLocations, elem)
    end

    ::continue::
  end

  -- if there is no target, that means there is "no space"
  if not next(ret.targetLocations) and transientMoveCounts == 0 then
    ret.enabled = false
    ret.disableReason = {type = "noSpace"}
    return ret
  end


  -- figure out where the cargo will go when auto loading
  local tgtIds = {}
  for id, elem in ipairs(ret.targetLocations) do
    if elem.enabled then
      table.insert(tgtIds, id)
    end
  end
  table.sort(tgtIds, function(a,b)
      local tgtA = ret.targetLocations[a]
      local tgtB = ret.targetLocations[b]
      if tgtA.maxAmount ~= tgtB.maxAmount then
        return tgtA.maxAmount > tgtB.maxAmount
      else
        return (tgtA.totalCargoSlots - tgtA.usedCargoSlots) < (tgtB.totalCargoSlots - tgtB.usedCargoSlots)
      end
    end
    )
  ret.autoLoadLocations = {}
  local autoloadCounts = 0
  for _, id in ipairs(tgtIds) do
    for i = 1, ret.targetLocations[id].maxAmount do
      if autoloadCounts < #ret.ids then
        table.insert(ret.autoLoadLocations, ret.targetLocations[id].location)
        autoloadCounts = autoloadCounts + 1
      end
    end
  end

  if not next(ret.autoLoadLocations) and ret.transientMoveCounts == 0 then
    ret.enabled = false
    ret.disableReason = {type = "noSpace"}
    return ret
  end

  return ret
end
M.formatCargoGroup = formatCargoGroup


M.tryLoadAll = function(ids)



end


-- this function first groups the cargo, then formats each individual group.
local function clusterFormatCargo(cargo, playerCargoContainers, updateFirstSeen)
  local ret = {}
  --cargo can only be clustered if their groupId is the same
  --current location also needs to be the same, but that is guaranteed by the caller of this function
  local cargoByGroupId = {}
  for _, c in ipairs(cargo) do
    --if not c.hiddenInFacility then
      local gId = string.format("%d-%d", c.groupId, c.loadedAtTimeStamp or -1)
      cargoByGroupId[gId] = cargoByGroupId[gId] or {}
      -- finalize the fields that require "costly" computation at this point
      dGenerator.finalizeParcelItemDistanceAndRewards(c)
      if updateFirstSeen then
        c.firstSeen = c.firstSeen or dGeneral.time()
      end
      table.insert(cargoByGroupId[gId], c)
    --end
  end
  -- format each group individually
  for _, group in pairs(cargoByGroupId) do
    local formatted = formatCargoGroup(group, playerCargoContainers, updateFirstSeen)
    table.insert(ret, formatted)
    formatted.cardType = "parcelGroup"
    if playerCargoContainers then
      formatted.isFacilityCard = true
    else
      formatted.isPlayerCard = true
    end
    addCard(formatted)
  end
  table.sort(ret, lowestIdSort)
  return ret
end

------------------------------
-- Vehicle Offer Formatting --
------------------------------

-- gets the thumbnail for a vehicle
local function getVehicleThumb(vehicle)
  local model = core_vehicles.getModel(vehicle.model)
  if not model then return nil end
  local config = model.configs[vehicle.config]
  if not config then return nil end
  return config.preview
end



local function formatVehicleOfferForUi(offers)
  local ret = {}

  local hasSpawnWhenCommitingCargoOffer = false
  for _, offer in ipairs(offers) do
    hasSpawnWhenCommitingCargoOffer = hasSpawnWhenCommitingCargoOffer or offer.spawnWhenCommitingCargo
  end

  for _, offer in ipairs(offers) do
    dGenerator.finalizeVehicleOffer(offer)
    local item = {
      id = offer.id,
      name = offer.vehicle.name,
      type = "vehOffer",
      vehOfferType = offer.data.type,
      vehName = offer.vehicle.name,
      vehBrand = offer.vehicle.brand,
      vehMileage = offer.vehicle.mileage,
      destinationName = dParcelManager.getLocationLabelShort(offer.task.destination),
      destinationNameLong = dParcelManager.getLocationLabelLong(offer.task.destination),
      locationName = dParcelManager.getLocationLabelShort(offer.origin),
      locationNameLong = dParcelManager.getLocationLabelLong(offer.origin),
      task = dVehOfferManager.makeTaskLabel(offer.task),
      thumbnail = getVehicleThumb(offer.vehicle) or '/ui/images/appDefault.png',
      distance = offer.data.originalDistance,
      rewards = offer.rewards,
      rewardMoney = offer.rewards.money,
      remainingOfferTime = offer.offerExpiresAt - (dGeneral.time()),
      connector = "ConName",
      unlockTag = offer.vehicle.filterName,
      enabled = true,
      spawnWhenCommitingCargo = offer.spawnWhenCommitingCargo,

      route = {
        type = "navgraph",
        locations = {offer.origin, offer.task.destination}
      },
      modifiers = dVehOfferManager.getDefaultVehicleModifiersForUI(),
      bigMapIds = {}
    }

    local enabled, reason = dVehOfferManager.isVehicleTagUnlocked(offer.vehicle.unlockTag)
    item.bigMapIds[string.format("delivery-parking-%s-%s", offer.task.destination.facId, offer.task.destination.psPath)] = true

    -- if this item is expired, return early.
    if item.remainingOfferTime <= 0 then
      item.enabled = false
      item.disableReason = {type = "expired"}
      goto continue
    end

    item.unlockInfo = reason
    if not enabled then
      item.enabled = false
      item.disableReason = reason -- this can already include levels
      goto continue
    end

    --if next(dVehicleTasks.getVehicleTasks()) or hasSpawnWhenCommitingCargoOffer then
    --  item.enabled = false
    --  item.disableReason = {type="limit", limit=1, label ="You can deliver at most 1 vehicle at a time."}
    --  goto continue
   -- end

    ::continue::

    if item.spawnWhenCommitingCargo then
      item.enabled = true
      item.disableReason = nil
    end


    table.insert(ret, item)
    item.cardType = "vehicleOffer"
    item.isFacilityCard = true
    addCard(item)
  end
  return ret
end


local function formatAcceptedOfferForUI(offer)
  local item = {
    id = offer.id,
    name = offer.vehicle.name,
    vehName = offer.vehicle.name,
    vehBrand = offer.vehicle.brand,
    vehMileage = offer.vehicle.mileage,
    vehOfferType = offer.data.type,
    destinationName = dParcelManager.getLocationLabelShort(offer.task.destination),
    task = dVehOfferManager.makeTaskLabel(offer.task),
    thumbnail = getVehicleThumb(offer.vehicle) or '/ui/images/appDefault.png',
    distance = offer.data.originalDistance,
    rewards = offer.rewards,
    rewardMoney = offer.rewards.money,
    connector = "ConName",
    type = offer.data.type,
    enabled = true,


    route = {
      type = "navgraph",
      locations = {{type="vehicle", vehId = offer.vehicle.vehId}, offer.task.destination}
    },
    modifiers = dVehOfferManager.getDefaultVehicleModifiersForUI(),
    bigMapIds = {}
  }
  item.bigMapIds[string.format("delivery-parking-%s-%s", offer.task.destination.facId, offer.task.destination.psPath)] = true

  if offer.vehicle then
    item.abandonInfo = {
      penaltyMoney = offer.rewards.money * dGeneral.getDeliveryAbandonPenaltyFactor(),
      vehId = offer.vehicle.vehId
    }
  end

  item.taskList = {"No task..?"}
  local task = dVehicleTasks.getVehicleTaskForOffer(offer)
  if not task or not task.tasks then
    if item.type == "vehicle" then
      item.taskList = {string.format("Enter the vehicle.")}
    else
      item.taskList = {string.format("Couple the trailer.")}
    end
  else
    local task = task.tasks[task.activeTaskIndex]
    item.taskList = {task.type or "no type?"}
    if task.type == "coupleTrailer" then
      item.taskList = {string.format("Couple the trailer.")}
    elseif task.type == "enterVehicle" then
      item.taskList = {string.format("Enter the vehicle.")}
    elseif task.type == "bringToDestination" or task.type == "confirmDropOff" then
      item.taskList = {string.format("Drop off %s at %s.", item.type == "trailer" and "the trailer" or "the vehicle", item.destinationName)}
    elseif task.type == "putIntoParkingSpot" then
      --not used atm
    end
  end
  return item
end
M.formatAcceptedOfferForUI = formatAcceptedOfferForUI
M.abandonAcceptedOffer = function(vehId)
  dVehicleTasks.giveBackDeliveryVehicle(vehId)
end

local function getAcceptedVehicleOffers()
  local vehicleTasks = career_modules_delivery_vehicleTasks.getVehicleTasks()
  local res = {}
  for _, taskData in ipairs(vehicleTasks) do
    if not taskData.giveBack then
      local vehOffer = formatAcceptedOfferForUI(taskData.offer)
      table.insert(res, vehOffer)
      vehOffer.cardType = "vehicleOffer"
      vehOffer.isPlayerCard = true
      addCard(vehOffer)
    end
  end


  local vehOffers = dVehOfferManager.getAllOfferUnexpired()
  for _, offer in ipairs(vehOffers) do
    if offer.spawnWhenCommitingCargo then
      local vehOffer = formatAcceptedOfferForUI(offer)
      vehOffer.transientMove = true
      table.insert(res, vehOffer)
      vehOffer.cardType = "vehicleOffer"
      vehOffer.isPlayerCard = true
      vehOffer.spawnWhenCommitingCargo = true
      addCard(vehOffer)
    end
  end

  return res
end

---------------------------
-- Material Data Formatting --
---------------------------

local function formatFluidDestinations(materialType, facPsLocation)
  local destinations = { }
  for _, fac in ipairs(dGenerator.getFacilities()) do
    if fac.logisticTypesReceivedLookup[materialType] and fac.materialStorages[materialType] then
      local destinationAp = dGenerator.selectAccessPointByLookupKeyByType(fac.accessPointsByName, materialType, "logisticTypesReceivedLookup")
      if destinationAp then
        table.insert(destinations, {
          id = fac.id,
          name = fac.name,
          destinationName = dParcelManager.getLocationLabelShort({type="facilityParkingspot", facId = fac.id, psPath = destinationAp.psPath}),
          distance = dGenerator.getDistanceBetweenFacilities(facPsLocation, {type="facilityParkingspot", facId = fac.id, psPath = destinationAp.psPath}),
          bigMapId = string.format("delivery-parking-%s-%s", destinationAp.facId, destinationAp.psPath),
          storage = fac.materialStorages[materialType],
        })
      end
    end
  end
  return destinations
end

local function formatFluidOrigins(materialType, facPsLocation)
  --[[
  local destinations = { }
  for _, fac in ipairs(dGenerator.getFacilities()) do
    if fac.logisticTypesProvidedLookup[materialType] and fac.materialStorages[materialType] then
      local destinationAp = dGenerator.selectAccessPointByLookupKeyByType(fac.accessPointsByName, materialType, "logisticTypesReceivedLookup")
      table.insert(destinations, {
        id = fac.id,
        name = fac.name,
        distance = dGenerator.getDistanceBetweenFacilities(facPsLocation, {type="facilityParkingspot", facId = fac.id, psPath = fac.dropOffSpots[1]:getPath()}),
        storage = fac.materialStorages[materialType],
      })
    end
  end
  return destinations
  ]]
  return {}
end

local function formatLoadTargets(storage, playerCargoContainers)
  local targetLocations = {}
  local totalStorableVolume = 0
  for _, con in ipairs(playerCargoContainers) do
    local materialData = dGenerator.getMaterialsTemplatesById(storage.materialType)
    local materialDataType = materialData.type

    if con.cargoTypesLookup[materialDataType] then
      totalStorableVolume = totalStorableVolume + con.freeCargoSlots

      local transientCargoSlots = 0
      for _, cargo in ipairs(dParcelManager.getAllCargoCustomFilter(function(c) return c.sourceStorage == storage.id and c._transientMove end)) do
        if dParcelManager.sameLocation(cargo._transientMove.targetLocation, con.location) then
          transientCargoSlots = cargo.slots
        end
      end

      if storage.storedVolume > 0 then

        -- use empty containers or same-fluids containers with remaining space
        if con.usedCargoSlots-transientCargoSlots == 0 then
          table.insert(targetLocations, {
            label = con.name,
            maxAmount = math.min(con.freeCargoSlots+transientCargoSlots, storage.storedVolume),
            selectedAmount = transientCargoSlots,
            location = con.location,
            containerVehicleInfo = {
              vehId = con.vehId,
              vehName = con.vehName,
              conName = con.name,
            },
            usedCargoSlots = 0,
            totalCargoSlots = con.totalCargoSlots,

          })
        end
        if (con.freeCargoSlots+transientCargoSlots) > 0 and next(con.rawCargo) and con.rawCargo[1].materialType == storage.materialType then
          table.insert(targetLocations, {
            label = con.name,
            maxAmount = math.min(con.freeCargoSlots+transientCargoSlots, storage.storedVolume),
            selectedAmount = transientCargoSlots,
            location = con.location,
            containerVehicleInfo = {
              vehId = con.vehId,
              vehName = con.vehName,
              conName = con.name,
            },
            usedCargoSlots = con.usedCargoSlots - transientCargoSlots,
            totalCargoSlots = con.totalCargoSlots,
          })
        end
      end
    end
  end
  --[[
  if totalStorableVolume == 0 then
    table.insert(targetLocations, {
      label = "No Space!",
      amount = math.min(totalStorableVolume, storage.storedVolume),
      disabled = true,
    })
  end
  if storage.storedVolume == 0 then
    table.insert(targetLocations, {
      label = "Nothing to load!",
      amount = math.min(totalStorableVolume, storage.storedVolume),
      disabled = true,
    })
  end
  if totalStorableVolume > 0 and storage.storedVolume > 0 then
    table.insert(targetLocations, {
      label = "Load All",
      amount = math.min(totalStorableVolume, storage.storedVolume),
      targetLocation = {type="auto"}
    })
  end
  ]]
  return targetLocations
end

local function clearTransientMovesForStorage(materialType)
  local fac = dGenerator.getFacilityById(cargoScreenFacId)
  local facStorage = fac.materialStorages[materialType]
  for _, cargo in ipairs(dParcelManager.getAllCargoCustomFilter(function(c) return c.sourceStorage == facStorage.id and c._transientMove end)) do
    cargo.location = {type="delete"}
    dParcelManager.clearTransientMoveForCargo(cargo.id)
    print("deleting " .. cargo.id)
  end
end
M.clearTransientMovesForStorage = clearTransientMovesForStorage

local function moveMaterialFromUi(materialType, cargoType, amount, targetLocation)
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)

    --dump(materialType, cargoType, amount, targetLocation)

    local fac = dGenerator.getFacilityById(cargoScreenFacId)
    local facStorage = fac.materialStorages[materialType]
    local materialData = dGenerator.getMaterialsTemplatesById(materialType)

    local allValidStorages = {}
    if targetLocation.type == "auto" then
      -- figure out eligible storages from the player where it can go into
      local emptyPartialStorages, emptyWholeStorages, validPartialStorages, validWholeStorages = {}, {}, {}, {}
      for _, con in ipairs(playerCargoContainers) do
        if con.cargoTypesLookup[cargoType] and con.freeCargoSlots > 0 then
          if not next(con.rawCargo) then
            if con.freeCargoSlots < amount then
              table.insert(emptyPartialStorages, con)
            else
              table.insert(emptyWholeStorages, con)
            end
          else
            if con.rawCargo[1].type == materialType then
              if con.freeCargoSlots < amount then
                table.insert(validPartialStorages, con)
              else
                table.insert(validWholeStorages, con)
              end
            end
          end
        end
      end

      -- sort whole storages by remaining(total) volume - smallest first
      table.sort(emptyWholeStorages, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)
      table.sort(validWholeStorages, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)

      -- sort partial storages by remaining volume - largest first
      table.sort(emptyPartialStorages, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)
      table.sort(validPartialStorages, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)

      -- all of these storages should be able to take at least some of the material
      arrayConcat(allValidStorages, validWholeStorages)
      arrayConcat(allValidStorages, validPartialStorages)
      arrayConcat(allValidStorages, emptyWholeStorages)
      arrayConcat(allValidStorages, emptyPartialStorages)
    elseif targetLocation.type == "vehicle" then
      for _, con in ipairs(playerCargoContainers) do
        if con.containerId == targetLocation.containerId then
          table.insert(allValidStorages, con)
        end
      end
    end
    -- fill in storages one after another until we're done or out of storages (out of storages should be checked before sending to the UI anyway...)
    local remainingVolume = amount
    local storageIdx = 1
    while remainingVolume > 0 and storageIdx <= #allValidStorages do
      local storage = allValidStorages[storageIdx]
      local storageAmount = math.min(storage.freeCargoSlots, remainingVolume)
      if storageAmount > 0 then
        -- this removes the facility tank too
        dGenerator.addMaterialAsParcelToContainer(storage, facStorage, storageAmount, cargoScreenFacId, cargoScreenPsPath)
      end
      remainingVolume = remainingVolume - storageAmount
      storageIdx = storageIdx + 1
    end
    if remainingVolume > 0 then
      log("W","",string.format("Tried loading %0.1fL %s from %s, but %0.1fL remained unloaded!",amount, materialType, fac.id, remainingVolume))
    end
  end)
end
M.moveMaterialFromUi = moveMaterialFromUi


local function formatMaterialStorage(fac, facPsLocation, playerCargoContainers)
  dGenerator.finalizeMaterialDistances(fac)
  table.sort(playerCargoContainers, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)
  local data = { }
  for _, materialType in ipairs(tableKeysSorted(fac.materialStorages)) do
    local storage = fac.materialStorages[materialType]
    local material = dGenerator.getMaterialsTemplatesById(materialType)
    local locked, minTier = dParcelMods.lockedBecauseOfMods({[material.type]=true})
    if storage.isProvider then
      local fluidData = {
        id = storage.id,
        storage = storage,
        material = material,
        isProvider = true,
        locations = formatFluidDestinations(materialType, facPsLocation),
        targetLocations = formatLoadTargets(storage, playerCargoContainers),
        modifiers = {},
        rewardMoneyPerLiter = material.money,
        enabled = true,
        _transientMaterialMoveAmount = 0,
        unlockInfo  = {
          type = "minLevel", icon = "boxPickUp03", longLabel = string.format("Requires Skill 'Cargo Delivery' lvl %d", minTier), shortLabel = string.format("lvl %d", minTier)
        },
        bigMapIds = {},
      }
      for _, loc in ipairs(fluidData.locations or {}) do
        fluidData.bigMapIds[loc.bigMapId] = true
      end

      for _, targetLocation in ipairs(fluidData.targetLocations) do
        fluidData._transientMaterialMoveAmount = fluidData._transientMaterialMoveAmount + targetLocation.selectedAmount
      end

      if not next(fluidData.targetLocations or {}) then
        fluidData.enabled = false
        fluidData.disableReason = {type = "noSpace"}
      end
      
      if locked then
        fluidData.enabled = false
        fluidData.disableReason = {type = "locked"}
      end

      local label, desc = dParcelMods.getLabelAndShortDescription(material.type)
      table.insert(fluidData.modifiers, {type = material.type, icon = dParcelMods.getModifierIcon(material.type), active = true, label = label, description = desc})

      fluidData.name = material.name
      fluidData.density = material.density
      fluidData.rewardMoney = material.money
      table.insert(data, fluidData)
      fluidData.cardType = "storage"
      fluidData.isFacilityCard = true
      addCard(fluidData)
    end
    --[[if storage.isReceiver then
      local fluidData = {
        storage = storage,
        material = material,
        isReceiver = true,
        material = dGenerator.getMaterialsTemplatesById(materialType),
        locations = formatFluidOrigins(materialType, facPsLocation),
        loadTargets = {},
        sellButtons = formatSellButtons(storage, playerCargoContainers)
      }
      table.insert(data, fluidData)
    end]]



  end
  return data
end


local function formatMaterialDestinationsPlayer(con, materialType)
  local destinations = { }
  for _, fac in ipairs(dGenerator.getFacilities()) do
    if fac.logisticTypesReceivedLookup[materialType] then

      local distanceKey = string.format("%d-%s-%s", con.vehId, fac.facId, fac.dropOffSpots[1]:getPath())
      if vehToLocationDistanceCache[distanceKey] == nil then
        vehToLocationDistanceCache[distanceKey] = false
        local a, b = dGenerator.getLocationCoordinates({type="vehicle", vehId=con.vehId}), dGenerator.getLocationCoordinates({type="facilityParkingspot", facId=fac.facId, psPath=fac.dropOffSpots[1]:getPath()})
        if a and b then
          vehToLocationDistanceCache[distanceKey] = dGenerator.distanceBetween(a,b)
        end
      end

      table.insert(destinations, {
        name = fac.name,
        distance = vehToLocationDistanceCache[distanceKey],
        storage = fac.materialStorages[materialType],
      })
    end
  end
  return destinations
end


local function formatContainerAsStorage(con)
  local cargo = con.rawCargo[1]
  local data = {
    storage = {
      capacity = con.totalCargoSlots,
      storedVolume = con.usedCargoSlots
    },
    material = cargo and dGenerator.getMaterialsTemplatesById(cargo.type) or {empty = true},
    destinations = {},
  }
  if not data.material.empty then
    data.destinations = formatMaterialDestinationsPlayer(con, cargo.type)
  end
end


---------------------------------------------
-- main cargo information getter functions --
---------------------------------------------

M.deliveryScreenExternalButtonPressed = function(id)
  if id == "openDeliveryProgress" then
    guihooks.trigger('ChangeState', {state = 'branchPage', params = {branchKey = 'labourer', skillKey = 'delivery'}})
  end
  if id == "openVehicleDeliveryProgress" then
    guihooks.trigger('ChangeState', {state = 'branchPage', params = {branchKey = 'labourer', skillKey = 'vehicleDelivery'}})
  end
end

-- gets all offers and player cargo, depending on supplied facId and psPath.
local function requestCargoDataForUi(facId, psPath, updateMaxTimeTimestamp)
  if updateMaxTimeTimestamp ~= false then
    cargoOverviewMaxTimeTimestamp = dGeneral.time()
    cargoOverviewScreenOpenedTime = cargoOverviewMaxTimeTimestamp - pastDeliveryTimespan
  end
  sentNewCargoNotificationAlready = false
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)

    local uiData = {
      player = {
        vehicles = {},
      },
      availableSystems = {},
      settings = dGeneral.getSettings(),
      facilityPanels = {
        {
          type = "skill",
          skillInfo = career_modules_branches_landing.getBranchSkillCardData("delivery"),
          branchId = "labourer", skillId="delivery",
          filterValueButtons = {'parcel','trailer','material'},
          heading = "Cargo Delivery",
          description = 'Deliver parcels, fluids, dry bulk in containers, or haul small and large trailers.',
          externalButtons = { {
            type = "progress",
            label = "Progress",
            externalButtonId = 'openDeliveryProgress',
          } }
        }, {
          type = "skill",
          skillInfo = career_modules_branches_landing.getBranchSkillCardData("vehicleDelivery"),
          branchId = "labourer", skillId="vehicleDelivery",
          filterValueButtons = {'vehicle'},
          heading = "Car Jockey",
          description = 'Drive a wide variety of vehicles safely to their destination.',
          externalButtons = { {
            type = "progress",
            label = "Progress",
            externalButtonId = 'openVehicleDeliveryProgress',
          } }
        }, {
          type = "services",
          filterValueButtons = {'loaner'},
          heading = "Services",
          description = 'Earn reputation to increase rewards. Loan vehicles to use as delivery vehicle.',
          externalButtons = {
            {
              type = "reputaion",
              label = "View Reputation Details",
              externalButtonId = 'reputation',
            }
          }

        }
      },
      levelInfo = {
        name = career_modules_uiUtils.getCareerCurrentLevelName().title
      }
    }

    local hasTooFastVehicle = false
    for _, con in ipairs(playerCargoContainers) do
      if not hasTooFastVehicle then
        local veh = scenetree.findObjectById(con.vehId)
        if veh then
          hasTooFastVehicle = veh:getVelocity():length() > 0.25
        end
      end
    end
    uiData.player.isMoving = hasTooFastVehicle


    table.clear(cardsById)
    cardId = 0
    local facPsLocation
    if facId and facId ~= "undefined" then
      local fac = dGenerator.getFacilityById(facId)
      fac.progress.interacted = true
      local organization = freeroam_organizations.getUIDataForOrg(fac.associatedOrganization)
      uiData.facility = {
        name = fac.name,
        longDescription = fac.facilityInformation or "No facility information written yet.",
        id = fac.id,
        preview = fac.preview,
        outgoingCargo = {},
        trailerOffers = {},
        vehicleOffers = {},
      }
      if organization then
        career_career.interactWithOrganization(fac.associatedOrganization)
        uiData.facility.organization = organization
        if fac.hasLoanerSpots then
          local loanersFormatted = career_modules_loanerVehicles.formatLoanerOfferForUi(fac) or {}
          for _, item in ipairs(loanersFormatted) do
            item.cardType = "loaner"
            item.isFacilityCard = true
            addCard(item)

            if item.spawnWhenCommitingCargo then
              local copy = deepcopy(item)
              copy.isFacilityCard = false
              copy.isPlayerCard = true
              addCard(copy)
            end
          end
        end

        for _, item in ipairs(career_modules_loanerVehicles.formatSpawnedLoanersForUi()) do
          item.isFacilityCard = false
          item.isPlayerCard = true
          item.cardType = "loaner"
          addCard(item)
        end
      end

      uiData.availableSystems = fac.providedSystemsLookup
      -- patch in large delivery systems
      uiData.availableSystems.largeFluidDelivery = uiData.availableSystems.largeFluidDelivery or fac.receivedSystemsLookup.largeFluidDelivery
      uiData.availableSystems.largeDryBulkDelivery = uiData.availableSystems.largeDryBulkDelivery or fac.receivedSystemsLookup.largeDryBulkDelivery
      -- small fluid delivery disabled atm
      uiData.availableSystems.smallFluidDelivery = nil

      if psPath and psPath ~= "undefined" then
        local ps = dGenerator.getParkingSpotByPath(psPath)
        facPsLocation = {type = "facilityParkingspot", facId = facId, psPath = psPath}

        -- add all parcels at this location
        --local outgoingCargo = dParcelManager.getAllCargoCustomFilter(function() return true end)
        local outgoingCargo = dParcelManager.getAllCargoForFacilityUnexpiredUndelivered(facId, cargoOverviewScreenOpenedTime, cargoOverviewMaxTimeTimestamp)
        uiData.facility.outgoingCargo = clusterFormatCargo(outgoingCargo, playerCargoContainers, true)

        -- add all vehicle and trailer offers at this location
        local vehOffers = dVehOfferManager.getAllOfferAtFacilityUnexpired(facId, psPath)
        local vehs, trailers = {}, {}
        for _, offer in ipairs(vehOffers) do
          if offer.data.type == "vehicle" then
            table.insert(vehs, offer)
          else
            table.insert(trailers, offer)
          end
        end
        if fac.providedSystemsLookup.vehicleDelivery then
          uiData.facility.vehicleOffers = formatVehicleOfferForUi(vehs)
        end
        if fac.providedSystemsLookup.trailerDelivery then
          uiData.facility.trailerOffers = formatVehicleOfferForUi(trailers)
        end

        if next(fac.materialStorages) then
          uiData.facility.materialStorageData = formatMaterialStorage(fac, facPsLocation, playerCargoContainers)
        end
      end
    end

    -- Player Data

    -- aggregates of money, weight etc
    local playerMoneySum, playerWeightSum, playerMoneySumNonTransient = 0, 0 ,0
    -- helper for distance calculation
    table.clear(vehToLocationDistanceCache)
    -- to see if the player can load different types of cargo
    local hasContainersOfCargoType = {}

    -- handle each container individually
    for _, con in ipairs(playerCargoContainers) do
      local entry = {
        vehId = con.vehId,
        name = con.name,
        moveToLabel = con.moveToLabel,
        cargoTypesLookup = con.cargoTypesLookup,
        cargoTypesString = con.cargoTypesString,
        totalCargoSlots = con.totalCargoSlots,
        usedCargoSlots = con.usedCargoSlots,
        freeCargoSlots = con.freeCargoSlots,
        transientCargoSlots = con.transientCargoSlots,
        cargo = clusterFormatCargo(con.rawCargo, nil),
        weight = 0,
        taskList = {},
      }
      for _, formatted in ipairs(entry.cargo) do
        formatted.nextTasks = {{label="Bring to " .. formatted.destinationName, checked = false}}
        formatted.taskList = {"Deliver to " .. formatted.destinationName}
      end

      for _, formatted in ipairs(clusterFormatCargo(con.transientCargo)) do
        formatted.transientMove = true
        formatted.nextTasks = { }
        if facPsLocation and dParcelManager.sameLocation(formatted.location, facPsLocation) then
          formatted.nextTasks[1] = {label="Loading here", checked = true}
          formatted.taskList = {"Deliver to " .. formatted.destinationName}
        else
          formatted.nextTasks[1] = {label="Load at " .. formatted.locationNameLong, checked = false}
          formatted.taskList = {"Pick up at " .. formatted.locationNameLong}
        end
        formatted.nextTasks[2] = {label="Bring to " .. formatted.destinationNameLong, checked = false}

        table.insert(entry.cargo, formatted)
      end
      -- player can load the cargo of this containers cargo type
      hasContainersOfCargoType[con.cargoTypesString] = true

      -- go through each item in this container
      for _, cargo in ipairs(entry.cargo) do
        -- enable systems for this type, even if the facilitiy does not offer it
        if cargo.type == "parcel" then
          uiData.availableSystems.parcelDelivery = true
        end
        if cargo.type == "fluid" then
          uiData.availableSystems.smallFluidDelivery = true
        end
        if cargo.type == "dryBulk" then
          uiData.availableSystems.smallDryBulk = true
        end

        -- add money and weight to sums
        playerMoneySum = playerMoneySum + #cargo.ids * cargo.rewardMoney
        entry.weight = entry.weight + cargo.weight * #cargo.ids


        -- calculate how far is is to this cargos destintaion (using cache)
        if cargo.destination.type == "facilityParkingspot" then
          local distanceKey = string.format("%d-%s-%s", con.vehId, cargo.destination.facId, cargo.destination.psPath)
          if vehToLocationDistanceCache[distanceKey] == nil then
            vehToLocationDistanceCache[distanceKey] = false
            local a, b = dGenerator.getLocationCoordinates(cargo.location), dGenerator.getLocationCoordinates(cargo.destination)
            if a and b then
              vehToLocationDistanceCache[distanceKey] = dGenerator.distanceBetween(a,b)
            end
          end
          cargo.distance = vehToLocationDistanceCache[distanceKey] or nil
        end

        -- figure out where this cargo item can be moved to
        cargo.targetLocations = {}
        -- check other conatiners if it can go there
        for _, otherCon in ipairs(playerCargoContainers) do
          --if cargo is fluid or materials, can only go in other containers with the same fluid/materials
          local isMixable = dGenerator.isMixable(cargo.materialType)
          local validTarget = true
          if not isMixable then
            local materialType = cargo.materialType
            for _, otherCargo in ipairs(otherCon.rawCargo) do
              validTarget = validTarget and otherCargo.materialType == cargo.materialType
            end
          end

          if validTarget and otherCon.cargoTypesLookup[cargo.type] then
            local loc = {
              label = otherCon.moveToLabel,
              location = otherCon.location,
              enabled = otherCon.freeCargoSlots >= cargo.slots,
              maxAmount = math.min(math.floor(otherCon.freeCargoSlots / cargo.slots), #cargo.ids),
              containerVehicleInfo = {
                vehId = con.vehId,
                vehName = con.vehName,
                conName = con.name,
              },
              usedCargoSlots = otherCon.usedCargoSlots,
              totalCargoSlots = otherCon.totalCargoSlots,
              selectedAmount = 0,
            }
            if con.containerId == otherCon.containerId then
              loc.maxAmount = #cargo.ids
              loc.usedCargoSlots = loc.usedCargoSlots - cargo.slots * #cargo.ids
              loc.selectedAmount = #cargo.ids
            end
            if loc.maxAmount > 0 then
              table.insert(cargo.targetLocations, loc)
            end
          end
        end
        if not cargo.transientMove then
          cargo.throwAwayInfo = {
            penalty = cargo.rewardMoney * dGeneral.getDeliveryAbandonPenaltyFactor(),
            location = {type="deleted"},
          }
        end
        --[[ previously loaded items can also be "thrown away"
        table.insert(cargo.targetLocations, {label = "Throw Away", location = {type="deleted"}, enabled = true, icon="trashBin1", extraData = {}})]]

      end

      -- add up the total player weight
      playerWeightSum = playerWeightSum + entry.weight

      -- add a "vehicle" entry for this container is there is none. containers are grouped by vehicle in ui
      if not uiData.player.vehicles[entry.vehId] then
        uiData.player.vehicles[entry.vehId] = { containers = {}, niceName = dGeneral.getVehicleName(entry.vehId), vehId = entry.vehId, hasContainersOfCargoType = {}}
      end
      uiData.player.vehicles[entry.vehId].hasContainersOfCargoType[con.cargoTypesString] = true
      table.insert(uiData.player.vehicles[entry.vehId].containers, entry)

      if not dGenerator.isMixable(con.cargoTypesString) then
        formatContainerAsStorage(con)
      end

    end

    -- set player fields
    uiData.player.loadedCargoMoneySum = playerMoneySum
    uiData.player.penaltyForAbandon = dGeneral.getDeliveryModePenalty()
    uiData.player.weightSum = playerWeightSum
    uiData.player.noContainers = not next(playerCargoContainers)
    uiData.player.hasContainersOfCargoType = hasContainersOfCargoType


    -- convert vehicles table to list for UI
    local vehicleInfoList = {}
    for vehId, vehicleInfo in pairs(uiData.player.vehicles) do
      --table.sort(vehicleInfo.containers, function(a,b) return a.name < b.name end)
      table.insert(vehicleInfoList, vehicleInfo)
    end
    table.sort(vehicleInfoList, function(a,b) return a.vehId < b.vehId end)
    uiData.player.vehicles = vehicleInfoList

    -- add the accepted offers (ie spawned delivery vehicles) too
    uiData.player.acceptedOffers = getAcceptedVehicleOffers()
    for _, offer in ipairs(uiData.player.acceptedOffers) do
      if offer.type == "vehicle" then
        uiData.availableSystems.vehicleDelivery = true
      end
      if offer.type == "trailer" then
        uiData.availableSystems.trailerDelivery = true
      end
    end

    uiData.cardsById = cardsById
    uiData.filterSets = career_modules_delivery_cargoCards.resetFilterCounters()

    uiData.sortingSets = career_modules_delivery_cargoCards.getCardSortingSetsByKey(cardsById)
    uiData.facilityCardGroupSets = career_modules_delivery_cargoCards.getCardGroupSetsByKey(cardsById, false)
    uiData.playerCardGroupSets = career_modules_delivery_cargoCards.getCardGroupSetsByKey(cardsById, true, playerCargoContainers)

    career_modules_delivery_cargoCards.addSortingValuesToGroups(cardsById, uiData.facilityCardGroupSets)
    career_modules_delivery_cargoCards.addSortingValuesToGroups(cardsById, uiData.playerCardGroupSets)

    uiData.filterSets = career_modules_delivery_cargoCards.getFilterSets(cardsById)

    career_modules_delivery_cargoCards.addFilterPlayerData(uiData.filterSets, uiData.playerCardGroupSets, playerCargoContainers)

    uiData.confirmButtonInfo = career_modules_delivery_cargoCards.getConfirmButtonFromPlayerCards(uiData.cardsById)


    M.setVisibleIdsForBigMap()
    M.setCargoScreenTab(cargoOverviewTab)
    --freeroam_bigMapMode.setOnlyIdsVisible({})
    

    --dumpz(uiData.playerCardGroupSets)
    -- notify UI
    guihooks.trigger("cargoDataForUiReady", uiData)
    M.highlightCargoInPoi(freeroam_bigMapMode.selectedPoiId)
  end)
end
-- update for the screen
local function onCargoGenerated(cargo)
  if not cargoOverviewScreenOpen then return end
  if sentNewCargoNotificationAlready then return end
  if not cargoScreenFacId then return end
  if cargo.origin.facId ~= cargoScreenFacId then return end
  if cargoScreenPsPath and cargo.origin.psPath ~= cargoScreenPsPath then return end
  sentNewCargoNotificationAlready = true
  guihooks.trigger("newCargoAvailable")
end

M.requestCargoDataForUi = requestCargoDataForUi
M.onCargoGenerated = onCargoGenerated

-------------------------------------------
-- Loading and Unloading Cargo functions --
-------------------------------------------

-- call this function to move the cargo to a different location. if moved to the player, a transient flag will be added. if moved back to facility, transient flag will be removed.
local function moveCargoFromUi(cargoId, targetLocation)
  --dParcelManager.changeCargoLocation(cargoId, targetLocation, true)
  dParcelManager.addTransientMoveCargo(cargoId, targetLocation)
  --[[
  for poiId, list in pairs(visibleBigMapIdsToCardIds) do
    for _, cargo in ipairs(list) do
      --dump(cargoId, cargo.id)
      if cargo.id == cargoId then
        --dump(poiId)
        --dump(freeroam_bigMapMode.navigateToMission(poiId))
        return
      end
    end
  end
  ]]
end
M.applyTransientMoves = function()
  dParcelManager.applyTransientMoves()
end


-- offer spawning is handled in vehOffermanager
M.spawnOffer = function(...) return dVehOfferManager.spawnOffer(...) end

local function toggleOfferForSpawning(offerId)
  local offer = dVehOfferManager.getOfferById(offerId)
  offer.spawnWhenCommitingCargo = not offer.spawnWhenCommitingCargo
end
M.toggleOfferForSpawning = toggleOfferForSpawning





M.moveCargoFromUi = moveCargoFromUi


-------------------------------------------
-- Entering and Exiting the Cargo Screen --
-------------------------------------------

-- called by activity accept or from the career menu to enter the cargo screen.
local function enterCargoOverviewScreen(facilityId, parkingSpotPath)
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)
    cargoOverviewScreenOpen = true
    cargoOverviewTab = ""
    cargoScreenFacId, cargoScreenPsPath = facilityId, parkingSpotPath
    cargoOverviewScreenOpenedTime = dGeneral.time() - pastDeliveryTimespan
    cargoOverviewMaxTimeTimestamp = dGeneral.time()

    gameplay_rawPois.clear()

    local options = {
      instant = true,
      cameraAdditionalHeightFactor = 0.65,
      horizontalOffsetFactor = 0,
      verticalOffsetFactor = 5,
      navigationBoundariesFactor = 1.5
    }
    freeroam_bigMapMode.enterBigMapWithCustomPOIs({}, M.deliveryMarkerSelected, options)
    if facilityId == nil and parkingSpotPath == nil then
      guihooks.trigger('ChangeState', {state = 'cargoOverview', params = {}})
    else
      guihooks.trigger('ChangeState', {state = 'cargoOverview', params = {facilityId = facilityId, parkingSpotPath = parkingSpotPath}})
    end
    extensions.hook("onEnterCargoOverviewScreen")
  end)
end
local function enterMyCargo() enterCargoOverviewScreen() end
M.enterMyCargo = enterMyCargo

-- called whenever the cargo screen is closed for any reason.
local function exitCargoOverviewScreen(facilityId, parkingSpotPath)
  cargoOverviewScreenOpen = false
  gameplay_rawPois.clear()
  --career_career.closeAllMenus()
  freeroam_bigMapMode.exitBigMap(true)
  simTimeAuthority.pause(false) -- this is only necessary because the career pause menu doesnt unpause in time for the bigMap to start, so the bigMap will not unpause by itself
  dGeneral.requestUpdateContainerWeights()
  dGeneral.checkExitDeliveryMode()
end

-- call this function to commit the configuration and clear all transient flags.
local function commitDeliveryConfiguration()
  local playerCargo = dParcelManager.getAllCargoInVehicles()
  local transientCargo = dParcelManager.getTransientMoveCargo()
  local countTotal, countTransient, countDeleted, deletedMoneySum = 0,0,0,0

  local movedCargo, remainingCargo = dParcelManager.applyTransientMoves({type="facilityParkingspot",facId=cargoScreenFacId, psPath=cargoScreenPsPath})


  log("I","",string.format("Commited Delivery Configuration. (Cargo Added: %d. Remaining to be loaded: %d)",#movedCargo, #remainingCargo))

  -- TODO: cleanup throwing away
  --[[if countDeleted > 1 then

    ui_message(string.format("Thrown away %d items. Penalty: %0.2f", countDeleted, deletedMoneySum * dGeneral.getDeliveryAbandonPenaltyFactor()))
    career_modules_playerAttributes.addAttributes({money=-deletedMoneySum  * dGeneral.getDeliveryAbandonPenaltyFactor()}, {tags={"delivery","gameplay","fine"}, label="Penalty for throwing away cargo."})
  end]]

  if not career_modules_delivery_general.isDeliveryModeActive() and (#movedCargo > 0 or #remainingCargo > 0) then
    dGeneral.startDeliveryMode()
  end
  dGeneral.requestUpdateContainerWeights()

  local doSpawning = function()
    local vehOffers = dVehOfferManager.getAllOfferUnexpired()
    for _, offer in ipairs(vehOffers) do
      if offer.spawnWhenCommitingCargo and offer.origin.facId == cargoScreenFacId then
        offer.spawnWhenCommitingCargo = nil
        dVehOfferManager.spawnOffer(offer.id)
      end
    end
    career_modules_loanerVehicles.spawnAllOffers()

  end
  dGeneral.updateContainerWeights(
    function(data)
      print(data)
      local maxDelay = 0
      for _, delay in pairs(data) do
        maxDelay = math.max(delay, maxDelay)
      end
      if maxDelay > 0 then
        maxDelay = math.max(maxDelay, 1)
        -- make
        local sequence = {
          step.makeStepWait(maxDelay+0.5),
          step.makeStepReturnTrueFunction(function()
            for vehId, data in pairs(data) do
              local veh = scenetree.findObjectById(vehId)
              core_vehicleBridge.executeAction(veh, 'setFreeze', false)
            end
            gameplay_markerInteraction.setForceReevaluateOpenPrompt()
          return true
          end
          ),
          step.makeStepReturnTrueFunction(function()
            doSpawning()
            return true
          end
          )
        }
        step.startStepSequence(sequence, callback)
        -- add loading progress bar
        guihooks.trigger("OpenSimpleDelayPopup",{timer=maxDelay, heading="Loading Cargo..."})
      else
        -- no delay, no freeze
        for vehId, data in pairs(data) do
          local veh = scenetree.findObjectById(vehId)
          core_vehicleBridge.executeAction(veh, 'setFreeze', false)
        end
        doSpawning()
        gameplay_markerInteraction.setForceReevaluateOpenPrompt()
      end
      log("I","",string.format("%0.2fs delay after adjusting weights for cargo.", maxDelay))
    end
    )
end

-- call this function to cancel the delivery - all cargo will be placed back.
local function cancelDeliveryConfiguration()
  dParcelManager.clearAllTransientMoves()
  for _, offer in ipairs(dVehOfferManager.getAllOfferCustomFilter(function() return true end)) do
    offer.spawnWhenCommitingCargo = nil
  end
  career_modules_loanerVehicles.unmarkAllForSpawning()
  dGeneral.getNearbyVehicleCargoContainers(nop)
  ui_message("Cancelled Delivery Configuration.")
end

M.enterCargoOverviewScreen = enterCargoOverviewScreen
M.exitCargoOverviewScreen = exitCargoOverviewScreen
M.commitDeliveryConfiguration = commitDeliveryConfiguration
M.cancelDeliveryConfiguration = cancelDeliveryConfiguration


--------------------------------------
-- Route Planning and route display --
--------------------------------------

local routePlanner = require('gameplay/route/route')()
local function getDistanceBetweenPoints(pos1, pos2)
  routePlanner:setupPath(pos1, pos2)
  return routePlanner.path[1].distToTarget
end

local function getClosestNeighbor(sourceId, targetsById, result, onlyClosestTarget)
  local minDist = math.huge
  local minDistTarget
  targetsById[sourceId] = nil
  for otherFacId, targetData in pairs(targetsById) do
    local dist = targetData.distances[sourceId]
    if dist < minDist then
      minDistTarget = targetData
      minDist = dist
    end
  end
  table.insert(result, minDistTarget.pos)
  if tableSize(targetsById) <= 1 or onlyClosestTarget then return end
  getClosestNeighbor(minDistTarget.id, targetsById, result)
end

local function setBestRoute(onlyClosestTarget)
  local allCargo = career_modules_delivery_parcelManager.getAllCargoInVehicles(true)
  if tableIsEmpty(allCargo) then
    core_groundMarkers.setPath(nil)
    freeroam_bigMapMode.resetRoute()
    return
  end

  local targetsById = {player = {distances = {}}}
  local hasTargetableCargo = false
  for _, cargo in ipairs(allCargo) do
    local target
    if (M.isCargoScreenOpen() and cargo.location.facId == cargoScreenFacId) or not cargo._transientMove then
      target = cargo.destination
    else
      target = cargo.location
    end
    --print(cargo.name .. " -> ")
    --dump(target)
    if target.type == "facilityParkingspot" then
      local targetId = string.format("%s-%s", target.facId, target.psPath)
      hasTargetableCargo = true
      if not targetsById[targetId] then
        local targetData = {pos = dGenerator.getParkingSpotByPath(target.psPath).pos, location = target, id = targetId}
        local distToPlayer = getDistanceBetweenPoints(getPlayerVehicle(0):getPosition(), targetData.pos)
        targetData.distances = {player = distToPlayer}
        targetsById.player.distances[targetId] = distToPlayer
        targetsById[targetId] = targetData
      end
    elseif target.type == "multi" then
      -- pick the best out of the possible locations...
      -- which is simply the one which has the most

    end
  end
  if not hasTargetableCargo then
    core_groundMarkers.setPath(nil)
    freeroam_bigMapMode.resetRoute()
    return
  end

  for tgtId1, targetData1 in pairs(targetsById) do
    for tgtId2, targetData2 in pairs(targetsById) do
      if tgtId1 ~= tgtId2 and tgtId1 ~= "player" and tgtId2 ~= "player" then
        targetData1.distances[tgtId2] = dGenerator.getDistanceBetweenFacilities(targetData1.location, targetData2.location)
      end
    end
  end

  local result = {}
  getClosestNeighbor("player", deepcopy(targetsById), result, onlyClosestTarget)
  core_groundMarkers.setPath(result, {clearPathOnReachingTarget = false})
  freeroam_bigMapMode.resetRoute()
end

-- recalculate route after closing the popup with the rewards
local function onDeliveryRewardsPopupClosed()
  -- recalculate the best route after delivering, because sometimes the the waypoint at the delivery spot doesnt count as "reached" for the groundmarkers and so it will keep pointing to it
  if career_modules_delivery_general.getSettings().automaticRoute then
    setBestRoute(true)
  end

  -- tell player they can take a taxi back, and show one-time
  -- 0.5 s delayed
  local sequence = {
    step.makeStepWait(0.5),
    step.makeStepReturnTrueFunction(function()
      career_modules_linearTutorial.introPopup("delivery/cargoDelivered")
      if gameplay_walk.isWalking() then
        ui_message("Press [action=reset_physics] to open the recovery menu to take a taxi.",6,"post_delivery","local_taxi")
        career_modules_linearTutorial.introPopup("delivery/postDeliveryTaxi")
      end
      return true
  end)}
  step.startStepSequence(sequence)
end

local function onCargoPickedUp()
  -- recalculate the best route after delivering, because sometimes the the waypoint at the delivery spot doesnt count as "reached" for the groundmarkers and so it will keep pointing to it
  if career_modules_delivery_general.getSettings().automaticRoute then
    setBestRoute(true)
  end
end


-- Show the full route in bigMap
local function onActivateBigMapCallback()
  if career_modules_delivery_general.isDeliveryModeActive() and career_modules_delivery_general.getSettings().automaticRoute then
    setBestRoute()
  end
end

-- Show only the route up until the first destination in gameplay
local function onDeactivateBigMapCallback()
  if career_modules_delivery_general.isDeliveryModeActive() and career_modules_delivery_general.getSettings().automaticRoute then
    setBestRoute(true)
  end
end

M.setBestRoute = setBestRoute
M.onCargoPickedUp = onCargoPickedUp
M.onDeliveryRewardsPopupClosed = onDeliveryRewardsPopupClosed
M.onActivateBigMapCallback = onActivateBigMapCallback
M.onDeactivateBigMapCallback = onDeactivateBigMapCallback


---------------------------------------------------
-- clicking/hovering markers on the cargo screen --
---------------------------------------------------

-- highlight entries in list
local function highlightCargoInPoi(poiId)
  if not visibleBigMapIdsToCardIds[poiId] or not poiId then
    guihooks.trigger("sendHighlightedCardIds", {})
    return
  end
  local cardIds = {}
  for _, id in ipairs(freeroam_bigMapMarkers.getIdsFromHoveredPoiId(poiId)) do
    local elem = visibleBigMapIdsToCardIds[id]
    if elem then
      for cardId, _ in pairs(elem.cardIds) do
        cardIds[cardId] = true
      end
    end
  end

  guihooks.trigger("sendHighlightedCardIds", cardIds)
end

-- when a marker is clicked, set route there
local function deliveryMarkerSelected(poiId)

  highlightCargoInPoi(poiId)
  if not visibleBigMapIdsToCardIds[poiId] then return end
  if not dGeneral.isAutomaticRouteEnabled() then
    freeroam_bigMapMode.navigateToMission(poiId)
  end
end
M.deliveryMarkerSelected = deliveryMarkerSelected

-- when a marker is hovered, highlight entries in list
M.onBigmapHoveredPoiIdChanged = function(poiId)
  if not cargoOverviewScreenOpen then return end
  highlightCargoInPoi(poiId or freeroam_bigMapMode.selectedPoiId)
end

-- when a parcel list entry is hovered, preview the route on bigMap

local function showRoutePreview(route)
  if not route then freeroam_bigMapMode.clearRoutePreview() return end
  if route.type == "navgraph" then
    local unsimplifiedRoute = {}
    for _, loc in ipairs(route.locations) do
      if loc.type ~= "multi" then
        local pos =  dGenerator.getLocationCoordinates(loc)
        table.insert(unsimplifiedRoute, pos)
      end
    end
    if #unsimplifiedRoute > 1 then
      local routeUtil = require('/lua/ge/extensions/gameplay/route/route')()
      routeUtil:setupPathMulti(unsimplifiedRoute)
      freeroam_bigMapMode.setRoutePreview(routeUtil.path)
    else
      freeroam_bigMapMode.clearRoutePreview()
    end
  else
    freeroam_bigMapMode.clearRoutePreview()
  end
end
M.showRoutePreview = showRoutePreview


local function showCargoRoutePreview(cargoId)
  if cargoId == nil then
    freeroam_bigMapMode.clearRoutePreview()
    return
  end
  local cargo = dParcelManager.getCargoById(cargoId)
  if not cargo then return end

  if cargo.destination.type == "multi" then
    local route = {}
    local fromPos = dGenerator.getLocationCoordinates(cargo.location)
    for _, dest in ipairs(cargo.destination.destinations) do
      local toPos = dGenerator.getLocationCoordinates(dest)
      table.insert(route, {pos = fromPos})
      table.insert(route, {pos = toPos})
    end
    freeroam_bigMapMode.setRoutePreview(route)
  else
    local fromPos = dGenerator.getLocationCoordinates(cargo.location)
    local toPos = dGenerator.getLocationCoordinates(cargo.destination)
    if fromPos and toPos then
      freeroam_bigMapMode.setRoutePreviewSimple(fromPos, toPos)
    end
  end
end

-- when a vehicle offer list entry is hovered, preview route on bigMap
local function showVehicleOfferRoutePreview(offerId)
  if offerId == nil then
    freeroam_bigMapMode.clearRoutePreview()
    return
  end
  local offer = dVehOfferManager.getOfferById(offerId)
  if not offer then return end
  local fromPos = dGenerator.getLocationCoordinates(offer.locations[1])
  local toPos = dGenerator.getLocationCoordinates(offer.locations[2])
  if fromPos and toPos then
    freeroam_bigMapMode.setRoutePreviewSimple(fromPos, toPos)
  end
end

-- when a parcel list entry is hovered, preview the route on bigMap
local function showLocationRoutePreview(locationId, asProvider)
  if locationId == nil then
    freeroam_bigMapMode.clearRoutePreview()
    return
  end
  local fromPos = dGenerator.getLocationCoordinates({type="facilityParkingspot",facId = cargoScreenFacId, psPath = cargoScreenPsPath})
  local fac = dGenerator.getFacilityById(locationId)
  local toPos = dGenerator.getLocationCoordinates({type="facilityParkingspot", facId = fac.id, psPath=(asProvider and fac.pickUpSpots[1] or fac.dropOffSpots[1]):getPath()})
  if fromPos and toPos then
    freeroam_bigMapMode.setRoutePreviewSimple(fromPos, toPos)
  end
end
M.showLocationRoutePreview = showLocationRoutePreview

-- when a cargo list element ist clicked, set the bigMap route there
local function setCargoRoute(cargoId, origin)
  if cargoId == nil then
    return
  end
  local cargo = dParcelManager.getCargoById(cargoId)
  if not cargo then return end
  local toPos = dGenerator.getLocationCoordinates(origin and cargo.origin or cargo.destination)
  if toPos then
    freeroam_bigMapMode.setNavFocus(toPos)
  end
end

--by default, all cargo locations are active as bigMap markers. this function sets it so, that only the relevant markers are actually visible.
-- relevant markers include: destination of loaded and available cargo, vehicle offers
local tabNameToType = { vehicles = "vehicle", trailers = "trailer", parcels = "parcel", smallFluids="fluid", smallDryBulk="dryBulk", largeFluids="fluid", largeDryBulk="dryBulk" }
local function setVisibleIdsForBigMap()
  visibleBigMapIdsToCardIds = {}
  for cardId, card in pairs(cardsById) do
    --print("Card Id: " .. cardId)
    for bigMapId, _ in pairs(card.bigMapIds or {}) do
      --print("  -> " ..bigMapId)
      visibleBigMapIdsToCardIds[bigMapId] = visibleBigMapIdsToCardIds[bigMapId] or {cardIds = {}}
      visibleBigMapIdsToCardIds[bigMapId].cardIds[cardId] = true
    end
  end
end

M.showCargoRoutePreview = showCargoRoutePreview
M.showVehicleOfferRoutePreview = showVehicleOfferRoutePreview
M.highlightCargoInPoi = highlightCargoInPoi
M.setCargoRoute = setCargoRoute
M.setVisibleIdsForBigMap = setVisibleIdsForBigMap


-- other/utility functions
M.exitDeliveryMode = function() dGeneral.exitDeliveryMode() end
M.showCargoContainerHelpPopup = function()
  career_modules_linearTutorial.introPopup("cargoContainerHowTo", true)
end
M.unloadCargoPopupClosed = function() dProgress.unloadCargoPopupClosed() end
M.requestDropOffData = function(...) dProgress.requestDropOffData(...) end
M.confirmDropOffData = function(...) dProgress.confirmDropOffData(...) end
M.clearTransientMoveForCargo = function(...) dParcelManager.clearTransientMoveForCargo(...) end

M.dropOffPopupClosed = function(mode)
  if mode == "results" then
    extensions.hook("onDeliveryRewardsPopupClosed")
  end
  if mode == "cargoSelection" then
    extensions.hook("onDeliveryDropOffCargoSelectionPopupClosed")
  end
end

return M