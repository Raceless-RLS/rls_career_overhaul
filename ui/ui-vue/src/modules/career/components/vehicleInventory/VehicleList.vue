<template>
  <BngList layout-selector v-bng-disabled="!vehicleInventoryStore" @layout-change="onLayoutChange" :layout="LIST_LAYOUTS.TILES">
    <VehicleTile v-if="listStatus" :data="{ _message: listStatus }" :layout="itemLayout" v-bng-disabled />
    <VehicleTile v-else v-for="vehicle in listView"
      :data="vehicle" :layout="itemLayout" :selected="vehSelected && vehSelected.id === vehicle.id"
      :is-tutorial="vehicleInventoryStore && vehicleInventoryStore.vehicleInventoryData.tutorialActive"
      :money="vehicleInventoryStore ? vehicleInventoryStore.vehicleInventoryData.playerMoney : 0"
      v-bng-disabled="vehicle.disabled"
      tabindex="0" bng-nav-item v-bng-on-ui-nav:ok.asMouse.focusRequired
      v-bng-popover:right-start.click="popId" @click="select(vehicle, $event)" />

    <BngPopoverMenu :name="popId" focus @hide="selectedVehId = null">
      <template v-for="(buttonData, index) in vehicleInventoryStore.vehicleInventoryData.chooseButtonsData">
        <BngButton v-if="buttonData.repairRequired && vehSelected.needsRepair && !vehicleInventoryStore.vehicleInventoryData.tutorialActive"
          :accent="ACCENTS.menu" disabled>
          {{ buttonData.buttonText }} (Needs repair)
        </BngButton>
        <BngButton v-else-if="isFunctionAvailable(vehSelected, buttonData)"
          :accent="ACCENTS.menu"
          @click="vehicleInventoryStore.chooseVehicle(vehSelected.id, index)">
          {{ buttonData.buttonText }}
        </BngButton>
      </template>
      <BngButton
        v-if="vehicleInventoryStore.vehicleInventoryData.buttonsActive.returnLoanerEnabled && vehSelected.returnLoanerPermission.allow"
        :accent="ACCENTS.menu"
        @click="confirmReturnVehicle()">
        Return loaned vehicle
      </BngButton>
      <BngButton
        v-if="vehSelected.delayReason === 'repair'"
        :accent="ACCENTS.menu"
        :disabled="vehSelected.expediteRepairCost > vehicleInventoryStore.vehicleInventoryData.playerMoney"
        @click="confirmExpediteRepair(vehSelected)">
        Expedite Repair
        <BngUnit :money="vehSelected.expediteRepairCost" />
      </BngButton>
      <BngButton
        v-if="vehSelected.delayReason !== 'repair' && vehicleInventoryStore.vehicleInventoryData.buttonsActive.repairEnabled"
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.repairPermission.allow"
        @click="openRepairMenu()">
        Repair
      </BngButton>
      <BngButton
        v-if="vehicleInventoryStore.vehicleInventoryData.buttonsActive.storingEnabled"
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.storePermission.allow"
        @click="storeVehicle()">
        Put in storage
      </BngButton>
      <BngButton
        v-if="!vehSelected.ownsRequiredInsurance"
        :disabled="vehSelected.policyInfo.initialBuyPrice > vehicleInventoryStore.vehicleInventoryData.playerMoney"
        @click="buyInsurance(vehSelected.policyInfo.id)">
        Purchase insurance
        <BngUnit :money="vehSelected.policyInfo.initialBuyPrice" />
      </BngButton>
      <BngButton
        v-if="vehicleInventoryStore.vehicleInventoryData.buttonsActive.favoriteEnabled"
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.favoritePermission.allow || vehSelected.favorite"
        @click="setFavoriteVehicle()">
        Set as Favorite
      </BngButton>
      <BngButton
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.licensePlateChangePermission.allow"
        @click="personalizeLicensePlate(vehSelected)">
        Personalize license plate
      </BngButton>
      <BngButton
        v-if="vehicleInventoryStore.vehicleInventoryData.buttonsActive.sellEnabled && !vehiclesForSale.includes(vehSelected.id)"
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.sellPermission.allow"
        @click="confirmSellVehicle()">
        Instant Sell
      </BngButton>
      <BngButton
        v-if="vehicleInventoryStore.vehicleInventoryData.buttonsActive.sellEnabled && !vehiclesForSale.includes(vehSelected.id)"
        :accent="ACCENTS.menu"
        :disabled="!vehSelected.sellPermission.allow"
        @click="confirmListForSale()">
        List for Sale
      </BngButton>
      <BngButton
        v-if="vehiclesForSale.includes(vehSelected.id)"
        :accent="ACCENTS.menu"
        @click="confirmRemoveFromSale()">
        Remove Listing
      </BngButton>
    </BngPopoverMenu>
  </BngList>
</template>

<script setup>
import { ref, computed, nextTick, onMounted } from "vue"
import { lua, useBridge } from "@/bridge"
import { BngList, BngButton, BngPopoverMenu, BngUnit, ACCENTS, LIST_LAYOUTS } from "@/common/components/base"
import { vBngDisabled, vBngPopover, vBngOnUiNav } from "@/common/directives"
import VehicleTile from "./VehicleTile.vue"
import { useVehicleInventoryStore } from "../../stores/vehicleInventoryStore"
import { openConfirmation, openPrompt } from "@/services/popup"
import { $translate } from "@/services/translation"
import { usePopover } from "@/services/popover"
import { uniqueId } from "@/services/uniqueId"

const { units, events } = useBridge()

const popover = usePopover()
const popId = uniqueId("veh_options")
const popHide = () => popover.hide(popId)

const vehicleInventoryStore = useVehicleInventoryStore()
const selectedVehId = ref()

const vehiclesForSale = ref([])

onMounted(() => {
   lua.career_modules_vehicleMarketplace.requestInitialData()
});

events.on("marketplaceUpdate", (data) => {
  vehiclesForSale.value = Object.keys(data).map(id => Number(id))
})

const vehSelected = computed(() => {
  if (typeof selectedVehId.value != "number" ) return
  for (const vehicle of listView.value) {
    if (vehicle.id == selectedVehId.value) return vehicle
  }

  return
})

const careerStatusData = ref({})

const updateCareerStatusData = () => lua.career_modules_uiUtils.getCareerStatusData().then(data => (careerStatusData.value = data))

const cantPayLicensePlate = computed(() =>
  !careerStatusData.value.money || 300 > careerStatusData.value.money
)

const listStatus = computed(() =>
  !vehicleInventoryStore
  ? "Please wait..."
  : !Array.isArray(vehicleInventoryStore.filteredVehicles) || vehicleInventoryStore.filteredVehicles.length === 0
  ? "You don't currently own any vehicles"
  : null
)

const listView = computed(() => {
  if (!vehicleInventoryStore || !Array.isArray(vehicleInventoryStore.filteredVehicles) || vehicleInventoryStore.filteredVehicles.length === 0) return []
  const res = vehicleInventoryStore.filteredVehicles
  if (singleFunction.value) {
    for (const veh of res) {
      veh.disabled = !isFunctionAvailable(veh, singleFunction.value)
    }
  }
  res.sort((a, b) => a.favorite ? -1 : b.favorite ? 1 : a.niceName.localeCompare(b.niceName))
  return res
})

const itemLayout = ref("tile")
const onLayoutChange = val => itemLayout.value = val === LIST_LAYOUTS.LIST ? "row" : "tile"

// returns a function if we only have a single option available
const singleFunction = computed(() => {
  // no data yet
  if (!vehicleInventoryStore || !vehicleInventoryStore.vehicleInventoryData) return null
  const data = vehicleInventoryStore.vehicleInventoryData
  // normal menu functions are available
  if (Object.values(data.buttonsActive).includes(true)) return null
  // zero or more than one custom functions
  if (!Array.isArray(data.chooseButtonsData) || data.chooseButtonsData.length !== 1) return null
  // return the only function available
  return data.chooseButtonsData[0]
})



function select(vehicle, evt) {
  const show =
    vehicleInventoryStore && vehicleInventoryStore.vehicleInventoryData
    && (Object.values(vehicleInventoryStore.vehicleInventoryData.buttonsActive).includes(true) || vehicleInventoryStore.vehicleInventoryData.chooseButtonsData.length > 0)
    && vehicle && (!vehSelected.value || vehSelected.value.id !== vehicle.id)
  let popover
  if (evt && evt.target) {
    let cur = evt.target
    while (true) {
      popover = cur.__popover
      if (popover) break
      cur = cur.parentNode
      if (cur === document.body) break
    }
  }
  // evaluate the single function available, if any
  if (vehicle && singleFunction.value) {
    // next two lines are popover error avoidance for this mode (note: errors are console-only and not affecting anything)
    selectedVehId.value = null
    popover && popover.hide()
    // call the function
    vehicleInventoryStore.chooseVehicle(vehicle.id, 0)
    return
  }
  // hide and nextTick is to make it properly work with uiNav
  show && popover && popover.hide()
  nextTick(() => {
    if (show) {
      selectedVehId.value = vehicle.id
      popover && popover.show()
    } else {
      popover && popover.hide()
      selectedVehId.value = null
    }
    // console.log(show ? "SHOW" : "HIDE", popover.isShown() === show ? "success" : "fail", evt.target)
  })
}

const isFunctionAvailable = (vehicle, buttonData) => !(
  vehicle.timeToAccess ||
  vehicle.missingFile ||
  (buttonData.insuranceRequired && !vehicle.ownsRequiredInsurance) ||
  (buttonData.requiredVehicleNotInGarage && vehicle.inGarage) ||
  (buttonData.requiredOtherVehicleInGarage && !vehicle.otherVehicleInGarage) ||
  (buttonData.ownedRequired && !vehicle.owned)
)

const confirmSellVehicle = async () => {
  const vehicle = vehSelected.value
  popHide()
  const hardcoreMultiplier = lua.career_modules_hardcore.isHardcoreMode() ? 0.33 : 0.66
  const res = await openConfirmation("", `Do you want to sell this vehicle for ${units.beamBucks(vehicle.value * hardcoreMultiplier)}?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) lua.career_modules_inventory.sellVehicleFromInventory(vehicle.id)
}

const confirmListForSale = async () => {
  const vehicle = vehSelected.value
  popHide()
  const res = await openConfirmation("", `Do you want to list this vehicle for sale?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) lua.career_modules_inventory.listVehicleForSale(vehicle.id)
}

const confirmRemoveFromSale = async () => {
  const vehicle = vehSelected.value
  popHide()
  const res = await openConfirmation("", `Do you want to remove this vehicles listing?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) lua.career_modules_inventory.removeVehicleFromSale(vehicle.id)
}

const confirmReturnVehicle = async () => {
  const vehicle = vehSelected.value
  popHide()
  const res = await openConfirmation("", `Do you want to return this loaned vehicle to the owner?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) lua.career_modules_inventory.returnLoanedVehicleFromInventory(vehicle.id)
}

const personalizeLicensePlate = async () => {
  const vehicle = vehSelected.value
  popHide()
  updateCareerStatusData()
  const res = await openPrompt("Enter your new license plate text:", "Personalize License Plate",  { maxLength: 10, defaultValue: vehicle.config.licenseName, buttons: [
    { label: $translate.instant("ui.common.cancel"), value: false, extras: { cancel: true, accent: ACCENTS.secondary } },
    { label: $translate.instant("ui.common.okay") + ` (Cost: ${units.beamBucks(300)})`, value: text => text, extras: {
      disabled: cantPayLicensePlate,
      accent: ACCENTS.primary,
    } },
  ]})

  if (res != false)  {
    lua.career_modules_inventory.purchaseLicensePlateText(vehicle.id, res, 300)
    vehicle.config.licenseName = res
  }
}

const confirmExpediteRepair = async () => {
  const vehicle = vehSelected.value
  popHide()
  let price = vehicle.expediteRepairCost
  const res = await openConfirmation("", `Do you want to expedite the repair for ${units.beamBucks(price)}?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) lua.career_modules_inventory.expediteRepairFromInventory(vehicle.id, price)
}

const openRepairMenu = () => {
  const vehicle = vehSelected.value
  popHide()
  lua.career_modules_insurance.openRepairMenu(vehicle, vehicleInventoryStore.vehicleInventoryData.originComputerId)
}

const setFavoriteVehicle = () => {
  const vehicle = vehSelected.value
  popHide()
  lua.career_modules_inventory.setFavoriteVehicle(vehicle.id)
  lua.career_modules_inventory.sendDataToUi()
}

const storeVehicle = () => {
  const vehicle = vehSelected.value
  popHide()
  lua.career_modules_inventory.removeVehicleObject(vehicle.id)
  lua.career_modules_inventory.sendDataToUi()
}

const buyInsurance = () => {
  const vehicle = vehSelected.value
  popHide()
  lua.career_modules_insurance.purchasePolicy(vehicle.id)
  lua.career_modules_inventory.sendDataToUi()
}
</script>
