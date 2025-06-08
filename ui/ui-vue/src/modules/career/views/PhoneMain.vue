<template>
  <PhoneWrapper app-name="Home" status-font-color="#FFFFFF" status-blend-mode="">
    <div class="home-screen">
      <div 
        v-for="app in apps" 
        :key="app.name" 
        class="app-item"
      >
        <button 
          class="app-container"
          @click="navigateTo(app.route)"
          :style="{ backgroundColor: app.color }"
        >
          <BngIcon 
            class="app-icon" 
            :type="app.icon" 
            :style="{ color: app.iconColor }"
          />
        </button>
        <span class="app-name">{{ app.name }}</span>
      </div>
    </div>
  </PhoneWrapper>
</template>

<script setup>
import PhoneWrapper from "./PhoneWrapper.vue"
import { BngIcon, icons } from "@/common/components/base"
import { useRouter } from 'vue-router'

const router = useRouter()

const apps = [
  { name: 'Taxi', icon: icons.taxiCar3, route: '/career/phone-taxi', color: '#ffd700', iconColor: '#000000' },
  { name: 'Repo', icon: icons.tow, route: '/career/phone-repo', color: '#1E90FF', iconColor: '#ffffff' },
  { name: 'Car Meet', icon: icons.cars, route: '/career/car-meets-phone', color: '#696969', iconColor: '#ffffff' },
  { name: 'Marketplace', icon: icons.shoppingCart, route: '/career/phone-marketplace', color: '#228B22', iconColor: '#ffffff' }
  // Add more apps using icons from the existing icon system
]

const navigateTo = (route) => {
  router.push(route)
}
</script>

<style scoped lang="scss">
.home-screen {
  padding: 20px;
  padding-top: 500px;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 20px;
  max-width: 500px;
  margin: 0 auto;
}

.app-item {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.app-container {
  --app-bg: rgba(0, 0, 0, 0.818);
  --icon-color: white;

  background-color: var(--app-bg);
  border-radius: 16px;
  padding: 8px;
  cursor: pointer;
  transition: all 0.2s ease, background-color 0.2s ease;
  display: flex;
  flex-direction: column;
  align-items: center;
  aspect-ratio: 1/1;
  justify-content: space-between;
  position: relative;
  border: 0px solid transparent;

  &::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(
      to bottom, 
      transparent 0%,
      rgba(0, 0, 0, 0.5) 100%
    );
    pointer-events: none;
  }

  &:hover {
    transform: scale(1.05);
  }
}

.app-icon {
  font-size: 3.5em;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--icon-color);
  transition: color 0.2s ease;
  position: relative;
}

.app-name {
  color: white;
  font-size: 14px;
  text-align: center;
  font-weight: 500;
  margin-top: 8px;
  width: 100%;
  position: relative;
}

// Override phone wrapper's dark background
:deep(.phone-content) {
  background: linear-gradient(to bottom, #000000, #1509fb);
}
</style> 