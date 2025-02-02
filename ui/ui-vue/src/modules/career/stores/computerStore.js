import { computed, ref } from "vue"
import { defineStore } from "pinia"
import { lua } from "@/bridge"

export const useComputerStore = defineStore("computer", () => {
  // States
  const computerData = ref({})
  const activeVehicleIndex = ref(0)

  const activeInventoryId = computed(() => {
    if (computerData.value.vehicles && computerData.value.vehicles[activeVehicleIndex.value]) {
      return computerData.value.vehicles[activeVehicleIndex.value].inventoryId
    }
    return "0"
  })

  const generalComputerFunctions = computed(() => {
    if (!computerData.value.computerFunctions) return []
    let result = []
    result = Object.values(computerData.value.computerFunctions.general)
    result.sort((a, b) => {
      if (a.order != undefined && b.order != undefined) return (a.order < b.order ? -1 : 1)
      return (a.label < b.label ? -1 : 1)
    })
    return result
  })

  const vehicleSpecificComputerFunctions = computed(() => {
    if (!computerData.value.computerFunctions) return {}
    let result = {}
    for (const [inventoryId, computerFunctions] of Object.entries(computerData.value.computerFunctions.vehicleSpecific)) {
      let sortedFunctions = Object.values(computerFunctions)
      sortedFunctions.sort((a, b) => {
        if (a.order != undefined && b.order != undefined) return (a.order < b.order ? -1 : 1)
        return (a.label < b.label ? -1 : 1)
      })
      result[inventoryId] = sortedFunctions
    }
    return result
  })

  const activityComputerFunctions = computed(() => {
    return [
      {
        id: 'carMeets',
        label: 'Car Meets',
        disabled: false,
        order: 1,
        callback: () => {
          lua.career_modules_carmeets.openMenu()
        }
      }
      // Future activities will be added here
    ]
  })

  const setComputerData = data => {
    computerData.value = data
    if ((computerData.value.vehicles && computerData.value.vehicles.length <= activeVehicleIndex.value) || computerData.value.resetActiveVehicleIndex) {
      activeVehicleIndex.value = 0
    }
  }

  // Actions
  const requestComputerData = () => {
    lua.career_modules_computer.getComputerUIData().then(setComputerData)
  }

  const computerButtonCallback = async (computerFunctionId, inventoryId) => {
    // First check if it's an activity function
    const activityFunction = activityComputerFunctions.value.find(f => f.id === computerFunctionId)
    if (activityFunction) {
      await activityFunction.callback()
      return
    }

    // If not an activity, use the regular computer callback
    await lua.career_modules_computer.computerButtonCallback(computerFunctionId, inventoryId ? Number(inventoryId) : undefined)
  }

  const onMenuClosed = () => {
    lua.career_modules_computer.onMenuClosed()
  }

  const switchActiveVehicle = offset => {
    activeVehicleIndex.value = (activeVehicleIndex.value + offset + computerData.value.vehicles.length) % computerData.value.vehicles.length
  }

  return {
    activeVehicleIndex,
    activeInventoryId,
    computerData,
    generalComputerFunctions,
    vehicleSpecificComputerFunctions,
    activityComputerFunctions,
    requestComputerData,
    computerButtonCallback,
    switchActiveVehicle,
    onMenuClosed,
  }
})
