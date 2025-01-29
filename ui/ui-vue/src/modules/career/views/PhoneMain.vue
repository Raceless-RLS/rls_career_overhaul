<template>
  <PhoneWrapper app-name="Home">
  </PhoneWrapper>
</template>

<script setup>
import PhoneWrapper from "./PhoneWrapper.vue"
</script>

<style scoped lang="scss">
// Override phone wrapper's dark background
:deep(.phone-content) {
  background: white;
}
</style> 