<template>
  <PhoneWrapper app-name="Taxi">
    <svg class="phone-minimap" :viewBox="viewBox">
      <!-- Map background only -->
      <path v-for="(path, idx) in mapPaths" :key="'path-'+idx" 
             :d="path.d" :stroke="path.color" fill="none" stroke-width="2"/>
      
      <!-- Player vehicle only -->
      <polygon :points="playerIcon" 
               fill="#FF6600" stroke="#fff" stroke-width="1.5"
               :transform="`rotate(${playerRotation})`"/>
    </svg>
  </PhoneWrapper>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import PhoneWrapper from './PhoneWrapper.vue'

// Reactive state
const viewBox = ref('0 0 100 100')
const mapPaths = ref([])
const playerRotation = ref(0)
const playerIcon = ref('0,-5 -4,5 0,3 4,5')

// Lua event handlers
onMounted(() => {
  window.bngApi.engineLua('extensions.load("phone_minimap")')
  window.addEventListener('phoneMinimapUpdate', handleMinimapUpdate)
})

onUnmounted(() => {
  window.bngApi.engineLua('extensions.unload("phone_minimap")')
  window.removeEventListener('phoneMinimapUpdate', handleMinimapUpdate)
})

function handleMinimapUpdate(event) {
  const data = event.detail
  viewBox.value = `${data.viewX} ${data.viewY} ${data.viewW} ${data.viewH}`
  playerRotation.value = data.playerRot
}

// Initial map data loading
window.addEventListener('phoneMinimapData', event => {
  mapPaths.value = event.detail.paths
})
</script>

<style scoped lang="scss">
.phone-minimap {
  width: 100%;
  height: 100%;
  background: rgba(255, 255, 255, 0.9); // Light background for taxi UI
  border-radius: 0em;
}
</style> 