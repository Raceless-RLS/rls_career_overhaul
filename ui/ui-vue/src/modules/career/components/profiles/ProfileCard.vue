<template>
  <BngCard
    v-bng-panel
    v-bng-sound-class="'bng_hover_generic'"
    :backgroundImage="preview"
    :footerStyles="cardFooterStyles"
    :hideFooter="!statusExpanded"
    animateFooterDelay="0.1s"
    animateFooterType="slide"
    class="profile-card"
    :class="{ 'profile-card-active': active, 'manage-active': isManageActive, 'profile-outdated': incompatibleVersion }"
    @panelopen="() => openPanel(true)"
    @panelclose="() => openPanel(false)">
    <div class="profile-card-cover">
      <div class="profile-card-container">
        <div class="profile-card-title">
          {{ $ctx_t(id) }}
        </div>
        <div v-if="!isManageActive" class="profile-card-date">
          <span v-if="active">
            {{ $ctx_t("ui.career.nowplaying") }}
          </span>
          <span v-else>
            {{ $ctx_t("ui.career.lastplayed") }}
            {{ lastPlayedDescription }}
          </span>
        </div>
        <div v-if="props.hardcoreMode" class="profile-card-date">
          <span>Hardcore</span>
        </div>
      </div>
    </div>
    <div class="profile-card-content" v-bng-on-ui-nav:back="onBack">
      <ProfileManage v-if="isManageActive && statusExpanded" :profileId="id" :active="active" @activeMenuChanged="onManageActiveMenuChanged" />
      <ProfileStatus v-else :branches="branches" :expanded="statusExpanded" :beamXP="beamXP" :vouchers="vouchers" :money="money" />
    </div>
    <template #buttons>
      <template v-if="isManageActive && manageMenuFooterButtons && manageMenuFooterButtons.length > 0">
        <BngButton
          v-for="(button, index) of manageMenuFooterButtons"
          :key="index"
          v-bind="button.props"
          v-on="button.events"
          v-bng-sound-class="button.soundClass"
          v-bng-focus-if="button.id === 'cancel'" />
      </template>
      <BngButton
        v-else-if="isManageActive"
        v-bng-sound-class="'bng_cancel_generic'"
        v-bng-focus-if="opened && active"
        accent="outlined"
        @click="isManageActive = false"
        >Back</BngButton
      >
      <template v-else>
        <BngButton
          v-bng-sound-class="'bng_click_generic'"
          v-bng-focus-if="opened && (active || incompatibleVersion)"
          accent="outlined"
          @click="isManageActive = true"
          >Manage</BngButton
        >
        <BngButton
          v-bng-sound-class="'bng_click_generic'"
          v-bng-focus-if="opened && !active && !incompatibleVersion"
          @click="load"
          :disabled="active || incompatibleVersion"
          >Load</BngButton
        >
      </template>
    </template>
  </BngCard>
</template>

<script setup>
import { computed, ref, watch, watchEffect } from "vue"
import { timeSpan } from "@/utils/datetime"
import { BngButton, BngCard } from "@/common/components/base"
import { vBngPanel, vBngSoundClass, vBngFocusIf, vBngOnUiNav } from "@/common/directives"
import ProfileStatus from "./ProfileStatus.vue"
import ProfileManage from "./ProfileManage.vue"
import { useProfilesStore } from "../../stores/profilesStore"
import { useUINavScope } from "@/services/uiNav"

const store = useProfilesStore()

const props = defineProps({
  id: {
    type: String,
    required: true,
  },
  date: {
    type: String,
    required: true,
  },
  creationDate: {
    type: String,
    required: true,
  },
  incompatibleVersion: Boolean,
  outdatedVersion: {
    type: Boolean,
    required: true,
  },
  preview: {
    type: String,
    default: "/ui/modules/career/profilePreview_WCUSA.jpg",
  },
  beamXP: Object,
  vouchers: Object,
  money: Object,
  active: Boolean,
  branches: Array,
  statusExpanded: Boolean,
  create: Boolean,
  selected: Boolean,
  hardcoreMode: Boolean,
})

const emit = defineEmits(["lockActiveState", "expandStatusChange", "manageStatusChanged"])

const isManageActive = ref(false)
const manageMenuFooterButtons = ref(null)

const lastPlayedDescription = computed(() => timeSpan(props.date))
const cardFooterStyles = {
  "background-color": "hsla(217, 22%, 12%, 1)",
}

const load = async () => await store.loadProfile(props.id)

const onManageActiveMenuChanged = menuProperties => {
  manageMenuFooterButtons.value = menuProperties.buttons
  emit("lockActiveState", menuProperties.lock)
  emit("expandStatusChange", !menuProperties.closeManage)
}

const opened = ref(false)
const openPanel = open => (opened.value = open)

watchEffect(() => {
  if (isManageActive.value && !props.statusExpanded) isManageActive.value = false
})

watch(
  () => isManageActive.value,
  value => {
    emit("manageStatusChanged", value)
  }
)

function onBack() {
  if (isManageActive.value) isManageActive.value = false
}
</script>

<style lang="scss" scoped>
.profile-card {
  &.profile-card-active {
    :deep() {
      > :last-child {
        border-bottom: 0.3em solid var(--bng-orange-400);
        border-bottom-left-radius: 0;
        border-bottom-right-radius: 0;
      }
    }
  }

  &.manage-active {
    .profile-card-cover {
      flex: 0.5 0.0001 auto;
    }

    .profile-card-content {
      flex: 1 1 auto;
      justify-content: start;
    }
  }

  &.profile-outdated {
    background-color: #808080 !important;
    background-blend-mode: luminosity;
  }
}

.profile-card-cover {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding: 1em 0;
  flex: 1 0.0001 auto;
  border-radius: 0.25em 0.25em 0 0;
  overflow: hidden;
  color: #fff;

  > .profile-card-container {
    position: absolute;
    display: flex;
    flex-direction: column;
    max-width: 80%;
    align-items: flex-start;
    font-family: "Overpass", var(--fnt-defs);

    > .profile-card-title {
      font-weight: 900;
      font-size: 2em;
      letter-spacing: 0.02em;
      line-height: 1.2em;
      padding: 0 0.5em;
      background-color: var(--bng-black-6);
      overflow-wrap: break-word;
      font-family: "Overpass", var(--fnt-defs);
    }

    > .profile-card-date {
      letter-spacing: 0.02em;
      line-height: 1.2em;
      padding: 0.25em 1em;
      background-color: var(--bng-black-6);
    }
  }
}

.profile-card-content {
  display: flex;
  flex: 0.0001 1 auto;
  flex-flow: column;
  justify-content: space-between;
  align-items: stretch;
  // padding: 0 1em 1em;
  overflow: hidden;
  // background: hsla(217, 22%, 12%, 1);
}
</style>
