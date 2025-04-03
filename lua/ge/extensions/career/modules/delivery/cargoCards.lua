-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local dParcelManager, dCargoScreen, dGeneral, dGenerator, dProgress, dVehOfferManager, dParcelMods, dVehicleTasks
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dProgress = career_modules_delivery_progress
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
  dParcelMods = career_modules_delivery_parcelMods
  dVehicleTasks = career_modules_delivery_vehicleTasks
end

local filterTags = {
  {
    value = "parcel", label = "Parcel Delivery", icon = "cardboardBox", type="cargo",
    shortDescription = "Deliver small and large parcels all over the map.",
    noContent = "This facility does not offer parcel delivery.",
    cover = "/gameplay/branches/labourer/filterCovers/parcelCover.jpg",
    howTo = {label="How does parcel delivery work?", pages={"delivery/parcelDeliveryHelp"}},
    groupings = {"destinations","ungrouped"},
  }, {
    value = "vehicle", label = "Car Jockey", icon = "keys1", type="cargo",
    shortDescription = "Drive vehicles to repair jobs or bring them to private residences.",
    noContent = "This facility does not offer vehicles for delivery.",
    cover = "/gameplay/branches/labourer/filterCovers/vehicleCover.jpg",
    howTo = {label="How does car jockey work?", pages={"delivery/vehicleDeliveryHelp"}},
    groupings = {"destinations","ungrouped"},
  }, {
    value = "trailer", label = "Trailer Delivery", icon = "smallTrailer", type="cargo",
    shortDescription = "Tow small and large trailers to where they are needed.",
    noContent = "This facility does not have trailers for delivery.",
    cover = "/gameplay/branches/labourer/filterCovers/trailerCover.jpg",
    howTo = {label="How do I deliver trailers?", pages={"delivery/trailerDeliveryHelp"}},
    groupings = {"destinations","ungrouped"},
  }, {
    value = "material", label = "Materials Delivery", icon = "droplet", type="cargo",
    shortDescription = "Deliver large amounts of fluids and dry bulk as orders or in custom sizes.",
    noContent = "This facility does not offer materials delivery.",
    cover = "/gameplay/branches/labourer/filterCovers/materialsCover.jpg",
    howTo = {label="How do I deliver materials?", pages={"delivery/materialsDeliveryHelp"}},
    groupings = {"cargoType", "destinations","ungrouped"},
  }, {
    value = "all", label = "All Cargo", icon = "infinity", type="cargo",
    shortDescription = "Showing all cargo this facility has to offer.",
    cover = "/gameplay/branches/labourer/filterCovers/everythingCover.jpg",
    hideDetailed = true,
    groupings = {"destinations","cargoType","ungrouped"},
  }, {
    value = "loaner", label = "Loaner Vehicles", icon = "carCoins", type="other",
    shortDescription = "Loan vehicles from this organization to use for delivering other cargo.",
    noContent = "This facility does not offer loaner vehicles.",
    cover = "/gameplay/branches/labourer/filterCovers/loanerCover.jpg",
    howTo = {label="What are loaner vehicles?", pages={"delivery/loanerHelp"}},
    groupings = {"loaner", "ungrouped"},
  },
}
local filtersByKey = {}
local function resetFilterCounters()
  for _, filter in ipairs(filterTags) do
    filter.facilityCards = 0
    filter.playerCards = 0
    filtersByKey[filter.value] = filter
  end
end
local defaultSortings = {"rewardMoney", "distance", "weight", "availablilty"}

local function makeGroup(groupsByKey, key, label, meta)
  groupsByKey[key] = groupsByKey[key] or {label=label, meta=meta}
end

local function getCardGroupSetsByKey(cardsById, usePlayerCards, playerCargoContainers)
  local groupsByKey = {
    ungrouped = {label="None", meta={type="hidden"}},
    -- cargo types
    type_parcel = {label="Parcel"},
    type_fluid = {label="Fluid"},
    type_dryBulk = {label="Dry Bulk"},
    type_vehicle = {label="Vehicle"},
    type_trailer = {label="Trailer"},
    type_loaner = {label="Loaner"},
    type_loaner_vehicle = {label="Loaner Vehicle"},
    type_loaner_trailer = {label="Loaner Trailer"},

    -- destination (keys built from cards)
    destination_noDestination = {label = "Unknown Destination?"},

    type_totalStorage_parcel = {meta={type="totalStorage", usedCargoSlots = 0, totalCargoSlots = 0, icon="cardboardBox"}},
    type_totalStorage_fluid = {meta={type="totalStorage", usedCargoSlots = 0, totalCargoSlots = 0, icon="droplet"}},
    type_totalStorage_dryBulk = {meta={type="totalStorage", usedCargoSlots = 0, totalCargoSlots = 0, icon="rocks"}},
  }

  if usePlayerCards and playerCargoContainers then
    for _, con in ipairs(playerCargoContainers) do
      local icon = "cardboardBox"
      local totalGroupMeta = groupsByKey['type_totalStorage_parcel'].meta
      if con.cargoTypesLookup.fluid then
        icon = "droplet"
        totalGroupMeta = groupsByKey['type_totalStorage_fluid'].meta
      elseif con.cargoTypesLookup.dryBulk then
        icon = "rocks"
        totalGroupMeta = groupsByKey['type_totalStorage_dryBulk'].meta
      end
      totalGroupMeta.usedCargoSlots = totalGroupMeta.usedCargoSlots + con.usedCargoSlots
      totalGroupMeta.totalCargoSlots = totalGroupMeta.totalCargoSlots + con.totalCargoSlots
      totalGroupMeta.fillPercent = 0
      if totalGroupMeta.totalCargoSlots > 0 then
        totalGroupMeta.fillPercent = totalGroupMeta.usedCargoSlots / totalGroupMeta.totalCargoSlots
      end


      groupsByKey[string.format("container_%d_%d", con.vehId, con.containerId)] = {
        label = con.name,
        meta = {
          container = con,
          usedCargoSlots = con.usedCargoSlots,
          totalCargoSlots= con.totalCargoSlots,

          type = "container",
          fillPercent = con.usedCargoSlots / con.totalCargoSlots,
          icon = icon
        },
        showEmpty = true,
        filterTags = deepcopy(con.cargoTypesLookup),
      }
    end
  end

  -- build grouping data on cards
  for id, card in pairs(cardsById) do
    local groupTags = {}
    card.filterTags = card.filterTags or {}
    card.filterTags['all'] = true

    -- skip player cards and vice versa depending on usePlayerCards
    if
      (card.isPlayerCard and not usePlayerCards)
      or (card.isFacilityCard and usePlayerCards)
      or (card.isFacilityCard and card.hiddenInFacility)
       then
      goto continue
    end

    -- build filter data from card data
    groupTags['ungrouped'] = true
    --cargo type
    if card.cardType == "parcelGroup" then
      groupTags['type_'..card.type] = true
      if card.materialType then
        card.filterTags['material'] = true
      else
        card.filterTags['parcel'] = true
      end
    elseif card.cardType == "storage" then
      groupTags['type_'..card.material.type] = true
      card.filterTags['material'] = true
    elseif card.cardType == "vehicleOffer" then
      groupTags['type_'..card.vehOfferType] = true
      card.filterTags[card.vehOfferType] = true
    elseif card.cardType == "loaner" then
      groupTags['type_loaner'] = true
      groupTags['type_loaner_'..card.vehOfferType] = true
      card.filterTags['loaner'] = true
      --card.filterTags['loaner_'..card.vehOfferType] = true
    end

    if card.isPlayerCard then
      card.filterTags['myCargo'] = true
    end

    -- destinationName
    if card.destinationName then
      groupTags['destination_'..card.destinationName] = true
      makeGroup(groupsByKey, 'destination_'..card.destinationName, card.destinationName,
      { type="location", distance=card.distance })
    elseif card.cardType == "storage" then
      for _, destination in ipairs(card.locations) do
        groupTags['destination_'..destination.destinationName] = true
        makeGroup(groupsByKey, 'destination_'..destination.destinationName, destination.destinationName, { type="location", distance=destination.distance })
      end
    else
      groupTags['destination_noDestination'] = true
    end

    -- container location
    if card.isPlayerCard and card.cardType == 'parcelGroup' then
      local loc = card.location
      if card.transientMove then loc = card._transientMove.targetLocation end
      if loc.type == "vehicle" or card.transientMove  then
        groupTags[string.format("container_%d_%d", loc.vehId, loc.containerId)] = true
      end
    end

    -- tasklist grouping
    if usePlayerCards and card.isPlayerCard then
      local taskLabels = {"No Task?"}
      if card.cardType == "parcelGroup" then
        taskLabels = card.taskList
      elseif card.cardType == "vehicleOffer" then
        taskLabels = card.taskList
      end

      for _, label in ipairs(taskLabels) do
        groupTags['task_'..label] = true
        makeGroup(groupsByKey, 'task_'..label, label, { type="task" })
      end
    end

    ::continue::

    -- assign to card
    card.groupTags = groupTags

  end

  -- build group lists (new groups might have been added)
  for key, group in pairs(groupsByKey) do
    group.cardIdsUnsorted = {}
    group.meta = group.meta or {type="none"}
    group.filterTags = group.filterTags or {}
    group.filterTags['all'] = true
  end

  -- add card ids to groups
  for id, card in pairs(cardsById) do
    for groupKey, _ in pairs(card.groupTags) do
      table.insert(groupsByKey[groupKey].cardIdsUnsorted, id)
      for filterKey, _ in pairs(card.filterTags) do
        groupsByKey[groupKey].filterTags[filterKey] = true
      end
    end
    for filterKey, _ in pairs(card.filterTags) do
      if not usePlayerCards then
        local cardTypeKey = card.isFacilityCard and 'facilityCards' or 'playerCards'
        filtersByKey[filterKey][cardTypeKey] = filtersByKey[filterKey][cardTypeKey] + 1
      end
    end
  end

  -- build grouping sets

  local groupSetsByKey = { }
  groupSetsByKey['ungrouped'] = {
    key = "ungrouped",
    label = "None",
    hideProps = true,
    hideModsAndTimer = true,
    groups = {
      groupsByKey.ungrouped
    },
    sortings = defaultSortings,
  }
  groupSetsByKey['cargoType'] = {
    key = "cargoType",
    label = "Cargo Type",
    hideProps = true,
    hideModsAndTimer = true,
    focus = "none",
    groups = {
      groupsByKey.type_parcel,
      groupsByKey.type_fluid,
      groupsByKey.type_dryBulk,
      groupsByKey.type_vehicle,
      groupsByKey.type_trailer,
    },
    sortings = defaultSortings,
  }

  local destinationGroups = {}
  for key, group in pairs(groupsByKey) do
    if key ~= "destination_noDestination" and key:startswith('destination_') then
      table.insert(destinationGroups, group)
    end
  end
  table.sort(destinationGroups, function(a,b) return a.meta.distance < b.meta.distance end)
  table.insert(destinationGroups, groupsByKey['destination_noDestination'])
  groupSetsByKey['destinations'] = {
    key = "destinations",
    label = "Destinations",
    groups = destinationGroups,
    hideProps = true,
    hideModsAndTimer = true,
    focus = "destination",
    sortings = defaultSortings,
  }

  if usePlayerCards then
    local containerGroups = {}
    for _, con in ipairs(playerCargoContainers) do
      table.insert(containerGroups, groupsByKey[string.format("container_%d_%d", con.vehId, con.containerId)])
    end
    table.insert(containerGroups, groupsByKey.type_vehicle)
    table.insert(containerGroups, groupsByKey.type_trailer)

    groupSetsByKey['containers'] = {
      key = "containers",
      label = "Cargo Containers",
      groups = containerGroups,
      hideProps = true,
      hideModsAndTimer = true,
      hideTotalStorage = true,
      sortings = defaultSortings,
    }

    local taskGroups = {}
    for key, group in pairs(groupsByKey) do
      if key:startswith('task_') then
        group.showEmpty = true
        group.ignoreFilter = true
        table.insert(taskGroups, group)
      end
    end
    table.sort(taskGroups, function(a,b) return a.label < b.label end)
    groupSetsByKey['tasklist'] = {
      key = "tasklist",
      label = "Tasklist",
      groups = taskGroups,
      hideProps = true,
      hideModsAndTimer = true,
      sortings = defaultSortings,
    }
  end

  groupSetsByKey['loaner'] = {
    key = "loaner",
    label = "Vehicle Type",
    hideProps = true,
    hideModsAndTimer = true,
    groups = {
      groupsByKey.type_loaner_vehicle,
      groupsByKey.type_loaner_trailer,
    },
    sortings = {"cardId"}
  }

  groupSetsByKey['totalStorages'] = {
    key = 'totalStorages',
    groups = {
      groupsByKey.type_totalStorage_parcel,
      groupsByKey.type_totalStorage_fluid,
      groupsByKey.type_totalStorage_dryBulk,
    }
  }

  return groupSetsByKey
end

local function getCardSortingSetsByKey(cardsById)
  local sortSetsByKey = {}

  local cards = {}
  local idx = 1
  for _, card in pairs(cardsById) do
    card.sortValues = {}
    cards[idx] = card
    idx = idx + 1
  end

  -- cardId sorting
  table.sort(cards, function(a,b)
    return a.cardId < b.cardId
  end)
  for i, card in ipairs(cards) do
    card.sortValues.cardId = i
  end
  sortSetsByKey['cardId'] = {label = "Id", key = "cardId"}

  -- rewardMoney sorting: from high to low
  table.sort(cards, function(a, b)
    if not a.rewardMoney and not b.rewardMoney then
      return a.cardId < b.cardId
    end
    if not a.rewardMoney then
      return false
    end
    if not b.rewardMoney then
      return true
    end
    return a.rewardMoney < b.rewardMoney
  end)
  for i, card in ipairs(cards) do
    card.sortValues.rewardMoney = i
  end
  sortSetsByKey['rewardMoney'] = {label = "Rewards", key = "rewardMoney"}

  -- weight sorting: from high to low
  table.sort(cards, function(a, b)
    if not a.weight and not b.weight then
      return a.sortValues.rewardMoney < b.sortValues.rewardMoney
    end
    if not a.weight then
      return false
    end
    if not b.weight then
      return true
    end
    return a.weight < b.weight
  end)
  for i, card in ipairs(cards) do
    card.sortValues.weight = i
  end
  sortSetsByKey['weight'] = {label = "Weight", key = "weight"}

  -- distance sorting from close to far
  table.sort(cards, function(a, b)
    if not a.weight and not b.weight then
      return a.sortValues.rewardMoney < b.sortValues.rewardMoney
    end
    if not a.distance then
      return false
    end
    if not b.distance then
      return true
    end
    return a.distance < b.distance
  end)
  for i, card in ipairs(cards) do
    card.sortValues.distance = i
  end
  sortSetsByKey['distance'] = {label = "Distance", key = "distance"}


  local disableReasonOrder = {
    limit = 0,
    noSpace = 1,
    locked = 2,
    expired = 100
  }
  -- availablilty
  table.sort(cards, function(a, b)
    if a.enabled and b.enabled then
      return a.sortValues.rewardMoney < b.sortValues.rewardMoney
    end
    if not a.enabled and b.enabled then
      return false
    end
    if not b.enabled and a.enabled then
      return true
    end
    if not a.disableReason and not b.disableReason then
      return false
    end
    if not a.disableReason then
      return false
    end
    if not b.disableReason then
      return true
    end
    return disableReasonOrder[a.disableReason.type] < disableReasonOrder[b.disableReason.type]
  end)
  for i, card in ipairs(cards) do
    card.sortValues.availablilty = i
  end
  sortSetsByKey['availablilty'] = {label = "Availablilty", key = "availablilty"}


  return sortSetsByKey
end

local function addSortingValuesToGroups(cardsById, groupSets)
  -- give the groups in the groupsets the sorting values.
  for _, groupSet in pairs(groupSets) do
    for _, group in ipairs(groupSet.groups) do
      group.sortValues = {}
      for _, sortKey in ipairs({"cardId", "rewardMoney","weight","distance"}) do
        local min = math.huge
        for _, id in ipairs(group.cardIdsUnsorted) do
          min = math.min(min, cardsById[id].sortValues[sortKey] or math.huge)
        end
        group.sortValues[sortKey] = min
      end
    end
  end
end

local function getFilterSets(cardsById)
  local filterSets = { }
  for _, filter in ipairs(filterTags) do

    if filter.playerCards > 0 or filter.facilityCards > 0 then
      filter.hasAvailableOffers = true
    end
    filter.lockedInfo = nil
    local deliveryLevel = career_branches.getBranchLevel("delivery")
    if filter.value == "trailer" then
      if deliveryLevel < 1 then
        filter.lockedInfo = {
          type = "minLevel",
          icon = "boxPickUp03",
          longLabel = string.format("Requires 'Cargo Delivery' lvl 1", 1),
          shortLabel = string.format("lvl %d", 1),
          minLevel = 1
        }
      end
    end
    if filter.value == "material" then
      if deliveryLevel < 1 then
        filter.lockedInfo = {
          type = "minLevel",
          icon = "boxPickUp03",
          longLabel = string.format("Requires 'Cargo Delivery' lvl 1", 1),
          shortLabel = string.format("lvl %d", 1),
          minLevel = 1
        }
      end
    end

    -- if current facility does not offer this kind of orders then
    filter.order = i
    table.insert(filterSets, filter)
  end
  return filterSets
end



local function addFilterPlayerData(filterSets, playerGroupSets, playerCargoContainers)
  -- figure out if the player has storage for this thing.
  local storageAmount =  {parcel = 0, fluid = 0, dryBulk = 0}
  for _, con in ipairs(playerCargoContainers) do
    if con.cargoTypesLookup.parcel then
      storageAmount.parcel = 1
    elseif con.cargoTypesLookup.fluid then
      storageAmount.fluid = 1
    elseif con.cargoTypesLookup.dryBulk then
      storageAmount.dryBulk = 1
    end
  end
  for _, filter in ipairs(filterSets) do
    filter.noContainers = nil
    if filter.value == "parcel" and storageAmount.parcel == 0 then
      filter.noContainers = true
    elseif filter.value == "material" and (storageAmount.fluid == 0 and storageAmount.dryBulk == 0) then
      filter.noContainers = true
    elseif filter.value == "all" and (storageAmount.parcel == 0 and storageAmount.fluid == 0 and storageAmount.dryBulk == 0) then
      filter.noContainers = true
    end
  end

end

local function getConfirmButtonFromPlayerCards(cardsById)
  local itemCount = 0
  for _, card in pairs(cardsById) do
    if card.isPlayerCard and
       (   (card.transientMoveCounts and card.transientMoveCounts > 0)
        or card.spawnWhenCommitingCargo) then
      local count = 1
      if card.cardType == "parcelGroup" and (not card.materialType) then
        count = #card.ids
      end
      itemCount = itemCount + count
    end
  end
  return {
    itemCount = itemCount,
  }

end

M.resetFilterCounters = resetFilterCounters
M.getFilterSets = getFilterSets
M.addFilterPlayerData = addFilterPlayerData
M.getCardGroupSetsByKey = getCardGroupSetsByKey
M.addSortingValuesToGroups = addSortingValuesToGroups
M.getCardSortingSetsByKey = getCardSortingSetsByKey
M.getConfirmButtonFromPlayerCards = getConfirmButtonFromPlayerCards
return M
