<template>
  <div v-if="data" :class="{ [`veh-${layout}`]: true, selected, 'hover-enabled': enableHover }" role="button" v-bng-disabled="data.disabled">
    <div :class="{ preview: true, locked }">
      <img v-if="thumbUrl" :src="thumbUrl" alt="" />
      <span class="lock-reason" v-if="locked">{{ locked.reason }}</span>
      <span class="lock-time" v-if="locked && locked.eta">{{ locked.eta }}</span>
      <span class="valueReduced" v-if="!(data.returnLoanerPermission && data.returnLoanerPermission.allow) && data.partConditionAvg < 1">Value reduced!</span>
    </div>

    <div class="info" v-if="!data._message">
      <div class="title" v-if="data.niceName">
        <span class="name">{{ data.niceName }}</span>
        <div class="class-info">
          <div class="class-details">
            <span class="class-badge">
              <span v-if="data.certificationData && data.certificationData.vehicleClass">
                {{ data.certificationData.vehicleClass.class.name }} | {{ data.certificationData.vehicleClass.performanceIndex.toFixed(0) }}
              </span>
              <span v-else>
                N/A
              </span>
            </span>
          </div>
        </div>
        <BngIcon v-if="data.favorite" :type="icons.star" color="#fd0" v-bng-tooltip="'Favourite'" />
        <BngIcon v-if="data.delayReason === 'repair'" :type="icons.wrench" color="#fff" />
        <BngCondition v-else :integrity="partConditionAvg" :integrity-warning="data.needsRepair" :color="colour" show-tooltip />
      </div>

      <div v-if="description">
        <span class="desc">{{ description }}</span>
      </div>
      <div v-else>

        <!-- hide price for loaned vehicle -->
        <span v-if="!data.returnLoanerPermission.allow">
          <span v-if="partConditionAvg < 1" style="color: red;">Current Value:</span>
          <BngUnit :money="data.value" />
          <div v-if="partConditionAvg < 1">
            Total Value: <BngUnit :money="data.valueRepaired" />
          </div>
        </span>

        <span class="compact status" v-if="(!locked || locked.location) && location != 'Storage'">
          {{ location }}
        </span>
        <span class="compact status" v-else-if="location == 'Storage'">
          {{ data.niceLocation }}
        </span>
      </div>

      <div class="full row50">
        <span v-if="location == 'Storage'">
          Location:
          {{ data.niceLocation }}
        </span>
        <span v-else>
          Location:
          {{ location }}
        </span>
        <span>
          Insurance:
          {{ data.policyInfo ? data.policyInfo.name : "n/a" }}
          <div v-if="!data.ownsRequiredInsurance" class="warn">Not owned!</div>
        </span>
      </div>

    </div>
  </div>
</template>

<script>
export default {
  width: 18, // em
  margin: 0.25, // em, on each side
}
</script>

<script setup>
import { computed } from "vue"
import { BngCondition, BngUnit, BngIcon, icons } from "@/common/components/base"
import { vBngDisabled, vBngTooltip } from "@/common/directives"
// import { formatTime } from "@/utils/datetime"
import { useBridge } from "@/bridge"
const { units } = useBridge()

const props = defineProps({
  data: Object,
  isTutorial: Boolean,
  selected: Boolean,
  layout: {
    type: String,
    default: "tile",
    validator: val => ["tile", "row"].includes(val),
  },
  enableHover: {
    type: Boolean,
    default: true
  }
})

const partConditionAvg = computed(() => {
  if (!props.data) return 1
  if (props.data.partConditions) {
    const conds = Object.values(props.data.partConditions)
    return conds.reduce((i, c) => i + c.integrityValue, 0) / conds.length
  }
  return 1
})

const colour = computed(() => props.data?.config?.paints?.[0]?.baseColor ?? "#ccc")

const thumbUrl = computed(() => props.data.thumbnail ? `${props.data.thumbnail}?${props.data.dirtyDate}` : null)

const description = computed(() => props.isTutorial ? "Tutorial Vehicle" : props.data.description)

const location = computed(() => {
  let res
  if (locked.value && locked.value.location && typeof locked.value.location === 'string') {
    // Check for custom location string
    res = locked.value.location
  } else if (locked.value && !locked.value.location) {
    res = locked.value.reason
  } else if (props.data.inGarage) {
    res = "In garage"
  } else if (props.data.distance) {
    res = `${units.buildString("length", props.data.distance, 0)} away`
  } else {
    res = "Storage"
  }
  return res
})

const locked = computed(() => {
  /**
   * @type {Object}
   * @prop {string} [reason] Blocking reason
   * @prop {string} [eta] Estimated time
   * @prop {boolean} [location] If location should be processed and displayed normally
   */
  let res
  if (props.data._message) {
    res = { reason: props.data._message }
  } else if (props.data.missingFile) {
    res = { reason: "Missing File!" }
  } else if (props.data.timeToAccess) {
    const eta = (() => {
      const hours = ~~(props.data.timeToAccess / 3600)
      const minutes = ~~((props.data.timeToAccess % 3600) / 60)
      const seconds = ~~(props.data.timeToAccess % 60)
      
      let parts = []
      if (hours > 0) {
        parts.push(`${hours}hrs`)
      }
      if (minutes > 0 || hours > 0) {
        parts.push(`${minutes}min`)
      }
      parts.push(`${seconds}sec`)
      
      return parts.join(' ')
    })()

    if (props.data.delayReason === "bought") {
      res = { reason: "Out for delivery", eta }
    } else if (props.data.delayReason === "repair") {
      res = { reason: "Being repaired", eta, location: "Repair Shop" }
    } else if (props.data.delayReason === "rented") {
      res = { reason: "Rented Out", eta, location: "Movie Studio" }
    } else if (props.data.delayReason === "Police_certification") {
      res = { reason: "Certifying", eta, location: "Police Station" }
    } else if (props.data.delayReason === "delivery") {
      res = { reason: "Delivering", eta, location: "Delivering to " + props.data.niceLocation }
    } else {
      res = { reason: "Available in", eta }
    }
  } else if (props.data.needsRepair) {
    res = { reason: "Needs repair", location: true }
  } else if (!props.data.ownsRequiredInsurance) {
    res = { reason: "Insurance required", location: true }
  }
  /// for testing purposes
  // const sec = Math.random() * 5e2
  // const eta = formatTime(sec, 1)
  // const eta = `${~~(sec / 60)}:${String(~~sec % 60).padStart(2, "0")}`
  // res = { reason: "Being tested", eta }
  return res
})
</script>

<style lang="scss" scoped>
.veh-tile,
.veh-row {
  // flex: 1 0 14em;
  margin: 0.25em;

  font-family: "Overpass", var(--fnt-defs);
  background-color: rgba(#000, 0.6);
  color: #fff;

  > * {
    margin: 0.25em;
  }

  &.selected,
  &:focus,
  &:focus-within {
    // background-color: rgba(#747474, 0.8);
    .info .name {
      color: #f60;
    }
  }

  &.hover-enabled:hover {
    // background-color: rgba(#747474, 0.8);
    .info .name {
      color: #f60;
    }
  }

  &:focus,
  &:focus-within {
    .tags {
      z-index: 100;
    }
  }

  &[disabled] {
    pointer-events: none;
    > * {
      color: #aaa;
    }
  }
}

.veh-tile {
  width: 14em;
  height: 16em;
}

.veh-row {
  display: flex;
  flex-flow: row;
  flex-wrap: nowrap;
  justify-content: stretch;
  align-content: stretch;
  height: 7em;
}

.preview {
  position: relative;
  width: calc(100% - 0.5em);
  height: calc(100% - 4.5em);
  display: inline-flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  overflow: hidden;
  img {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    object-fit: cover;
    object-position: 50% 50%;
  }
}
[disabled],
.locked {
  img {
    filter: brightness(50%) saturate(50%);
  }
}
.locked {
  > .lock-reason,
  > .lock-time {
    font-size: 1.5em;
    text-align: center;
    text-shadow: 0 0 0.2em #000;
  }
  > .lock-time {
    font-size: 1.75em;
    font-weight: 200;
    letter-spacing: 0.1em;
  }
  > .valueReduced {
    font-size: 1em;
    font-weight: 200;
    color: red;
  }
}
.veh-row .preview {
  flex: 0 0 12em;
  width: 12em;
  height: unset;
  img {
    top: -5%;
    left: -5%;
    width: 110%;
    height: 110%;
  }
  > .lock-reason {
    font-size: 1.2em;
  }
  > .lock-time {
    font-size: 1.5em;
  }
}

.info {
  > * {
    display: flex;
    flex-flow: row nowrap;
    justify-content: stretch;
    align-items: baseline;
    > * {
      flex: 0 0 auto;
    }
    width: 100%;
    padding: 0.25em;
    line-height: 1.2em;
    text-align: left;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
  }
  .name {
    flex: 1 1 auto;
    white-space: nowrap;
    text-overflow: ellipsis;
    overflow: hidden;
    font-size: 1.1em;
    font-weight: 700;
  }
  .desc {
    font-weight: 400;
  }
  .status {
    flex: 1 1 auto;
    text-align: right;
    white-space: nowrap;
  }
  .row50 > * {
    flex: 1 1 50%;
    width: 50%;
  }
}
.veh-tile .info {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  height: 6em;
  > *:first-child {
    align-items: center;
    height: 2em;
    padding-top: 0.5em;
    background-color: #0009;
  }
  .full {
    display: none;
  }
}
.veh-row .info {
  flex: 1 1 60%;
  width: 60%;
  position: relative;
  .compact {
    display: none;
  }
  .full {
    font-size: 1.1em;
  }
}

.warn {
  color: rgb(242, 75, 75);
}

.class-info {
  display: flex;
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
