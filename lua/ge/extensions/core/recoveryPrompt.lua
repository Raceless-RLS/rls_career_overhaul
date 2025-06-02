-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local active = false

local function slowerThan(v) local veh = getPlayerVehicle(0) if veh then return veh:getVelocity():len() <= v end return false end

local movingSlowlyThreshold = 10 -- m/s
local stoppedThreshold = 0.5 --m/s
local conditions = {
  outOfPursuit = function(type, vehId)
    if career_modules_playerDriving and career_modules_playerDriving.playerPursuitActive() then
      return false, "Disabled because of police chase."
    end
    return true
  end,
  vehicleSlow = function(type, vehId)
    local veh = scenetree.findObjectById(vehId)
    if veh then
      if veh:getVelocity():len() >= movingSlowlyThreshold then
        return false, "Stop your vehicle."
      end
    end
    return true
  end,
  vehicleStopped = function(type, vehId)
    local veh = scenetree.findObjectById(vehId)
    if veh then
      if veh:getVelocity():len() >= stoppedThreshold then
        return false, "Stop your vehicle completely."
      end
    end
    return true
  end,
  vehicleInInventory = function(type, vehId)
    if not (career_modules_inventory and career_modules_inventory.getInventoryIdFromVehicleId(vehId)) then
      return false, "This vehicle is not in your inventory."
    end
    return true
  end,
  vehicleOwned = function(type, vehId)
    if career_modules_inventory then
      local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)
      if inventoryId then
        local vehInfo = career_modules_inventory.getVehicles()[inventoryId]
        if vehInfo and vehInfo.owned then return true end
      end
    end
    return false, "You do not own this vehicle."
  end,
  favouriteSet = function(type, vehId)
    local favoriteVehicleId = career_modules_inventory.getFavoriteVehicle()
    if not favoriteVehicleId then return false, "No favourite vehicle set." end
    local vehInfo = career_modules_inventory.getVehicles()[favoriteVehicleId]
    if not vehInfo then return false, "No favourite vehicle set." end
    if vehInfo.timeToAccess
    or not career_modules_inventory.getVehicleIdFromInventoryId(favoriteVehicleId) and career_modules_insurance.inventoryVehNeedsRepair(favoriteVehicleId) -- vehicle is not spawned and needs a repair
    then
      return false, "Favourite vehicle still in repair."
    end
    return true
  end,
  notTestdriving = function(type, vehId)
    if career_modules_testDrive and career_modules_testDrive.isActive() then
      return false, "Disabled during test drive."
    end
    return true
  end,
  duringTestdrive = function(type, vehId)
    if career_modules_testDrive and career_modules_testDrive.isActive() then
      return true
    end
    return false
  end,
  towToRoadAllowedByPermission = function(type, vehId)
    if not career_modules_permissions then return true end
    local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)
    local reason = career_modules_permissions.getStatusForTag("recoveryTowToGarage", {inventoryId = inventoryId})
    return reason.allow, reason.label
  end,
  vehicleIsDeliveryVehicle = function(type, vehId)
    if not career_modules_delivery_vehicleTasks then return false end
    if career_modules_delivery_vehicleTasks.isVehicleDeliveryVehicle(vehId) then
      return true
    end
    return false
  end
}

local flipUpRightCost = 50
local towToRoadCost = 75
local baseTowToGarageCost = 250

local function getPriceFunction(basePrice)
  return function(target)
    if career_modules_insurance.isRoadSideAssistanceFree(career_modules_inventory.getInventoryIdFromVehicleId(target.vehId)) then
      return {money = {amount = 0, canBeNegative = true}}
    end
    return {money = {amount = basePrice, canBeNegative = true}}
  end
end

local buttonOptions = {
  -- available durign regular career gameplay
  towToRoad = {
    label = "ui.career.towToRoad",
    type = "vehicle",
    includeConditions = {},
    enableConditions = {conditions.outOfPursuit, conditions.vehicleSlow, conditions.notTestdriving, conditions.vehicleInInventory},
    atFadeFunction = function(target)
      local veh = scenetree.findObjectById(target.vehId)
      if veh then
        spawn.teleportToLastRoad(veh, {resetVehicle = false})
        if not career_modules_insurance.isRoadSideAssistanceFree(career_modules_inventory.getInventoryIdFromVehicleId(target.vehId)) then
          career_modules_payment.pay({money = {amount = towToRoadCost, canBeNegative = true}}, {label = string.format("Towed your vehicle to the road")})
        end
      end
    end,
    order = 5,
    startSlot = 7,
    active = true,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
    icon = "road",
    confirmationText = "Do you want to tow your vehicle to the nearest road?",
    price = getPriceFunction(towToRoadCost)
  },
  flipUpright = {
    label = "Flip Upright",
    type = "vehicle",
    includeConditions = {},
    enableConditions = {conditions.outOfPursuit, conditions.vehicleStopped, conditions.vehicleInInventory, conditions.notTestdriving},
    atFadeFunction = function(target)
      local veh = scenetree.findObjectById(target.vehId)
      if veh then
        spawn.safeTeleport(veh, veh:getPosition(), quatFromDir(veh:getDirectionVector()), nil, nil, nil, nil, false )
        if not career_modules_insurance.isRoadSideAssistanceFree(career_modules_inventory.getInventoryIdFromVehicleId(target.vehId)) then
          career_modules_payment.pay({money = {amount = flipUpRightCost, canBeNegative = true}}, {label = string.format("Flipped your vehicle upright")})
        end
      end
    end,
    order = 15,
    startSlot = 3,
    active = true,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Flip",
    icon = "carToWheels",
    confirmationText = "Do you want your vehicle to be flipped upright?",
    price = getPriceFunction(flipUpRightCost)
  },
  getFavoriteVehicle = {
    type = "walk",
    label = "Retrieve favorite vehicle",
    includeConditions = {},
    enableConditions = {conditions.outOfPursuit, conditions.favouriteSet, conditions.notTestdriving},
    atFadeFunction = function() career_modules_playerDriving.retrieveFavoriteVehicle() end,

    order = 11,
    active = false,
    enabled = true,
    fadeActive = true,
    icon = "carStarred",
    confirmationText = "Do you want to retrieve your favorite vehicle?"
  },
  -- only during mission
  flipMission = {
    type = "vehicle",
    label = "Flip Upright",
    --includeCondition = function() return gameplay_missions_missionManager.getForegroundMissionId() ~= nil end,
    includeConditions = {},
    enableConditions = {conditions.vehicleStopped},
    atFadeFunction = nop,
    order = 5,
    startSlot = 3,
    active = false,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Flip",
    icon = "carToWheels"
  },
  recoverMission = {
    type = "vehicle",
    label = "Recover",
    includeConditions = {},
    enableConditions = {conditions.vehicleSlow},
    atFadeFunction = nop,
    order = 7,
    startSlot = 7,
    active = false,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
    icon = "car"
  },
  submitMission = {
    type = "none",
    label = "Submit Score",
    includeConditions = {},
    enableConditions = {},
    atFadeFunction = nop,
    order = 10,
    startSlot = 5,
    active = false,
    enabled = true,
    fadeActive = false,
    icon = "checkboxOn"
  },
  restartMission = {
    type = "none",
    label = "Restart Mission",
    includeConditions = {},
    enableConditions = {},
    atFadeFunction = nop,
    order = 15,
    startSlot = 1,
    active = false,
    enabled = true,
    fadeActive = false,
    icon = "restart"
  },
  -- only during tutorial
  repairHere = {
    type = "vehicle",
    label = "Repair",
    --veh, pos, rot, checkOnlyStatics_, visibilityPoint_, removeTraffic_, centeredPosition, resetVehicle
    atFadeFunction = function()
      local veh = getPlayerVehicle(0)
      if veh then
        if career_career.isActive() then
          if career_modules_inventory.getCurrentVehicle() then
            career_modules_inventory.updatePartConditions(nil, career_modules_inventory.getCurrentVehicle(), function() career_modules_insurance.startRepair(nil) end)
          end
        else
          spawn.safeTeleport(veh, veh:getPosition(), quatFromDir(veh:getDirectionVector()), nil, nil, nil, nil, true )
        end
      end
    end,
    includeConditions = {},
    enableConditions = {conditions.vehicleSlow},
    order = 10,
    active = true,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
    icon = "wrench"
  },
  -- testing for non-career freeroam
  resetVehicle = {
    type = "vehicle",
    label = "Reset Vehicle",
    includeConditions = {},
    enableConditions = {},
    atFadeFunction = function() be:resetVehicle(0) end,
    order = 20,
    active = false,
    enabled = true,
    fadeActive = true
  },
  -- during testdrive
  stopTestdrive = {
    type = "none",
    label = "Stop test drive",
    --veh, pos, rot, checkOnlyStatics_, visibilityPoint_, removeTraffic_, centeredPosition, resetVehicle
    atFadeFunction = function()
      career_modules_testDrive.stop(true)
    end,
    includeConditions = {conditions.duringTestdrive},
    enableConditions = {},
    order = 10,
    active = true,
    enabled = true,
    fadeActive = true,
    icon = "restart"
  },
    -- during testdrive
  giveBackDeliveryVehicle = {
    type = "vehicle",
    label = "Discard Delivery Vehicle",
    --veh, pos, rot, checkOnlyStatics_, visibilityPoint_, removeTraffic_, centeredPosition, resetVehicle
    atFadeFunction = function(target)
      career_modules_delivery_vehicleTasks.giveBackDeliveryVehicle(target.vehId)
    end,
    includeConditions = {conditions.outOfPursuit, conditions.vehicleIsDeliveryVehicle},
    enableConditions = {conditions.vehicleSlow},
    order = 10,
    active = true,
    enabled = true,
    fadeActive = true,
    icon = "restart"
  },
  returnLoanedVehicle = {
    label = "Return loaned vehicle",
    type = "vehicle",
    includeConditions = {function(_, vehId) return conditions.vehicleInInventory(_, vehId) and not conditions.vehicleOwned(_, vehId) end},
    enableConditions = {conditions.outOfPursuit, conditions.vehicleStopped, conditions.notTestdriving},
    atFadeFunction = function(target)
      if career_modules_inventory then
        local inventoryId = career_modules_inventory.getInventoryIdFromVehicleId(target.vehId)
        if inventoryId then
          career_modules_loanerVehicles.returnVehicle(inventoryId)
        end
      end
    end,
    order = 5,
    active = true,
    enabled = true,
    fadeActive = true,
    fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
    icon = "car",
    confirmationText = "Do you want to return this loaned vehicle?"
  },
}

local function addTowingButtons()
  if not getCurrentLevelIdentifier() then return end
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  local discoveredGarages = 0

  -- add garage tow buttons
  for i, garage in ipairs(garages) do
    if not garage.noQuickTravel then
      local function getPrice(target)
        if career_modules_insurance.isRoadSideAssistanceFree(career_modules_inventory.getInventoryIdFromVehicleId(target.vehId)) then
          return nil
        end
        local price = career_modules_quickTravel.getPriceForQuickTravelToGarage(garage) * 9
        if price > 0 then price = price + baseTowToGarageCost end
        return {money = {amount = career_modules_quickTravel.getPriceForQuickTravelToGarage(garage), canBeNegative = true}}
      end

      if career_modules_garageManager.isDiscoveredGarage(garage.id) then
        discoveredGarages = discoveredGarages + 1
        buttonOptions[string.format("towTo%s", garage.id)] =
        {
          type = "vehicle",
          label = function(options, target)
            return string.format("%s", translateLanguage(garage.name, garage.name, true))
          end,
          includeConditions = {},
          menuTag = "towing",
          enableConditions = {conditions.outOfPursuit, conditions.vehicleSlow, conditions.vehicleInInventory, conditions.notTestdriving, conditions.towToRoadAllowedByPermission},
          atFadeFunction = function(target)
            career_modules_playerDriving.teleportToGarage(garage.id, scenetree.findObjectById(target.vehId), false)
            if career_modules_quickTravel.getPriceForQuickTravelToGarage(garage) > 0 then
              career_modules_insurance.useTow(career_modules_inventory.getInventoryIdFromVehicleId(target.vehId))
            end
            local price = getPrice(target)
            if price then
              career_modules_payment.pay(price, {label = string.format("Towed your vehicle to your garage")})
            end
          end,
          message = "ui.career.towed",
          order = discoveredGarages,
          active = true,
          enabled = true,
          fadeActive = true,
          fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
          icon = "garageNumber"..discoveredGarages,
          price = getPrice,
          confirmationText = "Do you want to tow your vehicle to this garage?",
          path = "towing/",
          noUniqueID = true,
        }
      end
    end
  end
end

local function addTaxiButtons()
  if not getCurrentLevelIdentifier() then return end
  local garages = freeroam_facilities.getFacilitiesByType("garage")
  local discoveredGarages = 0

  -- add garage taxi buttons
  for i, garage in ipairs(garages) do
    if not garage.noQuickTravel then

      if career_modules_garageManager.isDiscoveredGarage(garage.id) then
        discoveredGarages = discoveredGarages + 1
        buttonOptions[string.format("taxiTo%s", garage.id)] =
        {
          type = "walk",
          label = function(options)
            return string.format("%s", translateLanguage(garage.name, garage.name, true))
          end,
          includeConditions = {},
          menuTag = "taxi",
          enableConditions = {},
          atFadeFunction = function()
            career_modules_quickTravel.quickTravelToGarage(garage)
          end,
          order = discoveredGarages,
          active = true,
          enabled = true,
          fadeActive = true,
          fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
          icon = "garageNumber"..discoveredGarages,
          price = function() return {money = {amount = career_modules_quickTravel.getPriceForQuickTravelToGarage(garage)}} end,
          confirmationText = "Do you want to use the taxi?",
          path = "taxi/",
          noUniqueID = true,
        }
      end
    end
  end

  local function getPrice()
    local lastVehicleId = career_modules_inventory.getLastVehicle()
    local vehObjId = career_modules_inventory.getVehicleIdFromInventoryId(lastVehicleId)
    if vehObjId then
      local vehObj = getObjectByID(vehObjId)
      local pos = vehObj:getPosition()
      local price = career_modules_quickTravel.getPriceForQuickTravel(pos)
      return {money = {amount = price}}
    end
  end

  buttonOptions.taxiToVehicle =
    {
      type = "walk",
      label = function(options)
        return "Your last vehicle"
      end,
      includeConditions = {},
      menuTag = "taxi",
      enableConditions = {},
      atFadeFunction = function()
        local lastVehicleId = career_modules_inventory.getLastVehicle()
        local vehObjId = career_modules_inventory.getVehicleIdFromInventoryId(lastVehicleId)
        if vehObjId then
          local vehObj = getObjectByID(vehObjId)
          local pos = vehObj:getPosition()
          career_modules_quickTravel.quickTravelToPos(pos, true, "Took a taxi to your vehicle")
        end
      end,
      order = 25,
      active = true,
      enabled = function()
        local lastVehicleId = career_modules_inventory.getLastVehicle()
        return career_modules_inventory.getVehicleIdFromInventoryId(lastVehicleId)
      end,
      fadeActive = true,
      fadeStartSound = "event:>UI>Missions>Vehicle_Recover",
      icon = "car",
      price = getPrice,
      confirmationText = "Do you want to use the taxi?",
      path = "taxi/",
      noUniqueID = true,
    }
end

local function onCareerModulesActivated(alreadyInLevel)
  if alreadyInLevel then
    addTowingButtons()
    addTaxiButtons()
  end
end

local function onClientStartMission(levelPath)
  if career_career.isActive() then
    M.setDefaultsForCareer()
    addTowingButtons()
    addTaxiButtons()
  end
end

local function isActive() return active end
local function setActive(a) active = a end
local function setDefaultsForFreeroam()
  active = false
  for _, o in pairs(buttonOptions) do o.active = false end
end

local function setDefaultsForCareer()
  active = true
  for _, o in pairs(buttonOptions) do o.active = false end
  buttonOptions.towToRoad.active = true
  buttonOptions.flipUpright.active = true

  buttonOptions.getFavoriteVehicle.active = true
  buttonOptions.stopTestdrive.active = true
  buttonOptions.giveBackDeliveryVehicle.active = true
  buttonOptions.returnLoanedVehicle.active = true
  addTowingButtons()
  addTaxiButtons()
end

local function setDefaultsForTutorial()
  active = true
  for _, o in pairs(buttonOptions) do o.active = false end
  buttonOptions.towToRoad.active = true
  buttonOptions.repairHere.active = true
  buttonOptions.flipUpright.active = true
  buttonOptions.getFavoriteVehicle.active = false
end

local function setEverythingActive()
  active = true
  for _, o in pairs(buttonOptions) do o.active = true end
end

local function deactivateAllButtons() for _, o in pairs(buttonOptions) do o.active = false end end

local function setButtonActiveById(id, a)
  if not buttonOptions[id] then log("W","","Tried to set active for button, but the id couldnt be found: " .. dumps(id)) return end
  buttonOptions[id].active = a
end

local function getButtonActiveById(id)
  if not buttonOptions[id] then log("W","","Tried to get enable for button, but the id couldnt be found: " .. dumps(id)) return end
  return buttonOptions[id].active
end

local function setButtonEnabledById(id, e)
  if not buttonOptions[id] then log("W","","Tried to set enable for button, but the id couldnt be found: " .. dumps(id)) return end
  buttonOptions[id].enabled = e
  if e then
    buttonOptions[id].active = e
  end
end

local function highestOrderPlusOne()
  local highest = 0
  for _, o in pairs(buttonOptions) do
    highest = math.max(highest, o.order)
  end
  return highest + 1
end

local function addButton(id, label, atFadeFunction, order, message, active, enabled, fadeActive, icon)
  if not id then log("E","","Tried creating button without ID!" ) return end
  if buttonOptions[id] and not buttonOptions[id].customButton then log("E","Tried to add a button, but it already exists and it's not a custom button, so it's not allowed! " .. dumps(id)) return end
  -- fill some defaults for the button if it doesnt have them
  if active == nil then active = true end
  if fadeActive == nil then fadeActive = true end
  local btn = {
    label = label or "No Label!",
    atFadeFunction = atFadeFunction or function() log("E","","No Function set for " .. dumps(id) ) end,
    order = order or highestOrderPlusOne(),
    message = message,
    active = active,
    enabled = enabled,
    customButton = true,
    fadeActive = fadeActive,
    icon = icon,
    uniqueID = id,
  }
  if buttonOptions[id] then
    log("E","","Button for Id already exists and will be overwritten: " .. dumps(id) .. ": " .. dumps(buttonOptions[btn.id]))
  end
  buttonOptions[id] = btn
  -- check if there's any collision for the orders
  local orders = {}
  for _, o in pairs(buttonOptions) do
    if orders[o.order] then log("E","Order Collision for buttons: " .. orders[o.order] .. "/"..o.id) end
    orders[o.order] = o.id
  end
end

local function removeButtonById(id)
  if not buttonOptions[id] then log("W","","Tried removing button, but it doesnt exist: " .. dumps(id)) return end
  if not buttonOptions[id].customButton then log("E","Tried to remove a button, but it's not a custom button, so it's not allowed! " .. dumps(id)) return end
  buttonOptions[id] = nil
end

M.isActive = isActive
M.setActive = setActive
M.setDefaultsForFreeroam = setDefaultsForFreeroam
M.setDefaultsForCareer = setDefaultsForCareer
M.setDefaultsForTutorial = setDefaultsForTutorial
M.setEverythingActive = setEverythingActive
M.deactivateAllButtons = deactivateAllButtons
M.addButton = addButton
M.removeButtonById = removeButtonById
M.getButtonActiveById = getButtonActiveById
M.setButtonActiveById = setButtonActiveById
M.setButtonEnabledById = setButtonEnabledById


-- counter utility

local function setButtonLimits(limits)
  for _, o in pairs(buttonOptions) do o.limit = nil end
  for id, limit in pairs(limits or {}) do
    if limit == -1 then
      buttonOptions[id].limit = nil
    else
      buttonOptions[id].limit = limit
    end
  end
end

local function resetButtonLimitCounters(onlyFor)
  for id, o in pairs(buttonOptions) do
    if not onlyFor or onlyFor[id] then
      o.count = 0
    end
  end
end

local function getButtonLimitsAndCounts()
  local ret = {}
  for id, o in pairs(buttonOptions) do
    ret[id] = {limit = o.limit, count = o.count}
  end
  return ret
end

M.setButtonLimits = setButtonLimits
M.resetButtonLimitCounters = resetButtonLimitCounters
M.getButtonLimitsAndCounts = getButtonLimitsAndCounts

-- serialization
local function serializeState()
  local ret = {
    active = active,
    buttons = {}
  }
  for id, btn in pairs(buttonOptions) do
    ret.buttons[id] = btn.active or false
  end
  return ret
end
local function deserializeState(data)
  active = data.active
  for id, btnActive in pairs(data.buttons or {}) do
    setButtonActiveById(id, btnActive)
  end
end
M.serializeState = serializeState
M.deserializeState = deserializeState

-- this is the actual recovery process. create a snapshot before the fadeing starts
local currentRecoveryOptionId = nil
local currentRecoveryOptionTarget = nil
local fadeDuration = 0.3
local function buttonPressed(buttonId, target)
  if career_career and career_career.isActive() and not gameplay_walk.isWalking() and not gameplay_missions_missionManager.getForegroundMissionId() then
    core_vehicleBridge.executeAction(getPlayerVehicle(0), 'createPartConditionSnapshot', "beforeTeleport")
    core_vehicleBridge.executeAction(getPlayerVehicle(0), 'setPartConditionResetSnapshotKey', "beforeTeleport")
  end

  currentRecoveryOptionId = buttonId
  currentRecoveryOptionTarget = target
  if buttonOptions[buttonId].fadeActive then
    core_vehicleBridge.requestValue(getPlayerVehicle(0), function()
      if buttonOptions[buttonId].fadeStartSound then
        Engine.Audio.playOnce('AudioGui',buttonOptions[buttonId].fadeStartSound)
      end
      ui_fadeScreen.start(fadeDuration)
    end , 'ping')
  else
    M.handleCurrRecoveryOption()
  end
end

local popupData
local function onPopupClosed()
  currentRecoveryOptionId = nil
  popupData = nil
  simTimeAuthority.pause(false)
end

local function handleCurrRecoveryOption()
  if not currentRecoveryOptionId then return end
  local option = buttonOptions[currentRecoveryOptionId]
  extensions.hook("onRecoveryPromptButtonPressed", currentRecoveryOptionId)
  if option then
    option.atFadeFunction(currentRecoveryOptionTarget)
    if option.count then
      option.count = option.count + 1
    end
    if option.message then
      ui_message(option.message, 5, "recoveryPromptMessage")
    end
  else
    log("E","","Couldnt use recovery option. none was found for ID " .. currentRecoveryOptionId)
  end

  if option.fadeActive then
    ui_fadeScreen.stop(fadeDuration)
  end

  currentRecoveryOptionId = nil
  currentRecoveryOptionTarget = nil
  if not option.keepMenuOpen then
    onPopupClosed()
  end
  gameplay_markerInteraction.setForceReevaluateOpenPrompt()
    --extensions.hook("onCareerCustomTowHook")
end

local function onScreenFadeState(state)
  -- only proceed if we actually have a recovery request.
  handleCurrRecoveryOption()
end

local function getRecoveryTargets()
  if not gameplay_walk.isWalking() then
    return {{type = "vehicle", vehId = be:getPlayerVehicleID(0)}}
  end
  local vehInFront = gameplay_walk.getVehicleInFront()
  if vehInFront then
    return {
      {type = "vehicle", vehId = vehInFront:getId()},
      {type = "walk"}
    }
  else
    return {{type = "walk"}}
  end
end

local function sortByOrder(a,b) return a.order < b.order end
local function getButtonsForTarget(target)
  local buttons = {}
  for id, option in pairs(buttonOptions) do
    if (option.type or "none") == target.type and option.active then
      local add = true
      for key, cond in ipairs(option.includeConditions or {}) do
        add = cond(target.type, target.vehId)
      end
      if add then
        local enabled = type(option.enabled) == "function" and option.enabled(option, target) or option.enabled
        local reason = nil
        for key, cond in ipairs(option.enableConditions or {}) do
          local en, rs = cond(target.type, target.vehId)
          enabled = en and enabled
          reason = reason or rs
        end
        local label = type(option.label) == "function" and option.label(option, target) or option.label
        if option.limit then
          label = {txt = 'missions.missions.recoveryPrompt.remainingUses', context = {label = label, count = option.limit - option.count}}
          enabled = enabled and option.count < option.limit
        end

        local price = type(option.price) == "function" and option.price(target) or option.price
        local disableReason = reason or (not enabled and "Disabled")
        local uniqueID = "recovery_"..id .."_".. dumps(target)
        local btn = {
          label = label,
          luaCallback = function() core_recoveryPrompt.buttonPressed(id, target) end,
          order = option.order,
          startSlot = option.startSlot or 1,
          keepMenuOpen = option.keepMenuOpen,
          price = price,
          enabled = enabled,
          disableReason = disableReason,
          soundClass = (option.fadeStartSound and "bng_click_empty" or nil),
          icon = option.icon,
          confirmationText = option.confirmationText,
          ["goto"] = option["goto"],
          path = option.path,
          uniqueID = uniqueID,
        }
        if option.noUniqueID then
          btn.uniqueID = nil
        end
        table.insert(buttons, btn)
      end
    end
  end
  table.sort(buttons, sortByOrder)
  return buttons
end

local function createPopupData()
  if not active then popupData = nil return false end
  local buttons = {}
  local targets = getRecoveryTargets()
  for i, target in ipairs(targets) do
    for _, btn in ipairs(getButtonsForTarget(target)) do
      table.insert(buttons, btn)
    end
  end
  for _, btn in ipairs(getButtonsForTarget({type="none"})) do
    table.insert(buttons, btn)
  end
  if not next(buttons) then
    log("W","","Tried to open recovery prompt, but no buttons were active. Not opening prompt.")
    return false
  end

  if next(buttons) then
    buttons[1].default = true
  end

  -- TODO in the future the file could probably be refactored so we dont need popupData at all anymore, but for now it works
  popupData = {title = title or "Recovery Menu", buttons = buttons}
  return true
end

local function onResetGameplay(playerID)
  if active then
    local root = "/root/sandbox/quick/"
    if career_career.isActive() then
      root = "/root/sandbox/career/"
    end
    if gameplay_missions_missionManager.getForegroundMissionId() then
      root = "/root/sandbox/mission/"
    end
    core_quickAccess.setEnabled(true, root)
  end
end

local function addButtonsForLevel(level)
  for _, context in ipairs({
    {
      root = "/root/sandbox/career/",
      enabled = function() return career_career.isActive() and not gameplay_missions_missionManager.getForegroundMissionId() end,
    },
    {
      root = "/root/sandbox/mission/",
      enabled = function() return gameplay_missions_missionManager.getForegroundMissionId() end,
    }
  }) do
    local root = context.root
    core_quickAccess.addEntry(
      {
        level = root .. (level or ""),
        generator = function(entries)
          if not context.enabled() then return end
          createPopupData()
          if not popupData then return end
          for _, button in ipairs(popupData.buttons or {}) do
            if button.path == level then
              local entry = {
                title = button.label,
                icon = button.icon,
                priority = 90,
                holdToClick = button.confirmationText,
                price = button.price,
                enabled = button.enabled,
                startSlot = button.startSlot,
                ["goto"] = button["goto"],
                disableReason = button.disableReason,
                uniqueID = button.uniqueID,
                ignoreAsRecentActionForCategory = "sandbox",
                onSelect = function()
                  button.luaCallback()
                  return button.keepMenuOpen and {"reload"} or {"hide"}
                end
              }
              table.insert(entries, entry)
            end
          end
        end
      }
    )

    if level then
      local name, icon = nil, nil
      if level == "taxi/" then
        name = "Taxi"
        icon = "taxiCheckerLamp"
      end
      if level == "towing/" then
        name = "Towing"
        icon = "tow"
      end
      core_quickAccess.addEntry({ level = root, title = name, icon = icon, ["goto"] = root ..level, uniqueID = name.."unique" })
    end
  end
end

local quickAccessInitialized
local function onBeforeRadialOpened()
  if quickAccessInitialized then return end
  quickAccessInitialized = true
  addButtonsForLevel(nil)
  addButtonsForLevel("taxi/")
  addButtonsForLevel("towing/")
end

local function onHideRadialMenu()
  popupData = nil
end

local function onQuickAccessLoaded()
  quickAccessInitialized = nil
end

M.addTowingButtons = addTowingButtons
M.addTaxiButtons = addTaxiButtons

M.buttonPressed = buttonPressed
M.onPopupClosed = onPopupClosed
M.onResetGameplay = onResetGameplay
M.onScreenFadeState = onScreenFadeState
M.handleCurrRecoveryOption = handleCurrRecoveryOption
M.uiPopupButtonPressed = uiPopupButtonPressed
M.uiPopupCancelPressed = uiPopupCancelPressed

M.onCareerModulesActivated = onCareerModulesActivated
M.onClientStartMission = onClientStartMission
M.onBeforeRadialOpened = onBeforeRadialOpened
M.onHideRadialMenu = onHideRadialMenu
M.onQuickAccessLoaded = onQuickAccessLoaded
return M