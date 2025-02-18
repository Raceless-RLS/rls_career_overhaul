<template>
    <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Marketplace" back @back="close">
        <div class="marketplace-container">
            <div class="header">
                <h2>Vehicles Listed</h2>
                <!-- <button class="list-button" @click="router.push('/career/vehicle-inventory')">List Vehicle For
                    Sale</button> -->
                <BngSwitch v-model="notifications"> Notifications </BngSwitch>

            </div>
            <hr class="custom-hr">
            <template v-if="listedVehicles.length">
                <div v-for="vehicle in listedVehicles" :key="vehicle.id" class="vehicle-listing">
                    <div class="vehicle-card" :class="{ active: showOffers === vehicle.id }">
                        <img :src="vehicle.thumbnail ? vehicle.thumbnail : image" alt="" class="vehicle-image">
                        <div class="vehicle-info">
                            <div class="vehicle-header">
                                <div>
                                    <div class="year"> {{ vehicle.year }}</div>
                                    <div class="model">{{ vehicle.niceName }}</div>
                                    <div class="mileage"> {{ units.buildString('length', vehicle.mileage, 0) }} </div>
                                </div>
                                <button class="messages-badge" @click="toggleOffers(vehicle.id)">
                                    <BngIcon :type="icons.dialogOutline" />
                                    <span class="badge" v-if="vehicleOffers(vehicle.id).length">{{
                                        vehicleOffers(vehicle.id).length }}</span>
                                </button>
                            </div>
                            <div class="vehicle-specs">
                                <div class="specs">
                                    <div>{{ vehicle.power }} PS</div>
                                    <div>{{ vehicle.torque }} NM</div>
                                    <div>{{ vehicle.weight }} KG</div>
                                    <div>{{ vehicle.powerPerWeight }} PS/KG</div>
                                </div>
                                <div>
                                    <button class="event-times" :class="{ active: showEventTimes === vehicle.id }"
                                        @click="toggleEventTimes(vehicle.id)">
                                        Free-roam event times
                                        <BngIcon
                                            :type="showEventTimes === vehicle.id ? icons.arrowLargeUp : icons.arrowLargeDown" />
                                    </button>
                                    <div class="price-info">
                                        <div class="repIncrease">
                                            <BngIcon :type="icons.arrowsUp" :color="'#4caf50'" />
                                            {{ vehicle.meetReputation ? vehicle.meetReputation : 0 }}%
                                        </div>
                                        <div class="price">
                                            <BngIcon :type="icons.beamCurrency" :color="'#4caf50'" />{{
                                                formatValue(vehicle.value) }}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div v-if="showEventTimes === vehicle.id" class="event-times-dropdown">
                        <template v-if="Object.keys(vehicle.FRETimes || {}).length">
                            <div v-for="(time, name) in vehicle.FRETimes" :key="name" class="time-entry">
                                <span>{{ name }}:</span>
                                <span>{{ formatTime(time) }}</span>
                            </div>
                        </template>
                        <div v-else class="no-times-message">
                            No stored times
                        </div>
                    </div>
                    <div v-if="showOffers === vehicle.id" class="offers-container">
                        <template v-if="vehicleOffers(vehicle.id).length">
                            <div v-for="offer in vehicleOffers(vehicle.id)" :key="offer.customer" class="offer-row">
                                <span class="dealer-name">{{ offer.customer }}</span>
                                <div class="offer-actions">
                                    <span class="offer-amount">Offered: ${{ formatValue(offer.price) }}</span>
                                    <button class="accept-btn"
                                        @click="acceptOffer(vehicle.id, offer.customer)">Accept</button>
                                    <button class="decline-btn"
                                        @click="declineOffer(vehicle.id, offer.customer)">Decline</button>
                                </div>
                            </div>
                        </template>
                        <div v-else class="no-times-message">
                            No active offers
                        </div>
                    </div>
                </div>
            </template>
            <div v-else class="no-vehicles-message">
                No Vehicles Listed
            </div>
        </div>
    </ComputerWrapper>
</template>

<script setup>
import { ref, onMounted, computed, onBeforeMount, watch } from "vue"
import ComputerWrapper from "./ComputerWrapper.vue";
import { useComputerStore } from "../stores/computerStore";
import { openConfirmation } from "@/services/popup"
import { useVehicleInventoryStore } from "../stores/vehicleInventoryStore";
import { BngIcon, icons, ACCENTS, BngSwitch } from "@/common/components/base"
import { lua, useBridge } from '@/bridge'
import { $translate } from "@/services/translation"

const vehiclesForSale = ref([])

const { units, events } = useBridge()

const computerStore = useComputerStore();
const vehicleInventoryStore = useVehicleInventoryStore();
const showEventTimes = ref(null)
const showOffers = ref(null)
const image = ref("/settings/cloud/saves/Profile 17/autosave3/career/vehicles/5.png")

const marketplaceData = ref({})
const notifications = ref(true)

onMounted(() => {
    lua.career_modules_vehicleMarketplace.requestInitialData()
});

onBeforeMount(() => {
  vehicleInventoryStore.requestInitialData()
})

events.on("marketplaceUpdate", (data) => {
    marketplaceData.value = data
    vehiclesForSale.value = Object.keys(data)
})

watch(notifications, (newValue, oldValue) => {
  lua.career_modules_vehicleMarketplace.toggleNotifications(newValue)
})

const close = () => {
    lua.career_career.closeAllMenus()
}

const toggleEventTimes = (vehicleId) => {
    showEventTimes.value = showEventTimes.value === vehicleId ? null : vehicleId
}

const toggleOffers = (vehicleId) => {
    showOffers.value = showOffers.value === vehicleId ? null : vehicleId
}

const formatValue = (value) => {
    if (value === null || value === undefined) {
        return '0';
    }
    const num = Number(value);
    if (isNaN(num)) {
        return '0';
    }
    return num.toLocaleString('en-US', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
    });
}

const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60)
    const secs = (seconds % 60).toFixed(2).padStart(5, '0')
    return `${mins}:${secs}`
}

const vehicleOffers = (vehicleId) => {
    return marketplaceData.value[vehicleId].offers || []
}

const acceptOffer = async (vehicleId, customer) => {
    const res = await openConfirmation("", `Do you want to accept this offer for $${formatValue(vehicleOffers(vehicleId).find(offer => offer.customer === customer).price)} from ${customer}?`, [
        { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
        { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
    ])
    if (res) lua.career_modules_vehicleMarketplace.acceptOffer(vehicleId, customer)
}

const declineOffer = async (vehicleId, customer) => {
    const res = await openConfirmation("", `Do you want to decline this offer for $${formatValue(vehicleOffers(vehicleId).find(offer => offer.customer === customer).price)} from ${customer}?`, [
        { label: $translate.instant("ui.common.yes"), value: true, extras: { default: true } },
        { label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.secondary } },
    ])
    if (res) lua.career_modules_vehicleMarketplace.declineOffer(vehicleId, customer)
}

const listedVehicles = computed(() => {
    return vehicleInventoryStore.filteredVehicles.filter(vehicle =>
        vehiclesForSale.value.includes(vehicle.id.toString())
    )
})

</script>

<style scoped lang="scss">
.marketplace-container {
    width: max-content;
    min-width: 40%;
    height: 95%;
    background-color: #282828;
    border-radius: 15px;
    padding: 20px;
    color: white;
    overflow-y: auto;
    font-family: "Overpass", sans-serif;
}

.custom-hr {
    border: 0;
    height: 2px;
    background: #4B4B4B;
    margin: 10px 0;
}

.header {
    display: flex;
    justify-content: space-between;
    align-items: center;

    h2 {
        font-size: 24px;
        margin: 0;
    }
}

.list-button {
    background-color: #3474eb;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 600;
    color: white;
    padding: 6px 16px;
    border-radius: 10px;
    border: none;
    cursor: pointer;
    margin-top: -6px;
}

.vehicle-listing {
    position: relative;
    margin-top: 10px;
}

.vehicle-card {
    background-color: #293037;
    border-radius: 15px;
    overflow: hidden;
    display: flex;
    border: none;
    margin-bottom: 0;
    position: relative;
}

.vehicle-image {
    margin: 10px;
    width: 300px;
    height: 174px;
    border-radius: 15px;
    background-color: #3b3b3b;
}

.vehicle-info {
    padding: 10px;
    flex-grow: 1;
    display: grid;
    grid-template-rows: repeat(2, auto);
}

.vehicle-header {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0px;
}

.vehicle-specs {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 100px;
}

.year {
    font-size: 12px;
    color: #888;
}

.model {
    font-size: 24px;
    font-weight: bold;
}

.mileage {
    color: #888;
    font-size: 12px;
}

.messages-badge {
    position: relative;
    font-size: 26px;
    display: flex;
    align-items: center;
    justify-content: flex-start;
    margin-top: -32px;
    background-color: transparent;
    border: none;
    color: white;
    font-family: "Overpass", sans-serif;
    cursor: pointer;

    .badge {
        background-color: #ff4444;
        display: flex;
        align-items: center;
        justify-content: center;
        border-radius: 50%;
        width: 15px;
        height: 15px;
        font-size: 12px;
        margin-left: -15px;
        margin-top: -15px;
        font-weight: 650;
    }
}

.specs {
    display: grid;
    grid-template-rows: repeat(4, auto);
    gap: 5px;
    margin-bottom: 0px;
}

.event-times {
    background-color: #3D3D3D;
    font-size: 14px;
    font-weight: 650;
    color: white;
    padding: 4px 12px 4px 16px;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-right: 12px;
    border-radius: 10px;
    width: 230px;

    &.active {
        border-bottom-left-radius: 0;
        border-bottom-right-radius: 0;
    }
}

.price-info {
    text-align: right;
}

.repIncrease {
    color: #4caf50;
    font-size: 16px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-top: 25px;
    margin-bottom: -5px;
}

.price {
    font-size: 24px;
    font-weight: bold;
    color: #4caf50;
    display: flex;
    align-items: center;
    justify-content: flex-end;
}

.event-times-dropdown {
    position: absolute;
    max-height: 150px;
    overflow-y: auto;
    top: 100px;
    /* Adjust based on your button height */
    right: 22px;
    z-index: 100;
    background-color: #3D3D3D;
    padding: 10px;
    width: 230px;
    border-radius: 0 0 10px 10px;
}

.time-entry {
    display: flex;
    justify-content: space-between;
    padding: 5px 0;

    span:first-child {
        color: #888;
    }

    span:last-child {
        font-weight: 600;
    }
}

.offers-container {
    background-color: #1A1818;
    border-radius: 0 0 15px 15px;
    margin-top: -10px;
    padding: 5px;
    position: relative;
    z-index: 1;
}

.offer-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 8px 16px;
    background-color: #2B2C28;
    margin: 10px;
    border-radius: 8px;
}

.dealer-name {
    font-weight: 500;
    color: white;
}

.offer-amount {
    color: white;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    margin-right: 25px;
}

.offer-actions {
    display: flex;
    gap: 10px;
    color: black;
}

.accept-btn,
.decline-btn {
    color: black;
    padding: 4px 16px;
    font-size: 14px;
    border: none;
    border-radius: 10px;
    font-weight: 600;
    cursor: pointer;
}

.accept-btn {
    background-color: #4CAF50;
    margin-right: 10px;
}

.decline-btn {
    background-color: #f44336;
}

.no-times-message {
    text-align: center;
    color: #888;
    padding: 5px 0;
}

.no-vehicles-message {
    text-align: center;
    color: #888;
    padding: 20px;
    font-size: 1.2em;
}
</style>
