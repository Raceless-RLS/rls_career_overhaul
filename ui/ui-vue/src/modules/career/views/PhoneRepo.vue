<template>
    <PhoneWrapper app-name="Repo" status-font-color="#FFFFFF" status-blend-mode="normal">
        <div class="repo-container" ref="container" @click="handleBackgroundClick">
            <!-- Minimap Background -->
            <div class="map-container">
                <svg class="minimap-layer terrain-layer"></svg>
                <svg class="minimap-layer vehicle-layer"></svg>
            </div>

            <!-- Reward Bubble -->
            <div class="reward-bubble" v-if="currentReward > 0">
                ${{ formatCurrency(currentReward) }}
            </div>

            <!-- No Mission State -->
            <div class="bottom-panel" v-if="currentState === 'no_mission'">
                <div class="panel-header">Vehicle Repo Service</div>
                <div class="panel-content">
                    <div class="instruction-text" v-if="isInRepoVehicle">Generate a new repo mission to earn money by recovering vehicles.</div>
                    <div class="instruction-text" v-if="!isInRepoVehicle">You need to be in a repo vehicle to start missions.</div>
                </div>
                <button class="state-button" @click.stop="generateMission()" v-if="isInRepoVehicle">
                    Generate Mission
                </button>
                <button class="state-button disabled" v-if="!isInRepoVehicle" disabled>
                    Need Repo Vehicle
                </button>
            </div>

            <div class="bottom-panel" v-if="currentState === 'loading'">
                <div class="panel-header">Loading</div>
                <div class="panel-content">
                    <div class="instruction-text">Loading Mission...</div>
                </div>
            </div>

            <!-- Picking Up State -->
            <div class="bottom-panel" v-if="currentState === 'picking_up'">
                <div class="panel-header">
                    <span class="vehicle-type">Repo</span>
                    <button class="close-button" @click.stop="abandonMission()">
                        <BngIcon class="x-icon" :type="icons.xmark" />
                    </button>
                </div>
                <div class="vehicle-display">{{ vehicleBrand }} {{ vehicleName }}</div>
                <div class="instruction-text">Find and collect this vehicle</div>
                <div class="vehicle-details">
                    <span class="vehicle-info">
                        {{ vehicleYear }}
                    </span>
                    <span class="vehicle-info">
                        {{ units.buildString('length', vehicleMileage, 0) }}
                    </span>
                </div>
            </div>

            <!-- Dropping Off State -->
            <div class="bottom-panel" v-if="currentState === 'dropping_off'">
                <div class="panel-header">
                    <span class="vehicle-type">Repo</span>
                    <button class="close-button" @click.stop="abandonMission()">
                        <BngIcon class="x-icon" :type="icons.xmark" />
                    </button>
                </div>
                <div class="vehicle-display">{{ vehicleBrand }} {{ vehicleName }}</div>
                <div class="instruction-text">Deliver to: {{ deliveryLocation }}</div>
                <div class="vehicle-details">
                    <span class="vehicle-info">
                        {{ vehicleYear }}
                    </span>
                    <span class="vehicle-info">
                        {{ formatDistance(distanceToDestination) }}
                    </span>
                </div>
            </div>

            <!-- Completed State -->
            <div class="complete-overlay" v-if="currentState === 'completed'">
                <div class="complete-modal">
                    <div class="fare-display center">${{ formatCurrency(currentReward) }}</div>
                    <div class="vehicle-details center">
                        <span class="vehicle-info">{{ vehicleBrand }} {{ vehicleName }}</span>
                    </div>
                    <div class="vehicle-details center">
                        <span class="vehicle-info">
                            {{ formatDistance(totalDistance) }}
                        </span>
                    </div>
                    <button class="state-button complete" @click.stop="completeMission()">Complete</button>
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
import { lua, useBridge } from '@/bridge'

const { units, events } = useBridge()

const store = useMinimapStore()
const container = ref(null)

// State management
const currentState = ref('no_mission')
const currentReward = ref(0)
const isInRepoVehicle = ref(false)

// Vehicle Details
const vehicleBrand = ref('')
const vehicleName = ref('')
const vehicleYear = ref('')
const vehicleMileage = ref(0)
const deliveryLocation = ref('')
const distanceToDestination = ref(0)
const totalDistance = ref(0)

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

const formatDistance = (distance) => {
    if (distance < 1000) {
        return `${Math.round(distance)} m`
    } else {
        return `${(distance / 1000).toFixed(1)} km`
    }
}

const generateMission = () => {
    lua.gameplay_repo.generateJob()
    currentState.value = 'loading'
}

const abandonMission = () => {
    lua.gameplay_repo.cancelJob()
    currentState.value = 'no_mission'
    currentReward.value = 0
}

const completeMission = () => {
    lua.gameplay_repo.completeJob()
    currentState.value = 'no_mission'
    currentReward.value = 0
}

const handleBackgroundClick = () => {
    if (currentState.value === 'completed') {
        completeMission()
    }
}

const updateRepoState = (data) => {
    if (!data) return

    // Update state based on repo job data
    if (data.state) {
        currentState.value = data.state
    }

    // Update vehicle details
    if (data.vehicle) {
        vehicleBrand.value = data.vehicle.Brand || ''
        vehicleName.value = data.vehicle.Name || ''
        vehicleYear.value = data.vehicle.year || ''
        vehicleMileage.value = data.vehicle.Mileage || 0
    }

    // Update location information
    if (data.deliveryLocation) {
        deliveryLocation.value = data.deliveryLocation || ''
    }

    if (data.distanceToDestination) {
        distanceToDestination.value = data.distanceToDestination || 0
    }

    if (data.totalDistance) {
        totalDistance.value = data.totalDistance || 0
    }

    // Update reward
    if (data.reward) {
        currentReward.value = data.reward || 0
    }

    // Update isInRepoVehicle
    if (data.isRepoVehicle !== undefined) {
        isInRepoVehicle.value = data.isRepoVehicle
    }
}

onMounted(() => {
    // Listen for updates from Lua
    events.on('updateRepoState', updateRepoState)
    
    // Initialize minimap
    store.init()
    const terrainLayer = container.value.querySelector('.terrain-layer')
    const vehicleLayer = container.value.querySelector('.vehicle-layer')
    terrainLayer.appendChild(store.svgLayers.terrain)
    vehicleLayer.appendChild(store.svgLayers.vehicles)
    
    // Request initial state
    lua.gameplay_repo.requestRepoState()
})

</script>

<style scoped lang="scss">
.repo-container {
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
}

.panel-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-family: 'Overpass', sans-serif;
    font-size: 1.2em;
    font-weight: 600;
    margin-bottom: 0.5rem;
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

.vehicle-type {
    font-size: 1em;
    background: rgba(30, 144, 255, 0.6);
    color: rgb(255, 255, 255);
    padding: 0.25rem 0.5rem 0.15rem 0.5rem;
    border-radius: 0.5rem;
    font-weight: 600;
    align-items: center;
    justify-content: center;
}

.vehicle-display {
    font-size: 1.8em;
    font-weight: 700;
    color: #010101;
    margin-top: 0.25rem;
    margin-bottom: 0.25rem;
    font-family: 'Overpass', sans-serif;
}

.instruction-text {
    font-size: 1.2em;
    color: #333;
    margin-bottom: 0.5rem;
    font-family: 'Overpass', sans-serif;
}

.vehicle-details {
    display: flex;
    margin-bottom: 0.5rem;
    font-family: 'Overpass', sans-serif;

    .vehicle-info {
        font-size: 1.1em;
        background: rgba(196, 205, 230, 0.8);
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
    background: #1E90FF;
    color: rgb(255, 255, 255);
    border: none;
    border-radius: 10px;
    font-size: 1.75em;
    font-weight: 600;
    font-family: 'Overpass', sans-serif;

    &.abandon {
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
}

.fare-display {
    font-size: 1.8em;
    color: #010101;
    margin: 0.5rem 0;
    font-family: 'Overpass', sans-serif;

    &.center {
        text-align: center;
    }
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
    background: rgba(196, 205, 230, 0.8);
    border-radius: 0.5rem;
    float: right;

    &:hover {
        transform: scale(1.15);
    }
}

.panel-content {
    margin-bottom: 1rem;
}
</style> 