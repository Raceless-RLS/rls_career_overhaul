<template>
  <!--div class="vehicle-shop-wrapper"-->
  <BngCard class="vehicle-shop-wrapper" v-bng-blur bng-ui-scope="vehicleList">
    <div class="address-bar">
      <BngButton v-bng-on-ui-nav:back,menu.asMouse @click="close" :accent="ACCENTS.attention">
        <BngBinding ui-event="back" deviceMask="xinput" />Back
      </BngButton>
      <div class="spacer"></div>
      <div class="field">
        <BngInput 
          v-model="localSearchQuery"
          placeholder="Search for a vehicle"
          @focus="inputFocused = true"
          @blur="triggerSearch"
          @keydown.enter="triggerSearch"
        />
      </div>
      <div class="spacer" style="width: 8em"></div>
    </div>
    <div class="site-body" bng-nav-scroll bng-nav-scroll-force>
      <!-- <div class="heading">
        Place for customizing the shop's appearance, planning to add some image here
        <h1 style="width:100%; text-align:center;">{{ getHeaderText() }}</h1>
      </div> -->
      <!-- <div class="layo-ut">
        <span v-for="(layout, key) of layouts" :key="key" @click="switchLayout(key)" :class="{'layout-selected': layout.selected}">{{ layout.name }}</span>
      </div> disabled temporarily -->
      <div class="price-notice"><span>*&nbsp;</span><span>Additional taxes and fees are applicable</span></div>
      
      <!-- Show regular list if at a specific dealer -->
      <div v-if="vehicleShoppingStore?.vehicleShoppingData?.currentSeller" class="vehicle-list">
        <VehicleCard
          v-for="(vehicle, key) in vehicleShoppingStore.filteredVehicles"
          :key="key"
          :vehicleShoppingData="vehicleShoppingStore.vehicleShoppingData"
          :vehicle="vehicle" />
      </div>
      
      <!-- Show all vehicles in a flat list when searching -->
      <div v-else-if="hasActiveSearch" class="vehicle-list">
        <VehicleCard
          v-for="(vehicle, key) in allFilteredVehicles"
          :key="vehicle.shopId"
          :vehicleShoppingData="vehicleShoppingStore.vehicleShoppingData"
          :vehicle="vehicle" />
      </div>
      
      <!-- Show dealer sections if browsing all dealers without search -->
      <div v-else>
        <Accordion class="dealer-groups" singular>
          <AccordionItem
            v-for="dealer in vehicleShoppingStore.vehiclesByDealer"
            :key="dealer.id"
            :data-dealerid="dealer.id"
            navigable
            :expanded="dealer.expanded"
            @expanded="(state) => onDealerExpanded(dealer, state)"
          >
            <template #caption>
              <div class="dealer-caption">
                <div 
                  v-if="dealerMetadata[dealer.id]?.preview" 
                  class="dealer-preview"
                  :style="{ backgroundImage: `url('${dealerMetadata[dealer.id].preview}')` }"
                ></div>
                <div class="dealer-info">
                  <div class="dealer-name">{{ dealerMetadata[dealer.id]?.name || dealer.name }}</div>
                  <div class="dealer-description">{{ dealerMetadata[dealer.id]?.description }}</div>
                </div>
                <div class="dealer-count">
                  {{ dealer.vehicles.length }} Vehicles
                </div>
              </div>
            </template>

            <div class="vehicle-list">
              <VehicleCard
                v-for="(vehicle, key) in dealer.vehicles"
                :key="key"
                :vehicleShoppingData="vehicleShoppingStore.vehicleShoppingData"
                :vehicle="vehicle" />
            </div>
          </AccordionItem>
        </Accordion>
      </div>
    </div>
  </BngCard>
  <!--/div-->
</template>

<script setup>
import { reactive, onMounted, ref, computed, watch } from "vue"
import VehicleCard from "./VehicleCard.vue"
import { BngCard, BngButton, ACCENTS, BngBinding, BngInput } from "@/common/components/base"
import { vBngBlur, vBngOnUiNav } from "@/common/directives"
import { lua } from "@/bridge"
import { useVehicleShoppingStore } from "../../stores/vehicleShoppingStore"
import { Accordion, AccordionItem } from "@/common/components/utility"

import { useUINavScope } from "@/services/uiNav"
useUINavScope("vehicleList")

const vehicleShoppingStore = useVehicleShoppingStore()
const dealerMetadata = ref({})
const inputFocused = ref(false)
const localSearchQuery = ref('')
const activeSearchQuery = ref('')

// Trigger search only on explicit action (Enter key or blur)
const triggerSearch = () => {
  activeSearchQuery.value = localSearchQuery.value.trim()
  inputFocused.value = false // Reset focus state
}

// Use a separate variable to track if we have an active search
const hasActiveSearch = computed(() => activeSearchQuery.value.length > 0)

// Collect all vehicles across all dealers when searching
const allFilteredVehicles = computed(() => {
  if (!hasActiveSearch.value) return []
  
  const query = activeSearchQuery.value.toLowerCase()
  let allVehicles = []
  
  // If we're at a specific dealer, use filteredVehicles
  if (vehicleShoppingStore?.vehicleShoppingData?.currentSeller) {
    return vehicleShoppingStore.filteredVehicles
  }
  
  // Otherwise collect vehicles from all dealers
  vehicleShoppingStore.vehiclesByDealer.forEach(dealer => {
    dealer.vehicles.forEach(vehicle => {
      const searchFields = [
        vehicle.Name,
        vehicle.Brand, 
        vehicle.niceName,
        vehicle.model_key,
        vehicle.config_name,
      ]
      
      const matchesSearch = searchFields.some(field => 
        field && field.toString().toLowerCase().includes(query)
      )
      
      if (matchesSearch) {
        allVehicles.push(vehicle)
      }
    })
  })
  
  // Sort by price
  return allVehicles.sort((a, b) => a.Value - b.Value)
})

// Fetch dealership data on component mount
onMounted(async () => {
  const currentLevel = await lua.getCurrentLevelIdentifier()
  console.log("Current Level:", currentLevel)
  
  const facilities = await lua.career_modules_vehicleShopping.getShoppingData()
  console.log("Facilities:", facilities)
  
  if (facilities?.dealerships) {
    // Create a lookup object by dealer ID
    dealerMetadata.value = facilities.dealerships.reduce((acc, dealer) => {
      acc[dealer.id] = dealer
      return acc
    }, {})
    console.log("Dealer Metadata:", dealerMetadata.value)
  }
})

const getHeaderText = () => {
  const data = vehicleShoppingStore ? vehicleShoppingStore.vehicleShoppingData : {}
  if (data.currentSeller == null || data.currentSeller === undefined) {
    return "BeamCar24"
  }
  return data.currentSellerNiceName
}

const getWebsiteText = () => {
  const headerText = getHeaderText()
  return headerText.replace(/\s+/g, "-") + ".com"
}

const close = () => {
  lua.career_modules_vehicleShopping.cancelShopping()
}

const layouts = reactive([
  { name: "switch", selected: true, class: "" },
  { name: "me", selected: false, class: "" },
  { name: "please", selected: false, class: "" },
])
function switchLayout(key) {
  for (let i = 0; i < layouts.length; i++) layouts[i].selected = key === i
}

const onDealerExpanded = (dealer, state) => {
  dealer.expanded = state
}

const sortedDealers = computed(() => {
  return vehicleShoppingStore.vehiclesByDealer.slice().sort((a, b) => {
    const nameA = dealerMetadata.value[a.id]?.name || a.name;
    const nameB = dealerMetadata.value[b.id]?.name || b.name;
    return nameA.localeCompare(nameB);
  });
});
</script>

<style scoped lang="scss">
.vehicle-shop-wrapper {
  flex: 1 1 auto;
  min-height: 0;
  max-width: 80rem;
  height: 100%;
  .address-bar {
    flex: 0 0 auto;
    display: flex;
    flex-flow: row;
    align-items: center;
    background-color: var(--bng-cool-gray-700);
    padding: 0.5rem;

    & > .spacer {
      flex: 0.2 0.2 0.25rem;
    }
    & > .field {
      border-radius: var(--bng-corners-1);
      background-color: var(--bng-cool-gray-900);
      // border: 0.0625rem solid var(--bng-cool-gray-600);
      flex: 1 1 auto;
      text-overflow: ellipsis;
      color: white;
      text-align: center;
      // text-transform: lowercase;
      & > span {
        &::before {
          content: " ";
          display: inline-block;
          height: auto;
          color: var(--bng-cool-gray-400);
        }
        &::after {
          content: " ";
          display: inline-block;
          height: auto;
          color: var(--bng-cool-gray-400);
        }
      }
    }
  }

  .site-body {
    min-height: 0;
    overflow: auto;
    color: white;
  }
  .layo-ut {
    position: sticky;
    top: 0px;
    left: 1rem;
    z-index: 9999;
    border-radius: var(--bng-corners-2);
    width: 16rem;
    padding: 0.5rem;
    background: var(--bng-cool-gray-800);
  }
  .price-notice {
    display: inline-flex;
    padding: 0.25rem 1rem;
    justify-content: flex-end;
    width: 100%;
    color: var(--bng-cool-gray-200);
  }
  .heading {
    display: flex;
    flex-flow: row wrap;
    align-items: flex-start;
    padding: 0.5rem;
  }
  .vehicle-list {
    display: flex;
    flex-flow: row wrap;
    width: 100%;
    overflow-y: auto;
    padding: 0.5rem 0.5rem 1rem 0.5rem;
    // height: 90%;
    min-height: 0;
    // background: #bdc8d1;
  }
}

.layout-selected {
  color: pink;
}

.dealer-groups {
  min-height: 0;
  max-height: 80vh;
  display: flex;
  flex-direction: column;
}

.dealer-caption {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: center;
  overflow: hidden;
  width: 100%;
  height: 4em;
  padding: 0.5rem;

  .dealer-preview {
    width: 8em;
    height: 100%;
    background-size: cover;
    background-position: center;
    background-repeat: no-repeat;
    border-radius: var(--bng-corners-1);
  }

  .dealer-info {
    flex: 1 1 auto;
    padding: 0 1rem;
    overflow: hidden;

    .dealer-name {
      font-size: 1.2em;
      font-weight: 600;
    }

    .dealer-description {
      font-size: 0.9em;
      color: var(--bng-cool-gray-300);
      white-space: nowrap;
      text-overflow: ellipsis;
      overflow: hidden;
    }
  }

  .dealer-count {
    flex: 0 0 auto;
    padding: 0.5rem;
    font-weight: 300;
  }
}
</style>
