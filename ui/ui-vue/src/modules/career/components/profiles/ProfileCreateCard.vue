<template>
  <BngCard
    v-bng-panel
    v-bng-blur
    v-bng-sound-class="'bng_hover_generic'"
    :hideFooter="!isActive"
    :footerStyles="cardFooterStyles"
    class="profile-create-card"
    @panelopen="isActive = true"
    @panelclose="isActive = false">
    <div class="create-content-container">
      <template v-if="isActive">
        <div class="save-name-container">
          <BngInput v-model="profileName" externalLabel="Save Name" />
        </div>
        <div class="tutorial-check-container">
          <BngSwitch v-model="hardcoreMode"> Hardcore Mode </BngSwitch>
          <BngSwitch v-model="tutorialChecked">{{ $ctx_t("ui.career.tutorialCheckDesc") }}</BngSwitch>
          <span class="tutorial-desc" :class="{ checked: tutorialChecked }">{{ $ctx_t("ui.career.tutorialOnDesc") }}</span>
        </div>
      </template>
      <div v-else class="create-content-cover">
        <div class="cover-plus-container" @click="toggleIsActive">
          <div class="cover-plus-button">+</div>
        </div>
      </div>
    </div>
    <template #buttons>
      <BngButton v-bng-focus-if="true" :disabled="saveDisabled" @click="load">Start</BngButton>
      <BngButton accent="outlined" @click="toggleIsActive">Cancel</BngButton>
    </template>
  </BngCard>
</template>

<script>
const cardFooterStyles = {
  "background-color": "hsla(217, 22%, 12%, 1)",
}
</script>

<script setup>
import { computed, inject, ref, watch } from "vue"
import { vBngPanel, vBngBlur, vBngSoundClass, vBngFocusIf } from "@/common/directives"
import { BngButton, BngCard, BngInput, BngSwitch } from "@/common/components/base"
import { useProfilesStore } from "../../stores/profilesStore"

const store = useProfilesStore()

const emit = defineEmits(["activeStateChange"])

const profileName = defineModel("profileName", { required: true })
const hardcoreMode = ref(false)
const tutorialChecked = ref(true)
const isActive = ref(false)

const isSaveNameValid = inject("isSaveNameValidFn")

const saveDisabled = computed(() => !isSaveNameValid(profileName.value))

watch(
  () => isActive.value,
  value => emit("activeStateChange", value)
)

const toggleIsActive = () => (isActive.value = !isActive.value)

async function load() {
  await store.loadProfile(profileName.value, tutorialChecked.value, true, hardcoreMode.value)
}
</script>

<style lang="scss" scoped>
.profile-create-card {
  color: white;
}

.create-content-container {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.create-content-cover {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  justify-content: center;
  padding: 1em 0;
  flex: 1 0.0001 auto;
  border-radius: 0.25em 0.25em 0 0;
  overflow: hidden;

  > .cover-plus-container {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;

    > .cover-plus-button {
      font-weight: 400;
      font-size: 13em;
      line-height: 1em;
      background-color: transparent;
      flex: 0 0 auto;
      text-align: center;
      color: rgba(255, 255, 255, 0.2);
    }
  }
}

.save-name-container {
  flex: 1 1 auto;
  justify-content: start;
  padding: 1em;
  height: 52%;
  background: hsla(217, 22%, 12%, 1);
}

.tutorial-check-container {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  flex: auto;
  padding: 1em 1em;
  background: hsla(217, 22%, 12%, 1);

  > .tutorial-desc {
    padding-top: 1.5em;
    text-align: left;
    color: var(--bng-cool-gray-400);

    &.checked {
      color: #fff !important;
    }
  }
}
</style>
