<template>
  <div class="phone-wrapper" :style="{ 
    '--scale': scale,
    '--status-font-color': statusFontColor,
    '--status-blend-mode': statusBlendMode
  }">
    <div class="phone-bevel"></div>
    <div class="phone-screen">
      <!-- Status Bar -->
      <div class="phone-status-bar">
        <div class="phone-status-bar-left">
          <span>{{ timeString }}</span>
          <button class="status-back" v-bng-on-ui-nav:back,menu.asMouse @click="back"> <- Back</button>
        </div>
        <div class="phone-status-bar-right">
          <span>{{ appName }}</span>
        </div>
      </div>
      
      <!-- Optional Header Slot -->
      <template v-if="$slots.header">
        <slot name="header"></slot>
      </template>
      
      <!-- Main Content -->
      <div class="phone-content">
        <slot></slot>
      </div>
    </div>
  </div>
</template>

<script setup>
import { useEvents } from '@/services/events'
import { ref, onMounted, onUnmounted } from 'vue'
import { vBngOnUiNav } from "@/common/directives"
import { useRouter } from 'vue-router'
import { lua } from "@/bridge"

const props = defineProps({
  scale: {
    type: Number,
    default: 0.8
  },
  appName: {
    type: String,
    default: ''
  },
  statusFontColor: {
    type: String,
    default: '#ffffff'
  },
  statusBlendMode: {
    type: String,
    default: 'difference'
  }
})

const events = useEvents()
const timeString = ref('9:10')
const router = useRouter()

const updateTime = (data) => {
  if (data) {
    timeString.value = data
  }
}

onMounted(() => {
  lua.extensions.load("ui_phone_time")
  events.on("phone_time_update", data => updateTime(data))
  events.on("closePhone", close)
})

onUnmounted(() => {
})

const back = () => {
  router.back()
}

const close = () => {
  lua.extensions.unload("ui_phone_time")
  lua.career_career.closeAllMenus()
}

</script>

<style scoped lang="scss">
.phone-wrapper {
  position: fixed;
  bottom: -1.25em;
  right: 2em;
  z-index: 1000;
  transform: scale(var(--scale));
  transform-origin: bottom right;
  
  .phone-bevel {
    position: absolute;
    top: -0.7em;
    left: -0.7em;
    right: -0.7em;
    bottom: -0.7em;
    border-radius: 2.5em;
    background: linear-gradient(145deg,
    rgba(0,0,0,1) 100%,
      rgb(0, 0, 0) 100%
      
    );
    border: 0.15em solid rgba(168, 168, 168, 0.5)
  }

  .phone-screen {
    position: relative;
    width: 360px;
    height: 640px;
    border-radius: 2em;
    overflow: hidden;
    background: transparent;
    
    :deep(.card-cnt) {
      height: 100%;
      border-radius: 2em;
      overflow: hidden;
    }
  }

  .phone-content {
    height: 100%;
    overflow-y: hidden;
    color: white;
    border-radius: 1.5em;
  }
}

.phone-status-bar {
  position: absolute;
  top: 0.35em;
  left: 1em;
  right: 1em;
  display: flex;
  justify-content: space-between;
  font-size: 1.35em;
  font-weight: bold;
  color: var(--status-font-color);
  background-color: transparent;
  z-index: 10;
  mix-blend-mode: var(--status-blend-mode);
  text-shadow: 0 1px 2px rgba(0,0,0,0.3);
  pointer-events: none;

  &::before {
    content: '';
    position: absolute;
    top: -0.6em;
    left: -1em;
    right: -1em;
    height: calc(0.5em + 1.7em);
    background: linear-gradient(to bottom, var(--status-font-color), rgba(0,0,0,0) 100%);
    filter: invert(1);
    opacity: 1;
    z-index: -1;
  }
}

.phone-status-bar-left {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
}

.phone-status-bar-right {
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
}

.status-back{
  background-color: transparent;
  outline: none;
  border: none;
  z-index: -1;
  cursor: pointer;
  pointer-events: auto;
  font-size: 13px;
  font-weight: bold;
  color: var(--status-font-color);
}
</style> 