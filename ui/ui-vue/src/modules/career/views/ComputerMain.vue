<template>
  <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Home screen" close @close="close">

    <BngCard class="card-content" v-bng-blur="1" >
      <BngCardHeading>
        {{ computerLoading ? "Loading..." : "Vehicle management" }}
      </BngCardHeading>

      <div v-if="!computerLoading" class="vehicle-actions">
        <template v-if="hasVehicles">
          <h3>
            <div class="vehicle-select" >
              <BngButton style="height: 3em;" v-if="showVehicleSelectorButtons" :accent="ACCENTS.outlined" @click="switchActiveVehicle(-1)" v-bng-on-ui-nav:tab_l.asMouse :icon="icons.arrowLargeLeft">
                <BngBinding ui-event="tab_l" deviceMask="xinput" />
              </BngButton>
              <BngList v-if="currentVehicleData" style="width: 20em;">
                <VehicleTile
                  style="height: 13em"
                  :data="currentVehicleData"
                  layout="tile"
                  :enableHover="false"
                />

                <BngButton style="height: 2em;" @click="startPerformanceTest()" :disabled="isTutorialActive || !currentVehicleData || currentVehicleData.needsRepair || !currentVehicleData.owned">
                  {{ startTestTitle }}
                </BngButton>
              </BngList>
              <BngButton style="height: 3em;" v-if="showVehicleSelectorButtons" :accent="ACCENTS.outlined" @click="switchActiveVehicle(1)" v-bng-on-ui-nav:tab_r.asMouse :icon-right="icons.arrowLargeRight">
                <BngBinding ui-event="tab_r" deviceMask="xinput" />
              </BngButton>
            </div>
          </h3>

          <div class="actions-list" v-if="computerStore.activeInventoryId && computerStore.vehicleSpecificComputerFunctions[computerStore.activeInventoryId]">
            <BngImageTile
              v-for="(computerFunction, index) in computerStore.vehicleSpecificComputerFunctions[computerStore.activeInventoryId]"
              :key="computerFunction.id"
              :class="{ 'action-disabled': computerFunction.disabled }"
              tabindex="0" bng-nav-item v-bng-on-ui-nav:ok.asMouse.focusRequired
              @click="computerButtonCallback(computerFunction, computerStore.activeInventoryId)"
              @mouseover="setReason(0, infoById[computerFunction.id].reason)"
              @focus="setReason(0, infoById[computerFunction.id].reason)"
              @mouseleave="setReason(0)"
              @blur="setReason(0)"
              v-bng-ui-nav-focus="index == 0 ? 0 : undefined"
              :icon="infoById[computerFunction.id].icon"
              :label="infoById[computerFunction.id].label" />
          </div>
          <div class="disable-reason">
            <BngIcon class="disable-icon" v-show="disableReason[0]" :type="icons.info" />
            <span v-html="disableReason[0] || '&nbsp;'"></span>
          </div>
        </template>

        <h3 v-else>No vehicle in garage</h3>

        <div v-if="computerStore.generalComputerFunctions">
          <h3>Inventory, Shopping, Insurance</h3>
          <div class="actions-list">
            <template v-for="(computerFunction, index) in computerStore.generalComputerFunctions" :key="computerFunction.id">
              <BngImageTile
                v-if="!computerFunction.type"
                :class="{ 'action-disabled': computerFunction.disabled }"
                tabindex="0"
                bng-nav-item v-bng-on-ui-nav:ok.asMouse.focusRequired
                @click="computerButtonCallback(computerFunction)"
                @mouseover="setReason(1, infoById[computerFunction.id].reason)"
                @focus="setReason(1, infoById[computerFunction.id].reason)"
                @mouseleave="setReason(1)"
                @blur="setReason(1)"
                v-bng-ui-nav-focus="!hasVehicles && index == 0 ? 0 : undefined"
                :icon="infoById[computerFunction.id].icon"
                :label="infoById[computerFunction.id].label" />
            </template>
          </div>
          <div class="disable-reason">
            <BngIcon class="disable-icon" v-show="disableReason[1]" :type="icons.info" />
            <span v-html="disableReason[1] || '&nbsp;'"></span>
          </div>
        </div>

        <div>
          <h3>Activities & Events</h3>
          <div class="actions-list">
            <template v-for="(computerFunction, index) in computerStore.activityComputerFunctions">
              <BngImageTile
                v-if="!computerFunction.type"
                :class="{ 'action-disabled': computerFunction.disabled }"
                tabindex="0"
                bng-nav-item v-bng-on-ui-nav:ok.asMouse.focusRequired
                @click="computerButtonCallback(computerFunction)"
                @mouseover="setReason(2, infoById[computerFunction.id].reason)"
                @focus="setReason(2, infoById[computerFunction.id].reason)"
                @mouseleave="setReason(2)"
                @blur="setReason(2)"
                :icon="infoById[computerFunction.id].icon"
                :label="infoById[computerFunction.id].label" />
            </template>
          </div>
          <div class="disable-reason">
            <BngIcon class="disable-icon" v-show="disableReason[2]" :type="icons.info" />
            <span v-html="disableReason[2] || '&nbsp;'"></span>
          </div>
        </div>
      </div>
    </BngCard>
  </ComputerWrapper>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from "vue"
import { lua } from "@/bridge"
import { useComputerStore } from "../stores/computerStore"
import ComputerWrapper from "./ComputerWrapper.vue"
import { BngButton, ACCENTS, BngCard, BngCardHeading, BngBinding, BngImageTile, BngIcon, icons, BngList } from "@/common/components/base"
import { default as UINavEvents, UI_EVENT_GROUPS } from "@/bridge/libs/UINavEvents"
import { vBngOnUiNav, vBngBlur, vBngUiNavFocus } from "@/common/directives"
import VehicleTile from "../components/vehicleInventory/VehicleTile.vue"
import { LIST_LAYOUTS } from "@/common/components/base"

const computerStore = useComputerStore()
const currentVehicleData = ref(null)

watch(() => computerStore.activeInventoryId, (newId) => {
  if (Number(newId)) {
    lua.career_modules_inventory.getVehicleUiData(newId).then(data => {
      currentVehicleData.value = data
    })
  }
})

const showVehicleSelectorButtons = computed(() => computerStore.computerData.vehicles && computerStore.computerData.vehicles.length > 1)

const hasVehicles = computed(() => computerStore.computerData.vehicles && computerStore.computerData.vehicles.length)
const currentVehicleName = computed(() => (hasVehicles.value ? computerStore.computerData.vehicles[computerStore.activeVehicleIndex].vehicleName : ""))
const currentVehicleThumbnail = computed(() => (hasVehicles.value ? computerStore.computerData.vehicles[computerStore.activeVehicleIndex].thumbnail : ""))

const startTestTitle = computed(() => hasVehicles.value ? (computerStore.computerData.vehicles[computerStore.activeVehicleIndex].needsRepair ? "Assess Performance (Repair Required)" : "Assess Performance") : "")

// list of function IDs that are known to take some time, so we inform the user about loading
const slowFunctions = ["vehicleShop", "partInventory"]
const computerLoading = ref(false)

const computerButtonCallback = (computerFunction, inventoryId = undefined) => {
  if (computerFunction.disabled) return
  if (slowFunctions.includes(computerFunction.id)) {
    computerLoading.value = true
    // for some reason, both nextTick and window.requestAnimationFrame does not produce the desired result
    setTimeout(() => computerStore.computerButtonCallback(computerFunction.id, inventoryId), 100)
  } else {
    computerStore.computerButtonCallback(computerFunction.id, inventoryId)
  }
}
const switchActiveVehicle = computerStore.switchActiveVehicle

const iconById = {
  painting: icons.sprayCan,
  partShop: icons.cardboardBoxCoins,
  repair: icons.wrench,
  tuning: icons.cogs,
  insurancePolicies: icons.shieldHandCheckmark,
  vehicleInventory: icons.keys1,
  partInventory: icons.engine,
  vehicleShop: icons.carCoins,
  performanceIndex: icons.raceFlag,
  sleep: icons.night,
  carMeets: icons.cars,
  marketplace: icons.shoppingCart
}

const infoById = computed(() => [
  ...computerStore.generalComputerFunctions,
  ...(computerStore.activeInventoryId ? computerStore.vehicleSpecificComputerFunctions[computerStore.activeInventoryId] : undefined) || [],
  ...computerStore.activityComputerFunctions,
].reduce((res, func) => {
  res[func.id] = {
    icon: iconById[func.id] || icons.bug,
    label: func.label,
    reason: undefined,
  }
  if (func.reason) {
    /// nbsp by size:
    // narrow: " "
    // normal: " "
    // figure: " "
    res[func.id].label += " *"
    // string "func.disableReason" is for backward compatibility with an old style
    res[func.id].reason = func.reason.label
    // TODO: alternate something when "func.disableReason.type" is not "text" (discussion is on-going)
  }
  return res
}, {}))

const isTutorialActive = ref(false)
const disableReason = ref([null, null, null])
const setReason = (idx, reason = null) => {
  disableReason.value = disableReason.value.map((_, i) => i === idx ? reason : null)
}

const startPerformanceTest = function() {
  lua.career_modules_vehiclePerformance.startDragTestFromOutsideMenu(computerStore.activeInventoryId, computerStore.computerData.computerId)
}

const close = () => {
  if (computerLoading.value) return
  lua.career_career.closeAllMenus()
}

const start = async () => {
  UINavEvents.setFilteredEvents(UI_EVENT_GROUPS.focusMoveScalar)
  computerStore.requestComputerData()

  if (Number(computerStore.activeInventoryId)) {
    lua.career_modules_inventory.getVehicleUiData(computerStore.activeInventoryId).then(data => {
      currentVehicleData.value = data
    })
  }
  lua.career_modules_linearTutorial.isLinearTutorialActive().then(data => {
    isTutorialActive.value = data
  })
}

const kill = () => {
  computerStore.onMenuClosed()
  UINavEvents.clearFilteredEvents()
  computerStore.$dispose()
}

onMounted(start)
onUnmounted(kill)
</script>

<style scoped lang="scss">
.card-content {
  width: max-content;
  max-width: 100%;
  height: 100%;
  color: white;
  background-color: rgba(0, 0, 0, 0.75);
  & :deep(.card-cnt) {
    background-color: rgba(0, 0, 0, 0);
  }
}

.vehicle-actions {
  display: flex;
  flex-direction: column;
  overflow: auto;
  padding: {
    left: 2em;
    right: 2em;
  }
  > :deep(.tile) {
    display: inline-flex;
  }
}

.vehicle-select {
  display: inline-flex;
  font-size: 1rem;
  > * {
    flex: 0 0 auto;
    min-width: 3em !important;
    // width: 3em;
  }
}

.veh-preview {
  position: absolute;
  top: 1em;
  right: 2em;
  width: 11em;
  height: 6em;
  background-color: #0008;
  background-image: var(--veh-preview);
  background-size: cover;
  background-position: 50% 50%;
  background-repeat: no-repeat;

  // decoration
  // &::before,
  // &::after {
  //   content: "";
  //   position: absolute;
  //   width: 40%;
  //   height: 1em;
  //   background-color: #f60;
  //   transform: skewX(-23deg);
  // }
  // &::before {
  //   top: -1em;
  //   right: 20%;
  //   transform-origin: 50% 100%;
  // }
  // &::after {
  //   bottom: -1em;
  //   left: 20%;
  //   transform-origin: 50% 0%;
  // }
}

.actions-list {
  display: flex;
  flex-flow: row nowrap;
  justify-content: space-between;
  > * {
    flex: 0 0 auto;
    margin-bottom: 1em !important;
    &:not(:last-child) {
      margin-right: 2em !important;
    }
  }
  & [bng-nav-item] {
    cursor: pointer;
  }
}

.action-disabled {
  filter: brightness(70%);
  cursor: default !important;
}

.disable-reason {
  display: flex;
  align-items: baseline;
  height: 1.2em;
  .disable-icon {
    margin-right: 0.1em;
  }
}

.class-info-wrapper {
  display: inline-block;
  margin-left: 0.5em;
  vertical-align: middle;
}

.class-info {
  display: inline-flex;
  align-items: center;
  gap: 0.25em;
  font-size: 0.9em;

  .separator {
    color: #888;
    margin: 0 0.25em;
  }

  .class-details {
    display: flex;
    gap: 0.35em;
    align-items: center;
    padding-bottom: 3px;
  }

  .class-name {
    color: #ccc;
  }

  .performance-index {
    display: inline-flex;
    font-weight: 600;
    border-radius: 0.25em;
    overflow: hidden;
    align-items: center;

    .class-segment {
      background: #666;
      color: #fff;
      padding: 0.15em 0.4em;
      display: flex;
      align-items: center;
    }

    .number-segment {
      background: #444;
      color: #fff;
      padding: 0.15em 0.4em;
      display: flex;
      align-items: center;
    }
  }

  .class-na {
    color: #888;
  }

  .class-badge {
    display: inline-flex;
    align-items: center;
    background-color: rgba(90, 78, 20, 0.541);
    padding: 6px 8px 2px 8px;
    border-radius: 999px;
    color: #f0a500;
  }
}
</style>
