<template>
  <PhoneWrapper app-name="Car Meets">
    <div v-if="meetLocation || isRSVP" class="phone-meet-content">
      <h2 class="phone-meet-title"> {{ meetType }} Meet</h2>

      <div class="phone-meet-info">
        <img :src="meetImage" alt="" class="meet-image">
        <div class="info-row">
          <span class="label">Location:</span>
          <span class="value">{{ meetLocation }}</span>
        </div>
        <div class="info-row">
          <span class="label">Time:</span>
          <span class="value">{{ formatTime(meetTime) }}</span>
        </div>
      </div>

      <div class="phone-attendance">
        <h3>Attendance Level</h3>
        <div class="attendance-grid">
          <BngButton v-for="level in attendanceLevels" :key="level" :class="{ active: selectedAttendance === level }"
            @click="selectAttendance(level)"
            :accent="selectedAttendance === level ? ACCENTS.primary : ACCENTS.secondary" class="attendance-btn">
            {{ level }}
          </BngButton>
        </div>
      </div>

      <div class="phone-action-buttons">
        <BngButton class="decline-btn" @click="decline" v-show="!isRSVP" accent="secondary">
          Decline
        </BngButton>
        <BngButton class="rsvp-btn" @click="rsvp" v-show="!isRSVP" accent="primary">
          RSVP
        </BngButton>
        <BngButton class="rsvp-btn" v-show="isRSVP" @click="cancelRSVP" accent="secondary">Cancel RSVP</BngButton>
        <BngButton class="rsvp-btn" v-show="isRSVP" @click="setRoute" accent="primary">Set Route</BngButton>
      </div>
    </div>

    <div v-else class="phone-no-meets">
      <h2>No Scheduled Meets</h2>
      <p>Check back later</p>
    </div>
  </PhoneWrapper>
</template>

<script setup>
// Reuse the same script setup from CarMeetsMenu.vue
import { ref, onMounted } from 'vue'
import { BngButton, ACCENTS } from "@/common/components/base"
import PhoneWrapper from "./PhoneWrapper.vue"
import { lua, useBridge } from "@/bridge"

const { events } = useBridge()

// Existing state and logic from CarMeetsMenu.vue
const meetTime = ref(0.417)
const meetLocation = ref(null)
const meetType = ref("Showcase")
const meetImage = ref(null)
const attendanceLevels = ['LOW', 'MEDIUM', 'HIGH']
const selectedAttendance = ref('MEDIUM')
const isRSVP = ref(false)

onMounted(async () => {
  const meetData = await lua.career_modules_carmeets.checkAvailableMeets()
  if (meetData) {
    isRSVP.value = false
    meetTime.value = meetData.time
    meetLocation.value = meetData.location
    meetType.value = meetData.type
    meetImage.value = meetData.preview
  }
  lua.career_modules_carmeets.requestRSVPData()
  events.on('onRSVPData', (data) => {
    if (data) {
      isRSVP.value = true
      let attendanceLevelString;
      const attendanceIndex = data.attendance - 1;
      if (attendanceLevels[attendanceIndex]) {
        attendanceLevelString = attendanceLevels[attendanceIndex];
      } else {
        attendanceLevelString = 'MEDIUM';
      }
      selectedAttendance.value = attendanceLevelString;
      meetTime.value = data.time
      meetLocation.value = data.location
      meetType.value = data.type
      meetImage.value = data.preview
    }
  })
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
  if (isRSVP.value) {
    lua.career_modules_carmeets.updateAttendance(level)
  }
}

const rsvp = () => {
  lua.career_modules_carmeets.rsvpToMeet(selectedAttendance.value)
  close()
}

const decline = () => {
  lua.career_modules_carmeets.decline()
  close()
}

const cancelRSVP = () => {
  lua.career_modules_carmeets.cancelRSVP()
  close()
}

const setRoute = () => {
  lua.career_modules_carmeets.setRoute()
  close()
}

const close = () => {
  lua.career_career.closeAllMenus()
}
</script>

<style scoped lang="scss">
.phone-meet-content {
  height: 95%;
  color: white;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  padding: 5px;
  padding-top: 20px;
}

.phone-meet-title {
  font-size: 1.4em;
  text-align: center;
}

.phone-meet-info {
  .info-row {
    display: flex;
    justify-content: space-between;
    font-size: 1.5em;
    
    .label {
      color: #cccccc;
    }
  }
}

.meet-image {
    width: 100%;
    aspect-ratio: 16 / 9;
    border-radius: 15px;
    background-color: #3b3b3b;
    object-fit: cover;
}

.phone-attendance {
  h3 {
    font-size: 1.5em;
  }
}

.attendance-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  
  .attendance-btn {
    padding: 8px 5px;
    font-size: 0.9em;
  }
}

.phone-action-buttons {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;

  .decline-btn, .rsvp-btn {
    padding: 12px;
    font-size: 1em;
  }
}

.phone-no-meets {
  text-align: center;
  padding: 40px 20px;
  
  h2 {
    font-size: 1.2em;
    margin-bottom: 10px;
  }
  
  p {
    color: #888888;
  }
}
</style> 