// Career routes --------------------------------------

import ProgressLanding from "./views/ProgressLanding.vue"
import BranchPage from "./views/BranchPage.vue"
import CargoDeliveryReward from "./views/CargoDeliveryReward.vue"
import CargoOverview from "./views/CargoOverviewMain.vue"
import CargoDropOff from "./views/CargoDropOff.vue"
import Computer from "./views/ComputerMain.vue"
import InspectVehicle from "./views/InspectVehicleMain.vue"
import InsurancePolicies from "./views/InsurancePoliciesMain.vue"
import Logbook from "./views/Logbook.vue"
import Milestones from "./views/Milestones.vue"
import MyCargo from "./views/MyCargo.vue"
import Painting from "./views/PaintingMain.vue"
import PartInventory from "./views/PartInventoryMain.vue"
import PartShopping from "./views/PartShoppingMain.vue"
import Pause from "./views/Pause.vue"
import PauseBigMiddlePanel from "./views/PauseBigMiddlePanel.vue"
import Profiles from "./views/Profiles.vue"
import Repair from "./views/RepairMain.vue"
import Tuning from "./views/TuningMain.vue"
import VehicleInventory from "./views/VehicleInventoryMain.vue"
import VehiclePurchase from "./views/VehiclePurchaseMain.vue"
import VehicleShopping from "./views/VehicleShoppingMain.vue"
import VehiclePerformance from "./views/VehiclePerformanceMain.vue"
import Sleep from "./views/SleepMenu.vue"
import RoleAssignment from "./views/RoleAssignment.vue"
import CarMeets from "./views/CarMeetsMenu.vue"
import PurchaseGarage from "./views/PurchaseGarage.vue"
import PhoneMain from "./views/PhoneMain.vue"
import PhoneMinimap from "./views/PhoneMinimap.vue"
import PhoneMarketplace from "./views/PhoneMarketplace.vue"
import Marketplace from "./views/Marketplace.vue"
import PhoneTaxi from "./views/PhoneTaxi.vue"
import CarMeetsPhone from "./views/CarMeetsPhone.vue"


export default [
  // Career Pause
  {
    path: "/menu.careerPause",
    name: "menu.careerPause",
    component: Pause,
    props: true,
    meta: {
      clickThrough: true,
      infoBar: {
        withAngular: true,
        visible: true,
        showSysInfo: true,
      },
      uiApps: {
        shown: false,
      },
    },
  },
  {
    path: "/career",
    children: [
      // Career Pause
      {
        path: "pauseBigMiddlePanel",
        name: "pauseBigMiddlePanel",
        component: PauseBigMiddlePanel,
        props: true,
      },

      // Logbook
      {
        path: "logbook/:id(\\*?.*?)?",
        name: "logbook",
        component: Logbook,
        props: true,
      },

      {
        path: "milestones/:id(\\*?.*?)?",
        name: "milestones",
        component: Milestones,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },

      // Computer
      {
        path: "computer",
        name: "computer",
        component: Computer,
        props: true,
        meta: {
          uiApps: {
            shown: false,
            //layout: "tasklist",
          },
        },
      },

      // Vehicle Inventory
      {
        path: "vehicleInventory",
        name: "vehicleInventory",
        component: VehicleInventory,
      },

      // Vehicle Certification
      {
        path: "vehiclePerformance/:inventoryId?/:computerId?/:backUIState?/:testInProgress?",
        name: "vehiclePerformance",
        component: VehiclePerformance,
        props: true,
      },

      // Tuning
      {
        path: "tuning",
        name: "tuning",
        component: Tuning,
      },

      // Painting
      {
        path: "painting",
        name: "painting",
        component: Painting,
      },

      // Repair
      {
        path: "repair/:header?",
        name: "repair",
        component: Repair,
        props: true,
      },

      // Part Shopping
      {
        path: "partShopping",
        name: "partShopping",
        component: PartShopping,
        meta: {
          uiApps: {
            shown: false,
            //layout: "tasklist",
          },
        },
      },

      // Part Inventory
      {
        path: "partInventory",
        name: "partInventory",
        component: PartInventory,
      },

      // Vehicle Purchase
      {
        path: "vehiclePurchase/:vehicleInfo?/:playerMoney?/:inventoryHasFreeSlot?/:lastVehicleInfo?",
        name: "vehiclePurchase",
        component: VehiclePurchase,
        props: true,
      },

      // Vehicle Shopping
      {
        path: "vehicleShopping",
        name: "vehicleShopping",
        component: VehicleShopping,
        meta: {
          uiApps: {
            shown: false,
            //layout: "tasklist",
          },
        },
      },

      // Insurance policies List
      {
        path: "insurancePolicies",
        name: "insurancePolicies",
        component: InsurancePolicies,
      },

      // Inspect Vehicle
      {
        path: "inspectVehicle",
        name: "inspectVehicle",
        component: InspectVehicle,
      },

      // Delivery Reward
      {
        path: "cargoDeliveryReward",
        name: "cargoDeliveryReward",
        component: CargoDeliveryReward,
        props: true,
      },

      // delivery dropoff
      {
        path: "cargoDropOff/:facilityId?/:parkingSpotPath(\\*?.*?)?",
        name: "cargoDropOff",
        component: CargoDropOff,
        props: true,
      },

      // Cargo Overview
      {
        path: "cargoOverview/:facilityId?/:parkingSpotPath(\\*?.*?)?",
        name: "cargoOverview",
        component: CargoOverview,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },
      {
        path: "myCargo",
        name: "myCargo",
        component: MyCargo,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },

      // Branch Landing Page
      {
        path: "progressLanding/:pathId?/:comesFromBigMap?",
        name: "progressLanding",
        component: ProgressLanding,
        props: route => ({
          pathId: route.params.pathId,
          comesFromBigMap: route.params.comesFromBigMap === "true" || route.params.comesFromBigMap === true
        }),
        meta: {
          uiApps: {
            shown: false,
          },
          infoBar: {
            visible: true,
          },
        },
      },

      // Domain Landing Page
      {
        path: "domainSelection",
        name: "domainSelection",
        component: ProgressLanding,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
          infoBar: {
            visible: true,
          },
        },
      },

      //Branch Landing Page
      {
        path: "branchPage/:branchKey?/:skillKey?/",
        name: "branchPage",
        component: BranchPage,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
          infoBar: {
            visible: true,
          },
        },
      },

      // Profiles
      {
        path: "profiles",
        name: "profiles",
        component: Profiles,
        meta: {
          uiApps: {
            shown: false,
          },
          infoBar: {
            visible: true,
            showSysInfo: true,
          },
        }
      },

      // Sleep Menu
      {
        path: "sleep-menu",
        name: "sleep-menu",
        component: Sleep
      },

      // Police Assignment
      {
        path: "roleAssignment",
        name: "roleAssignment",
        component: RoleAssignment
      },

      {
        path: "carMeets",
        name: "carMeets",
        component: CarMeets
      },

      {
        path: "purchase-garage",
        name: "purchase-garage",
        component: PurchaseGarage
      },

      {
        path: "phone-minimap",
        name: "phone-minimap",
        component: PhoneMinimap
      },

      {
        path: "phone-main",
        name: "phone-main",
        component: PhoneMain
      },

      {
        path: "car-meets-phone",
        name: "car-meets-phone",
        component: CarMeetsPhone
      },

      {
        path: "phone-taxi",
        name: "phone-taxi",
        component: PhoneTaxi
      },

      {
        path: "marketplace",
        name: "marketplace",
        component: Marketplace
      },

      { 
        path: "phone-marketplace",
        name: "phone-marketplace",
        component: PhoneMarketplace
      }

    ],
  },
]
