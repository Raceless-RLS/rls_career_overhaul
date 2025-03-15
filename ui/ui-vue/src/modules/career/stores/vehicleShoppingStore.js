import { computed, ref } from "vue"
import { defineStore } from "pinia"
import { lua } from "@/bridge"

export const useVehicleShoppingStore = defineStore("vehicleShopping", () => {
  // States
  const vehicleShoppingData = ref({})
  const searchQuery = ref('')
  
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

    // Apply search filtering if searchQuery exists
    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase().trim()
      filteredList = filteredList.filter(vehicle => {
        const searchFields = [
          vehicle.Name,
          vehicle.Brand,
          vehicle.niceName,
          vehicle.model_key,
          vehicle.config_name,
        ]
        
        // Check each field that might contain what user is searching for
        return searchFields.some(field => {
          return field && field.toString().toLowerCase().includes(query)
        })
      })
    }

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
      
      // Apply search filtering if searchQuery exists
      if (searchQuery.value) {
        const query = searchQuery.value.toLowerCase().trim()
        dealer.vehicles = dealer.vehicles.filter(vehicle => {
          const searchFields = [
            vehicle.Name,
            vehicle.Brand,
            vehicle.niceName,
            vehicle.model_key,
            vehicle.config_name,
          ]
          
          // Check each field that might contain what user is searching for
          return searchFields.some(field => {
            return field && field.toString().toLowerCase().includes(query)
          })
        })
      }
    })

    // Only return dealers with vehicles (after filtering)
    return Object.values(grouped).filter(dealer => dealer.vehicles.length > 0)
  })

  // Actions
  const requestVehicleShoppingData = async () => {
    vehicleShoppingData.value = await lua.career_modules_vehicleShopping.getShoppingData()
  }
  
  // Add a method to set the search query
  const setSearchQuery = (query) => {
    searchQuery.value = query
  }

  return {
    vehicleShoppingData,
    filteredVehicles,
    vehiclesByDealer,
    requestVehicleShoppingData,
    searchQuery,
    setSearchQuery,
  }
})
