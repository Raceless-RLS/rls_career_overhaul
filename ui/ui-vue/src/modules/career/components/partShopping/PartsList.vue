<template>
  <div class="search-container">
    <BngInput 
      v-model="searchTerm"
      floating-label="Search for parts" :leading-icon="icons.search"
      @focus="inputFocused = true"
      @blur="triggerSearch"
      @keydown.enter="triggerSearch"
    />
  </div>
  <div class="parts-wrapper">
    <BngCardHeading v-if="partShoppingStore.category === 'cargo'">
      Cargo
    </BngCardHeading>
    <BngCardHeading v-else-if="partShoppingStore.filteredParts[0]">
      {{ partShoppingStore.partShoppingData.slotsNiceName[partShoppingStore.filteredParts[0].containingSlot] }}
    </BngCardHeading>

    <div v-if="displayedParts.length > 0" class="parts-list">
      <div v-for="part in displayedParts" class="part-item"
        :class="{ 'part-installed': partShoppingStore.partShoppingData.vehicleSlotToPartMap[part.containingSlot] &&
                  partShoppingStore.partShoppingData.vehicleSlotToPartMap[part.containingSlot].description.description === part.description.description }"
      >
        <div class="part-info-col">
          <div>
            <span class="part-name">
              <div v-if="part.partId">
                {{ part.description.description }} (Inventory)
              </div>
              <div v-else-if="part.emptyPlaceholder">
                Empty
              </div>
              <div v-else>
                {{ part.description.description }}
              </div>
            </span>
          </div>
          <div class="part-info-row">
            <span v-if="part.partId" class="mileage-text">
              Mileage: {{ units.buildString("length", part.partCondition.odometer, 0) }}
            </span>
            <span v-if="partShoppingStore.category === 'cargo'">
              {{ partShoppingStore.partShoppingData.slotsNiceName[part.containingSlot] }}
            </span>
            <span v-if="!part.partId && !part.emptyPlaceholder" class="right"><BngPropVal :iconType="icons.beamCurrency" :valueLabel="units.beamBucks(part.finalValue)" /></span>
          </div>
        </div>

        <BngButton
          :accent="isPartInShoppingCart(part) ? ACCENTS.attention : ACCENTS.outlined"
          class="part-button"
          :disabled="partShoppingStore.partShoppingData.tutorialPartNames !== undefined && (!partShoppingStore.partShoppingData.tutorialPartNames[part.name] || isPartInShoppingCart(part))"
          @click="isPartInShoppingCart(part) ? lua.career_modules_partShopping.removePartBySlot(part.containingSlot) : lua.career_modules_partShopping.installPartByPartShopId(part.partShopId)"
          :icon="isPartInShoppingCart(part) ? icons.undo : ''">
          <div v-if="!isPartInShoppingCart(part)">
            Install
          </div>
        </BngButton>
      </div>
    </div>
    <div v-else-if="searchTerm && partShoppingStore.filteredParts.length > 0" class="no-results">
      No parts matching "{{ searchTerm }}"
    </div>
  </div>
</template>

<script setup>
import { BngButton, BngPropVal, BngCardHeading, BngInput, ACCENTS, icons } from "@/common/components/base"
import { lua, useBridge } from "@/bridge"
import { onMounted, onUnmounted, ref, computed } from "vue"
import { usePartShoppingStore } from "../../stores/partShoppingStore"

const partShoppingStore = usePartShoppingStore()
const { units } = useBridge()
const searchTerm = ref('')
const inputFocused = ref(false)
let oldBack

const displayedParts = computed(() => {
  if (!searchTerm.value) {
    return partShoppingStore.filteredParts
  }
  
  const term = searchTerm.value.toLowerCase()
  return partShoppingStore.filteredParts.filter(part => 
    part.description?.description?.toLowerCase().includes(term)
  )
})

const triggerSearch = () => {
  // Reset focus state
  inputFocused.value = false
  
  // Any additional search processing could go here
  // Currently the computed property handles all the filtering
}

const isPartInShoppingCart = (part) => {
  if (!partShoppingStore.partShoppingData || !partShoppingStore.partShoppingData.shoppingCart) return false
  let partList = partShoppingStore.partShoppingData.shoppingCart.partsInList
  for (let i = 0; i < partList.length; i++) {
    let shoppingCartPart = partList[i]
    if (shoppingCartPart.partId == part.partId && shoppingCartPart.sourcePart && part.name == shoppingCartPart.name && part.containingSlot == shoppingCartPart.containingSlot) return true
  }
  return false
}

onMounted(() => {
  oldBack = partShoppingStore.backAction
  partShoppingStore.backAction = () => partShoppingStore.setSlot("")
})

onUnmounted(() => {
  partShoppingStore.backAction = oldBack
})
</script>

<style lang="scss" scoped>
.parts-wrapper {
  display: flex;
  flex-direction: column;
  width: 100%;
  height: auto;
  max-height: 100%;
}

.parts-list {
  width: 100%;
  height: auto;
  max-height: 100%;
  padding: 0 1em;
  overflow: hidden auto;
}

.part-item {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: center;
  overflow: hidden;
  width: 100%;
  height: 4em;
  color: #fff;
  > *:first-child {
    padding-left: 0.25em;
  }
  &.part-installed {
    border-radius: 0.25em 0 0 0.25em;
    background-image: linear-gradient(90deg, rgba(#f60, 0.5), rgba(#f60, 0.0) 65%);
  }
  > * {
    flex: 1 1 auto;
  }
  &:not(:last-child) {
    border-bottom: 1px solid #666;
  }
}

.part-info-col {
  display: flex;
  flex-direction: column;
  justify-content: stretch;
  flex: 1 1 auto; /* Allows it to grow but keeps it within bounds */
  max-width: calc(100% - 100px); /* Adjust according to the button width */
  overflow: hidden;

  > * {
    max-width: 100%;
    overflow: hidden;
  }
}

.part-info-row {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: baseline;
  > * {
    flex: 1 1 auto;
  }
}

.part-button {
  min-width: 100px;
  flex: 0 0 auto; /* Prevent it from shrinking or growing */
}

.part-name {
  display: block;
  font-size: 1.1em;
  font-weight: 600;
  white-space: nowrap;
  text-overflow: ellipsis;
  overflow: hidden;
}

.mileage-text {
  font-size: 0.9em;
  font-weight: normal;
  color: rgba(255, 255, 255, 0.8);
}

.center {
  text-align: center;
}
.right {
  text-align: right;
}

.search-container {
  width: 100%;
}

.no-results {
  padding: 1em;
  text-align: center;
  color: rgba(255, 255, 255, 0.7);
  font-style: italic;
}
</style>
