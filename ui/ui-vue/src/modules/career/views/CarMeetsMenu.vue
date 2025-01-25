<template>
  <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Car Meets" back @back="close">
      <div class="car-meets-menu">
          <div class="meet-details">
              <div v-if="meetLocation" class="scheduled-meet">
                  <h2 class="meet-title">Car Meet ({{ formatTime(meetTime) }})</h2>

                  <div class="meet-info">
                      <div class="info-row">
                          <span class="label">Location:</span>
                          <span class="value">{{ meetLocation }}</span>
                      </div>
                      <div class="info-row">
                          <span class="label">Meet Type:</span>
                          <span class="value">{{ meetType }}</span>
                      </div>
                  </div>

                  <div class="attendance-section">
                      <h3>Attendance</h3>
                      <div class="attendance-buttons">
                          <BngButton v-for="level in attendanceLevels" :key="level"
                              :class="{ active: selectedAttendance === level }" @click="selectAttendance(level)"
                              :accent="selectedAttendance === level ? ACCENTS.primary : ACCENTS.secondary">
                              {{ level }}
                          </BngButton>
                      </div>
                  </div>

                  <div class="action-buttons">
                      <BngButton class="decline-button" @click="decline" :accent="ACCENTS.secondary">DECLINE
                      </BngButton>
                      <BngButton class="rsvp-button" @click="rsvp" :accent="ACCENTS.primary">RSVP</BngButton>
                  </div>
              </div>
              <div v-else class="no-meets">
                  <h2>No meets currently scheduled</h2>
                  <p>Come back later</p>
              </div>
          </div>
      </div>
  </ComputerWrapper>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { BngButton, ACCENTS } from "@/common/components/base"
import ComputerWrapper from "./ComputerWrapper.vue"
import { useComputerStore } from "../stores/computerStore"
import { lua } from "@/bridge"

const computerStore = useComputerStore()
const meetTime = ref(0.417) // 10:00 PM (22:00)
const meetLocation = ref(null)
const meetType = ref("Showcase")
const attendanceLevels = ['LOW', 'MEDIUM', 'HIGH']
const selectedAttendance = ref('MEDIUM')

onMounted(async () => {
  const meetData = await lua.career_modules_carmeets.checkAvailableMeets()
  if (meetData) {
      meetTime.value = meetData.time
      meetLocation.value = meetData.location
      meetType.value = meetData.type
  }else{
      meetTime.value = 0.417
      meetLocation.value = null
      meetType.value = null
  }
})

const formatTime = (time) => {
  let hours = Math.floor((time * 24 + 12) % 24)
  const minutes = Math.floor((time * 24 * 60) % 60)

  if (hours === 24) hours = 0
  const period = hours >= 12 ? 'PM' : 'AM'
  hours = hours % 12 || 12

  return `${hours}:${minutes.toString().padStart(2, '0')} ${period}`
}

const selectAttendance = (level) => {
  selectedAttendance.value = level
}

const rsvp = () => {
  lua.career_modules_carmeets.rsvpToMeet(selectedAttendance.value)
  close()
}

const decline = () => {
  lua.career_modules_carmeets.decline()
  close()
}

const close = () => {
  lua.career_modules_carmeets.closeMenu()
}
</script>

<style scoped lang="scss">
.car-meets-menu {
  width: fit-content;
  min-width: 500px;
  padding: 10px 10px;
  color: white;
  background-color: rgba(0, 0, 0, 0.8);
  border-radius: 10px;
}

.meet-details {
  padding: 5px 5px;

  .meet-title {
      font-size: 1.5em;
      margin-bottom: 10px;
      margin-top: 5px;
  }
}

.meet-info {
  margin-bottom: 10px;

  .info-row {
      display: flex;
      margin-bottom: 10px;

      .label {
          min-width: 120px;
          font-weight: bold;
      }
  }
}

.attendance-section {
  margin-bottom: 5px;
  margin-top: 5px;

  h3 {
      margin-top: 5px;
      margin-bottom: 5px;
  }

  .attendance-buttons {
      display: flex;
      gap: 10px;

      :deep(.bng-button) {
          flex: 1;
      }
  }
}

.action-buttons {
  display: flex;
  justify-content: flex-end;
  gap: 5px;
  margin-top: 10px;

  .decline-button {
      background-color: rgba(255, 255, 255, 0.1);
      border-radius: 2px;
  }

  .rsvp-button {
      background-color: #cc4c00;
      border-radius: 2px;
  }

  :deep(.bng-button) {
      padding: 5px 5px;
      font-size: 1em;
  }
}
</style>