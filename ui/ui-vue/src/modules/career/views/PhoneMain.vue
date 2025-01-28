<template>
  <PhoneWrapper>
    <template #header>
      <h2 class="screen-title">Home</h2>
    </template>

    <div class="home-screen">
      <!-- Add your home screen content here -->
      <p>Welcome to your phone</p>
    </div>
  </PhoneWrapper>
</template>

<script setup>
import PhoneWrapper from "./PhoneWrapper.vue"
</script>

<style scoped lang="scss">
.home-screen {
  height: 100%;
  background: white;
  color: #333;
  padding: 1.5rem;
  
  // Basic text styling
  p {
    margin: 0;
    font-size: 1.1em;
  }
}

.screen-title {
  color: #333;
  margin: 0;
  padding: 0.5em 0;
  font-weight: 500;
}

// Override phone wrapper's dark background
:deep(.phone-content) {
  background: white;
}
</style> 