<template>
  <div class="phone-wrapper" :style="{ 
    '--scale': scale,
    '--status-font-color': statusFontColor,
    '--status-blend-mode': statusBlendMode
  }">
    <div class="phone-bevel"></div>
    <BngCard class="phone-screen" v-bng-blur="1">
      <!-- Status Bar -->
      <div class="phone-status-bar">
        <span class="status-time">{{ timeString }}</span>
        <span class="status-app">{{ appName }}</span>
      </div>
      
      <!-- Optional Header Slot -->
      <template v-if="$slots.header" #header>
        <slot name="header"></slot>
      </template>
      
      <!-- Main Content -->
      <div class="phone-content">
        <slot></slot>
      </div>
    </BngCard>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { BngCard } from "@/common/components/base"
import { vBngBlur } from "@/common/directives"

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

const timeString = ref('')
let timeInterval

const updateTime = () => {
  timeString.value = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  })
}

onMounted(() => {
  updateTime()
  timeInterval = setInterval(updateTime, 1000)
})

onUnmounted(() => {
  clearInterval(timeInterval)
})

// Expose toggle methods if needed
defineExpose({
  toggleVisibility: () => {
    // Implementation would depend on your state management
  }
})
</script>

<style scoped lang="scss">
.phone-wrapper {
  position: fixed;
  bottom: -2em;
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

.status-time, .status-app {
  pointer-events: auto;
}
</style> 