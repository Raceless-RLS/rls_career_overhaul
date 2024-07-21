-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {"core_vehicleBridge"}

local dParcelManager, dCargoScreen, dGeneral, dGenerator, dPages, dProgress, dVehOfferManager, dParcelMods, dVehicleTasks
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dPages = career_modules_delivery_pages
  dProgress = career_modules_delivery_progress
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
  dParcelMods = career_modules_delivery_parcelMods
  dVehicleTasks = career_modules_delivery_vehicleTasks
end

local cargoOverviewScreenOpen = false
local cargoOverviewTab = ""
local visibleIdsToCargo = {}
M.isCargoScreenOpen = function() return cargoOverviewScreenOpen end
M.setCargoScreenTab = function(tab)
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)
    cargoOverviewTab = string.lower(tab)
    M.setVisibleIdsForBigMap(playerCargoContainers)
    freeroam_bigMapMode.setOnlyIdsVisible(tableKeys(visibleIdsToCargo))
    gameplay_rawPois.clear()
    freeroam_bigMapMarkers.clearMarkers()
  end)
end
M.getCargoScreenTab = function() return cargoOverviewTab end
local cargoScreenFacId, cargoScreenPsPath = nil, nil
local cargoOverviewScreenOpenedTime = -1
local cargoOverviewMaxTimeTimestamp = -1
local sentNewCargoNotificationAlready = false
-- how far back in time items should be shown
local pastDeliveryTimespan = 60

-- cargo filter helpers
local function itemsAtFacilityFilter(cargo, facId)
  return cargo.location.facId == facId
    and cargo.offerExpiresAt > cargoOverviewScreenOpenedTime
    and cargo.generatedAtTimestamp <= cargoOverviewMaxTimeTimestamp
end



local function formatCargoGroup(group, playerCargoContainers, longLabel, showFirstSeen)
  longLabel = true
  local labelFunction = dParcelManager.getLocationLabelShort--longLabel and dParcelManager.getLocationLabelLong or dParcelManager.getLocationLabelShort

  local ret = {
    ids = {}, -- implicit count of included objects in this group
    name = group[1].name,
    originName = labelFunction(group[1].origin),
    locationName = labelFunction(group[1].location),
    destinationName = labelFunction(group[1].destination),
    origin = group[1].origin,
    location = group[1].location,
    destination = group[1].destination,
    type = group[1].type,
    slots = 0,
    distance = group[1].data.originalDistance, -- m
    rewards = {},
    enabled = true, -- not needed in player view
    disableReason = "No space", -- not needed in player view
    targetLocations = {},
    transient = group[1].transient or false,
    _preTransientLocation = group[1]._preTransientLocation or nil,
    remainingOfferTime = group[1].offerExpiresAt - (dGeneral.time()),
    remainingDeliveryTime = math.random()*360,
    weight = group[1].weight,
    --firstSeen = group[1].firstSeen,
    modifiers = {}
  }
  if showFirstSeen then
    if group[1].firstSeen and (dGeneral.time() - group[1].firstSeen) < 3 then
      ret.showNewTimer = 3 - (dGeneral.time() - group[1].firstSeen)
    end
  end
  --ret.name = ret.name .. (group[1].firstSeen and group[1].firstSeen or "not seen")
  local modifierKeys = {}
  for _, v in ipairs(group[1].modifiers) do
    local mod = {}
    mod.type = v.type
    modifierKeys[v.type] = true
    if v.type == "timed" then
      mod.data = {
        active = group[1].location.type == "vehicle" and not group[1].transient,
        deliveryTime = v.deliveryTime,
        paddingTime = v.paddingTime,
        remainingDeliveryTime = v.expirationTimeStamp and (v.expirationTimeStamp - dGeneral.time()) or v.deliveryTime,
        paddedRemainingDeliveryTime = v.definitiveExpirationTimeStamp and (v.definitiveExpirationTimeStamp - dGeneral.time()) or v.deliveryTime + v.paddingTime,
      }
      mod.data.remainingPaddingTime = mod.data.remainingDeliveryTime > 0 and mod.data.paddingTime or mod.data.paddedRemainingDeliveryTime

    elseif v.type == "fragile" then
      mod.data = {
        active = group[1].location.type == "vehicle" and group[1].transient,
        health = v.health,
        currentHealth = v.currentHealth,
        label = "Fragile: " .. v.currentHealth,
      }
    end
    table.insert(ret.modifiers, mod)
  end


  ret.rewards = group[1].rewards
  ret.slots = group[1].slots

  if #group == 1 then
    ret.ids = {group[1].id}
  else
    for _, cargo in ipairs(group) do
      table.insert(ret.ids, cargo.id)
      --ret.slots = ret.slots + cargo.slots
      --for key, value in pairs(cargo.rewards) do
      --  ret.rewards[key] = (ret.rewards[key] or 0) + value
      --end
    end
  end

  if playerCargoContainers then
    -- Only add the container with the least free cargo space
    table.sort(playerCargoContainers, function(a,b) return a.freeCargoSlots < b.freeCargoSlots end)
    for _, con in ipairs(playerCargoContainers) do
      local elem = {
        enabled = con.freeCargoSlots >= group[1].slots and con.cargoTypesLookup[group[1].type] and ret.remainingOfferTime > 0,
        label = con.moveToLabel,
        location = con.location
      }
      if elem.enabled then
        elem.disableReason = (not elem.enabled) and "No space a"
        table.insert(ret.targetLocations, elem)
        break
      end
    end
  end
  if not next(ret.targetLocations) then
    ret.enabled = false
    ret.disableReason = "No Space"
  end
  local lockedBecauseOfMods, minTier = dParcelMods.lockedBecauseOfMods(modifierKeys)
  if lockedBecauseOfMods then
    ret.enabled = false
    ret.locked = true
    ret.disableReason = "Locked (Lvl "..minTier..")"
    ret.lockedReason = {icon = "boxPickUp03", level = minTier}
  end

  ret.id = ret.ids[#ret.ids]
  --dump(ret)
  return ret
end

local lowestIdSort = function(a,b) return a.ids[1] < b.ids[1] end
local function clusterFormatCargo(cargo, playerCargoContainers, longLabel, updateFirstSeen)
  local ret = {}
  --cargo can only be clustered if their groupId is the same and transient is the same
  --current location also needs to be the same, but that is guaranteed by the caller of this function
  local cargoByGroupId = {}
  for _, c in ipairs(cargo) do
    local gId = string.format("%d-%s-%d", c.groupId, c.transient or false, c.loadedAtTimeStamp or -1)
    cargoByGroupId[gId] = cargoByGroupId[gId] or {}
    dGenerator.finalizeParcelItemDistanceAndRewards(c)
    if updateFirstSeen then
      c.firstSeen = c.firstSeen or dGeneral.time()
    end
    table.insert(cargoByGroupId[gId], c)
  end
  -- format each group individually
  for _, group in pairs(cargoByGroupId) do
    table.insert(ret, formatCargoGroup(group, playerCargoContainers, longLabel, updateFirstSeen))
  end
  table.sort(ret, lowestIdSort)
  return ret
end

local routePlanner = require('gameplay/route/route')()
local function getDistanceBetweenPoints(pos1, pos2)
  routePlanner:setupPath(pos1, pos2)
  return routePlanner.path[1].distToTarget
end

local function getClosestNeighbor(facId, allNodesDict, result)
  local minDist = math.huge
  local minDistFacility
  allNodesDict[facId] = nil
  for otherFacId, facilityData in pairs(allNodesDict) do
    local dist = facilityData.distances[facId]
    if dist < minDist then
      minDistFacility = facilityData
      minDist = dist
    end
  end
  table.insert(result, minDistFacility.pos)
  if tableSize(allNodesDict) <= 1 then return end
  getClosestNeighbor(minDistFacility.facility.facId, allNodesDict, result)
end

local function setBestRoute()
  local allCargo = career_modules_delivery_parcelManager.getAllCargoInVehicles()
  if tableIsEmpty(allCargo) then return end

  local allNodesDict = {player = {distances = {}}}

  for _, cargo in ipairs(allCargo) do
    if not allNodesDict[cargo.destination.facId] then
      local facilityData = {pos = dGenerator.getParkingSpotByPath(cargo.destination.psPath).pos, facility = cargo.destination}
      local distToPlayer = getDistanceBetweenPoints(getPlayerVehicle(0):getPosition(), facilityData.pos)
      facilityData.distances = {player = distToPlayer}
      allNodesDict.player.distances[cargo.destination.facId] = distToPlayer
      allNodesDict[cargo.destination.facId] = facilityData
    end
  end

  for facId1, facilityData1 in pairs(allNodesDict) do
    for facId2, facilityData2 in pairs(allNodesDict) do
      if facId1 ~= facId2 and facId1 ~= "player" and facId2 ~= "player" then
        facilityData1.distances[facId2] = dGenerator.getDistanceBetweenFacilities(facilityData1.facility, facilityData2.facility)
      end
    end
  end

  local result = {}
  getClosestNeighbor("player", deepcopy(allNodesDict), result)
  core_groundMarkers.setFocus(result)
  freeroam_bigMapMode.resetRoute()
end

local function onCargoDelivered()
  -- recalculate the best route after delivering, because sometimes the the waypoint at the delivery spot doesnt count as "reached" for the groundmarkers and so it will keep pointing to it
  if core_groundMarkers.currentlyHasTarget() then
    if tableSize(core_groundMarkers.endWP) > 1 then
      setBestRoute()
    end
  end
end


local function getVehicleThumb(vehicle)
  local model = core_vehicles.getModel(vehicle.model)
  if not model then return nil end
  local config = model.configs[vehicle.config]
  if not config then return nil end
  return config.preview
end

local function formatVehicleOfferForUi(offers, typeUnlocked)
  local ret = {}
  for _, offer in ipairs(offers) do
    dGenerator.finalizeVehicleOffer(offer)
    local item = {
      id = offer.id,
      name = offer.name,
      vehName = offer.vehicle.name,
      vehBrand = offer.vehicle.brand,
      vehMileage = offer.vehicle.mileage,
      task = dVehOfferManager.makeTaskLabel(offer.task),
      thumbnail = getVehicleThumb(offer.vehicle) or '/ui/images/appDefault.png',
      distance = offer.data.originalDistance,
      rewards = offer.rewards,
      remainingOfferTime = offer.offerExpiresAt - (dGeneral.time()),
      connector = "ConName",
      unlockTag = offer.vehicle.filterName,

    }
    local enabled, reason = dVehOfferManager.isVehicleTagUnlocked(offer.vehicle.unlockTag)
    item.enabled = enabled
    item.disableReason = reason

    if not enabled then
      item.locked = true
      item.lockedReason = reason
      item.enabled = false
      item.disableReason = "Locked"
    end

    --if item.enabled then
    --  if next(dVehicleTasks.getVehicleTasks()) then
    --    item.enabled = false
    --    item.disableReason = "Limit reached"
    --  end
    --end
    table.insert(ret, item)
  end
  return ret
end
M.formatVehicleOfferForUi = formatVehicleOfferForUi

local function formatAcceptedOfferForUI(offer)
  return {
    id = offer.id,
    name = offer.name,
    task = dVehOfferManager.makeTaskLabel(offer.task),
    thumbnail = getVehicleThumb(offer.vehicle) or '/ui/images/appDefault.png',
    distance = offer.data.originalDistance,
    rewards = offer.rewards,
    connector = "ConName",
    type = offer.data.type,
  }
end

local function getAcceptedVehicleOffers()
  local vehicleTasks = career_modules_delivery_vehicleTasks.getVehicleTasks()
  local res = {}
  for _, taskData in ipairs(vehicleTasks) do
    local vehOffer = formatAcceptedOfferForUI(taskData.offer)
    table.insert(res, vehOffer)
  end
  return res
end

local function requestCargoDataForUi(facId, psPath, updateMaxTimeTimestamp)
  if updateMaxTimeTimestamp ~= false then
    cargoOverviewMaxTimeTimestamp = dGeneral.time()
    cargoOverviewScreenOpenedTime = cargoOverviewMaxTimeTimestamp - pastDeliveryTimespan
  end
  sentNewCargoNotificationAlready = false
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)
    M.setVisibleIdsForBigMap(playerCargoContainers)
    freeroam_bigMapMode.setOnlyIdsVisible(tableKeys(visibleIdsToCargo))
    gameplay_rawPois.clear()
    freeroam_bigMapMarkers.clearMarkers()
    freeroam_bigMapMarkers.setNextMarkersFullAlphaInstant()

    local uiData = {
      player = {
        vehicles = {},
      },
      availableSystems = {},
    }
    local facPsLocation
    if facId and facId ~= "undefined" then
      local fac = dGenerator.getFacilityById(facId)
      uiData.facility = {
        name = fac.name,
        outgoingCargo = {},
        trailerOffers = {},
        vehicleOffers = {},
      }
      uiData.availableSystems = fac.providedSystemsLookup


      local unlocked, status = dProgress.isFacilityUnlocked(facId)
      if not unlocked then
        uiData.facility.disabled = true
        uiData.facility.disabledReasonHeader = status.disabledReasonHeader
        uiData.facility.disabledReasonContent = status.disabledReasonContent
        uiData.facility.progress = status.progress
      end

      if psPath and psPath ~= "undefined" then
        local ps = dGenerator.getParkingSpotByPath(psPath)
        facPsLocation = {type = "facilityParkingspot", facId = facId, psPath = psPath}

        if fac.providedSystemsLookup.parcelDelivery then
          local outgoingCargo = dParcelManager.getAllCargoForLocationUnexpiredUndelivered(facPsLocation, cargoOverviewScreenOpenedTime, cargoOverviewMaxTimeTimestamp)

          uiData.facility.outgoingCargo = clusterFormatCargo(outgoingCargo, playerCargoContainers, nil, true)
        end

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
          uiData.facility.vehicleOffers = M.formatVehicleOfferForUi(vehs, dProgress.isVehicleDeliveryUnlocked())
        end
        if fac.providedSystemsLookup.trailerDelivery then
          uiData.facility.trailerOffers = M.formatVehicleOfferForUi(trailers, dProgress.isTrailerDeliveryUnlocked())
        end
      else
        -- facility overview, all parking spots. not used atm
        local itemsAtFacility = dParcelManager.getAllCargoCustomFilter(itemsAtFacilityFilter, facId)
        --dumpz(itemsAtFacility)
        uiData.facility.outgoingCargo = clusterFormatCargo(itemsAtFacility, nil, true, true)

      end
    end
    --dumpz(nearbyVehicles, 1)
    local playerMoneySum = 0
    local playerWeightSum = 0
    local playerMoneySumNonTransient = 0
    local vehToLocationDistanceCache = {}
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
        cargo = clusterFormatCargo(con.rawCargo, nil, not (facId and facId ~= "undefined")),
        weight = 0
      }
      for _, cargo in ipairs(entry.cargo) do
        uiData.availableSystems.parcelDelivery = true

        playerMoneySum = playerMoneySum + #cargo.ids * cargo.rewards.money
        if not cargo.transient then
          playerMoneySumNonTransient = playerMoneySumNonTransient + #cargo.ids * cargo.rewards.money
        end
        cargo.targetLocations = {}
        local distanceKey = string.format("%d-%s-%s", con.vehId, cargo.destination.facId, cargo.destination.psPath)
        vehToLocationDistanceCache[distanceKey] = vehToLocationDistanceCache[distanceKey] or
          dGenerator.distanceBetween(dGenerator.getLocationCoordinates(cargo.location), dGenerator.getLocationCoordinates(cargo.destination))
        cargo.distance = vehToLocationDistanceCache[distanceKey]

        if cargo.transient then
          if cargo._preTransientLocation.type == "facilityParkingspot" and facPsLocation then
            table.insert(cargo.targetLocations, {label = "Put Back", location = facPsLocation, enabled = true})
            uiData.player.transientCargoExists = true
          end
        end
        for _, otherCon in ipairs(playerCargoContainers) do
          if con.containerId ~= otherCon.containerId then
            table.insert(cargo.targetLocations, {
              label = otherCon.moveToLabel,
              location = otherCon.location,
              enabled = (otherCon.freeCargoSlots >= cargo.slots and otherCon.cargoTypesLookup[cargo.type])
            })
          end
        end
        if not cargo.transient or (cargo.transient and cargo._preTransientLocation.type == "vehicle") then
          table.insert(cargo.targetLocations, {label = "Throw Away", location = {type="deleted"}, enabled = true, extraData = {penalty = cargo.rewards.money * dGeneral.getDeliveryAbandonPenaltyFactor()}})
        end
        if uiData.facility then
          for _, outCargo in ipairs(uiData.facility.outgoingCargo or {}) do
            if dParcelManager.sameLocation(outCargo.destination, cargo.destination) then
              outCargo.highlightDestinationName = true
            end
          end

          for _, inCargo in ipairs(uiData.facility.incomingCargo or {}) do
            if dParcelManager.sameLocation(inCargo.destination, cargo.destination) then
              inCargo.highlightOriginName = true
            end
          end
        end


        entry.weight = entry.weight + cargo.weight * #cargo.ids
      end
      playerWeightSum = playerWeightSum + entry.weight

      if not uiData.player.vehicles[entry.vehId] then
        uiData.player.vehicles[entry.vehId] = { containers = {}, niceName = dGeneral.getVehicleName(entry.vehId), vehId = entry.vehId}
      end

      table.insert(uiData.player.vehicles[entry.vehId].containers, entry)
    end

    uiData.player.loadedCargoMoneySum = playerMoneySum
    uiData.player.penaltyForAbandon = playerMoneySumNonTransient * dGeneral.getDeliveryAbandonPenaltyFactor()
    uiData.player.weightSum = playerWeightSum
    uiData.player.noContainers = not next(playerCargoContainers)
    -- convert vehicles table to list
    local vehicleInfoList = {}
    for vehId, vehicleInfo in pairs(uiData.player.vehicles) do
      table.sort(vehicleInfo.containers, function(a,b) return a.name < b.name end)
      table.insert(vehicleInfoList, vehicleInfo)
    end
    table.sort(vehicleInfoList, function(a,b) return a.vehId < b.vehId end)
    uiData.player.vehicles = vehicleInfoList
    uiData.player.acceptedOffers = getAcceptedVehicleOffers()
    for _, offer in ipairs(uiData.player.acceptedOffers) do
      if offer.type == "vehicle" then
        uiData.availableSystems.vehicleDelivery = true
      end
      if offer.type == "trailer" then
        uiData.availableSystems.trailerDelivery = true
      end
    end
    guihooks.trigger("cargoDataForUiReady", uiData)
    M.highlightCargoInPoi(freeroam_bigMapMode.selectedPoiId)
  end)
end

-- call this function to move the cargo to a different location. if moved to the player, a transient flag will be added. if moved back to facility, transient flag will be removed.
local function moveCargoFromUi(cargoId, targetLocation)
  --dump(cargoId, targetLocation)
  dParcelManager.changeCargoLocation(cargoId, targetLocation, true)
  for poiId, list in pairs(visibleIdsToCargo) do
    for _, cargo in ipairs(list) do
      --dump(cargoId, cargo.id)
      if cargo.id == cargoId then
        --dump(poiId)
        --dump(freeroam_bigMapMode.navigateToMission(poiId))
        return
      end
    end
  end
end


-- call this function to commit the configuration and clear all transient flags.
local function commitDeliveryConfiguration()
  local playerCargo = dParcelManager.getAllCargoInVehicles()
  local countTotal, countTransient, countDeleted, deletedMoneySum = 0,0,0,0

  for _, cargo in ipairs(playerCargo) do
    countTotal = countTotal + 1
    if cargo.transient then
      if cargo.location.type ~= "deleted" then
        countTransient = countTransient + 1
      else
        countDeleted = countDeleted + 1
        deletedMoneySum = deletedMoneySum + cargo.rewards.money
      end
    end
  end
  ui_message(string.format("Commited Delivery Configuration. (Cargo Added: %d. Total Cargo Loaded: %d)",countTransient, countTotal))
  if countDeleted > 1 then
    ui_message(string.format("Thrown away %d items. Penalty: %0.2f", countDeleted, deletedMoneySum * dGeneral.getDeliveryAbandonPenaltyFactor()))
    career_modules_playerAttributes.addAttributes({money=-deletedMoneySum  * dGeneral.getDeliveryAbandonPenaltyFactor()}, {tags={"delivery","gameplay","fine"}, label="Penalty for throwing away cargo."})
  end

  if not career_modules_delivery_general.isDeliveryModeActive() and countTotal > 0 then
    dGeneral.startDeliveryMode()
  end
  dParcelManager.clearTransientFlags()
  dGeneral.updateContainerWeights()
end

-- call this function to cancel the delivery - all cargo will be placed back.mm
local function cancelDeliveryConfiguration()
  dParcelManager.undoTransientCargo()
  ui_message("Cancelled Delivery Configuration.")
end



local function highlightCargoInPoi(poiId)
  if not visibleIdsToCargo[poiId] or not poiId then
    guihooks.trigger("sendHighlightedCargoIds", {})
    return
  end
  local cargoIds = {}
  for _, id in ipairs(freeroam_bigMapMarkers.getIdsFromHoveredPoiId(poiId)) do
    for _, cargo in ipairs(visibleIdsToCargo[id]) do
      cargoIds[cargo.cargo.id] = true
    end
  end

  guihooks.trigger("sendHighlightedCargoIds", cargoIds)
end
M.highlightCargoInPoi = highlightCargoInPoi

local function deliveryMarkerSelected(poiId)
  highlightCargoInPoi(poiId)
  if not visibleIdsToCargo[poiId] then return end
  freeroam_bigMapMode.navigateToMission(poiId)
end

M.onBigmapHoveredPoiIdChanged = function(poiId)
  if not cargoOverviewScreenOpen then return end
  highlightCargoInPoi(poiId or freeroam_bigMapMode.selectedPoiId)
end

local function showCargoRoutePreview(cargoId)
  if cargoId == nil then
    freeroam_bigMapMode.clearRoutePreview()
    return
  end
  local cargo = dParcelManager.getCargoById(cargoId)
  if not cargo then return end
  local fromPos = dGenerator.getLocationCoordinates(cargo.location)
  local toPos = dGenerator.getLocationCoordinates(cargo.destination)
  if fromPos and toPos then
    freeroam_bigMapMode.setRoutePreviewSimple(fromPos, toPos)
  end
end

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

local tabNameToType = {
  vehicles = "vehicle",
  trailers = "trailer"
}
M.setVisibleIdsForBigMap = function(playerCargoContainers)
  visibleIdsToCargo = {}

  if cargoScreenFacId then
    local facility = dGenerator.getFacilityById(cargoScreenFacId)
    if cargoScreenPsPath then
      local facPsLocation = {type = "facilityParkingspot", facId = cargoScreenFacId, psPath = cargoScreenPsPath}
      local id = string.format("delivery-parking-%s-%s", facPsLocation.facId, facPsLocation.psPath)
      visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}

      -- TODO: also get all the cargo that is to be delivered to the current facility
      if M.getCargoScreenTab() == "parcels" then
        local outgoingCargo = dParcelManager.getAllCargoForLocationUnexpiredUndelivered(facPsLocation, cargoOverviewScreenOpenedTime, cargoOverviewMaxTimeTimestamp)
        for _, cargo in ipairs(outgoingCargo) do
          local id = string.format("delivery-parking-%s-%s", cargo.destination.facId, cargo.destination.psPath)
          visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
          table.insert(visibleIdsToCargo[id], {cargo = cargo, outgoing = true, loc = cargo.destination})
        end
      end

      if M.getCargoScreenTab() == "vehicles" or M.getCargoScreenTab() == "trailers" then
        local trailerOffers = dVehOfferManager.getAllOfferAtFacilityUnexpired(cargoScreenFacId, cargoScreenPsPath)
        for _, offer in ipairs(trailerOffers) do
          if offer.data.type == tabNameToType[M.getCargoScreenTab()] and offer.locations then
            for _, location in ipairs(offer.locations) do
              local id = string.format("delivery-parking-%s-%s", location.facId, location.psPath)
              visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
              table.insert(visibleIdsToCargo[id], {cargo = offer, outgoing = true})
            end
          end
        end
      end

      --[[if facility.showIncomingCargo then
        local incomingCargo = dParcelManager.getAllCargoForDestinationStillAtOriginUnexpired(facPsLocation, cargoOverviewScreenOpenedTime, cargoOverviewMaxTimeTimestamp)
        for _, cargo in ipairs(incomingCargo) do
          local id = string.format("delivery-parking-%s-%s", cargo.origin.facId, cargo.origin.psPath)
          visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
          table.insert(visibleIdsToCargo[id], {cargo = cargo, incoming = true, loc = cargo.origin})
        end
      end]]
    else
      local itemsAtFacility = dParcelManager.getAllCargoCustomFilter(itemsAtFacilityFilter, cargoScreenFacId)
      for _, cargo in ipairs(itemsAtFacility) do
        local id = string.format("delivery-parking-%s-%s", cargo.destination.facId, cargo.destination.psPath)
        visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
        table.insert(visibleIdsToCargo[id], {cargo = cargo, outgoing = true, loc = cargo.destination})
        id = string.format("delivery-parking-%s-%s", cargo.origin.facId, cargo.origin.psPath)
        visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
        table.insert(visibleIdsToCargo[id], {cargo = cargo, incoming = true, loc = cargo.destination})
      end
      for _, ps in ipairs(facility.pickUpSpots or {}) do
        local id = string.format("delivery-parking-%s-%s", cargoScreenFacId, ps:getPath())
        visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
      end
    end
  end
  for _, con in ipairs(playerCargoContainers) do
    for _, cargo in ipairs(con.rawCargo) do
      local id = string.format("delivery-parking-%s-%s", cargo.destination.facId, cargo.destination.psPath)
      visibleIdsToCargo[id] = visibleIdsToCargo[id] or {}
      table.insert(visibleIdsToCargo[id], {cargo = cargo, player = true, loc = cargo.destination} )
    end
  end
end

local function enterCargoOverviewScreen(facilityId, parkingSpotPath)
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)
    cargoOverviewScreenOpen = true
    cargoOverviewTab = "parcels"
    cargoScreenFacId, cargoScreenPsPath = facilityId, parkingSpotPath
    cargoOverviewScreenOpenedTime = dGeneral.time() - pastDeliveryTimespan
    cargoOverviewMaxTimeTimestamp = dGeneral.time()

    M.setVisibleIdsForBigMap(playerCargoContainers)


    gameplay_rawPois.clear()
    --dump(tableKeys(visibleIdsToCargo))
    freeroam_bigMapMode.enterBigmapWithCustomPOIs(tableKeys(visibleIdsToCargo), deliveryMarkerSelected, true, 2)
    guihooks.trigger('ChangeState', {state = 'cargoOverview', params = {facilityId = facilityId, parkingSpotPath = parkingSpotPath}})
    extensions.hook("onEnterCargoOverviewScreen")
  end)
end
M.enterCargoOverviewScreen = enterCargoOverviewScreen


local function exitCargoOverviewScreen(facilityId, parkingSpotPath)
  cargoOverviewScreenOpen = false
  commitDeliveryConfiguration()
  gameplay_rawPois.clear()
  career_career.closeAllMenus()
  freeroam_bigMapMode.exitBigMap(true)
  simTimeAuthority.pause(false) -- this is only necessary because the career pause menu doesnt unpause in time for the bigmap to start, so the bigmap will not unpause by itself
end

local function onCargoGenerated(cargo)
  if not cargoOverviewScreenOpen then return end
  if sentNewCargoNotificationAlready then return end
  if not cargoScreenFacId then return end
  if cargo.origin.facId ~= cargoScreenFacId then return end
  if cargoScreenPsPath and cargo.origin.psPath ~= cargoScreenPsPath then return end
  sentNewCargoNotificationAlready = true
  guihooks.trigger("newCargoAvailable")
end

M.onCargoGenerated = onCargoGenerated
M.onCargoDelivered = onCargoDelivered


M.spawnOffer = function(...) return dVehOfferManager.spawnOffer(...) end

M.requestCargoDataForUi = requestCargoDataForUi
M.moveCargoFromUi = moveCargoFromUi
M.commitDeliveryConfiguration = commitDeliveryConfiguration
M.cancelDeliveryConfiguration = cancelDeliveryConfiguration
M.exitCargoOverviewScreen = exitCargoOverviewScreen
M.setBestRoute = setBestRoute
M.exitDeliveryMode = function() dGeneral.exitDeliveryMode() end
M.showCargoContainerHelpPopup = function()
  career_modules_linearTutorial.introPopup("cargoContainerHowTo", true)
end

M.showCargoRoutePreview = showCargoRoutePreview
M.showVehicleOfferRoutePreview = showVehicleOfferRoutePreview
M.setCargoRoute = setCargoRoute
M.unloadCargoPopupClosed = function() dProgress.unloadCargoPopupClosed() end

return M