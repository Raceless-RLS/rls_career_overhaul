<template>
  <LayoutSingle class="assignment-layout">
    <!-- CERTIFICATION CARD -->
    <BngCard
      v-if="!showConfirmModal"
      class="certification-card"
    >
      <BngCardHeading>Certify Your Vehicle For {{ type }} Work</BngCardHeading>

      <div class="certification-info">
        <p>The certification process takes {{ convertTime(time) }} and will cost ${{ cost }}</p>
      </div>

      <!-- Button in the bottom-right, no separate footer slot -->
      <div class="certify-button-container">
        <BngButton
          @click="showConfirmation"
          :accent="ACCENTS.primary"
          :disabled="!canPay()"
        >
          Certify
        </BngButton>
      </div>
    </BngCard>

    <!-- CONFIRMATION MODAL -->
    <transition name="fade">
      <div
        v-if="showConfirmModal"
        class="confirmation-overlay"
      >
        <BngCard class="confirmation-card">
          <BngCardHeading>Confirm Certification</BngCardHeading>

          <div class="modal-content">
            <p>Are you sure you want to certify your vehicle?</p>
            <p>This process will take your vehicle for {{ convertTime(time) }} and will cost ${{ cost }}</p>
          </div>

          <!-- Two buttons centered -->
          <div class="confirm-button-container">
            <BngButton
              ref="yesButton"
              @click="confirmCertification"
              :accent="ACCENTS.primary"
            >
              Yes
            </BngButton>
            <BngButton
              @click="cancelConfirmation"
              :accent="ACCENTS.secondary"
            >
              No
            </BngButton>
          </div>
        </BngCard>
      </div>
    </transition>
  </LayoutSingle>
</template>

<script setup>
import { lua } from '@/bridge'
import { ref, nextTick, onMounted } from 'vue'
import {
  BngButton,
  ACCENTS,
  BngCard,
  BngCardHeading
} from '@/common/components/base'
import { LayoutSingle } from '@/common/layouts'
// import { lua } from '@/bridge' // if needed

const showConfirmModal = ref(false)
const yesButton = ref(null)

const time = ref(0)
const cost = ref(0)
const type = ref('')

onMounted(async () => {
  const assignmentData = await lua.career_modules_assignRole.requestAssignmentData()
  if (assignmentData) {
    time.value = assignmentData.time
    cost.value = assignmentData.cost
    type.value = assignmentData.type
  }
})

function convertTime(time) {
  const hours = ~~(time / 3600)
  const minutes = ~~((time % 3600) / 60)
  const seconds = ~~(time % 60)
  
  const parts = []
  if (hours > 0) parts.push(`${hours}hrs`)
  if (minutes > 0) parts.push(`${minutes}min`)
  if (seconds > 0 || parts.length === 0) parts.push(`${seconds}sec`) // Always show at least seconds

  return parts.join(' ')
}

function canPay() {
  return lua.career_modules_assignRole.canPay()
}

function goToPlayState() {
  window.bngApi.engineLua('guihooks.trigger("ChangeState", {state = "play", params = {}})')
}

function showConfirmation() {
  showConfirmModal.value = true
  // Focus the "Yes" button after rendering if you like
  nextTick(() => {
    yesButton.value?.$el?.focus?.()
  })
}

function confirmCertification() {
  showConfirmModal.value = false
  lua.career_modules_assignRole.startCertification()
}

function cancelConfirmation() {
  showConfirmModal.value = false
  goToPlayState()
}
</script>

<style scoped lang="scss">
.assignment-layout {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: white;
}

/* --- CERTIFICATION CARD --- */
.certification-card {
  :deep(.card-cnt) {
    background: rgba(0, 0, 0, 0.8);
    border-radius: 0.25em;
    /* Minimal padding inside the card */
    padding: 0.25em;
  }
}

.certification-info {
  margin: 0.1em 0;
  text-align: center;
  p {
    font-size: 0.9em;
    opacity: 0.9;
    margin: 0.25em 0;
  }
}

/* Button at the bottom-right */
.certify-button-container {
  display: flex;
  justify-content: flex-end;
  margin-top: 0.25em;
}

/* --- CONFIRMATION MODAL --- */
.confirmation-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  z-index: 100; /* ensure it's above everything else */
}

.confirmation-card {
  :deep(.card-cnt) {
    background: rgba(0, 0, 0, 0.8);
    border-radius: 0.5em;
    padding: 0.5em;
    /* Optional shadow/border for contrast */
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.15);
  }
}

.modal-content {
  text-align: center;
  margin: 0.25em 0;
  p {
    margin: 0.25em 0; /* Add this to reduce space between paragraphs */
  }
}

.confirm-button-container {
  display: flex;
  justify-content: center;
  gap: 1em;
  margin-top: 0.25em;
}

/* Simple fade transition */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
