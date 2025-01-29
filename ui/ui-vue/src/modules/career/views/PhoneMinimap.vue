<template>
  <PhoneWrapper app-name="Minimap" status-font-color="#FFFFFF" status-blend-mode="">
    <div class="minimap-container" ref="container">
      
      <div class="map-base" :style="mapTransform">
        <svg class="minimap-layer terrain-layer"></svg>
        <svg class="minimap-layer vehicle-layer"></svg>
      </div>
    </div>
  </PhoneWrapper>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useMinimapStore } from '../stores/minimapStore'
import PhoneWrapper from './PhoneWrapper.vue'

const store = useMinimapStore()
const container = ref(null)

onMounted(() => {
store.init()

// Attach layers to correct containers
const terrainLayer = container.value.querySelector('.terrain-layer')
const vehicleLayer = container.value.querySelector('.vehicle-layer')

terrainLayer.appendChild(store.svgLayers.terrain)
vehicleLayer.appendChild(store.svgLayers.vehicles)
})

onUnmounted(() => {
  store.cleanup()
})
</script>

<style scoped>
.map-base {
width: 100%;
height: 100%;
transform-origin: center center;
}

.minimap-container {
width: 100%;
height: 100%;
background: rgba(40, 40, 40, 0.9);
}

.minimap-layer {
  position: absolute;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
</style>