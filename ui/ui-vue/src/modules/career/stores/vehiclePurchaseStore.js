import { ref, watch, computed } from "vue"
import { defineStore } from "pinia"
import { useBridge, lua } from "@/bridge"

export const useVehiclePurchaseStore = defineStore("vehiclePurchase", () => {
  const { events } = useBridge()

  const purchaseType = ref("")
  const vehicleInfo = ref({})
  const playerMoney = ref(0)
  const inventoryHasFreeSlot = ref(false)
  const tradeInVehicleInfo = ref({})
  const tradeInEnabled = ref(false)
  const forceTradeIn = ref(false)
  const locationSelectionEnabled = ref(false)
  const forceNoDelivery = ref(false)
  const ownsRequiredInsurance = ref(false)
  const makeDelivery = ref(false)
  const buyRequiredInsurance = ref(false)
  const buyCustomLicensePlate = ref(false)
  const customLicensePlateText = ref("")
  const dealershipId = ref("")
  const prices = ref({})

  const finalPackagePrice = computed(() => {
    let price = prices.value.finalPrice

    if (buyRequiredInsurance.value) {
      let insurancePrice = vehicleInfo.value.requiredInsurance.initialBuyPrice
      price += insurancePrice
    }

    if (buyCustomLicensePlate.value) {
      price += prices.value.customLicensePlate
    }
    return price
  })

  const handlePurchaseData = data => {
    vehicleInfo.value = data.vehicleInfo
    playerMoney.value = data.playerMoney
    inventoryHasFreeSlot.value = data.inventoryHasFreeSlot
    purchaseType.value = data.purchaseType
    tradeInEnabled.value = data.tradeInEnabled
    locationSelectionEnabled.value = data.locationSelectionEnabled
    forceNoDelivery.value = data.forceNoDelivery
    ownsRequiredInsurance.value = data.ownsRequiredInsurance
    prices.value = data.prices
    makeDelivery.value = false
    buyRequiredInsurance.value = false
    buyCustomLicensePlate.value = false
    customLicensePlateText.value = ""
    dealershipId.value = data.dealershipId

    forceTradeIn.value = data.forceTradeIn

    if (data.tradeInVehicleInfo !== undefined) {
      tradeInVehicleInfo.value = data.tradeInVehicleInfo
    } else {
      tradeInVehicleInfo.value = {}
    }

    if (!ownsRequiredInsurance.value) {
      buyRequiredInsurance.value = true
    }
  }

  watch(() => buyRequiredInsurance.value, updateInsurancePurchase)

  function updateInsurancePurchase(newValue, oldValue) {
    if (!ownsRequiredInsurance.value && !buyRequiredInsurance.value) makeDelivery.value = true
  }

  function requestPurchaseData() {
    lua.career_modules_vehicleShopping.sendPurchaseDataToUi()
  }

  function buyVehicle(makeDelivery) {
    if (buyRequiredInsurance.value) {
      lua.career_modules_insurance.purchasePolicy(vehicleInfo.value.requiredInsurance.id)
    }
    let options = {makeDelivery: makeDelivery}
    if (buyCustomLicensePlate.value) {
      options.licensePlateText = customLicensePlateText.value
    }
    options.dealershipId = dealershipId.value
    lua.career_modules_vehicleShopping.buyFromPurchaseMenu(purchaseType.value, options)
  }

  async function getInventory() {
    return await lua.career_modules_inventory.getVehicles()
  }

  function chooseTradeInVehicle() {
    lua.career_modules_vehicleShopping.openInventoryMenuForTradeIn()
  }

  function removeTradeInVehicle() {
    lua.career_modules_vehicleShopping.removeTradeInVehicle()
  }

  function cancel() {
    lua.career_modules_vehicleShopping.cancelPurchase(purchaseType.value)
  }

  function dispose() {
    listen(false)
  }

  // Lua events
  const listen = state => {
    const method = state ? "on" : "off"
    events[method]("vehiclePurchaseData", handlePurchaseData)
  }
  listen(true)

  return {
    buyRequiredInsurance,
    buyVehicle,
    cancel,
    chooseTradeInVehicle,
    dispose,
    forceNoDelivery,
    forceTradeIn,
    getInventory,
    inventoryHasFreeSlot,
    locationSelectionEnabled,
    makeDelivery,
    ownsRequiredInsurance,
    playerMoney,
    prices,
    finalPackagePrice,
    removeTradeInVehicle,
    requestPurchaseData,
    tradeInEnabled,
    tradeInVehicleInfo,
    vehicleInfo,
    buyCustomLicensePlate,
    customLicensePlateText
  }
})
