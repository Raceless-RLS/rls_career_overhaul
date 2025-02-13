<template>
  <div style="height: 100%; color: white;">
    <BngInput class="searchField" floating-label="Search" :leading-icon="icons.search" v-model.trim="partInventoryStore.searchString" />
    <BngCard style="max-height: 90%;" v-bng-disabled="!partInventoryStore">
      <div v-if="!partInventoryStore">
        Please wait...
      </div>
      <!-- <div v-else-if="groups.length === 0">
        You don't currently own any parts
      </div> -->
      <Accordion v-else class="part-groups" singular>
        <AccordionItem v-for="(group, index) in groups" :key="group.id" :data-groupid="group.id" ref="accordionItems"
          navigable @expanded="group.onExpanded" captionAlignItemsOption="center" @selected="accordionItems[index] ? accordionItems[index].captionClick() : undefined">

          <BngButton
            v-if="group.name == ' Inventory'"
            :accent="ACCENTS.outlined"
            @click="openSellPopup()">
            Sell Parts
          </BngButton>

          <template #caption>
            <div class="veh-part-caption">
              <BngIcon v-if="group.icon" class="veh-icon" :type="group.icon" />
              <div v-if="group.thumbnail" class="veh-preview" :style="{ backgroundImage: `url('${group.thumbnail}')` }" ></div>
              <span class="veh-name">
                {{ group.name }}
                <span class="veh-name-count">({{ group.parts.length }})</span>
              </span>
            </div>
          </template>

          <div v-for="(part, index) in group.parts" class="part-item"
            bng-ui-scope="veh-part-inv"
            v-bng-on-ui-nav:back="() => group.onExpanded(false)">
            <div class="part-info-col" v-if="(group.ready || index < immediateLimit)">
              <div>
                <span class="part-name">{{ part.name }}</span>
              </div>
              <div class="part-info-row">
                <span class="right">{{ part.mileage }}</span>
                <!-- note: BngUnit is very slow -->
                <!-- <span class="right"><BngUnit :money="part.value" /></span> -->
                <!-- <span class="right"><BngPropVal :iconType="icons.beamCurrency" :valueLabel="units.beamBucks(part.value)" /></span> -->
                <span class="right"><BngPropVal :iconType="icons.beamCurrency" :valueLabel="part.valueFormatted" /></span>
                <span v-if="groupBy !== 'location'" class="center">{{ part.location }}</span>
                <span v-else-if="groupBy !== 'model'" class="center">{{ part.model }}</span>
              </div>
            </div>
            <BngButton
              v-if="(group.ready || index < immediateLimit)"
              :disabled="!part.functions.install || disableInstallButtons"
              :accent="ACCENTS.outlined"
              class="part-button"
              @click="movePartToLocation(partInventoryStore.partInventoryData.currentVehicle, part.data.id)"
              v-bng-tooltip="'Put into current vehicle'">
              Install
            </BngButton>
            <BngButton
              v-if="(group.ready || index < immediateLimit) && !part.functions.sell"
              :disabled="!part.functions.uninstall || disableInstallButtons"
              :accent="ACCENTS.outlined"
              class="part-button"
              @click="movePartToLocation(0, part.data.id)"
              v-bng-tooltip="'Remove from vehicle'">
              Uninstall
            </BngButton>
            <BngButton
              v-if="(group.ready || index < immediateLimit) && part.functions.sell"
              :accent="ACCENTS.outlined"
              class="part-button"
              @click="confirmSellPart(part.data)">
              Sell
            </BngButton>
          </div>
        </AccordionItem>
      </Accordion>
    </BngCard>
  </div>

</template>

<script setup>
import { ref, toRaw, watchEffect, markRaw, onMounted } from "vue"
import { lua, useBridge } from "@/bridge"
import { BngCard, BngUnit, BngPropVal, BngButton, BngIcon, ACCENTS, icons, BngInput } from "@/common/components/base"
import { Accordion, AccordionItem } from "@/common/components/utility"
import { vBngDisabled, vBngTooltip } from "@/common/directives"
import { usePartInventoryStore } from "../../stores/partInventoryStore"
import { openConfirmation, openExperimental, openMessage, openScreenOverlay,openPrompt,addPopup } from "@/services/popup"
import { $translate } from "@/services/translation"
import { vBngOnUiNav } from "@/common/directives"
import PartSellingPopup from "../partInventory/PartSellingPopup.vue"

const { units, events } = useBridge()

const emit = defineEmits(["partSold"])
const partInventoryStore = usePartInventoryStore()

// number of parts to show right away
const immediateLimit = 15

const groupBy = ref("location")

const groups = ref([])
const accordionItems = ref([])
const disableInstallButtons = ref(false)
const listedVehicleIds = ref([])

onMounted(() => {
  lua.career_modules_vehicleMarketplace.requestInitialData()
})

const addExpandedFuncToGroup = (group) => {
  group.onExpanded = state => {
    // group will be mutated later, so it's better to find it
    const grp = groups.value.find(g => g.id === group.id)
    grp.expanded = state
    if (!state) {
      delete grp.ready
      const elm = document.querySelector(`[data-groupid="${group.id}"] > .bng-accitem-caption`)
      elm && elm.focus()
      return
    }
    if (!("ready" in grp)) {
      grp.ready = false
      setTimeout(() => {
        // for safety, find it again
        const grp = groups.value.find(g => g.id === group.id)
        if (grp && (typeof grp.ready === "boolean")) {
          grp.ready = true
        }
      }, 100)
    }
  }
}

const openSellPopup = async () => {
  const res = await addPopup(PartSellingPopup, { parts: groups.value[0].parts }).promise
  if (res) {
    emit("partSold")
  }
}

events.on("marketplaceUpdate", (data) => {
    listedVehicleIds.value = Object.keys(data)
})

watchEffect(() => {
  disableInstallButtons.value = false
  if (!partInventoryStore || !Array.isArray(partInventoryStore.partInventoryData.partList) || partInventoryStore.partInventoryData.partList.length === 0) {
    return []
  }
  const res = []

  if (groupBy.value == "location") {
    let group = {
      id: 0,
      name: " Inventory",
      parts: [],
      expanded: false,
      icon: icons.BNGFolder
    }
    addExpandedFuncToGroup(group)
    res.push(group)

    for (const [vehId, vehicle] of Object.entries(partInventoryStore.partInventoryData.vehicles)) {
      let group = {
        id: vehId,
        name: vehicle.niceName,
        parts: [],
        expanded: false,
        thumbnail: partInventoryStore.partInventoryData.vehicles[vehId].thumbnail
      }
      addExpandedFuncToGroup(group)
      res.push(group)
    }
  }

  for (const part of partInventoryStore.partInventoryData.filteredPartList) {
    const item = {
      name: part.missingFile ? "Missing File" : part.description.description,
      model: part.vehicleModel,
      mileage: units.buildString("length", part.partCondition.odometer, 0),
      // value: part.finalValue,
      valueFormatted: units.beamBucks(part.finalValue),
      location: part.location,
      // please leave the whitespace in inventory name - it helps it sort to the top without any visual change
      locationName: part.location === 0 ? " Inventory" : partInventoryStore.partInventoryData.vehicles[part.location].niceName,
      functions: {
        install: false,
        uninstall: false,
        sell: false,
      },
      data: part,
    }
    if (!part.missingFile && part.accessible) {
      item.functions.install =
        part.fitsCurrentVehicle
        && part.location !== partInventoryStore.partInventoryData.currentVehicle
        && (part.location === 0 || !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[part.location])
        && !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[partInventoryStore.partInventoryData.currentVehicle]
        && !listedVehicleIds.value.includes(part.location.toString())
      item.functions.uninstall =
        part.location !== 0
        && !part.isInCoreSlot
        && !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[part.location]
        && !listedVehicleIds.value.includes(part.location.toString())
      item.functions.sell =
        part.location === 0
    }
    const groupId = item[groupBy.value]
    let group = res.find(g => g.id == groupId)
    if (!group) {
      group = {
        id: groupId,
        name: item[`${groupBy.value}Name`] || item[groupBy.value],
        parts: [],
        expanded: false,
      }
      if (part.location > 0) {
        group.thumbnail = partInventoryStore.partInventoryData.vehicles[part.location].thumbnail
      } else {
        // folder BNGFolder
        group.icon = icons.BNGFolder
      }
      // this function and group.ready is solely to relieve the lag effect with a magic trick of not showing everything right away, until we find a better solution
      // right now only 15 elements are rendered right away, others - after the 100ms delay
      addExpandedFuncToGroup(group)
      res.push(group)
    }
    group.parts.push(item)
  }
  if (res.length > 0) {
    const sorter = (a, b) => a.name.localeCompare(b.name)
    res.sort(sorter)
    for (const group of res) {
      group.parts.sort(sorter)
    }
  }
  // restore the state
  for (const group of groups.value) {
    if (group.ready) {
      const grp = res.find(g => g.name === group.name)
      if (grp) {
        grp.expanded = true
        grp.ready = true
      }
    }
  }
  // show the result
  groups.value = res
})

const confirmSellPart = async partToSell => {
  const res = await openConfirmation(partToSell.description.description, `Do you want to sell this part for ${units.beamBucks(partToSell.finalValue)}?`, [
    { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
    { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
  ])
  if (res) sellPart(partToSell)
}

const showPartInstallPopup = (data) => {
  if (data) {
    if (data.success) {
      partInventoryStore.openNewPartsPopup(data.newPartIds)
    } else {
      openMessage(data.title, data.message)
    }
  }
}

const movePartToLocation = (location, partId) => {
  if (disableInstallButtons.value) { return }
  disableInstallButtons.value = true
  lua.career_modules_partInventory.movePart(location, partId).then(showPartInstallPopup)
}

const sellPart = part => {
  lua.career_modules_partInventory.sellParts([part.id])
  emit("partSold")
}
</script>

<style scoped lang="scss">
.part-groups {
  max-height: 100%;
  overflow: hidden auto;
}

.searchField {
  background-color: rgba(0, 0, 0, 0.575);
}

.veh-part-caption {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: center;
  overflow: hidden;
  width: 100%;
  height: 4em;
  $preview: 8em; // thumbnail width
  .veh-icon {
    $sz: 4; // in em
    $diff: $preview - $sz;
    padding: 0 calc($diff / 2 / $sz);
    font-size: $sz * 1em;
    background-color: #aaa5;
  }
  .veh-preview {
    width: $preview;
    align-self: stretch;
    background-size: auto 110%;
    background-position: 50% 50%;
    background-repeat: no-repeat;
  }
  .veh-name {
    flex: 1 1 auto;
    padding-left: 0.3em;
    font-size: 1.2em;
    .veh-name-count {
      font-weight: 300;
    }
  }
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
}
.part-info-row {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: baseline;
  > * {
    flex: 1 1 33.333%;
  }
}

.part-button {
  flex: 0 0 auto;
}

.part-name {
  font-size: 1.1em;
  font-weight: 600;
  white-space: nowrap;
  text-overflow: ellipsis;
  // overflow: hidden;
}

.center {
  text-align: center;
}
.right {
  text-align: right;
}
</style>
