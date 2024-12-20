import { computed, ref } from "vue"
import { defineStore } from "pinia"
import { lua } from "@/bridge"

export const useVehicleShoppingStore = defineStore("vehicleShopping", () => {
  // States
  const vehicleShoppingData = ref({})
  const filteredVehicles = computed(() => {
    const d = vehicleShoppingData.value
    if (!d.vehiclesInShop) return []

    let filteredList = Object.keys(d.vehiclesInShop).reduce(function (result, key) {
      if (d.currentSeller) {
        if (d.vehiclesInShop[key].sellerId === d.currentSeller) result.push(d.vehiclesInShop[key])
      } else {
        result.push(d.vehiclesInShop[key])
      }

      return result
    }, [])

    if (filteredList.length) filteredList.sort((a, b) => a.Value - b.Value)

    return filteredList
  })

  // Add a new computed property to group vehicles by dealer
  const vehiclesByDealer = computed(() => {
    const d = vehicleShoppingData.value
    if (!d.vehiclesInShop) return []

    // Group vehicles by sellerId
    const grouped = Object.values(d.vehiclesInShop).reduce((acc, vehicle) => {
      if (!acc[vehicle.sellerId]) {
        acc[vehicle.sellerId] = {
          id: vehicle.sellerId,
          name: vehicle.sellerName || 'Unknown Dealer',
          vehicles: [],
          expanded: false
        }
      }
      acc[vehicle.sellerId].vehicles.push(vehicle)
      return acc
    }, {})

    // Sort vehicles by price within each dealer
    Object.values(grouped).forEach(dealer => {
      dealer.vehicles.sort((a, b) => a.Value - b.Value)
    })

    return Object.values(grouped)
  })

  // Actions
  const requestVehicleShoppingData = async () => {
    vehicleShoppingData.value = await lua.career_modules_vehicleShopping.getShoppingData()
  }

  return {
    vehicleShoppingData,
    filteredVehicles,
    vehiclesByDealer,
    requestVehicleShoppingData,
  }
})
