<template>
    <PhoneWrapper app-name="Taxi" status-font-color="#FFFFFF" status-blend-mode="normal">
        <div class="taxi-container" ref="container" @click="handleBackgroundClick">
            <!-- Minimap Background -->
            <div class="map-container">
                <svg class="minimap-layer terrain-layer"></svg>
                <svg class="minimap-layer vehicle-layer"></svg>
            </div>

            <!-- Reward Bubble -->
            <div class="reward-bubble" v-if="currentState !== 'start'">
                ${{ formatCurrency(totalReward) }}
            </div>

            <!-- Start State -->
            <div class="bottom-panel" v-if="currentState === 'start'">
                <div class="rider-details center">
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.person" />
                        {{ currentCapacity }}
                    </span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.carUp" />
                        {{ vehicleMultiplier }}
                    </span>
                </div>
                <button class="state-button" @click.stop="setState('ready')">
                    Drive Now
                </button>
            </div>

            <!-- Ready State -->
            <div class="bottom-panel" v-if="currentState === 'ready'">
                <div class="rider-details center">
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.person" />
                        {{ currentCapacity }}
                    </span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.carUp" />
                        {{ vehicleMultiplier }}
                    </span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.sync" />
                        {{ fareStreak }}
                    </span>
                </div>
                <button class="state-button stop" @click.stop="setState('stop')">
                    Stop Driving
                </button>
            </div>

            <!-- Pickup/Dropoff State -->
            <div class="bottom-panel" v-if="currentState === 'pickup' || currentState === 'dropoff'">
                <div class="rider-details">
                    <span class="rider-type">Standard</span> <span class="rider-info">★ {{ riderRating }}</span>
                </div>
                <div class="ride-status">
                    {{ currentState === 'pickup' ? 'Picking up' : 'Dropping off' }} {{ riderCount }} passengers
                </div>
                <div class="fare-display small">${{ formatCurrency(farePerKm) }}/km</div>
                <div class="rider-details center">
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.person" />
                        {{ riderCount }}/{{ currentCapacity }}
                    </span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.carUp" />
                        {{ vehicleMultiplier }}
                    </span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.sync" />
                        {{ fareStreak }}
                    </span>
                </div>
            </div>

            <!-- Accept Rider State -->
            <div class="bottom-panel rider" v-if="currentState === 'accept'">
                <div class="rider-header">
                    <span class="rider-type">Standard</span>
                    <button class="close-button" @click.stop="setState('reject')">
                        <BngIcon class="x-icon" :type="icons.xmark" />
                    </button>
                </div>
                <div class="fare-display">${{ formatCurrency(farePerKm) }}/km</div>
                <div class="rider-details">
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.person" />
                        {{ riderCount }}
                    </span>
                    <span class="rider-info">★ {{ riderRating }}</span>
                    <span class="rider-info">
                        <BngIcon class="app-icon" :type="icons.sync" />
                        {{ fareStreak }}
                    </span>
                </div>
                <button class="state-button" @click.stop="setState('working')">
                    Accept
                </button>
            </div>

            <!-- Complete State -->
            <div class="complete-overlay" v-if="currentState === 'complete'">
                <div class="complete-modal">
                    <div class="fare-display center">${{ formatCurrency(totalFare) }}</div>
                    <div class="rider-details center">
                        <span class="rider-info">{{ riderType }}</span>
                        <span class="rider-info">
                            <BngIcon class="app-icon" :type="icons.person" />
                            {{ riderCount }}
                        </span>
                        <span class="rider-info">★ {{ riderRating }}</span>
                        <span class="rider-info">
                            <BngIcon class="app-icon" :type="icons.sync" />
                            {{ fareStreak }}
                        </span>
                    </div>
                    <div class="rider-details center">
                        <span class="rider-info">
                            <BngIcon class="app-icon" :type="icons.road" />
                            {{ distanceTraveled }}km
                        </span>
                        <span class="rider-info">
                            <BngIcon class="app-icon" :type="icons.carUp" />
                            x{{ vehicleMultiplier }}
                        </span>
                        <span class="rider-info">
                            <BngIcon class="app-icon" :type="icons.timer" />
                            x{{ timeMultiplier }}
                        </span>
                    </div>
                    <button class="state-button complete" @click.stop="setState('ready')">Complete</button>
                </div>
            </div>
        </div>
    </PhoneWrapper>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useMinimapStore } from '../stores/minimapStore'
import PhoneWrapper from './PhoneWrapper.vue'
import { BngIcon, icons } from "@/common/components/base"
import { useEvents } from '@/services/events'
import { lua } from "@/bridge"

const events = useEvents()

const store = useMinimapStore()
const container = ref(null)

// State management
const currentState = ref('ready')
const totalReward = ref(0)
const fareStreak = ref(0)

// Fare
const currentFare = ref({})
const farePerKm = ref(0)
const distanceTraveled = ref(0)
const totalFare = ref(0)
const timeMultiplier = ref(0)

// Vehicle Specific
const vehicleMultiplier = ref(0)
const currentCapacity = ref(0)

// Rider Details
const riderType = ref('Standard')
const riderCount = ref(0)
const riderRating = ref(0)

const formatCurrency = (value) => {
    if (value >= 1e6) {
        const millions = (value / 1e6).toPrecision(3)
        return `${millions.replace(/\.0+$|(\.[0-9]*[1-9])0+$/, '$1')}M`
    }
    if (value >= 1e3) {
        const thousands = (value / 1e3).toPrecision(3)
        return `${thousands.replace(/\.0+$|(\.[0-9]*[1-9])0+$/, '$1')}k`
    }
    return value.toFixed(0)
}

const setState = (newState) => {
    currentState.value = newState
    if (newState === 'start') {
        lua.gameplay_taxi.prepareTaxiJob()
        totalReward.value = 0
    } else if (newState === 'reject') {
        lua.gameplay_taxi.rejectJob()
        currentState.value = 'ready'
    } else if (newState === 'ready') {
        lua.gameplay_taxi.setAvailable()
    } else if (newState === 'working') {
        lua.gameplay_taxi.acceptJob()
        currentState.value = 'pickup'

    } else if (newState === 'stop') {
        lua.gameplay_taxi.stopTaxiJob()
        currentState.value = 'start'
    }
}


const handleBackgroundClick = () => {
    if (currentState.value === 'complete') {
        setState('ready')
    }
}

const handleFare = () => {
    if (!currentFare.value) return

    farePerKm.value = Number(currentFare.value.baseFare ?? 0)
    riderCount.value = Number(currentFare.value.passengers ?? 0)
    riderRating.value = Number(currentFare.value.passengerRating ?? 0)
    totalFare.value = Number(currentFare.value.totalFare ?? 0)
    distanceTraveled.value = Number(currentFare.value.totalDistance ?? 0)
    timeMultiplier.value = Number(currentFare.value.timeMultiplier ?? 1)
}

onMounted(() => {
    events.on('updateTaxiState', (state) => {
        currentState.value = state.state
        currentFare.value = state.currentFare
        currentCapacity.value = state.availableSeats
        vehicleMultiplier.value = state.vehicleMultiplier
        totalReward.value = state.cumulativeReward,
            fareStreak.value = state.fareStreak
        handleFare()
    })
    store.init()
    const terrainLayer = container.value.querySelector('.terrain-layer')
    const vehicleLayer = container.value.querySelector('.vehicle-layer')
    terrainLayer.appendChild(store.svgLayers.terrain)
    vehicleLayer.appendChild(store.svgLayers.vehicles)
    lua.gameplay_taxi.requestTaxiState()
})

</script>

<style scoped lang="scss">
.taxi-container {
    position: relative;
    width: 100%;
    height: 100%;
}

.map-container {
    position: absolute;
    top: 0;
    left: 0;
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

.bottom-panel {
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    background: rgb(216, 224, 246);
    color: rgb(0, 0, 0);
    padding: 0.75rem;
    margin: 0.5rem;
    margin-bottom: 2rem;
    border-radius: 15px;

    &.rider {
        background: rgb(216, 224, 246);
        color: rgb(0, 0, 0);
        font-weight: 600;
    }
}

.capacity-display {
    display: flex;
    gap: 2rem;
    margin-bottom: 1.5rem;
    justify-content: space-between;
    padding: 0.5rem 3rem 0 3rem;
    font-size: 1.25em;
    font-family: 'Overpass', sans-serif;
    font-weight: 600;
    align-items: center;

    .capacity-item {
        display: flex;
    }
}

.reward-bubble {
    position: absolute;
    top: 40px;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(0, 0, 0, 0.9);
    padding: 0.5rem 1.5rem;
    border-radius: 25px;
    color: white;
    font-weight: bold;
    font-size: 1.2em;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
}

.rider-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-family: 'Overpass', sans-serif;
}

.rider-type {
    font-size: 1em;
    background: rgb(196, 205, 230);
    color: rgb(0, 0, 0);
    padding: 0.25rem 0.5rem 0.15rem 0.5rem;
    border-radius: 0.5rem;
    font-weight: 600;
    align-items: center;
    justify-content: center;
}

.ride-status {
    font-size: 1.5em;
    font-weight: 700;
    color: #010101;
    margin-top: 0.25rem;
    margin-bottom: 0.25rem;
    font-family: 'Overpass', sans-serif;

    &.center {
        text-align: center;
    }
}


.fare-display {
    font-size: 1.8em;
    color: #010101;
    margin-top: 0.25rem;
    margin-bottom: 0.25rem;
    font-family: 'Overpass', sans-serif;

    &.center {
        text-align: center;
    }

    &.small {
        font-size: 1.2em;
    }
}

.rider-details {
    display: flex;
    margin-bottom: 0.5rem;
    font-family: 'Overpass', sans-serif;

    .rider-info {
        font-size: 1.1em;

        background: rgb(196, 205, 230);
        color: rgb(0, 0, 0);
        padding: 0.1rem 0.5rem 0.05rem 0.5rem;
        margin-left: 0.25em;
        margin-right: 0.25em;
        border-radius: 0.5rem;
    }

    &.center {
        justify-content: center;
    }
}

.state-button {
    width: 100%;
    padding: 0.75rem 0rem 0.65rem 0rem;
    background: #2f2bff;
    color: rgb(255, 255, 255);
    border: none;
    border-radius: 10px;
    font-size: 1.75em;
    font-weight: 600;
    font-family: 'Overpass', sans-serif;

    &.stop {
        background: #ff1744;
    }

    &.complete {
        background: #0f7b0f;
    }

    &:hover {
        transform: scale(1.02);
    }
}

.complete-overlay {
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
}

.complete-modal {
    background: rgb(216, 224, 246);
    font-weight: 600;
    padding: 1rem;
    border-radius: 20px;
    width: 90%;
    column-gap: 5rem;
}

.app-icon {
    font-size: 125%;
    color: rgb(0, 0, 0);
    align-content: center;
}

.x-icon {
    font-size: 1em;
    color: rgb(0, 0, 0);
    justify-content: center;
    align-items: center;
}

.close-button {
    font-size: 1.25em;
    height: 1.75em;
    width: 1.75em;
    border: none;
    background: rgb(196, 205, 230);
    border-radius: 0.5rem;
    float: right;

    &:hover {
        transform: scale(1.15);
    }
}
</style>
