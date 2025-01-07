<template>
  <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Sleep" back @back="close">
    <div class="sleep-menu">
      <div class="time-display">
        <span class="time-label">Time</span>
        <div class="time-slider">
          <input type="range" v-model="selectedTime" min="0" max="1" step="0.001" />
          <span>{{ formatTime(selectedTime) }}</span>
        </div>
      </div>

      <div class="preset-times">
        <BngButton @click="setTime(0.77)">Sunrise</BngButton>
        <BngButton @click="setTime(0)">Noon</BngButton>
        <BngButton @click="setTime(0.5)">Midnight</BngButton>
        <BngButton @click="setTime(0.22)">Sunset</BngButton>
      </div>

      <div class="time-adjustments">
        <BngButton @click="adjustTime(-0.0417)">-1h</BngButton>
        <BngButton @click="adjustTime(-0.007)">-10m</BngButton>
        <BngButton @click="adjustTime(0.007)">+10m</BngButton>
        <BngButton @click="adjustTime(0.0417)">+1h</BngButton>
      </div>

      <div class="day-night-toggle">
        <label>
          <span>Toggle Day/Night Cycle</span>
          <input type="checkbox" v-model="dayNightCycle">
        </label>
      </div>

      <div class="sleep-action">
        <BngButton class="sleep-button" @click="sleep">Sleep</BngButton>
      </div>
    </div>
  </ComputerWrapper>
</template>

<script setup>
import { ref, computed, watch } from 'vue'
import { BngButton, BngCard } from "@/common/components/base"
import ComputerWrapper from "./ComputerWrapper.vue"
import { useComputerStore } from "../stores/computerStore"
import { lua } from "@/bridge"

const computerStore = useComputerStore()
const selectedTime = ref(0)
const dayNightCycle = ref(true)

dayNightCycle.value = getDayNightCycle()

function getDayNightCycle() {
  return lua.career_modules_sleep.getDayNightCycle()
}

watch(dayNightCycle, (newValue) => {
  lua.career_modules_sleep.toggleDayNightCycle(newValue)
})

const formatTime = (time) => {
  let hours = Math.floor((time * 24 + 12) % 24)
  const minutes = Math.floor((time * 24 * 60) % 60)
  
  if (hours === 24) hours = 0
  
  return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`
}

const setTime = (time) => {
  selectedTime.value = time
}

const adjustTime = (adjustment) => {
  let newTime = selectedTime.value + adjustment
  if (newTime < 0) newTime += 1
  if (newTime > 1) newTime -= 1
  selectedTime.value = newTime
}

const sleep = () => {
  lua.career_modules_sleep.closeAllMenus()
  lua.career_modules_sleep.sleep(selectedTime.value)  
}

const close = () => {
  lua.career_modules_sleep.closeMenu()
}
</script>

<style scoped lang="scss">
.sleep-menu {
  width: fit-content;
  min-width: 500px;
  padding: 30px 40px;
  color: white;
  background-color: rgba(0, 0, 0, 0.8);
  border-radius: 8px;
}

.time-display {
  margin-bottom: 25px;
  
  .time-label {
    font-size: 1.5em;
    font-weight: bold;
    display: block;
    margin-bottom: 15px;
  }
  
  .time-slider {
    display: flex;
    align-items: center;
    gap: 15px;
    
    input[type="range"] {
      flex: 1;
      height: 4px;
    }
    
    span {
      min-width: 60px;
      text-align: right;
    }
  }
}

.preset-times {
  display: grid;
  grid-template-columns: repeat(2, minmax(200px, 1fr));
  gap: 15px;
  margin-bottom: 25px;

  :deep(.bng-button) {
    background-color: #cc4c00;
    width: 100%;
    white-space: nowrap;
  }
}

.time-adjustments {
  display: grid;
  grid-template-columns: repeat(4, minmax(80px, 1fr));
  gap: 15px;
  margin-bottom: 25px;

  :deep(.bng-button) {
    background-color: #cc4c00;
    width: 100%;
    white-space: nowrap;
  }
}

.day-night-toggle {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 25px;
  padding: 12px;
  background-color: rgba(255, 255, 255, 0.1);
  border-radius: 4px;

  label {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
  }
}

.sleep-action {
  display: flex;
  justify-content: flex-end;

  .sleep-button {
    padding: 10px 40px;
    font-size: 1.1em;
    background-color: #cc4c00;
  }
}
</style>