// Career routes --------------------------------------

import { CROSSFIRE_HINTS_ALL, CROSSFIRE_HINTS } from "@/services/infoBar.js"

import * as views from "./views"

export default [
  {
    path: "/career",
    children: [
      // Career Pause
      {
        path: "pause",
        name: "pause",
        component: views.Pause,
        props: true,
      },

      // Logbook
      {
        path: "logbook/:id(\\*?.*?)?",
        name: "logbook",
        component: views.Logbook,
        props: true,
      },

      {
        path: "milestones/:id(\\*?.*?)?",
        name: "milestones",
        component: views.Milestones,
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
        component: views.Computer,
        props: true,
        meta: {
          uiApps: {
            shown: true,
            layout: "tasklist",
          },
        },
      },

      // Vehicle Inventory
      {
        path: "vehicleInventory",
        name: "vehicleInventory",
        component: views.VehicleInventory,
      },

      // Tuning
      {
        path: "tuning",
        name: "tuning",
        component: views.Tuning,
      },

      // Painting
      {
        path: "painting",
        name: "painting",
        component: views.Painting,
      },

      // Repair
      {
        path: "repair/:header?",
        name: "repair",
        component: views.Repair,
        props: true,
      },

      // Organizations
      {
        path: "organizations/:orgId?",
        name: "organizations",
        component: views.Organizations,
        props: true,
      },

      // Part Shopping
      {
        path: "partShopping",
        name: "partShopping",
        component: views.PartShopping,
        meta: {
          uiApps: {
            shown: true,
            layout: "tasklist",
          },
        },
      },

      // Part Inventory
      {
        path: "partInventory",
        name: "partInventory",
        component: views.PartInventory,
      },

      // Vehicle Purchase
      {
        path: "vehiclePurchase/:vehicleInfo?/:playerMoney?/:inventoryHasFreeSlot?/:lastVehicleInfo?",
        name: "vehiclePurchase",
        component: views.VehiclePurchase,
        props: true,
      },

      // Vehicle Shopping
      {
        path: "vehicleShopping",
        name: "vehicleShopping",
        component: views.VehicleShopping,
        meta: {
          uiApps: {
            shown: true,
            layout: "tasklist",
          },
        },
      },

      // Insurance policies List
      {
        path: "insurancePolicies",
        name: "insurancePolicies",
        component: views.InsurancePolicies,
      },

      // Inspect Vehicle
      {
        path: "inspectVehicle",
        name: "inspectVehicle",
        component: views.InspectVehicle,
      },

      // Delivery Reward
      {
        path: "cargoDeliveryReward",
        name: "cargoDeliveryReward",
        component: views.CargoDeliveryReward,
        props: true,
      },

      // delivery dropoff
      {
        path: "cargoDropOff/:facilityId?/:parkingSpotPath(\\*?.*?)?",
        name: "cargoDropOff",
        component: views.CargoDropOff,
        props: true,
      },

      // Cargo Overview
      {
        path: "cargoOverview/:facilityId?/:parkingSpotPath(\\*?.*?)?",
        name: "cargoOverview",
        component: views.CargoOverview,
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
        component: views.MyCargo,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },

      //Branch Landing Page
      {
        path: "progressLanding/",
        name: "progressLanding",
        component: views.ProgressLanding,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },

      //Branch Landing Page
      {
        path: "branchPage/:branchKey?/:skillKey?/",
        name: "branchPage",
        component: views.BranchPage,
        props: true,
        meta: {
          uiApps: {
            shown: false,
          },
        },
      },

      // Profiles
      {
        path: "profiles",
        name: "profiles",
        component: views.Profiles,
        meta: {
          uiApps: {
            shown: false,
          },
          infoBar: {
            visible: true,
            showSysInfo: true,
            hints: CROSSFIRE_HINTS_ALL,
          },
        }
      },

      // Sleep Menu
      {
        path: "sleep-menu",
        name: "sleep-menu",
        component: views.Sleep
      },

      // Police Assignment
      {
        path: "roleAssignment",
        name: "roleAssignment",
        component: views.RoleAssignment
      },

      {
        path: "carMeets",
        name: "carMeets",
        component: views.CarMeets
      },

      {
        path: "purchase-garage",
        name: "purchase-garage",
        component: views.PurchaseGarage
      },

      {
        path: "phone-minimap",
        name: "phone-minimap",
        component: views.PhoneMinimap
      },

      {
        path: "phone-main",
        name: "phone-main",
        component: views.PhoneMain
      },

      {
        path: "car-meets-phone",
        name: "car-meets-phone",
        component: views.CarMeetsPhone
      },

      {
        path: "phone-taxi",
        name: "phone-taxi",
        component: views.PhoneTaxi
      },

      {
        path: "marketplace",
        name: "marketplace",
        component: views.Marketplace
      },

      { 
        path: "phone-marketplace",
        name: "phone-marketplace",
        component: views.PhoneMarketplace
      }

    ],
  },
]
