<template>
  <PhoneWrapper app-name="Car Meets">
    <div class="phone-meets-container">
      <div v-if="meetLocation" class="phone-meet-content">
        <h2 class="phone-meet-title"> {{ meetType }} Meet</h2>
        
        <div class="phone-meet-info">
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
            <BngButton v-for="level in attendanceLevels" 
                      :key="level"
                      :class="{ active: selectedAttendance === level }"
                      @click="selectAttendance(level)"
                      :accent="selectedAttendance === level ? ACCENTS.primary : ACCENTS.secondary"
                      class="attendance-btn">
              {{ level }}
            </BngButton>
          </div>
        </div>

        <div class="phone-action-buttons">
          <BngButton class="decline-btn" @click="decline" accent="secondary">
            Decline
          </BngButton>
          <BngButton class="rsvp-btn" @click="rsvp" accent="primary">
            RSVP
          </BngButton>
        </div>
      </div>

      <div v-else class="phone-no-meets">
        <h2>No Scheduled Meets</h2>
        <p>Check back later</p>
      </div>
    </div>
  </PhoneWrapper>
</template>

<script setup>
// Reuse the same script setup from CarMeetsMenu.vue
import { ref, onMounted } from 'vue'
import { BngButton, ACCENTS } from "@/common/components/base"
import PhoneWrapper from "./PhoneWrapper.vue"
import { lua } from "@/bridge"

// Existing state and logic from CarMeetsMenu.vue
const meetTime = ref(0.417)
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
  lua.career_career.closeAllMenus()
}
</script>

<style scoped lang="scss">
.phone-meets-container {
  height: 100%;
  padding: 15px;
  color: white;
}

.phone-meet-content {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.phone-meet-title {
  font-size: 1.4em;
  margin: 55px 0 10px 0;
  text-align: center;
}

.phone-meet-info {
  .info-row {
    display: flex;
    justify-content: space-between;
    margin-bottom: 12px;
    font-size: 1.5em;
    
    .label {
      color: #cccccc;
    }
  }
}

.phone-attendance {
    padding-top: 170px;
  h3 {
    font-size: 1.5em;
    margin: 15px 0 10px 0;
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
  margin-top: auto;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  padding-top: 50px;

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