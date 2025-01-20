<template>
  <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Home screen" close @close="close">

    <BngCard class="card-content" v-bng-blur="1" >
      <BngCardHeading>
        {{ computerLoading ? "Loading..." : "Vehicle management" }}
      </BngCardHeading>

      <div v-if="!computerLoading" class="vehicle-actions">
        <template v-if="hasVehicles">
          <div v-if="currentVehicleThumbnail" class="veh-preview" :style="{ '--veh-preview': `url('${currentVehicleThumbnail}')` }" ></div>

          <h3>
            {{ currentVehicleName }}
            <div class="vehicle-select" v-if="showVehicleSelectorButtons">
              <BngButton :accent="ACCENTS.outlined" @click="switchActiveVehicle(-1)" v-bng-on-ui-nav:tab_l.asMouse :icon="icons.arrowLargeLeft">
                <BngBinding ui-event="tab_l" deviceMask="xinput" />
              </BngButton>
              <BngButton :accent="ACCENTS.outlined" @click="switchActiveVehicle(1)" v-bng-on-ui-nav:tab_r.asMouse :icon-right="icons.arrowLargeRight">
                <BngBinding ui-event="tab_r" deviceMask="xinput" />
              </BngButton>
            </div>
          </h3>

          <div class="actions-list" v-if="computerStore.activeInventoryId && computerStore.vehicleSpecificComputerFunctions[computerStore.activeInventoryId]">
            <BngImageTile
              v-for="(computerFunction, index) in computerStore.vehicleSpecificComputerFunctions[computerStore.activeInventoryId]"
              :class="{ 'action-disabled': computerFunction.disabled }"
              tabindex="0" bng-nav-item v-bng-on-ui-nav:ok.asMouse.focusRequired
              @click="computerButtonCallback(computerFunction, computerStore.activeInventoryId)"
              @mouseover="setReason(0, infoById[computerFunction.id].reason)"
              @focus="setReason(0, infoById[computerFunction.id].reason)"
              @mouseleave="setReason(0)"
              @blur="setReason(0)"
              v-bng-focus-if="index == 0"
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
            <template v-for="(computerFunction, index) in computerStore.generalComputerFunctions">
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
                v-bng-focus-if="!hasVehicles && index == 0"
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
import { ref, computed, onMounted, onUnmounted } from "vue"
import { lua } from "@/bridge"
import { useComputerStore } from "../stores/computerStore"
import ComputerWrapper from "./ComputerWrapper.vue"
import { BngButton, ACCENTS, BngCard, BngCardHeading, BngBinding, BngImageTile, BngIcon, icons } from "@/common/components/base"
import { default as UINavEvents, UI_EVENT_GROUPS } from "@/bridge/libs/UINavEvents"
import { vBngOnUiNav, vBngBlur,vBngFocusIf } from "@/common/directives"

const computerStore = useComputerStore()
const showVehicleSelectorButtons = computed(() => computerStore.computerData.vehicles && computerStore.computerData.vehicles.length > 1)

const hasVehicles = computed(() => computerStore.computerData.vehicles && computerStore.computerData.vehicles.length)
const currentVehicleName = computed(() => (hasVehicles.value ? computerStore.computerData.vehicles[computerStore.activeVehicleIndex].vehicleName : ""))
const currentVehicleThumbnail = computed(() => (hasVehicles.value ? computerStore.computerData.vehicles[computerStore.activeVehicleIndex].thumbnail : ""))

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
  sleep: icons.night,
  carMeets: icons.cars
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

const disableReason = ref([null, null, null])
const setReason = (idx, reason = null) => {
  disableReason.value = disableReason.value.map((_, i) => i === idx ? reason : null)
}

const close = () => {
  if (computerLoading.value) return
  lua.career_career.closeAllMenus()
}

const start = () => {
  UINavEvents.setFilteredEvents(UI_EVENT_GROUPS.focusMoveScalar)
  computerStore.requestComputerData()
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
  height: auto;
  color: white;
  background-color: rgba(0, 0, 0, 0.75);
  & :deep(.card-cnt) {
    background-color: rgba(0, 0, 0, 0);
  }
}

.vehicle-actions {
  display: flex;
  flex-direction: column;
  overflow: hidden auto;
  padding: {
    left: 1em;
    right: 1em;
    bottom: 1em;
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
    min-width: 2em !important;
    // width: 3em;
  }
}

.veh-preview {
  position: absolute;
  top: 1em;
  right: 1em;
  width: 11em;
  height: auto;
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
    flex: 0 0 7em;
    margin-bottom: 0.5em !important;
    &:not(:last-child) {
      margin-right: 0.5em !important;
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
  height: 0.6em;
  .disable-icon {
    margin-right: 0.1em;
  }
  .disable-text {
    //
  }
}
</style>
