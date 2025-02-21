<template>
    <PhoneWrapper app-name="Marketplace" status-font-color="#ffffff" status-blend-mode="non">
        <div class="marketplace-container">
            <div class="header">
                <h2>Vehicles Listed</h2>
                <!-- <button class="list-button" @click="router.push('/career/vehicle-inventory')">List Vehicle For
                    Sale</button> -->
                <div class="header-right">
                    <BngSwitch v-model="notifications"> Notifications </BngSwitch>
                    <button class="help-button" @click="help">?</button>
                </div>
            </div>
            <hr class="custom-hr">
            <template v-if="listedVehicles.length && !helpPopup">
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
                                <div class="offer-actions">
                                    <span class="dealer-name">{{ offer.customer }}</span>
                                    <span class="offer-amount">${{ formatValue(offer.price) }}</span>
                                </div>
                                <div class="offer-actions">
                                    <button class="accept-btn"
                                        @click="acceptOffer(vehicle.id, offer.customer)" :disabled="vehicle.needsRepair">Accept</button>
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
            <div v-else-if="helpPopup">
                <div class="help-screen">
                    <div class="help-screen">
                        <h1>Marketplace Overview</h1>
                        <p>
                            Your vehicle’s appeal in the marketplace is determined by a range of criteria.
                            The more activities and customizations you complete, the higher the interest
                            from potential customers—and higher offers you'll receive (although offers come
                            in offline and at a longer interval).
                        </p>
                        <p>
                            To get started, list your vehicle for sale by going into your vehicle inventory and
                            selecting "List for
                            Sale".
                        </p>
                        <p>
                            Note: If you make changes to your vehicle after listing, you may lose current offers.
                        </p>

                        <h2>Vehicle Performance & Event Stats</h2>
                        <ul>
                            <li>
                                <strong>Performance Values:</strong>
                                These values represent your vehicle’s performance in free roam events.
                                The better you perform, the higher this score will be.
                            </li>
                            <li>
                                <strong>Completions:</strong>
                                Tracks how many free roam events you have participated in and your streak of consecutive
                                completions.
                                Consistency here boosts your vehicle’s appeal.
                            </li>
                            <li>
                                <strong>Arrests, Tickets, & Evades:</strong>
                                <ul>
                                    <li><em>Arrests:</em> Number of times you’ve been caught by the police.</li>
                                    <li><em>Tickets:</em> Times you’ve received fines.</li>
                                    <li><em>Evades:</em> How often you’ve successfully evaded the police.</li>
                                </ul>
                            </li>
                            <li>
                                <strong>Accidents:</strong>
                                Counts the number of repairs made via insurance. Fewer accidents might indicate a more
                                reliable
                                vehicle.
                            </li>
                            <li>
                                <strong>Movie Rentals:</strong>
                                Reflects the number of times your vehicle has been rented out for theater
                                events—demonstrating
                                versatility.
                            </li>
                            <li>
                                <strong>Repos:</strong>
                                Shows the number of vehicles you’ve successfully repossessed using your vehicle. This
                                can appeal to
                                certain high-paying customer types.
                            </li>
                            <li>
                                <strong>Taxi Dropoffs & Delivered Items:</strong>
                                <ul>
                                    <li><em>Taxi Dropoffs:</em> The number of passengers you’ve transported.</li>
                                    <li><em>Delivered Items:</em> Volume or count of deliveries you’ve made.</li>
                                </ul>
                            </li>
                            <li>
                                <strong>Suspects Caught:</strong>
                                Indicates the number of times you’ve used your vehicle in police chases to catch
                                suspects, enhancing
                                its law enforcement credentials.
                            </li>
                        </ul>

                        <h2>Customization & Upgrades</h2>
                        <ul>
                            <li>
                                <strong>Number of Added Parts:</strong>
                                How many upgrades or new parts have been added to your vehicle.
                                More upgrades often lead to higher performance and appeal.
                            </li>
                            <li>
                                <strong>Number of Removed Parts:</strong>
                                Indicates modifications or removals from the original setup, which can reflect a
                                vehicle’s
                                customization journey.
                            </li>
                        </ul>

                        <h2>Increasing Marketplace Interest</h2>
                        <ul>
                            <li>
                                <strong>Multi-Faceted Appeal:</strong>
                                Each of the criteria (performance, event stats, and customizations) plays a role in
                                attracting
                                customers.
                            </li>
                            <li>
                                <strong>Specialization:</strong>
                                If you focus on excelling in specific areas (like evading the police or delivering
                                items),
                                you might attract high-paying customers interested in that niche.
                            </li>
                            <li>
                                <strong>Offer Timing:</strong>
                                Offers are generated while you play the game and the interval depends on your interest.
                                They are also generated offline, and the interval between offers is five times longer than
                                normal.
                                More interest means you’ll receive these offers more quickly once the wait time is up.
                            </li>
                        </ul>

                        <p>
                            By excelling in these areas, your vehicle becomes more attractive on the marketplace.
                            The system rewards well-rounded performance and specialization, so focus on the stats
                            that best suit your play style to secure the best deals!
                        </p>
                    </div>
                </div>
            </div>
            <div v-else class="no-vehicles-message">
                No Vehicles Listed
            </div>
        </div>


    </PhoneWrapper>
</template>

<script setup>
import { ref, onMounted, computed, onBeforeMount, watch } from "vue"
import PhoneWrapper from "./PhoneWrapper.vue"
import { openConfirmation } from "@/services/popup"
import { useVehicleInventoryStore } from "../stores/vehicleInventoryStore";
import { BngIcon, icons, ACCENTS, BngSwitch } from "@/common/components/base"
import { lua, useBridge } from '@/bridge'
import { useRouter } from 'vue-router'
import { $translate } from "@/services/translation"

const vehiclesForSale = ref([])

const { units, events } = useBridge()

const router = useRouter()
const vehicleInventoryStore = useVehicleInventoryStore();
const showEventTimes = ref(null)
const showOffers = ref(null)
const image = ref("/settings/cloud/saves/Profile 17/autosave3/career/vehicles/5.png")
const notifications = ref(true)
const marketplaceData = ref({})
const helpPopup = ref(false)

watch(notifications, (newValue, oldValue) => {
    lua.career_modules_vehicleMarketplace.toggleNotifications(newValue)
})

onMounted(() => {
    lua.career_modules_vehicleMarketplace.requestInitialData()
});

onBeforeMount(() => {
    vehicleInventoryStore.requestInitialData()
})

events.on("marketplaceUpdate", (data) => {
    console.log("marketplaceUpdate", data)
    marketplaceData.value = data
    vehiclesForSale.value = Object.keys(data)
})

const close = () => {
    router.back()
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

const help = () => {
    helpPopup.value = !helpPopup.value
}

</script>

<style scoped lang="scss">
.marketplace-container {
    width: max-content;
    height: 97%;
    width: 100%;
    background-color: #282828;
    z-index: 1;
    padding: 10px;
    color: white;
    font-family: "Overpass", sans-serif;
    overflow-y: auto;
    -ms-overflow-style: none;
    /* IE and Edge */
    scrollbar-width: none;
    /* Firefox */

    &::-webkit-scrollbar {
        display: none;
    }
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
    margin-top: 40px;

    h2 {
        font-size: 20px;
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
    font-size: 14px;
}

.vehicle-card {
    background-color: #293037;
    border-radius: 15px;
    overflow: hidden;
    position: relative;
    margin-top: 10px;

    &.active {
        border-bottom-left-radius: 0;
        border-bottom-right-radius: 0;
    }
}

.vehicle-image {
    margin: 10px;
    width: 320px;
    height: 186px;
    border-radius: 15px;
    background-color: #3b3b3b;
    display: flex;
    align-items: center;
    justify-content: center;
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
    gap: 0px;
}

.year {
    font-size: 12px;
    color: #888;
    font-weight: 600;
}

.model {
    font-size: 24px;
    font-weight: bold;
}

.mileage {
    color: #888;
    font-size: 14px;
    font-weight: 600;
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
    top: 308px;
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
    flex-wrap: wrap;
    justify-content: space-evenly;
    padding: 8px 16px;
    background-color: #2B2C28;
    margin: 10px;
    border-radius: 8px;
}

.dealer-name {
    justify-content: space-evenly;
    font-weight: 500;
    color: white;
}

.offer-amount {
    color: #888;
}

.offer-actions {
    display: flex;
    gap: 10px;
    width: 100%;
    margin-top: 8px;
    justify-content: space-evenly;
}

.accept-btn,
.decline-btn {
    color: black;
    padding: 4px 16px;
    font-size: 16px;
    border: none;
    border-radius: 10px;
    font-weight: 600;
    cursor: pointer;
}

.accept-btn {
    background-color: #4CAF50;
    margin-right: 10px;
    
    &:disabled {
        background-color: #2d5a2f;
        opacity: 0.7;
        cursor: not-allowed;
    }
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

.vehicle-listing {
    position: relative;
}

.header-right {
    display: flex;
    align-items: center;
    gap: 10px;
}

.help-button {
    background-color: #3474eb;
    width: 30px;
    height: 30px;
    color: white;
    background-color: rgb(67, 70, 80);
    border-radius: 20px;
    font-size: 26px;
    font-weight: 700;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
}

.help-screen {
    font-family: Arial, sans-serif;
    line-height: 1.6;
    padding: 2px;
    color: white;

    h1,
    h2 {
        color: #fff;
        margin-bottom: 5px;
    }

    ul {
        margin: 5px 0 10px 10px;
    }

    li {
        margin-bottom: 4px;
    }

    strong {
        color: #ccc;
    }
}
</style>
