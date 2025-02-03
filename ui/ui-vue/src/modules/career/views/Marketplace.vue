<template>
    <ComputerWrapper :path="[computerStore.computerData.facilityName]" title="Marketplace" back @back="close">
        <div class="marketplace-container">
            <div class="header">
                <h2>Vehicles Listed</h2>
                <button class="list-button">List Vehicle For Sale</button>
            </div>
            <hr class="custom-hr">
            <div class="vehicle-card">
                <img src="/settings/cloud/saves/Profile 17/autosave3/career/vehicles/5.png" alt=""
                    class="vehicle-image">
                <div class="vehicle-info">
                    <div class="vehicle-header">
                        <div>
                            <div class="year">2022</div>
                            <div class="model">Civetta Scintilla</div>
                            <div class="mileage">44 Miles</div>
                        </div>
                        <div class="messages-badge">
                            <BngIcon :type="icons.dialogOutline" />
                            <span class="badge">2</span>
                        </div>
                    </div>
                    <div class="vehicle-specs">
                        <div class="specs">
                            <div>531 PS</div>
                            <div>523 HP</div>
                            <div>1533 KG</div>
                            <div>0.346 PS/KG</div>
                        </div>
                        <div>
                            <button class="event-times" :class="{ active: showEventTimes }" @click="toggleEventTimes">
                                Free-roam event times
                                <BngIcon :type="showEventTimes ? icons.arrowLargeUp : icons.arrowLargeDown" />
                            </button>
                            <div v-if="showEventTimes" class="event-times-dropdown">
                                <div class="time-entry">
                                    <span>Track:</span>
                                    <span>1:32.46</span>
                                </div>
                                <div class="time-entry">
                                    <span>Short Track:</span>
                                    <span>1:09.32</span>
                                </div>
                            </div>
                            <div class="price-info">
                                <div class="repIncrease">
                                    <BngIcon :type="icons.arrowsUp" :color="'#4caf50'" />
                                    3.5%
                                </div>
                                <div class="price">
                                    <BngIcon :type="icons.beamCurrency" :color="'#4caf50'" />278,116.00
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </ComputerWrapper>
</template>

<script setup>
import { ref, onMounted } from "vue"
import ComputerWrapper from "./ComputerWrapper.vue";
import { useComputerStore } from "../stores/computerStore";
import { BngIcon, icons } from "@/common/components/base"
import { lua } from '@/bridge'

const computerStore = useComputerStore();
const showEventTimes = ref(false)

onMounted(async () => {

});

const close = () => {
    lua.career_career.closeAllMenus
}

const toggleEventTimes = () => {
    showEventTimes.value = !showEventTimes.value
}

</script>

<style scoped lang="scss">
.marketplace-container {
    width: max-content;
    height: 100%;
    background-color: #282828;
    border-radius: 15px;
    padding: 20px;
    color: white;
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

.vehicle-card {
    background-color: #293037;
    border-radius: 15px;
    overflow: hidden;
    display: flex;
    border: none;
}

.vehicle-image {
    margin: 10px;
    width: 300px;
    height: 174px;
    border-radius: 15px;
    background-color: #ffffff;
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
    gap: 12px;
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
    background-color: #3D3D3D;
    padding: 10px;
    width: 230px;
    border-bottom-left-radius: 10px;
    border-bottom-right-radius: 10px;
    margin-top: -6px;
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
</style>
