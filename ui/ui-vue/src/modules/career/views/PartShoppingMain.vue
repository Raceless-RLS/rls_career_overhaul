<template>
  <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Parts" back @back="close">
    <Categories
      :cancel="confirmCancel"
    />
    <ShoppingCart
      :partShoppingData="partShoppingStore.partShoppingData"
      :cart-data="cartData"
      :player-money="partShoppingStore.partShoppingData.playerMoney"
      :apply="applyShopping"
      :cancel="confirmCancel"
    />
  </ComputerWrapper>
</template>

<script setup>
import { default as UINavEvents, UI_EVENT_GROUPS } from "@/bridge/libs/UINavEvents"
import { computed, onBeforeMount, onUnmounted } from "vue"
import ComputerWrapper from "./ComputerWrapper.vue"
import { usePartShoppingStore } from "../stores/partShoppingStore"
import ShoppingCart from "../components/ShoppingCart.vue"
import Categories from "../components/partShopping/Categories.vue"
import { useComputerStore } from "../stores/computerStore"
import { lua } from "@/bridge"
import { openConfirmation } from "@/services/popup"
import { $translate } from "@/services/translation"
import { ACCENTS } from "@/common/components/base"

const computerStore = useComputerStore()

const partShoppingStore = usePartShoppingStore()

const CANCEL_MESSAGE = "Are you sure you want to cancel?<br />All changes to your vehicle will be reversed"
const CONFIRM_BUTTONS = [
  { label: $translate.instant("ui.common.yes"), value: true },
  { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
]

const confirmCancel = async () => {
  if (!partShoppingStore.partShoppingData.shoppingCart.partsInList.length || await openConfirmation(null, CANCEL_MESSAGE, CONFIRM_BUTTONS)) {
    cancelShopping()
  }
}

const cartData = computed(() => {
  const cart = partShoppingStore.partShoppingData ? partShoppingStore.partShoppingData.shoppingCart : null
  const res = { total: 0, taxes: 0, items: [] }
  if (cart) {
    res.total = cart.total
    res.taxes = cart.taxes
    // Process partsInList and partsOutList separately
    const partsIn = Array.isArray(cart.partsInList) ? cart.partsInList : []
    const partsOut = Array.isArray(cart.partsOutList) ? cart.partsOutList : []
    
    // Map partsIn with positive values
    const mappedPartsIn = partsIn.map(item => ({
      name: item.description.description,
      price: item.finalValue,
      removeShow: !!item.sourcePart,
      removeDisabled: !!partShoppingStore.partShoppingData.tutorialPartNames,
      remove: () => lua.career_modules_partShopping.removePartBySlot(item.containingSlot),
    }))
    
    // Map partsOut with negative values
    const mappedPartsOut = partsOut
      .filter(item => !cart.keepUsedParts[item.containingSlot]) // Only show parts not in keepUsedParts
      .map(item => ({
        name: "Used " + item.description.description,
        price: -item.finalValue,
        removeShow: true,
        removeDisabled: false,
        remove: () => lua.career_modules_partShopping.keepUsedPartBySlot(item.containingSlot),
      }))

    res.items = [...mappedPartsIn, ...mappedPartsOut]
  }
  return res
})

const applyShopping = () => lua.career_modules_partShopping.applyShopping()
const cancelShopping = () => lua.career_modules_partShopping.cancelShopping()

const start = () => {
  partShoppingStore.setSlot("")
  partShoppingStore.requestInitialData()
  UINavEvents.setFilteredEvents(UI_EVENT_GROUPS.focusMoveScalar)
}

const kill = () => {
  partShoppingStore.cancelShopping()
  UINavEvents.clearFilteredEvents()
  partShoppingStore.$dispose()
}

const close = () => {
  partShoppingStore.backAction()
}

onBeforeMount(start)
onUnmounted(kill)
</script>

<style scoped lang="scss">
.md-content {
  display: block;
  flex-flow: column;
  position: relative;
  width: 100%;
  text-align: center;
  height: 100%;
  overflow-y: hidden;
}

.profileStatus {
  border-radius: var(--bng-corners-2);
  position: absolute;
  top: 0;
  right: 0;
  color: white;
  background-color: rgba(0, 0, 0, 0.7);
  & :deep(.card-cnt) {
    background-color: rgba(0, 0, 0, 0.7);
  }
}
</style>
