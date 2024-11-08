<template>
  <BngCard v-bng-disabled="!partInventoryStore">
    <div v-if="!partInventoryStore">
      Please wait...
    </div>
    <div v-else-if="groups.length === 0">
      You don't currently own any parts
    </div>
    <div v-else>
      <!-- Existing Accordion Component -->
      <Accordion class="part-groups" singular>
        <AccordionItem
          v-for="group in groups"
          :key="group.id"
          :data-groupid="group.id"
          navigable
          :expanded="group.expanded"
          @expanded="group.onExpanded"
        >
          <template #caption>
            <div class="veh-part-caption">
              <BngIcon v-if="group.icon" class="veh-icon" :type="group.icon" />
              <div
                v-if="group.thumbnail"
                class="veh-preview"
                :style="{ backgroundImage: `url('${group.thumbnail}')` }"
              ></div>
              <span class="veh-name">
                {{ group.name }}
                <span class="veh-name-count">({{ group.parts.length }})</span>
              </span>
            </div>
          </template>

          <!-- Inventory Group -->
          <template v-if="group.id === 0">
            <!-- Summary Item at Top -->
            <div class="part-item" bng-ui-scope="veh-part-inv">
              <div class="part-info-col">
                <div>
                  <span class="part-name">{{ group.parts.length }} Parts</span>
                </div>
                <div class="part-info-row">
                  <span class="right"></span>
                  <span class="right">
                    <BngPropVal :iconType="icons.beamCurrency" :valueLabel="totalInventoryValue" />
                  </span>
                  <span class="center"></span>
                </div>
              </div>
              <BngButton
                v-if="group.parts.length > 0"
                :accent="ACCENTS.outlined"
                class="part-button"
                @click="confirmSellAllParts"
              >
                Sell All
              </BngButton>
            </div>

            <!-- Individual Parts List -->
            <div
              v-for="(part, index) in group.parts"
              :key="part.data.id"
              class="part-item"
              bng-ui-scope="veh-part-inv"
              v-bng-on-ui-nav:back="() => group.onExpanded(false)"
            >
              <!-- Part Item Layout -->
              <div class="part-info-col" v-if="group.ready || index < immediateLimit">
                <div>
                  <span class="part-name">{{ part.name }}</span>
                </div>
                <div class="part-info-row">
                  <span class="right">{{ part.mileage }}</span>
                  <span class="right">
                    <BngPropVal :iconType="icons.beamCurrency" :valueLabel="part.valueFormatted" />
                  </span>
                  <span v-if="groupBy !== 'location'" class="center">{{ part.location }}</span>
                  <span v-else-if="groupBy !== 'model'" class="center">{{ part.model }}</span>
                </div>
              </div>
              <BngButton
                v-if="(group.ready || index < immediateLimit) && part.functions.sell"
                :accent="ACCENTS.outlined"
                class="part-button"
                @click="confirmSellPart(part.data)"
              >
                Sell
              </BngButton>
            </div>
          </template>

          <!-- Display parts for other groups -->
          <template v-else>
            <div
              v-for="(part, index) in group.parts"
              :key="part.data.id"
              class="part-item"
              bng-ui-scope="veh-part-inv"
              v-bng-on-ui-nav:back="() => group.onExpanded(false)"
            >
              <!-- Part Item Layout -->
              <div class="part-info-col" v-if="group.ready || index < immediateLimit">
                <div>
                  <span class="part-name">{{ part.name }}</span>
                </div>
                <div class="part-info-row">
                  <span class="right">{{ part.mileage }}</span>
                  <span class="right">
                    <BngPropVal :iconType="icons.beamCurrency" :valueLabel="part.valueFormatted" />
                  </span>
                  <span v-if="groupBy !== 'location'" class="center">{{ part.location }}</span>
                  <span v-else-if="groupBy !== 'model'" class="center">{{ part.model }}</span>
                </div>
              </div>
              <BngButton
                v-if="group.ready || index < immediateLimit"
                :disabled="!part.functions.install"
                :accent="ACCENTS.outlined"
                class="part-button"
                @click="movePartToLocation(partInventoryStore.partInventoryData.currentVehicle, part.data.id)"
                v-bng-tooltip="'Put into current vehicle'"
              >
                Install
              </BngButton>
              <BngButton
                v-if="(group.ready || index < immediateLimit) && !part.functions.sell"
                :disabled="!part.functions.uninstall"
                :accent="ACCENTS.outlined"
                class="part-button"
                @click="movePartToLocation(0, part.data.id)"
                v-bng-tooltip="'Remove from vehicle'"
              >
                Uninstall
              </BngButton>
              <BngButton
                v-if="(group.ready || index < immediateLimit) && part.functions.sell"
                :accent="ACCENTS.outlined"
                class="part-button"
                @click="confirmSellPart(part.data)"
              >
                Sell
              </BngButton>
            </div>
          </template>
        </AccordionItem>
      </Accordion>
    </div>
  </BngCard>
</template>

<script setup>
import { ref, toRaw, watchEffect, computed } from "vue"
import { lua, useBridge } from "@/bridge"
import { BngCard, BngUnit, BngPropVal, BngButton, BngIcon, ACCENTS, icons } from "@/common/components/base"
import { Accordion, AccordionItem } from "@/common/components/utility"
import { vBngDisabled, vBngTooltip } from "@/common/directives"
import { usePartInventoryStore } from "../../stores/partInventoryStore"
import { openConfirmation, openMessage } from "@/services/popup"
import { $translate } from "@/services/translation"
import { vBngOnUiNav } from "@/common/directives"

const { units } = useBridge()

const emit = defineEmits(["partSold"])
const partInventoryStore = usePartInventoryStore()

// Number of parts to show right away
const immediateLimit = 15

const groupBy = ref("location")

const groups = ref([])

// Computed property to calculate total inventory value
const totalInventoryValue = computed(() => {
  const inventoryGroup = groups.value.find(group => group.id === 0);
  if (inventoryGroup) {
    const totalValue = inventoryGroup.parts.reduce((acc, part) => acc + (part.data.finalValue || 0), 0);
    return units.beamBucks(totalValue);
  }
  return units.beamBucks(0);
});

watchEffect(() => {
  if (
    !partInventoryStore ||
    !Array.isArray(partInventoryStore.partInventoryData.partList) ||
    partInventoryStore.partInventoryData.partList.length === 0
  ) {
    groups.value = [];
    return;
  }

  console.log("###", partInventoryStore.partInventoryData);
  const res = [];

  for (const part of partInventoryStore.partInventoryData.partList) {
    const item = {
      name: part.missingFile ? "Missing File" : part.description.description,
      model: part.vehicleModel,
      mileage: units.buildString("length", part.partCondition.odometer, 0),
      valueFormatted: units.beamBucks(part.finalValue),
      location: part.location,
      locationName:
        part.location === 0
          ? " Inventory"
          : partInventoryStore.partInventoryData.vehicles[part.location].niceName,
      functions: {
        install: false,
        uninstall: false,
        sell: false,
      },
      data: part,
    };

    if (!part.missingFile && part.accessible) {
      item.functions.install =
        part.fitsCurrentVehicle &&
        part.location !== partInventoryStore.partInventoryData.currentVehicle &&
        (part.location === 0 ||
          !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[part.location]) &&
        !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[
          partInventoryStore.partInventoryData.currentVehicle
        ];
      item.functions.uninstall =
        part.location !== 0 &&
        !part.isInCoreSlot &&
        !partInventoryStore.partInventoryData.brokenVehicleInventoryIds[part.location];
      item.functions.sell = part.location === 0;
    }

    const groupId = item[groupBy.value];
    let group = res.find((g) => g.id === groupId);
    if (!group) {
      group = {
        id: groupId,
        name: item[`${groupBy.value}Name`] || item[groupBy.value],
        parts: [],
        expanded: false,
      };
      if (part.location > 0) {
        group.thumbnail =
          partInventoryStore.partInventoryData.vehicles[part.location].thumbnail;
      } else {
        // Folder icon
        group.icon = icons.BNGFolder;
      }
      group.onExpanded = (state) => {
        const grp = groups.value.find((g) => g.id === groupId);
        grp.expanded = state;
        if (!state) {
          delete grp.ready;
          const elm = document.querySelector(
            `[data-groupid="${groupId}"] > .bng-accitem-caption`
          );
          elm && elm.focus();
          return;
        }
        if (!("ready" in grp)) {
          grp.ready = false;
          setTimeout(() => {
            const grp = groups.value.find((g) => g.id === groupId);
            if (grp && typeof grp.ready === "boolean") {
              grp.ready = true;
            }
          }, 100);
        }
      };
      res.push(group);
    }
    group.parts.push(item);
  }

  if (res.length > 0) {
    const sorter = (a, b) => a.name.localeCompare(b.name);
    res.sort(sorter);
    for (const group of res) {
      group.parts.sort(sorter);
    }
  }

  // Restore the state
  for (const group of groups.value) {
    if (group.ready) {
      const grp = res.find((g) => g.name === group.name);
      if (grp) {
        grp.expanded = true;
        grp.ready = true;
      }
    }
  }

  // Show the result
  groups.value = res;
});

const confirmSellPart = async (partToSell) => {
  const res = await openConfirmation(
    partToSell.description.description,
    `Do you want to sell this part for ${units.beamBucks(partToSell.finalValue)}?`,
    [
      { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
      { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
    ]
  );
  if (res) sellPart(partToSell);
};

const showPartInstallPopup = (data) => {
  if (data) {
    if (data.success) {
      partInventoryStore.openNewPartsPopup(data.newPartIds);
    } else {
      openMessage(data.title, data.message);
    }
  }
};

const movePartToLocation = (location, partId) => {
  lua.career_modules_partInventory.movePart(location, partId).then(showPartInstallPopup);
};

const sellPart = (part) => {
  lua.career_modules_partInventory.sellPart(part.id);
  emit("partSold");
};

// Method to confirm selling all parts
const confirmSellAllParts = async () => {
  const res = await openConfirmation(
    "Sell All Parts",
    "Do you want to sell all parts in the inventory?",
    [
      { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
      { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
    ]
  );
  if (res) {
    sellAllParts();
  }
};

// Method to sell all parts in the inventory
const sellAllParts = () => {
  const inventoryGroup = groups.value.find((group) => group.id === 0);
  if (inventoryGroup) {
    inventoryGroup.parts.forEach((part) => {
      sellPart(part.data);
    });
  }
};
</script>

<style scoped lang="scss">
.part-groups {
  max-height: 100%;
  overflow: hidden auto;
}

.veh-part-caption {
  display: flex;
  flex-flow: row nowrap;
  justify-content: stretch;
  align-items: center;
  overflow: hidden;
  width: 100%;
  height: 4em;
  $preview: 8em; // Thumbnail width
  .veh-icon {
    $sz: 4; // In em
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

.inventory-summary {
  padding: 1em;
  .summary-info {
    display: flex;
    justify-content: space-between;
    font-size: 1.1em;
    margin-bottom: 1em;
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
}

.center {
  text-align: center;
}
.right {
  text-align: right;
}

.sell-all-button {
  margin-bottom: 1em;
}
</style>
