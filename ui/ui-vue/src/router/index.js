import { createRouter, createWebHashHistory } from "vue-router"
import { reportState } from "@/services/stateReporter.js"
import { useUIApps } from "@/services/uiApps.js"
import { useInfoBar } from "@/services/infoBar.js"

import CareerRoutes from "@/modules/career/routes"
import CreditsRoutes from "@/modules/credits/routes"
import DebugRoutes from "@/modules/debug/routes"
import GarageRoutes from "@/modules/garage/routes"
import LiveryEditorRoutes from "@/modules/liveryEditor/routes"
import MissionRoutes from "@/modules/missions/routes"
import RefuelRoutes from "@/modules/refuel/routes"
import RadialRoutes from "@/modules/radial/routes"
import VehicleConfigRoutes from "@/modules/vehicleConfig/routes"
import MainMenuRoutes from "@/modules/mainmenu/routes"

import NotFoundView from "@/views/NotFound.vue"

const isDevMode = process.env.NODE_ENV === "development"

const routes = [
  ...CareerRoutes,
  ...CreditsRoutes,
  ...GarageRoutes,
  ...LiveryEditorRoutes,
  ...MissionRoutes,
  ...RefuelRoutes,
  ...RadialRoutes,
  ...VehicleConfigRoutes,
  ...MainMenuRoutes,
  ...(isDevMode ? DebugRoutes : []),

  {
    path: "/:catchAll(.*)*",
    name: "unknown",
    component: NotFoundView,
  },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

router.bngUpdateMeta = to => {
  if (!to.meta) return
  if (to.meta.uiApps) handelUIAppsSettings(to.meta.uiApps)
  handleInfoBarSettings(to.meta.infoBar || {})
}

router.afterEach((to, from) => {
  // console.log(`Router from:${from.path} to:${to.path}`)
  // console.log(to.matched[0].name)

  // report state to Lua
  reportState(to.path, true, from.path)

  // deal with any 'meta' settings
  router.bngUpdateMeta(to)
})


const handelUIAppsSettings = settings => {
  const appsAPI = useUIApps()
  if (settings.layout) appsAPI.setLayout(settings.layout)
  // Only set the visibility if the property is specified (this is different to how angular behaves, but to keep all Vue states behaving as before - not touching UIApps - we need this)
  // TODO - We can switch to having `false` be default in the future
  if (settings.hasOwnProperty('shown')) appsAPI.setVisible(settings.shown)
}

const handleInfoBarSettings = settings => {
  const infoBar = useInfoBar()
  infoBar.visible = settings.visible
  infoBar.showSysInfo = settings.showSysInfo
  infoBar.withAngular = settings.withAngular
  if (settings.hints)  {
    infoBar.clearHints()
    infoBar.addHints(settings.hints)
  }
}

export default router
