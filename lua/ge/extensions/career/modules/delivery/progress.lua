-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
local dParcelManager, dCargoScreen, dGeneral, dGenerator, dProgress, dParcelMods, dVehOfferManager, dVehicleTasks
local step
M.onCareerActivated = function()
  dParcelManager = career_modules_delivery_parcelManager
  dCargoScreen = career_modules_delivery_cargoScreen
  dGeneral = career_modules_delivery_general
  dGenerator = career_modules_delivery_generator
  dProgress = career_modules_delivery_progress
  dParcelMods = career_modules_delivery_parcelMods
  dVehOfferManager = career_modules_delivery_vehicleOfferManager
  dVehicleTasks = career_modules_delivery_vehicleTasks
  step = util_stepHandler
end

local progress = {}

local progressTemplate = {

  cargoDeliveredByType = {
    parcel = 0,
    vehicle = 0,
    trailer = 0,
    fluid = 0,
    dryBulk = 0,
  }
}

M.setProgress = function(data)
  progress = data or deepcopy(progressTemplate)
end

M.getProgress = function()
  return progress
end

M.onCargoDelivered = function(cargoItems)

  local affectedFacilities = {}

  for _, cargo in ipairs(cargoItems or {}) do
    if cargo.materialType == nil then
      progress.cargoDeliveredByType.parcel = progress.cargoDeliveredByType.parcel + 1
    else
      local material = dGenerator.getMaterialsTemplatesById(cargo.materialType)
      progress.cargoDeliveredByType[material.type] = (progress.cargoDeliveredByType[material.type] or 0) + cargo.slots
    end

    local cargoOrigFacility = dGenerator.getFacilityById(cargo.origin.facId)
    cargoOrigFacility.progress.deliveredFromHere.countByType.parcel = cargoOrigFacility.progress.deliveredFromHere.countByType.parcel + 1
    cargoOrigFacility.progress.deliveredFromHere.moneySum = cargoOrigFacility.progress.deliveredFromHere.moneySum + (cargo.rewards.money or 0)

    local cargoDestFacility = dGenerator.getFacilityById(cargo.location.facId)
    cargoDestFacility.progress.deliveredToHere.countByType.parcel = cargoDestFacility.progress.deliveredToHere.countByType.parcel + 1
    cargoDestFacility.progress.deliveredToHere.moneySum = cargoDestFacility.progress.deliveredToHere.moneySum + (cargo.rewards.money or 0)

    dParcelMods.trackModifierStats(cargo)

    affectedFacilities[cargo.origin.facId] = true
    affectedFacilities[cargo.location.facId] = true
  end

  extensions.hook("onDeliveryFacilityProgressStatsChanged", affectedFacilities)
end


M.onVehicleTasksFinished = function(offers)
  local affectedFacilities = {}
  for _, o in ipairs(offers or {}) do
    local offer = o.offer
    progress.cargoDeliveredByType[offer.data.type] = progress.cargoDeliveredByType[offer.data.type] + 1

    local vehOrigFacility = dGenerator.getFacilityById(offer.origin.facId)
    vehOrigFacility.progress.deliveredFromHere.countByType[offer.data.type] = vehOrigFacility.progress.deliveredFromHere.countByType[offer.data.type] + 1
    vehOrigFacility.progress.deliveredFromHere.moneySum = vehOrigFacility.progress.deliveredFromHere.moneySum + (offer.rewards.money or 0)

    local vehDestFacility = dGenerator.getFacilityById(offer.dropOffFacId)
    vehDestFacility.progress.deliveredToHere.countByType[offer.data.type] = vehDestFacility.progress.deliveredToHere.countByType[offer.data.type] + 1
    vehDestFacility.progress.deliveredToHere.moneySum = vehDestFacility.progress.deliveredToHere.moneySum + (offer.rewards.money or 0)

    affectedFacilities[offer.origin.facId] = true
    affectedFacilities[offer.dropOffFacId] = true
  end
  extensions.hook("onDeliveryFacilityProgressStatsChanged", affectedFacilities)
end

local unlockStatus = nil
M.aggregateBefore = function()
  unlockStatus = {
    skillLevels = {}
  }
  for skill, _ in pairs(career_branches.getBranches()) do
    unlockStatus.skillLevels[skill] = career_branches.getBranchLevel(skill)
  end
end

M.aggregateAfter = function()
  local results = {}
  --[[
  TODO: reimplement
  for skill, _ in pairs(skillUnlockDescriptions) do
    for lvl = unlockStatus.skillLevels[skill], career_branches.getBranchLevel(skill) do
      for _, unlock in ipairs(skillUnlockDescriptions[skill][lvl] or {}) do
        table.insert(results, unlock.unlocks)
      end
    end
  end
  ]]
  unlockStatus = nil
  return results
end

local dropOffDataStatus = nil
M.requestDropOffData = function(facId, psPath)
  if dropOffDataStatus ~= nil then log("W","","Already unloading cargo...") end
  dropOffDataStatus = {}
  dropOffDataStatus.affectedOfferIds = {}
  dropOffDataStatus.parcelData = {}
  dropOffDataStatus.vehicleData = {}
  dropOffDataStatus.trailerData = {}
  dropOffDataStatus.playerVehicleData = {}
  dropOffDataStatus.location = {type="facilityParkingspot", facId=facId, psPath=psPath}
  local rewardKeys = {}
  local playerVehiclesById = {}
  --M.aggregateBefore()
  -- unload cargo
  dGeneral.getNearbyVehicleCargoContainers(function(playerCargoContainers)
    local playerDestinationParkingSpots = {}
    local playerVehIds = {}
    for _, con in ipairs(playerCargoContainers) do
      playerVehIds[con.vehId] = true
      for _, cargo in ipairs(con.rawCargo) do
        local validCargo = false
        if cargo.destination.type == "facilityParkingspot" then
          validCargo = dParcelManager.sameLocation(cargo.destination, dropOffDataStatus.location)
        elseif cargo.destination.type == "multi" then
          for _, dest in ipairs(cargo.destination.destinations) do
            validCargo = validCargo or dParcelManager.sameLocation(dest, dropOffDataStatus.location)
          end
        end

        if validCargo then
          if not playerVehiclesById[con.vehId] then
            playerVehiclesById[con.vehId] = { containers = {}, niceName = dGeneral.getVehicleName(con.vehId), vehId = con.vehId, containersById = {}}
          end
          if not playerVehiclesById[con.vehId].containersById[con.containerId] then
            playerVehiclesById[con.vehId].containersById[con.containerId] = {
              vehId = con.vehId,
              name = con.name,
              containerId = con.containerId,

              cargo = {},

              totalCargoSlots = con.totalCargoSlots,
              usedCargoSlots = con.usedCargoSlots,
              freeCargoSlots = con.freeCargoSlots,
            }
          end
          table.insert(playerVehiclesById[con.vehId].containersById[con.containerId].cargo, cargo)
        end
      end
    end

        -- convert vehicles table to list for UI
    dropOffDataStatus.playerVehicleData = {}
    for vehId, vehicleInfo in pairs(playerVehiclesById) do
      --table.sort(vehicleInfo.containers, function(a,b) return a.name < b.name end)
      for _, id in ipairs(tableKeysSorted(vehicleInfo.containersById)) do
        vehicleInfo.containersById[id].cargo = dParcelManager.addParcelRewardsSummary(deepcopy(vehicleInfo.containersById[id].cargo))
        table.insert(vehicleInfo.containers, vehicleInfo.containersById[id])
      end
      vehicleInfo.containersById = nil
      table.insert(dropOffDataStatus.playerVehicleData, vehicleInfo)
    end
    table.sort(dropOffDataStatus.playerVehicleData, function(a,b) return a.vehId < b.vehId end)
    dropOffDataStatus.rewardKeyIcons = rewardKeys
    dropOffDataStatus.vehicleData = dVehicleTasks.getVehicleDataWithRewardsSummary()
    M.openDropOffScreenGatheringComplete()
    -- try to re-open the prompt
  end)
end

M.unloadMaterialsManualStart = function(cargoId, destination)
  print("No longer used! unloadMaterialsManualStart")
end


local showSystemPopup = {}
M.openDropOffScreenGatheringComplete = function()
  -- still waiting for vehicles to be finished
  for _, data in pairs(dropOffDataStatus.vehicleData) do
    if not data.finished then return end
  end

    -- patch in xp icons info
  local branchInfo = {}

  -- already calc if we need it
  local confirmedCargoIds = {}
  local confirmedOfferIds = {}

  --sort into automatic and non-automatic
  local automaticDropOffItems = {}
  local manualDropOffItems = {}
  for _, vehicleInfo in pairs(dropOffDataStatus.playerVehicleData or {}) do
    for _, con in pairs(vehicleInfo.containers) do
      for _, cargo in pairs(con.cargo) do
        cargo.vehicleName = vehicleInfo.name
        cargo.containerName = con.name
        if cargo.automaticDropOff then
          table.insert(automaticDropOffItems, cargo)
          for _, id in ipairs(cargo.ids) do
            table.insert(confirmedCargoIds, {id=id})
          end
        else
          table.insert(manualDropOffItems, cargo)
        end
        -- add in rewards keys..?
        for key, amount in pairs(cargo.adjustedRewards) do
          branchInfo[key] = true
        end
      end
    end
  end

  for _, vehData in ipairs(dropOffDataStatus.vehicleData or {}) do
    table.insert(automaticDropOffItems, vehData)
    table.insert(confirmedOfferIds, vehData.id)
    for key, amount in pairs(vehData.adjustedRewards) do
      branchInfo[key] = true
    end
  end

  dropOffDataStatus.automaticDropOffItems = automaticDropOffItems
  dropOffDataStatus.manualDropOffItems = manualDropOffItems

  -- check how much i can unload for each material
  local unloadingMaterialInfoByKey = {}
  local fac = dGenerator.getFacilityById(dropOffDataStatus.location.facId)
  for _, item in ipairs(manualDropOffItems) do
    unloadingMaterialInfoByKey[item.materialType] = unloadingMaterialInfoByKey[item.materialType] or {storage = fac.materialStorages[item.materialType], amountToUnload = 0, items = {}}
    unloadingMaterialInfoByKey[item.materialType].amountToUnload = unloadingMaterialInfoByKey[item.materialType].amountToUnload + item.slots
    table.insert(unloadingMaterialInfoByKey[item.materialType].items, item)
  end


  dropOffDataStatus.customAmountPerMaterialType = {}
  for _, materialType in pairs(tableKeysSorted(unloadingMaterialInfoByKey)) do
    local info = unloadingMaterialInfoByKey[materialType]
    info.material = dGenerator.getMaterialsTemplatesById(materialType)

    table.insert(dropOffDataStatus.customAmountPerMaterialType, info)
  end


  if next(dropOffDataStatus.customAmountPerMaterialType) then

    for key, _ in pairs(branchInfo) do
      branchInfo[key] = {
        icon = career_branches.getBranchIcon(key),
        order = career_branches.getOrder(key)
      }
      if key:endswith("Reputation") then
        branchInfo[key].order, branchInfo[key].icon = 7000, "peopleOutline" --freeroam_organizations.getOrganizationIdOrderAndIcon()
      end
    end
    --dump(dropOffDataStatus)
    guihooks.trigger("SetDeliveryDropOffCargoSelection", dropOffDataStatus)
    dropOffDataStatus.branchInfo = branchInfo
    --dumpz(dropOffDataStatus,2)
  else
    local confirmedDropOffs = {
      confirmedCargoIds = confirmedCargoIds,
      confirmedOfferIds = confirmedOfferIds,
    }
    M.confirmDropOffData(confirmedDropOffs, dropOffDataStatus.location.facId, dropOffDataStatus.location.psPath)
    return
  end

  gameplay_markerInteraction.closeViewDetailPrompt(true)
  Engine.Audio.playOnce('AudioGui', 'event:>UI>Missions>Info_Open')
  gameplay_rawPois.clear()
  dropOffDataStatus = nil
end




local confirmedDropOffData = nil
M.confirmDropOffData = function(confirmedDropOffs, facId, psPath)
  if confirmedDropOffData ~= nil then log("W","","Already dropoffing cargo...") return end
  local location = {type="facilityParkingspot", facId=facId, psPath=psPath}
  confirmedDropOffData = {}
  confirmedDropOffData.parcelIdElems = confirmedDropOffs.confirmedCargoIds or {}
  confirmedDropOffData.offerIds = confirmedDropOffs.confirmedOfferIds or {}
  confirmedDropOffData.cargo = {}
  --dump(confirmedDropOffs)
  for _, elem in ipairs(confirmedDropOffData.parcelIdElems) do
    local cargo = dParcelManager.getCargoById(elem.id)
    local invId = career_modules_inventory.getInventoryIdFromVehicleId(cargo.location.vehId)
    if invId then
      print("Adding delivered items to inventory " .. invId .. " with amount " .. cargo.slots)
      local amount = cargo.slots and cargo.type == "parcel" and cargo.slots or cargo.slots / 6.25
      career_modules_inventory.addDeliveredItems(invId, cargo.slots)
    end
    -- check if we need to split materials
    if elem.amount and elem.amount < cargo.slots then
      local parts = dGenerator.splitOffPartsFromMaterialCargo(cargo, {elem.amount})
      -- parts[1] is the remaining cargo
      cargo = parts[2]
    end
    dParcelManager.changeCargoLocation(cargo.id, location)

    if cargo.materialType and not cargo.automaticDropOff then
      dGenerator.finalizeMaterialDistanceRewards(cargo, location)
    end

    cargo.originalRewards, cargo.breakdown, cargo.adjustedRewards = dParcelManager.getRewardsWithBreakdown(cargo)
    table.insert(confirmedDropOffData.cargo, cargo)
  end

  confirmedDropOffData.offers = dVehicleTasks.finishTasks(confirmedDropOffData.offerIds)
  confirmedDropOffData.weightUpdateComplete = false
  dGeneral.requestUpdateContainerWeights()
  confirmedDropOffData.onComplete = nop
  dGeneral.updateContainerWeights(function(data)
    confirmedDropOffData.weightUpdateComplete = true
    local maxDelay = 0
    for _, delay in pairs(data) do
      maxDelay = math.max(delay, maxDelay)
    end
    maxDelay = maxDelay
    if maxDelay >= 1 then
      confirmedDropOffData.maxDelayForWeightUpdate = maxDelay
      confirmedDropOffData.onComplete = function()
        local sequence = {
          step.makeStepWait(maxDelay+0.5),
          step.makeStepReturnTrueFunction(function()
            for vehId, data in pairs(data) do
              local veh = scenetree.findObjectById(vehId)
              core_vehicleBridge.executeAction(veh, 'setFreeze', false)
            end
          return true
          end
          )
        }
        step.startStepSequence(sequence, callback)
      end
    else
      confirmedDropOffData.maxDelayForWeightUpdate = 0
      -- 1s delay, no freeze
      for vehId, data in pairs(data) do
        if career_modules_inventory.getInventoryIdFromVehicleId(vehId) then
          print("found inventory id " .. career_modules_inventory.getInventoryIdFromVehicleId(vehId))
        else
          print("no inventory id")
        end
        local veh = scenetree.findObjectById(vehId)
        core_vehicleBridge.executeAction(veh, 'setFreeze', false)
      end
    end
    M.confirmDropOffCheckComplete()
  end)
  --M.confirmDropOffCheckComplete()
end

M.confirmDropOffCheckComplete = function()
  if not confirmedDropOffData then return end

    -- still waiting for vehicles to be finished
  for _, data in pairs(confirmedDropOffData.offers) do
    if not data.finished then return end
  end
  if not confirmedDropOffData.weightUpdateComplete then
    return
  end

  local rewards = {}
  local itemNames = {}
  local branchInfo = {}
  local rewardParcels = {}



  -- add rewards for parcels, then for vehicles
  -- group cargo

   --current location also needs to be the same, but that is guaranteed by the caller of this function
  local cargoByGroupId = {}
  for _, c in ipairs(confirmedDropOffData.cargo) do
    local gId = string.format("%d-%d", c.groupId, c.loadedAtTimeStamp or -1)
    cargoByGroupId[gId] = cargoByGroupId[gId] or {}
    -- finalize the fields that require "costly" computation at this point
    table.insert(cargoByGroupId[gId], c)
    table.insert(rewards, c.adjustedRewards)
    c.summaryId = gId
    table.insert(rewardParcels, c)
  end
    -- format each group individually
  for gId, group in pairs(cargoByGroupId) do
    table.insert(itemNames, string.format("%dx %s", #group, group[1].name))
  end

  for _, formattedOffer in ipairs(confirmedDropOffData.offers) do
    table.insert(itemNames, string.format("%s %s",formattedOffer.offer.name, formattedOffer.offer.vehicle.name))
    table.insert(rewards, formattedOffer.adjustedRewards)
  end


  -- calculate the simple and detailled breakdowns for UI


  local rewardSum = {}
  for _, reward in ipairs(rewards) do
    for key, amount in pairs(reward) do
      rewardSum[key] = (rewardSum[key] or 0) + amount
      branchInfo[key] = true
    end
  end
  --[[
  local aggregateChange = {}
  for key, _ in ipairs(branchInfo) do
    local branch = career_branches.getBranchById(key)
    if branch.id == "key" then
      local level, curLvlProgress, neededForNext, prevThreshold, nextThreshold = career_branches.calcBranchLevelFromValue(career_modules_playerAttributes.getAttributeValue(key), key)
      aggregateChange[key] = {
        isBranch = true,
        valueBefore = career_modules_playerAttributes.getAttributeValue(key),
        levelInfoBefore = {
          level = level,
          curLvlProgress = curLvlProgress,
          neededForNext = neededForNext,
          prevThreshold = prevThreshold,
          nextThreshold = nextThreshold
        }
      }
  end
  ]]
  career_modules_playerAttributes.addAttributes(rewardSum,{label=string.format("Rewards for %s", table.concat(itemNames, ", ")), tags={"gameplay"}}, true)

  for key, _ in pairs(branchInfo) do

    if key:endswith("Reputation") then
      local orgId = key:sub(1, -11)
      local organization = freeroam_organizations.getOrganization(orgId)
      branchInfo[key] = {
        icon = "peopleOutline",
        order = 7000,
        animationData = {
          name = "Reputation: " .. organization.name,
          max = organization.reputation.nextThreshold,
          min = organization.reputation.prevThreshold,
          value = organization.reputation.value
        },
        type = "reputation",
        branchLevels = organization.reputationLevels
      }
    else
      local branch = career_branches.getBranchById(key)
      branchInfo[key] = {
        icon = career_branches.getBranchIcon(key),
        order = career_branches.getOrder(key),
        animationData = career_modules_branches_landing.getBranchSkillCardData(key),
        branchLevels = deepcopy(branch.levels),
        showLevelUpPopup = true,
        unlockPopupHeader = string.format("%s %s: Level %d", translateLanguage(branch.name, branch.name), branch.isSkill and "Skill" or "Branch", career_branches.getBranchLevel(branch.id) or 0)
      }

      for i, levelInfo in ipairs(branchInfo[key].branchLevels) do
        levelInfo.levelLabel = "Level " .. i
      end

      if branch.isBranch then branchInfo[key].animationData.name = "Branch: " .. translateLanguage(branchInfo[key].animationData.name, branchInfo[key].animationData.name) end
      if branch.isSkill then branchInfo[key].animationData.name = "Skill: " .. translateLanguage(branchInfo[key].animationData.name, branchInfo[key].animationData.name) end
    end

    if key == "money" then
      branchInfo[key].icon = "beamCurrency"
      branchInfo[key].animationData = {
        type = "number",
        name = "Money",
        value = career_modules_playerAttributes.getAttribute("money").value
      }
    end

    if key == "beamXP" then
      branchInfo[key].icon = "beamXPLo"
      branchInfo[key].animationData = {
        type = "number",
        name = "BeamXP",
        value = career_modules_playerAttributes.getAttribute("beamXP").value
      }
    end
  end
  local rewardResult = {
    rewardParcels = rewardParcels,
    rewardOffers = confirmedDropOffData.offers,
    branchInfo = branchInfo,
    unloadingDelay = confirmedDropOffData.maxDelayForWeightUpdate
  }

  guihooks.trigger("SetDeliveryDropOffRewardResult", rewardResult)

  Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Buy_02')
  gameplay_markerInteraction.setForceReevaluateOpenPrompt(true)
  gameplay_rawPois.clear()

  M.onVehicleTasksFinished(confirmedDropOffData.offers)
  M.onCargoDelivered(confirmedDropOffData.cargo)
  confirmedDropOffData.onComplete()
  dGeneral.checkExitDeliveryMode()
  confirmedDropOffData = nil

  if career_career.isAutosaveEnabled() then
    career_saveSystem.saveCurrent()
  end
end


M.unloadCargoPopupClosed = function()
  Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Buy_02')
  career_modules_linearTutorial.introPopup("cargoDelivered")
  if next(showSystemPopup) then
    for _, key in ipairs(showSystemPopup) do
      career_modules_linearTutorial.introPopup(key.."Unlocked")
    end
  end
  gameplay_markerInteraction.setForceReevaluateOpenPrompt()
end



M.isFacilityUnlocked = function(facId)
  local fac = dGenerator.getFacilityById(facId)
  if not fac.unlockCondition then
    return true
  end
  if fac.unlockCondition.type == "minItemCount" then
    local val = fac.progress.itemsDeliveredToHere.count
    local tgt = fac.unlockCondition.target
    if val >= tgt then
      return true
    else
      return false, {
        disabledReasonHeader = "Facility not yet unlocked!",
        disabledReasonContent = string.format("Deliver %d Items here to be able to deliver from here.",tgt),
        progress = {
          {type="progressBar",minValue=0,maxValue=tgt,currValue=val, label=string.format("%d / %d Items delivered.", val, tgt)}
        }
      }
    end
  elseif fac.unlockCondition.type == "branchLevel" then
  end
  return true
end

M.isFacilityVisible = function(facId)
  local fac = dGenerator.getFacilityById(facId)
  if not fac then return false end
  if not fac.visibleCondition then
    return true
  end
  if fac.visibleCondition.type == "minItemCount" then
    local val = fac.progress.itemsDeliveredToHere.count
    local tgt = fac.unlockCondition.target
    if val >= tgt then
      return true
    else
      return false
    end
  end
  return true
end


M.getFacilityCountForCargoCount = function(direction)
  local count = 0
  for _, facility in ipairs(dGenerator.getFacilities()) do
    local c = 0
    for key, v in pairs(facility.progress[direction].countByType) do
      c = c + v
    end
    if c > 0 then count = count + 1 end
  end
  return count
end


M.getMoneyMultiplerForSkill = function(skill, tier)
  return career_branches.getLevelRewardMultiplier("logistics")
end


local function onBranchTierReached(skill, tier)
  if skill == "delivery" and tier > 1 then
    career_branches.getBranchById("vehicleDelivery").unlocked = true
  end
end

local soundObjectIds = {}
local soundNames = {
  money = 'event:>UI>Career>Progress_Money',
  progressBar = 'event:>UI>Career>Progress_XP'
}

local function activateSound(soundLabel, active)
  soundObjectIds["money"] = soundObjectIds["money"] or Engine.Audio.createSource('AudioGui', soundNames["money"])
  soundObjectIds["progressBar"] = soundObjectIds["progressBar"] or Engine.Audio.createSource('AudioGui', soundNames["progressBar"])
  if active then
    local sound = scenetree.findObjectById(soundObjectIds[soundLabel])
    if sound then
      sound:play(-1)
    end
  else
    for label, _ in pairs(soundNames) do
      local sound = scenetree.findObjectById(soundObjectIds[label])
      if sound then
        sound:stop(-1)
      end
    end
  end
end

M.onBranchTierReached = onBranchTierReached
M.activateSound = activateSound

return M