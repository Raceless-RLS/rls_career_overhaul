<template>
  <LayoutSingle class="purchase-layout">
    <div class="confirmation-overlay" >
        <BngCard class="confirmation-card">
          <BngCardHeading>Purchase {{ garageName }} </BngCardHeading>

          <div class="modal-content">
            <p>Purchase this garage for ${{ price }}?</p>
            <p>This will grant you an additional {{ garageCapacity }} vehicle slots</p>
          </div>

          <div class="confirm-button-container">
            <BngButton
              ref="purchaseButton"
              @click="confirmPurchase"
              :accent="ACCENTS.primary"
              :disabled=cantPay
            >
              Purchase
            </BngButton>
            <BngButton
              @click="cancelPurchase"
              :accent="ACCENTS.secondary"
            >
              Cancel
            </BngButton>
          </div>
        </BngCard>
      </div>
  </LayoutSingle>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { lua } from '@/bridge'
import {
  BngButton,
  ACCENTS,
  BngCard,
  BngCardHeading
} from '@/common/components/base'
import { LayoutSingle } from '@/common/layouts'

const purchaseButton = ref(null)
const price = ref(0)
const garageName = ref('')
const garageCapacity = ref(0)
const cantPay = ref(true)

onMounted(async () => {
  const garageData = await lua.career_modules_garageManager.requestGarageData()
  if (garageData) {
    price.value = garageData.price
    garageName.value = garageData.name
    garageCapacity.value = garageData.capacity
    cantPay.value = !(await lua.career_modules_garageManager.canPay())
  }
})

function confirmPurchase() {
  lua.career_modules_garageManager.buyGarage()
  lua.career_career.closeAllMenus()

}

function cancelPurchase() {
  lua.career_modules_garageManager.cancelGaragePurchase()
  lua.career_career.closeAllMenus()
}

</script>

<style scoped lang="scss">
.purchase-layout {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: white;
}

.confirmation-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  z-index: 100;
}

.confirmation-card {
  :deep(.card-cnt) {
    background: rgba(0, 0, 0, 0.8);
    border-radius: 0.75em;
    padding: 1em;
    box-shadow: 0 0 20px rgba(0, 0, 0, 0.4);
    border: 1px solid rgba(255, 255, 255, 0.15);
  }
}

.modal-content {
  text-align: center;
  margin: 0.25em 0;
  p {
    margin: 0.25em 0;
  }
}

.confirm-button-container {
  display: flex;
  justify-content: center;
  gap: 1em;
  margin-top: 0.25em;
}
</style> 