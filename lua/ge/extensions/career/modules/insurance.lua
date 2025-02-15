-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

M.dependencies = {'career_career', 'career_modules_payment', 'career_modules_playerAttributes'}

local plInsuranceDataFileName = "insurance"

local metersDrivenSinceLastPay = 0
local bonusDecrease = 0.05
local policyEditTime = 600 -- have to wait between perks editing
local testDriveClaimPrice = {
    money = {
        amount = 500,
        canBeNegative = true
    }
}
local minimumPolicyScore = 0.5
local quickRepairExtraPrice = 1000

-- loaded data
local availablePerks = {} -- to avoid copy pasting data in policies.json, this table comprises perks niceName and descriptions
local availablePolicies = {} -- the default insurance data in game folder

local plHistory = {} -- claims, tickets ...
local plPoliciesData = {} -- the player's saved insurance policies data
local insuredInvVehs = {} -- inventoryVehId with insurance id {invVehId : policyId}
local policyTows = {} -- policyId with tow count {policyId : towCount}

-- to calculate distance driven
local vec3Zero = vec3(0, 0, 0)
local lastPos = vec3(0, 0, 0)

-- helpers
-- this table represents the most commonly accessed insurance data of the current vehicle the player is driving
local currApplicablePolicyId = -1

local repairOptions = {
    repairNoInsurance = function(invVehInfo)
        local repairDetails = career_modules_valueCalculator.getRepairDetails(invVehInfo)
        return {
            repairTime = repairDetails.repairTime,
            isPolicyRepair = false,
            repairName = translateLanguage("insurance.repairOptions.repairNoInsurance.name",
                "insurance.repairOptions.repairNoInsurance.name", true),
            priceOptions = {{ -- one choice
            {
                text = "",
                price = {
                    money = {
                        amount = repairDetails.price,
                        canBeNegative = false
                    }
                }
            }}}
        }
    end,
    normalRepair = function(invVehInfo)
        return {
            repairTime = math.min(M.getPlPerkValue(insuredInvVehs[tostring(invVehInfo.id)], "repairTime"),
            career_modules_valueCalculator.getRepairDetails(invVehInfo).repairTime),
            isPolicyRepair = true,
            repairName = translateLanguage("insurance.repairOptions.normalRepair.name",
                "insurance.repairOptions.normalRepair.name", true),
            priceOptions = {{ -- one choice
            {
                text = "",
                price = {
                    money = {
                        amount = M.getActualRepairPrice(invVehInfo),
                        canBeNegative = true
                    }
                }
            }}}
        }
    end,
    quickRepair = function(invVehInfo)
        return {
            repairTime = 0,
            isPolicyRepair = true,
            repairName = translateLanguage("insurance.repairOptions.quickRepair.name",
                "insurance.repairOptions.quickRepair.name", true),
            priceOptions = {{{
                text = "",
                price = {
                    money = {
                        amount = M.getActualRepairPrice(invVehInfo),
                        canBeNegative = true
                    }
                }
            }, {
                text = "as extra fee",
                price = {
                    money = {
                        amount = quickRepairExtraPrice,
                        canBeNegative = true
                    }
                }
            }}, {{
                text = "",
                price = {
                    vouchers = {
                        amount = 1,
                        canBeNegative = false
                    }
                }
            }}}
        }
    end,
    instantFreeRepair = function(invVehInfo)
        return {
            hideInComputer = true,
            repairTime = 0,
            skipSound = true,
            paintRepair = true
        }
    end
}

-- gestures are things insurances give you when you've been driving well for a while
local gestures = {
    policyScoreDecrease = function(data)
        local plPolicyData = data.plPolicyData
        if plPolicyData.bonus <= minimumPolicyScore then
            return
        end

        local everyGestures = plHistory.policyHistory[plPolicyData.id].policyScoreDecreases
        local lastGesture = everyGestures[#everyGestures]
        if plPolicyData.totalMetersDriven - math.max(data.distRef, lastGesture and lastGesture.happenedAt or 0) >
            M.getPlPerkValue(plPolicyData.id, "renewal") / 2 then
            plPolicyData.bonus = math.floor(plPolicyData.bonus * (1 - bonusDecrease) * 100) / 100
            if plPolicyData.bonus < minimumPolicyScore then
                plPolicyData.bonus = minimumPolicyScore
            end

            table.insert(plHistory.policyHistory[plPolicyData.id].policyScoreDecreases, {
                happenedAt = plPolicyData.totalMetersDriven,
                time = os.time(),
                value = plPolicyData.bonus
            })

            ui_message(string.format(
                "Insurance policy '%s' score decreased to %0.2f due to not having submitted any claim for a while",
                availablePolicies[plPolicyData.id].name, plPolicyData.bonus), 6, "Insurance", "info")
        end
    end,
    freeRepair = function(data)
        local plPolicyData = data.plPolicyData
        if plPolicyData.hasFreeRepair then
            return
        end

        local everyGestures = plHistory.policyHistory[plPolicyData.id].freeRepairs
        local lastGesture = everyGestures[#everyGestures]
        if plPolicyData.totalMetersDriven - math.max(data.distRef, lastGesture and lastGesture.happenedAt or 0) >
            availablePolicies[plPolicyData.id].gestures.freeRepair.distance then
            plPolicyData.hasFreeRepair = true

            table.insert(plHistory.policyHistory[plPolicyData.id].freeRepairs, {
                happenedAt = plPolicyData.totalMetersDriven,
                time = os.time()
            })

            ui_message(string.format(
                "Insurance policy '%s' has given you a repair forgiveness due to not having submitted any claim for a while",
                availablePolicies[plPolicyData.id].name), 6, "Insurance", "info")
        end
    end
}

-- helper
local function getPlPerkValue(policyId, perkName)
    if policyId > -1 then -- -1 means not insured
        return availablePolicies[policyId].perks[perkName].changeability.changeParams.choices[plPoliciesData[policyId]
                   .perks[perkName]]
    end
end

local function savePoliciesData(currentSavePath)
    local dataToSave = {
        plPoliciesData = plPoliciesData,
        insuredInvVehs = insuredInvVehs,
        plHistory = plHistory,
        policyTows = policyTows or {}
    }

    career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/" .. plInsuranceDataFileName .. ".json", dataToSave,
        true)
end

-- change the current applicable insurance to the one of the switched vehicle's
-- only works with owned vehicle
local function initCurrInsurance()
    local newid = be:getPlayerVehicleID(0)
    if newid == -1 then
        return
    end

    if gameplay_walk.isWalking() then
        currApplicablePolicyId = -1
    else
        local invVehId = career_modules_inventory.getInventoryIdFromVehicleId(newid)
        if invVehId then
            local owned = career_modules_inventory.getVehicles()[invVehId].owned
            if #plPoliciesData > 0 and owned then
                currApplicablePolicyId = insuredInvVehs[tostring(invVehId)]
                local plPolicyData = plPoliciesData[currApplicablePolicyId]
                metersDrivenSinceLastPay = plPolicyData.totalMetersDriven % getPlPerkValue(plPolicyData.id, "renewal")
                local newVeh = scenetree.findObjectById(newid)
                if newVeh then
                    lastPos:set(newVeh:getPosition())
                end
            else
                currApplicablePolicyId = -1
            end
        else
            currApplicablePolicyId = -1
        end
    end
end

-- TODO : make the saves way more backward compatible (perks values, missing and new history...)
-- resetSomeData is there only for career debug, if true, will reset plPoliciesData and plHistory
local function loadPoliciesData(resetSomeData)
    if resetSomeData == nil then
        resetSomeData = false
    end

    local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
    if not saveSlot then
        return
    end

    local policiesJsonData = jsonReadFile("gameplay/insurance/policies.json")
    availablePolicies = policiesJsonData.insurancePolicies
    availablePerks = policiesJsonData.perks

    -- in order to avoid copying/pasting the common properties of every perk in policies.json, we define them once in availablePerks and then add those fields to each perk
    for _, policyInfo in pairs(availablePolicies) do
        local t = translateLanguage(policyInfo.name, policyInfo.name, true)
        policyInfo.name = translateLanguage(policyInfo.name, policyInfo.name, true)
        policyInfo.description = translateLanguage(policyInfo.description, policyInfo.description, true)
        policyInfo.perkPriceScale = {} -- perks prices have to scale along with the renewal distance.
        for index, price in pairs(policyInfo.perks.renewal.changeability.changeParams.premiumInfluence) do
            table.insert(policyInfo.perkPriceScale,
                price / policyInfo.perks.renewal.changeability.changeParams.premiumInfluence[1])
        end
        for perkName, perkInfo in pairs(policyInfo.perks) do
            perkInfo.name = perkName
            perkInfo.unit = availablePerks[perkName].unit
            perkInfo.niceName = translateLanguage(availablePerks[perkName].niceName, availablePerks[perkName].niceName,
                true)
            perkInfo.desc = translateLanguage(availablePerks[perkName].desc, availablePerks[perkName].desc, true)
        end
    end

    local savedPlPolicyData =
        (savePath and jsonReadFile(savePath .. "/career/" .. plInsuranceDataFileName .. ".json")) or {}

    local saveInfo = savePath and jsonReadFile(savePath .. "/info.json")
    if saveInfo and saveInfo.version < 42 then
        -- any save before 42 doesnt load the vehicles
        savedPlPolicyData.insuredInvVehs = {}
    end

    local isFirstLoadEver = not savedPlPolicyData.plPoliciesData or #savedPlPolicyData.plPoliciesData == 0
    if isFirstLoadEver then -- first load ever
        insuredInvVehs = {}
        plHistory = {
            generalHistory = { -- history that cannot be attached to any policy
                ticketEvents = {},
                testDriveClaims = {}
            },
            policyHistory = {} -- history that is attachable to a policy, like repair claims..
        }
        plPoliciesData = {}
        policyTows = {}
    else
        insuredInvVehs = savedPlPolicyData.insuredInvVehs
        plHistory = savedPlPolicyData.plHistory
        plPoliciesData = savedPlPolicyData.plPoliciesData
        if not savedPlPolicyData.policyTows then
            for policyId, policyData in pairs(plPoliciesData) do
                policyTows[policyId] = availablePolicies[policyId].perks["roadsideAssistance"].changeability.changeParams.choices[policyData.perks.roadsideAssistance]
            end
        else
            policyTows = savedPlPolicyData.policyTows
        end
    end

    -- backward compatibility along with first load default data
    for _, policyInfo in pairs(availablePolicies) do

        local updatedPerksData = {}
        for perkName, perkInfo in pairs(policyInfo.perks) do -- if new perks has been introduced, or modified
            if #plPoliciesData == 0 or not plPoliciesData[policyInfo.id] or
                not plPoliciesData[policyInfo.id].perks[perkName] then
                updatedPerksData[perkName] = perkInfo.baseValue -- define perks base value
            else
                updatedPerksData[perkName] = math.min(#policyInfo.perks[perkName].changeability.changeParams.choices,
                    plPoliciesData[policyInfo.id].perks[perkName]) -- if we remove options from a perk, need to make sure the old choice index deosn't exceed the new limit
            end
        end

        if not plPoliciesData[policyInfo.id] or resetSomeData then -- if new policy has been introduced, create new default data
            plPoliciesData[policyInfo.id] = {
                id = policyInfo.id,
                nextPolicyEditTimer = 0,
                totalMetersDriven = 0,
                bonus = 1,
                hasFreeRepair = false,
                owned = false
            }

            plHistory.policyHistory[policyInfo.id] = {
                id = policyInfo.id,
                policyScoreDecreases = {}, -- every time the policy has decrease the bonus because the player has driven well for a while
                freeRepairs = {}, -- isn't actually free, repairs that don't increase the premium
                claims = {},
                initialPurchase = {
                    purchaseTime = -1,
                    forFree = false
                },
                changedCoverage = {},
                renewedPolicy = {}
            }
        end
        local policyTowsValue = getPlPerkValue(policyInfo.id, "roadsideAssistance")
        plPoliciesData[policyInfo.id].perks = updatedPerksData
        policyTows[policyInfo.id] = policyTows[policyInfo.id] - policyTowsValue + getPlPerkValue(policyInfo.id, "roadsideAssistance")
    end

    if isFirstLoadEver then
        M.purchasePolicy(1, true) -- give the player the basic insurance
    end

    initCurrInsurance()
end

-- for now every part needs to be replaced
local function getDamagedParts(partConditions)
    local damagedParts = {
        partsToBeReplaced = {},
        partsToBeRepaired = {}
    }
    for partName, info in pairs(partConditions) do
        if info.integrityValue and info.integrityValue == 0 then
            table.insert(damagedParts.partsToBeReplaced, partName)
        end
    end
    return damagedParts
end

local function getNumberOfBrokenParts(partConditions)
    local damagedParts = getDamagedParts(partConditions)
    return #damagedParts.partsToBeRepaired + #damagedParts.partsToBeReplaced
end

local function purchasePolicy(policyId, forFree)
    if forFree == nil then
        forFree = false
    end
    local policyInfo = availablePolicies[policyId]
    local label = string.format("Bought insurance tier '%s'", policyInfo.name)

    if career_modules_payment.pay({
        money = {
            amount = forFree == true and 0 or policyInfo.initialBuyPrice,
            canBeNegative = false
        }
    }, {
        label = label
    }) then
        -- if we buy a policy that is needed for an uninsured vehicle, then apply it
        for invVehId, invVehPolicyId in pairs(insuredInvVehs) do
            if invVehPolicyId < 0 and math.abs(invVehPolicyId) == policyId then -- if not insured
                insuredInvVehs[tostring(invVehId)] = policyId
            end
        end

        -- if the bought policy is an upgrade, then move inventory vehicles from old policy to the upgraded policy
        if policyInfo.upgradedToFrom then
            for invVehId, invVehPolicyId in pairs(insuredInvVehs) do
                if invVehPolicyId == policyInfo.upgradedToFrom then
                    insuredInvVehs[tostring(invVehId)] = policyId
                end
            end
        end

        plPoliciesData[policyId].owned = true
        plHistory.policyHistory[policyId].initialPurchase = {
            purchaseTime = os.time(),
            forFree = forFree
        }
        M.sendUIData()
    end
end

local function inventoryVehNeedsRepair(vehInvId)
    local vehInfo = career_modules_inventory.getVehicles()[vehInvId]
    if not vehInfo then
        return
    end
    return career_modules_valueCalculator.partConditionsNeedRepair(vehInfo.partConditions)
end

local function repairPartConditions(data)
    if not data.partConditions then
        return
    end
    if data.paintRepair == nil then
        data.paintRepair = true
    end
    for name, info in pairs(data.partConditions) do
        if info.integrityValue then
            if info.integrityState and info.integrityState.energyStorage then
                -- keep the fuel level
                for _, tankData in pairs(info.integrityState.energyStorage) do
                    for attributeName, value in pairs(info.integrityState.energyStorage) do
                        if attributeName ~= "storedEnergy" then
                            tankData[attributeName] = nil
                        end
                    end
                end
            else
                if info.integrityValue == 0 and info.visualState then
                    if info.visualState.paint and info.visualState.paint.originalPaints then
                        if data.paintRepair then
                            info.visualState = {
                                paint = {
                                    originalPaints = info.visualState.paint.originalPaints
                                }
                            }
                        else
                            local numberOfPaints = tableSize(info.visualState.paint.originalPaints)
                            info.visualState = {
                                paint = {
                                    originalPaints = {}
                                }
                            }
                            for index = 1, numberOfPaints do
                                info.visualState.paint.originalPaints[index] = career_modules_painting.getPrimerColor()
                            end
                        end
                        info.visualState.paint.odometer = 0
                    else
                        -- if we dont have a replacement paint, just set visualState to nil
                        info.visualState = nil
                        info.visualValue = 1
                    end
                    info.odometer = 0
                end
                info.integrityState = nil
                info.integrityValue = 1
            end
        end
    end
end

-- when you damage a test drive vehicle, insurance needs to know
local function makeTestDriveDamageClaim(vehInfo)
    testDriveClaimPrice = {
        money = {
            amount = math.floor(vehInfo.value * 5) / 100,
            canBeNegative = true
        }
    }
    local label = string.format("Test drive vehicle damaged: -%i$", testDriveClaimPrice.money.amount)
    career_modules_payment.pay(testDriveClaimPrice, {
        label = label,
        tags = {"insurance", "repair", "testDrive"}
    })

    local rateIncrease = 1 + math.floor(
        ((vehInfo.value * 0.05) / ((700 - M.calculatePremiumDetails(1).perksPriceDetails['repairTime'].price) * 100)) *
            100) / 100
    local policyId = 1
    if (vehInfo.value > 80000) then
        policyId = 2
    end
    plPoliciesData[policyId].bonus = math.floor(plPoliciesData[policyId].bonus * rateIncrease * 100) / 100

    label = label .. string.format("\nYour insurance went up to :) %0.2f", plPoliciesData[policyId].bonus)
    ui_message(label, 5, "Insurance", "info")

    local claim = {
        time = os.time(),
        amount = math.floor(vehInfo.value * 5) / 100,
        policyScore = plPoliciesData[policyId].bonus,
        reason = "Test drive vehicle damaged:\n" .. vehInfo.name,
        policyId = policyId
    }

    table.insert(plHistory.generalHistory.testDriveClaims, claim)
end

local function getPolicyIdFromInvVehId(invVehId)
    return insuredInvVehs[tostring(invVehId)]
end

local function getPolicyScore(invVehId)
    local policyId = 1
    if invVehId then
        policyId = getPolicyIdFromInvVehId(invVehId)
    end
    return plPoliciesData[policyId].bonus
end

local function changePolicyScore(invVehId, rate, operation)
    if not operation then
        operation = function(bonus, rate)
            return bonus * rate
        end
    end
    local policyId
    if invVehId then
        policyId = getPolicyIdFromInvVehId(invVehId)
    end
    if not policyId then
        policyId = 1
    end
    plPoliciesData[policyId].bonus = math.max(operation(math.floor(plPoliciesData[policyId].bonus * 100) / 100, rate),
        minimumPolicyScore)
    return plPoliciesData[policyId].bonus
end

local function makeRepairClaim(invVehId, price, rateIncrease)
    if rateIncrease == nil then
        rateIncrease = 1 + bonusDecrease
    end
    local policyId = insuredInvVehs[tostring(invVehId)]
    local hasUsedFreeRepair = false

    if plPoliciesData[policyId].hasFreeRepair then
        plPoliciesData[policyId].hasFreeRepair = false
        hasUsedFreeRepair = true
    else
        plPoliciesData[policyId].bonus = math.min(math.floor(plPoliciesData[policyId].bonus * rateIncrease * 100) / 100, 35)
        local label = string.format("Your Insurance Increased by " .. rateIncrease .. " to " ..
                                        plPoliciesData[policyId].bonus)
        ui_message(label, 5, "Insurance", "info")
    end

    local claim = {
        deductible = price,
        policyScore = plPoliciesData[policyId].bonus,
        freeRepair = hasUsedFreeRepair,
        vehInfo = {
            niceName = career_modules_inventory.getVehicles()[invVehId].niceName
        },
        happenedAt = plPoliciesData[policyId].totalMetersDriven, -- to know when the claim happened, so can later on know how long the player hasn't made a claim for, and give him a bonus
        time = os.time()
    }

    career_modules_inventory.addAccident(invVehId)

    table.insert(plHistory.policyHistory[policyId].claims, claim)
    extensions.hook("onInsuranceRepairClaim")
end

local function onAfterVehicleRepaired(vehInfo)
    career_modules_inventory.setVehicleDirty(vehInfo.id)
    local vehId = career_modules_inventory.getVehicleIdFromInventoryId(vehInfo.id)
    if vehId then
        career_modules_fuel.minimumRefuelingCheck(vehId)
        if gameplay_walk.isWalking() then
            local veh = be:getObjectByID(vehId)
            gameplay_walk.setRot(veh:getPosition() - getPlayerVehicle(0):getPosition())
        end
    end
end

local startRepairVehInfo
local function startRepairDelayed(vehInfo, repairTime)
    if career_modules_inventory.getVehicleIdFromInventoryId(vehInfo.id) then -- vehicle is currently spawned
        if vehInfo.id == career_modules_inventory.getCurrentVehicle() then
            startRepairVehInfo = {
                inventoryId = vehInfo.id,
                repairTime = repairTime
            }
            gameplay_walk.setWalkingMode(true)
            return -- This function gets called again after the player left the vehicle
        end
        career_modules_inventory.removeVehicleObject(vehInfo.id)
    end
    career_modules_inventory.delayVehicleAccess(vehInfo.id, repairTime, "repair")
    onAfterVehicleRepaired(vehInfo)
end

local function missionStartRepairCallback(vehInfo)
    guihooks.trigger('MenuOpenModule', 'menu.careermission')
    guihooks.trigger('gameContextPlayerVehicleDamageInfo', {
        needsRepair = inventoryVehNeedsRepair(vehInfo.id)
    })
end

local function startRepairInstant(vehInfo, callback, skipSound)
    if career_modules_inventory.getVehicleIdFromInventoryId(vehInfo.id) then -- vehicle is currently spawned
        career_modules_inventory.spawnVehicle(vehInfo.id, 2, callback and function()
            callback(vehInfo)
        end)
    end
    onAfterVehicleRepaired(vehInfo)

    if not skipSound then
        Engine.Audio.playOnce('AudioGui', 'event:>UI>Missions>Vehicle_Recover')
    end
end

local function mergeRepairOptionPrices(price)
    local pricesList = {}

    if not price then
        return
    end

    for _, data in pairs(price) do
        table.insert(pricesList, data.price)
    end

    local merged = {}
    local canBeNegative
    for _, price in pairs(pricesList) do
        for currency, value in pairs(price) do
            if merged[currency] then
                merged[currency].amount = merged[currency].amount + value.amount
                merged[currency].canBeNegative = value.canBeNegative and merged[currency].canBeNegative
                canBeNegative = canBeNegative and value.canBeNegative
            else
                merged[currency] = {
                    amount = value.amount,
                    canBeNegative = value.canBeNegative
                }
                canBeNegative = value.canBeNegative
            end
        end
    end
    return merged, canBeNegative
end

local function getRateIncrease(vehId, fullcost, paid)
    local covering = math.max(fullcost - paid, 0)
    return 1 + math.floor((covering /
                              ((700 - M.calculatePremiumDetails(insuredInvVehs[tostring(vehId)]).perksPriceDetails['repairTime'].price) * 100)) * 100) / 100
end

local function startRepair(inventoryId, repairOptionData, callback)
    inventoryId = inventoryId or career_modules_inventory.getCurrentVehicle()
    repairOptionData = (repairOptionData and type(repairOptionData) == "table") and repairOptionData or {}
    repairOptionData.name = repairOptionData.name or "instantFreeRepair"

    local vehInfo = career_modules_inventory.getVehicles()[inventoryId]
    if not vehInfo then
        return
    end

    local repairOption = repairOptions[repairOptionData.name](vehInfo)
    local price = mergeRepairOptionPrices(repairOption.priceOptions and
                                              repairOption.priceOptions[repairOptionData.priceOption or 1] or nil)

    if price then
        career_modules_payment.pay(price, {
            label = "Repaired a vehicle: " .. (vehInfo.niceName or "(Unnamed Vehicle)")
        })
        Engine.Audio.playOnce('AudioGui', 'event:>UI>Career>Buy_01')
    end

    if repairOption.isPolicyRepair then -- the player can repair on his own without insurance
        local increase = nil
        if price.money then
            increase = getRateIncrease(inventoryId, repairOptionData.fullCost or 0, price.money.amount)
        end
        makeRepairClaim(inventoryId, price, increase)
    end

    -- the actual repair
    local paintRepair =
        repairOption.paintRepair or getPlPerkValue(insuredInvVehs[tostring(inventoryId)], "paintRepair") == true
    local data = {
        partConditions = vehInfo.partConditions,
        paintRepair = paintRepair
    }
    repairPartConditions(data)

    if repairOption.repairTime > 0 then
        startRepairDelayed(vehInfo, repairOption.repairTime)
    else
        startRepairInstant(vehInfo, callback, repairOption.skipSound)
    end
end

local function startRepairInGarage(vehInvInfo, repairOptionData)
    local repairOption = repairOptions[repairOptionData.name](vehInvInfo)

    local vehId = career_modules_inventory.getVehicleIdFromInventoryId(vehInvInfo.id)
    extensions.hook("onRepairInGarage", vehInvInfo, repairOptionData)
    return startRepair(vehInvInfo.id, repairOptionData, (vehId and repairOption.repairTime <= 0) and function(vehInfo)
        local vehObj = be:getObjectByID(vehId)
        if not vehObj then
            return
        end
        freeroam_facilities.teleportToGarage(career_modules_inventory.getClosestGarage().id, vehObj, false)
    end)
end

local function genericVehNeedsRepair(vehId, callback)
    local veh = be:getObjectByID(vehId)
    if not veh then
        return
    end
    local label = logBookLabel or "Repaired vehicle"
    core_vehicleBridge.requestValue(veh, function(res)
        local needsRepair = career_modules_valueCalculator.partConditionsNeedRepair(res.result)
        callback(needsRepair)
    end, 'getPartConditions')
end

-- used to renew insurance policies
local function updateDistanceDriven(dtReal)
    local plId = be:getPlayerVehicleID(0)
    if not career_modules_inventory.getInventoryIdFromVehicleId(plId) then
        return
    end

    local vehicleData = map.objects[plId]
    if not vehicleData then
        return
    end

    if lastPos ~= vec3Zero then
        local dist = lastPos:distance(vehicleData.pos)
        if (dist < 0.001) then
            return
        end -- should use some dt to more accurately discard low numbers when stationary
        plPoliciesData[currApplicablePolicyId].totalMetersDriven =
            plPoliciesData[currApplicablePolicyId].totalMetersDriven + dist
        metersDrivenSinceLastPay = metersDrivenSinceLastPay + dist
    end

    lastPos:set(vehicleData.pos)
end

local function calculatePremiumDetails(policyId, overiddenPerks)
    local premiumDetails = {
        perksPriceDetails = {},
        price = 0
    }
    local policyInfo = availablePolicies[policyId]
    local renewal = {}

    local perks = {}
    for _, perk in pairs(policyInfo.perks) do
        table.insert(perks, perk)
    end

    local perkPriceScale = policyInfo.perkPriceScale[tableFindKey(
        policyInfo.perks.renewal.changeability.changeParams.choices, (overiddenPerks and overiddenPerks ~= nil) and
            overiddenPerks.renewal or getPlPerkValue(policyInfo.id, "renewal"))]

    for _, perkData in pairs(perks) do
        local perkValue = getPlPerkValue(policyId, perkData.name)
        if overiddenPerks and overiddenPerks[perkData.name] ~= nil then
            perkValue = overiddenPerks[perkData.name]
        end

        local value
        if perkData.changeability.changeable then
            local index = tableFindKey(perkData.changeability.changeParams.choices, perkValue)
            value = perkData.changeability.changeParams.premiumInfluence[index]
            if perkData.name == "renewal" then
                renewal = value
            end
        else
            value = perkData.changeability.premiumInfluence
        end
        value = value * perkPriceScale
        premiumDetails.price = premiumDetails.price + value
        premiumDetails.perksPriceDetails[perkData.name] = {
            perk = perkData,
            price = value
        }
    end
    premiumDetails.perksPriceDetails["renewal"].price = (renewal - 1) * premiumDetails.price
    premiumDetails.price = math.floor(premiumDetails.price * renewal * 100) / 100
    return premiumDetails
end

local function getPremiumWithPolicyScore(policyId)
    local basePremium = calculatePremiumDetails(policyId).price
    local bonus = plPoliciesData[policyId].bonus
    local cappedBonus = math.min(bonus, 35) -- Cap the bonus at 35
    return basePremium * cappedBonus
end

-- overiddenPerks param is there only for the UI. Allows to calculate the premium of a non-existing policy
local function calculatePolicyPremium(policyId, overiddenPerks)
    local policyInfo = availablePolicies[policyId]
    local plPolicyInfo = plPoliciesData[policyId]
    local premium = 0

    for perkName, perkData in pairs(policyInfo.perks) do
        local perkValue = getPlPerkValue(policyId, perkName)

        if overiddenPerks and overiddenPerks[perkName] ~= nil then
            perkValue = overiddenPerks[perkName]
        end

        if perkData.changeability.changeable then
            local index = tableFindKey(perkData.changeability.changeParams.choices, perkValue)
            premium = premium + perkData.changeability.changeParams.premiumInfluence[index]
        else
            premium = premium + perkData.changeability.premiumInfluence
        end
    end

    return premium * plPolicyInfo.bonus
end

-- make player pay for insurance renewal every X meters
local function checkRenewPolicy()
    local plPolicyData = plPoliciesData[currApplicablePolicyId]
    local renewalDist = getPlPerkValue(currApplicablePolicyId, "renewal")
    if metersDrivenSinceLastPay > renewalDist then
        -- pay premium
        local premium = getPremiumWithPolicyScore(currApplicablePolicyId)

        table.insert(plHistory.policyHistory[plPolicyData.id].renewedPolicy, {
            time = os.time(),
            price = premium
        })

        local label = string.format("Insurance renewed! Tier: %s (-%0.2f$)",
            availablePolicies[currApplicablePolicyId].name, premium)
        local logBookLabel =
            string.format("Insurance renewed! Tier: %s", availablePolicies[currApplicablePolicyId].name)
        career_modules_payment.pay({
            money = {
                amount = premium,
                canBeNegative = true
            }
        }, {
            label = logBookLabel
        })
        ui_message(label, 5, "Insurance", "info")
        
        policyTows[currApplicablePolicyId] = getPlPerkValue(currApplicablePolicyId, "roadsideAssistance")
        metersDrivenSinceLastPay = 0
    end
end

local function getActualRepairPrice(vehInvInfo)
    -- This function returns the actual price of the repair, taking into account the deductible and the price of the repair without the policy  
    -- You will pay the lower value as a deductible is the max you will pay not the lowest
    local price = career_modules_valueCalculator.getInventoryVehicleValue(vehInvInfo.id, true) *
                      (getPlPerkValue(insuredInvVehs[tostring(vehInvInfo.id)], "deductible") / 100)
    return math.floor(math.min(price * 100, career_modules_valueCalculator.getRepairDetails(vehInvInfo).price * 80)) / 100
end

local originComputerId
local vehicleToRepairData
-- used in the garage computer
local function getRepairData()
    local data = {}
    local vehInfo = deepcopy(vehicleToRepairData)
    local policyId = insuredInvVehs[tostring(vehInfo.id)]
    local policyInfo = {
        hasFreeRepair = plPoliciesData[policyId].hasFreeRepair,
        name = availablePolicies[policyId].name
    }

    local repairOptionsSanitized = {}
    for repairOptionName, repairOptionFunction in pairs(repairOptions) do
        local repairOption = repairOptionFunction(vehInfo)
        if repairOption and not repairOption.hideInComputer then
            local repairOptionSanitized = {
                priceOptions = {},
                isPolicyRepair = repairOption.isPolicyRepair,
                repairName = repairOption.repairName,
                repairTime = repairOption.repairTime
            }
            for _, priceOption in pairs(repairOption.priceOptions) do
                local mergedPrice, canBeNegative = mergeRepairOptionPrices(priceOption)
                table.insert(repairOptionSanitized.priceOptions, {
                    prices = deepcopy(priceOption),
                    canPay = career_modules_payment.canPay(mergedPrice),
                    canBeNegative = canBeNegative
                })
            end
            repairOptionsSanitized[repairOptionName] = repairOptionSanitized
        end
    end
    local fullcost = 0
    local deductible = 0

    if repairOptionsSanitized["repairNoInsurance"].priceOptions[1].prices[1].price.money.amount then
        fullcost = repairOptionsSanitized["repairNoInsurance"].priceOptions[1].prices[1].price.money.amount
    end
    if repairOptionsSanitized["normalRepair"].priceOptions[1].prices[1].price.money.amount then
        deductible = repairOptionsSanitized["normalRepair"].priceOptions[1].prices[1].price.money.amount
    end

    data.policyInfo = policyInfo
    data.policyScoreInfluence = math.floor(((getRateIncrease(vehicleToRepairData.id, fullcost, deductible) *
                                               plPoliciesData[policyId].bonus) - plPoliciesData[policyId].bonus) * 100) /
                                    100
    data.repairOptions = repairOptionsSanitized
    data.baseDeductible = {
        money = {
            amount = getPlPerkValue(policyId, "deductible"),
            canBeNegative = true
        }
    }
    data.vehicle = vehInfo
    data.playerAttributes = career_modules_playerAttributes.getAllAttributes()
    data.numberOfBrokenParts = career_modules_valueCalculator.getNumberOfBrokenParts(
        career_modules_inventory.getVehicles()[vehInfo.id].partConditions)
    return data
end

local insurancePoliciesMenuOpen = false
-- can't edit policy perks instantly without delays, or players will cheat the system
local function updateEditPolicyTimer(dtReal)
    local sendDataToUI = false
    for _, plPolicyData in pairs(plPoliciesData) do
        if plPolicyData.nextPolicyEditTimer > 0 then
            plPolicyData.nextPolicyEditTimer = plPolicyData.nextPolicyEditTimer - dtReal
            sendDataToUI = true
        end
    end
    if sendDataToUI and insurancePoliciesMenuOpen then
        M.sendUIData()
    end
end

-- gestures are commercial gestures, eg give the player a bonus after not having crashed for a while
local function checkPolicyGestures()
    local policyData = availablePolicies[currApplicablePolicyId]
    local plPolicyData = plPoliciesData[currApplicablePolicyId]
    for gestureName, _ in pairs(policyData.gestures) do
        local data = {
            plPolicyData = plPolicyData,
            distRef = 0
        }

        local lastClaim =
            plHistory.policyHistory[currApplicablePolicyId].claims[#plHistory.policyHistory[currApplicablePolicyId]
                .claims]
        if lastClaim then
            data.distRef = lastClaim.happenedAt
        end

        gestures[gestureName](data)
    end
end

local function onUpdate(dtReal, dtSim, dtRaw)
    if not gameplay_missions_missionManager.getForegroundMissionId() and not gameplay_walk.isWalking() and
        currApplicablePolicyId > 0 then -- we don't track when in a mission
        checkRenewPolicy()
        checkPolicyGestures()
        updateDistanceDriven(dtReal)
    end
    updateEditPolicyTimer(dtReal)
end

local conditions = {
    applicableValue = function(data, values)
        if not data.vehValue then
            return false
        end
        if values.min and values.max then
            return data.vehValue >= values.min and data.vehValue <= values.max
        elseif values.min and not values.max then
            return data.vehValue >= values.min
        elseif values.max and not values.min then
            return data.vehValue <= values.max
        end
    end,
    population = function(data, values)
        if not data.population then
            return false
        end
        if values.min and values.max then
            return data.population >= values.min and data.population <= values.max
        elseif values.min and not values.max then
            return data.population >= values.min
        elseif values.max and not values.min then
            return data.population <= values.min
        end
    end,
    bodyStyles = function(data, values)
        if not data.bodyStyle then
            return false
        end
        for _, bodyStyle in pairs(values) do
            if data.bodyStyle[bodyStyle] then
                return true
            end
        end
        return false
    end,
    commercialClass = function(data, values)
        if not data.commercialClass then
            return false
        end
        for _, commercialClass in pairs(values) do
            if commercialClass == data.commercialClass then
                return true
            end
        end
    end
}

local function changeVehPolicy(invVehId, toPolicyId)
    if plPoliciesData[toPolicyId].owned then
        insuredInvVehs[tostring(invVehId)] = toPolicyId
        M.sendUIData()
    end
end

-- the actual logic for finding the best, minimum (cheapest) insurance policy for a vehicle
-- should always return at least one insurance policy, or we have a hole in insurance applicable conditions
local function getMinApplicablePolicyId(conditionData)
    -- First check if it's a commercial vehicle
    if conditionData.bodyStyle then
        for _, bodyStyle in pairs({"Bus", "Van", "Semi Truck"}) do
            if conditionData.bodyStyle[bodyStyle] then
                return 3  -- Commercial policy
            end
        end
    end

    -- If not commercial, check value for Daily Driver vs Prestige
    if conditionData.vehValue and conditionData.vehValue > 80000 then
        return 2  -- Prestige policy
    end

    return 1  -- Default to Daily Driver policy
end

local function getMinApplicablePolicyFromVehicleShoppingData(data)
    local conditionData = {
        vehValue = data.Value,
        population = data.Population,
        bodyStyle = (data.BodyStyle and data.BodyStyle) or data.aggregates["Body Style"]
    }
    if data["Commercial Class"] then
        conditionData.commercialClass = tonumber(string.match(data["Commercial Class"], "%d+"))
    end
    return availablePolicies[getMinApplicablePolicyId(conditionData)]
end

local function onEnterVehicleFinished()
    if startRepairVehInfo then
        local vehInfo = career_modules_inventory.getVehicles()[startRepairVehInfo.vehId]
        career_modules_inventory.removeVehicleObject(startRepairVehInfo.vehId)
        startRepairDelayed(vehInfo)
        startRepairVehInfo = nil
    end
end

local function hasLicensePlate(inventoryId)
    for partId, part in pairs(career_modules_partInventory.getInventory()) do
        if part.location == inventoryId then
            if string.find(part.name, "licenseplate") then
                return true
            end
        end
    end
end

local function getPlayerIsCop()
    local vehId = be:getPlayerVehicleID(0)
    if vehId and gameplay_traffic.getTrafficData()[vehId] then
        local role = gameplay_traffic.getTrafficData()[vehId].role.name
        return role == 'police'
    end
    return false
end

local offenseNames = {
    ["speeding"] = "Speeding",
    ["reckless"] = "Reckless Driving",
    ["intersection"] = "Failure to Yield",
    ["racing"] = "Felony Speeding",
    ["wrongWay"] = "Wrong Way",
    ["hitPolice"] = "Hitting a Police Vehicle"
}

local function onPursuitAction(vehId, data)
    if not gameplay_missions_missionManager.getForegroundMissionId() and vehId == be:getPlayerVehicleID(0) then
        if data.type == "arrest" then
            local fine = math.floor(data.score * 130) / 100

            local insuranceRate = 0

            local score = data.score

            if score <= 600 then
                -- For scores up to 600, gradually increase from 1.02 to 1.1
                insuranceRate = 1.02 + (0.08 * (score / 600))
            else
                -- For scores above 600, increase more rapidly and reach 2.0 at 8000
                insuranceRate = 1.1 + (0.9 * (1 - math.exp(-(score - 600) / 2000)))
            end
            insuranceRate = math.floor(insuranceRate * 100) / 100
            local vehId = career_modules_inventory.getInventoryIdFromVehicleId(vehId)
            local policyId = nil
            if insuredInvVehs[tostring(vehId)] then
                policyId = insuredInvVehs[tostring(vehId)]
            end
            M.changePolicyScore(policyId, insuranceRate)
            if not policyId then
                policyId = 1
            end
            if not hasLicensePlate(vehId) then
                fine = fine * 2.5
            end
            if career_modules_hardcore.isHardcoreMode() then
                fine = fine * 3
            end

            local effectText = {{
                label = "Money",
                value = -fine
            }, {
                label = "New policy score",
                value = plPoliciesData[policyId].bonus
            }}

            local offenseNames = {}
            for offenseKey, offenseData in pairs(data.offenses) do
                local offenseName = offenseNames[offenseKey] or offenseKey
                table.insert(offenseNames, offenseName)
            end
            local arrested = false
            if data.mode ~= 1 then
                arrested = true
            end

            if arrested then
                career_modules_inventory.addArrest(vehId)
            else
                career_modules_inventory.addTicket(vehId)
                fine = fine * 0.5
            end

            local eventDescription = arrested and "Arrested for " or "Ticketed for " .. table.concat(offenseNames, ", ")
            if not hasLicensePlate(vehId) then
                eventDescription = eventDescription .. " (no license plate)"
            end

            if career_modules_hardcore.isHardcoreMode() then
                eventDescription = eventDescription .. "\nHardcore mode is enabled, all fines are tripled."
            end

            table.insert(plHistory.generalHistory.ticketEvents, {
                type = "arrest",
                time = os.time(),
                policyName = availablePolicies[policyId].name,
                eventDescription = eventDescription,
                effectText = effectText
            })
            career_modules_payment.pay({
                money = {
                    amount = fine,
                    canBeNegative = true
                }
            }, {
                label = eventDescription,
                tags = {"fine", "criminal"}
            })
            local combinedMessage = string.format(
                "%s\nYou have been fined: $%.2f\nYour insurance policy score is now: %.2f",
                eventDescription, fine, plPoliciesData[policyId].bonus
            )
            ui_message(combinedMessage, 8, "Insurance", "info")
            career_saveSystem.saveCurrent()
            local vehId = be:getPlayerVehicleID(0)
            local playerTrafficData = gameplay_traffic.getTrafficData()[vehId]
            if playerTrafficData and playerTrafficData.pursuit then
                playerTrafficData.pursuit.mode = 0
                playerTrafficData.pursuit.score = 0
            end
        end
    end
end

local function addTicketEvent(description, effectText, invVehId)
    local policyId = 1
    if invVehId then
        policyId = insuredInvVehs[tostring(invVehId)]
    end
    table.insert(plHistory.generalHistory.ticketEvents, {
        type = "other",
        time = os.time(),
        policyName = availablePolicies[policyId].name,
        eventDescription = description,
        effectText = effectText
    })
end

local function onVehicleSwitched()
    initCurrInsurance()
end

local function onCareerModulesActivated(alreadyInLevel)
    loadPoliciesData()
end

local function onSaveCurrentSaveSlot(currentSavePath)
    savePoliciesData(currentSavePath)
end

-- TODO : write a more modulable history
local function sortByTimeReverse(a, b)
    return a.time > b.time
end
local function buildPolicyHistory()
    -- police tickets event
    local list = {}
    for _, event in ipairs(plHistory.generalHistory.ticketEvents) do
        if event.eventDescription then
            table.insert(list, {
                time = os.date("%c", event.time),
                event = event.eventDescription,
                policyName = event.policyName,
                effect = event.effectText
            })
        else
        table.insert(list, {
            time = os.date("%c", event.time),
            event = translateLanguage("insurance.history.event.policeTicket.name",
                "insurance.history.event.policeTicket.name", true),
            policyName = "General",
            effectText = {
                label = "Police Effect",
                value = 0
            }
            })
        end
    end

    for _, claim in ipairs(plHistory.generalHistory.testDriveClaims) do
        local effectText = {{
            label = "Money",
            value = claim.amount and -claim.amount or 0
        }, {
            label = "New policy score",
            value = claim.policyScore and claim.policyScore or 0
        }}

        table.insert(list, {
            time = os.date("%c", claim.time),
            event = claim.reason and claim.reason or "Test drive",
            policyName = availablePolicies[claim.policyId or 1].name,
            effect = effectText
        })
    end

    for _, policyHistoryInfo in pairs(plHistory.policyHistory) do
        -- repair claims event
        for _, claim in ipairs(policyHistoryInfo.claims) do
            local effectText = {}
            for currency, amount in pairs(claim.deductible) do
                table.insert(effectText, {
                    label = currency == "money" and "Money" or "Bonus star",
                    value = -amount.amount
                })
            end
            if claim.freeRepair then
                table.insert(effectText, {
                    label = "Accident forgiveness",
                    value = 0
                })
            else
                table.insert(effectText, {
                    label = "New policy score",
                    value = claim.policyScore
                })
            end
            table.insert(list, {
                time = os.date("%c", claim.time),
                event = translateLanguage("insurance.history.event.vehicleRepaired.name",
                    "insurance.history.event.vehicleRepaired.name", true) .. claim.vehInfo.niceName,
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end

        -- policies initial purchase events
        if plPoliciesData[policyHistoryInfo.id].owned then
            local effectText = {{
                label = "Money",
                value = policyHistoryInfo.initialPurchase.forFree and -0 or
                    -availablePolicies[policyHistoryInfo.id or 1].initialBuyPrice
            }}
            table.insert(list, {
                time = os.date("%c", policyHistoryInfo.initialPurchase.purchaseTime),
                event = translateLanguage("insurance.history.event.initialPurchase.name",
                    "insurance.history.event.initialPurchase.name", true),
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end

        -- bonus decrease events
        for _, bonusDecreaseEvent in ipairs(policyHistoryInfo.policyScoreDecreases) do
            local effectText = {{
                label = "New policy score",
                value = bonusDecreaseEvent.value
            }}
            table.insert(list, {
                time = os.date("%c", bonusDecreaseEvent.time),
                event = translateLanguage("insurance.history.event.policScoreDecreased.name",
                    "insurance.history.event.policScoreDecreased.name", true),
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end

        -- policy renewed events
        for _, renewedPolicyEvent in ipairs(policyHistoryInfo.renewedPolicy) do
            local effectText = {{
                label = "Money",
                value = -renewedPolicyEvent.price
            }}
            table.insert(list, {
                time = os.date("%c", renewedPolicyEvent.time),
                event = translateLanguage("insurance.history.event.policyRenewed.name",
                    "insurance.history.event.policyRenewed.name", true),
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end

        -- changed coverage events
        for _, coverageChangedEvent in ipairs(policyHistoryInfo.changedCoverage) do
            local effectText = {{
                label = "Money",
                value = -coverageChangedEvent.price
            }}
            table.insert(list, {
                time = os.date("%c", coverageChangedEvent.time),
                event = translateLanguage("insurance.history.event.coverageChanged.name",
                    "insurance.history.event.coverageChanged.name", true),
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end

        -- free repair events
        for _, freeRepairEvent in ipairs(policyHistoryInfo.freeRepairs) do
            local effectText = {{
                label = "Accident forgiveness",
                value = 1
            }}
            table.insert(list, {
                time = os.date("%c", freeRepairEvent.time),
                event = translateLanguage("insurance.history.event.accidentForgiveness.name",
                    "insurance.history.event.accidentForgiveness.name", true),
                policyName = availablePolicies[policyHistoryInfo.id or 1].name,
                effect = effectText
            })
        end
    end

    table.sort(list, sortByTimeReverse)

    return list
end

local function sendUIData()
    insurancePoliciesMenuOpen = true

    local data = {
        policiesData = {},
        policyHistory = buildPolicyHistory(),
        careerMoney = career_modules_playerAttributes.getAttributeValue("money"),
        careerVouchers = career_modules_playerAttributes.getAttributeValue("vouchers")
    }

    -- only send the required information, not everything
    for _, policyInfo in pairs(availablePolicies) do
        local perks = {}
        -- get player's data concerning this insurance
        local plPolicyData = plPoliciesData[policyInfo.id]

        local plData = {
            owned = plPolicyData.owned,
            bonus = plPolicyData.bonus,
            nextPolicyEditTimer = plPolicyData.nextPolicyEditTimer
        }

        for plPerkName, plPerkValue in pairs(plPolicyData.perks) do
            perks[plPerkName] = policyInfo.perks[plPerkName]
            perks[plPerkName].plValue = getPlPerkValue(policyInfo.id, plPerkName)
        end

        local plRenewal = getPlPerkValue(policyInfo.id, "renewal")
        local policyData = {
            id = policyInfo.id,
            name = policyInfo.name,
            resetBonus = policyInfo.resetBonus,
            paperworkFees = policyInfo.paperworkFees,
            description = policyInfo.description,
            premium = getPremiumWithPolicyScore(policyInfo.id),
            nextPaymentDist = (plRenewal - (plPolicyData.totalMetersDriven % plRenewal)) / 1000,
            initialBuyPrice = policyInfo.initialBuyPrice,
            perks = perks,

            plData = plData
        }

        table.insert(data.policiesData, policyData)
    end
    -- showFirstLoadPopup()
    guihooks.trigger('insurancePoliciesData', data)
end

-- remove the vehicle from the insuranced vehicles json files
local function onVehicleRemovedFromInventory(inventoryId)
    insuredInvVehs[tostring(inventoryId)] = nil
end

-- apply the minimum applicable insurance to the vehicle, and save it to the json file
local function onVehicleAddedToInventory(data)
    local conditionData = {
        vehValue = career_modules_valueCalculator.getInventoryVehicleValue(data.inventoryId),
        population = data.vehicleInfo and data.vehicleInfo.Population or nil,
        bodyStyle = data.vehicleInfo and
            ((data.vehicleInfo.BodyStyle and data.vehicleInfo.BodyStyle) or data.vehicleInfo.aggregates["Body Style"]) or
            nil
    }

    if data.vehicleInfo and data.vehicleInfo["Commercial Class"] then
        conditionData.commercialClass = tonumber(string.match(data.vehicleInfo["Commercial Class"], "%d+"))
    end

    local requiredPolicyId = getMinApplicablePolicyId(conditionData)
    if not plPoliciesData[requiredPolicyId].owned then
        requiredPolicyId = requiredPolicyId * -1
    end -- a negative insurance id means it is not insured and would require said insurance
    insuredInvVehs[tostring(data.inventoryId)] = requiredPolicyId
end

local function openRepairMenu(vehicle, _originComputerId)
    vehicleToRepairData = vehicle
    originComputerId = _originComputerId
    guihooks.trigger('ChangeState', {
        state = 'repair',
        params = {}
    })
end

local function changePolicyPerks(policyId, changedPerks)
    local policyTowsValue = getPlPerkValue(policyId, "roadsideAssistance")
    print("Policy Tows Value: " .. tostring(policyTowsValue))
    for perkName, perkValue in pairs(changedPerks) do
        local index = tableFindKey(availablePolicies[policyId].perks[perkName].changeability.changeParams.choices,
            perkValue)
        if plPoliciesData[policyId].perks[perkName] ~= nil then
            plPoliciesData[policyId].perks[perkName] = index
        end
    end
    policyTows[policyId] = policyTows[policyId] - policyTowsValue + getPlPerkValue(policyId, "roadsideAssistance")

    table.insert(plHistory.policyHistory[policyId].changedCoverage, {
        time = os.time(),
        price = availablePolicies[policyId].paperworkFees
    })

    local label = string.format("Policy coverage changed. Tier : %s", availablePolicies[policyId].name)
    career_modules_payment.pay({
        money = {
            amount = availablePolicies[policyId].paperworkFees,
            canBeNegative = false
        }
    }, {
        label = label,
        tags = {"insurance"}
    })
    plPoliciesData[policyId].nextPolicyEditTimer = policyEditTime
    M.sendUIData()
end

-- close the insurances computer menu
local function closeMenu()
    if originComputerId then
        local computer = freeroam_facilities.getFacility("computer", originComputerId)
        career_modules_computer.openMenu(computer)
    else
        career_career.closeAllMenus()
    end
end

-- open the insurances computer menu
local function openMenu(_originComputerId)
    originComputerId = _originComputerId
    if originComputerId then
        guihooks.trigger('ChangeState', {
            state = 'insurancePolicies',
            params = {}
        })
        extensions.hook("onComputerInsurance")
    end
end

local function onExitInsurancePoliciesList()
    insurancePoliciesMenuOpen = false
end

local function onComputerAddFunctions(menuData, computerFunctions)
    if menuData.computerFacility.functions["insurancePolicies"] then
        local computerFunctionData = {
            id = "insurancePolicies",
            label = "Insurance policies",
            callback = function()
                openMenu(menuData.computerFacility.id)
            end,
            order = 15
        }
        if menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive then
            computerFunctionData.disabled = true
            computerFunctionData.reason = career_modules_computer.reasons.tutorialActive
        end
        computerFunctions.general[computerFunctionData.id] = computerFunctionData
    end

    if menuData.computerFacility.functions["vehicleInventory"] then
        for _, vehicleData in ipairs(menuData.vehiclesInGarage) do
            local inventoryId = vehicleData.inventoryId
            local computerFunctionData = {
                id = "repair",
                label = "Repair",
                callback = function()
                    openRepairMenu(career_modules_inventory.getVehicles()[inventoryId], menuData.computerFacility.id)
                end,
                order = 5
            }
            -- tutorial
            if menuData.tutorialPartShoppingActive or menuData.tutorialTuningActive then
                computerFunctionData.disabled = true
                computerFunctionData.reason = {
                    type = "text",
                    label = "Disabled during tutorial. Use the recovery prompt instead."
                }
            end

            -- generic gameplay reason
            local reason = career_modules_permissions.getStatusForTag({"vehicleRepair"}, {
                inventoryId = inventoryId
            })
            if not reason.allow then
                computerFunctionData.disabled = true
            end
            if reason.permission ~= "allowed" then
                computerFunctionData.reason = reason
            end

            computerFunctions.vehicleSpecific[inventoryId][computerFunctionData.id] = computerFunctionData
        end
    end
end

local function payBonusReset(policyId)
    local policyData = availablePolicies[policyId]
    if plPoliciesData[policyId].bonus > policyData.resetBonus.conditions.minBonus and
        career_modules_payment.canPay(policyData.resetBonus.price) then
        local label = string.format("Policy score decreased. Tier : %s", policyData.name)
        career_modules_payment.pay(policyData.resetBonus.price, {
            label = label,
            tags = {"insurance", "goodBehaviour"}
        })
        plPoliciesData[policyId].bonus = 1
        sendUIData()
    end
end

M.getPolicyDeductible = function(vehInvId)
    return getPlPerkValue(insuredInvVehs[tostring(vehInvId)], "deductible")
end

M.getRepairTime = function(vehInvId)
    return getPlPerkValue(insuredInvVehs[tostring(vehInvId)], "repairTime")
end

local function getPlayerPolicyData()
    return plPoliciesData
end

local function getQuickRepairExtraPrice()
    return quickRepairExtraPrice
end

local function expediteRepair(inventoryId, price)
    if career_modules_payment.pay({
        money = {
            amount = price,
            canBeNegative = false
        }
    }, {
        label = "Expedited repair"
    }) then
        local vehInfo = career_modules_inventory.getVehicles()[inventoryId]
        vehInfo.timeToAccess = nil
        vehInfo.delayReason = nil
        career_modules_inventory.setVehicleDirty(inventoryId)
    end
end

M.isRoadSideAssistanceFree = function(invVehId)
    local applicablePolicy = plPoliciesData[insuredInvVehs[tostring(invVehId)]]
    if not applicablePolicy then
        return true
    end
    if policyTows[applicablePolicy.id] == nil then
        policyTows[applicablePolicy.id] = getPlPerkValue(applicablePolicy.id, "roadsideAssistance")
    end
    local value = policyTows[applicablePolicy.id]
    if value <= 0 then
        return false
    end
    return true
end

M.useTow = function(invVehId)
    if policyTows[insuredInvVehs[tostring(invVehId)]] > 0 then
        policyTows[insuredInvVehs[tostring(invVehId)]] = policyTows[insuredInvVehs[tostring(invVehId)]] - 1
    end
    print("Tows left: " .. tostring(policyTows[insuredInvVehs[tostring(invVehId)]]))
end
-- For UI
M.getVehPolicyInfo = function(vehInvId)
    return {
        policyOwned = insuredInvVehs[tostring(vehInvId)] > 0,
        policyInfo = availablePolicies[math.abs(insuredInvVehs[tostring(vehInvId)])]
    }
end
M.getTestDriveClaimPrice = function()
    return testDriveClaimPrice.money.amount
end
M.getPlHistory = function()
    return plHistory
end

M.genericVehNeedsRepair = genericVehNeedsRepair
M.makeRepairClaim = makeRepairClaim
M.makeTestDriveDamageClaim = makeTestDriveDamageClaim
M.startRepairInstant = startRepairInstant
M.startRepair = startRepair
M.inventoryVehNeedsRepair = inventoryVehNeedsRepair
M.missionStartRepairCallback = missionStartRepairCallback
M.openRepairMenu = openRepairMenu
M.getRepairData = getRepairData
M.closeMenu = closeMenu
M.repairPartConditions = repairPartConditions
M.purchasePolicy = purchasePolicy
M.changeVehPolicy = changeVehPolicy
M.getMinApplicablePolicyFromVehicleShoppingData = getMinApplicablePolicyFromVehicleShoppingData
M.getPlayerPolicyData = getPlayerPolicyData
M.payBonusReset = payBonusReset
M.getQuickRepairExtraPrice = getQuickRepairExtraPrice
M.expediteRepair = expediteRepair

M.calculatePremiumDetails = calculatePremiumDetails
M.calculatePolicyPremium = calculatePolicyPremium
M.startRepairInGarage = startRepairInGarage
M.openMenu = openMenu
M.sendUIData = sendUIData
M.closeMenu = closeMenu
M.changePolicyPerks = changePolicyPerks

-- hooks
M.onUpdate = onUpdate
M.onCareerModulesActivated = onCareerModulesActivated
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onComputerAddFunctions = onComputerAddFunctions
M.onVehicleSwitched = onVehicleSwitched
M.onEnterVehicleFinished = onEnterVehicleFinished
M.onExitInsurancePoliciesList = onExitInsurancePoliciesList
M.onPursuitAction = onPursuitAction

-- from vehicle inventory
M.onVehicleAddedToInventory = onVehicleAddedToInventory
M.onVehicleRemoved = onVehicleRemovedFromInventory

-- internal use only
M.getActualRepairPrice = getActualRepairPrice
M.getPlPerkValue = getPlPerkValue
M.changePolicyScore = changePolicyScore

-- career debug
M.resetPlPolicyData = function()
    loadPoliciesData(true)
end

M.dumpPolicyTows = function()
    print("Policy Tows:")
    dump(policyTows)
end
return M
