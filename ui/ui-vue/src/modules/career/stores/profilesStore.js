import { computed, ref } from "vue"
import { defineStore } from "pinia"
import { lua } from "@/bridge"
import { $translate } from "@/services"

export const useProfilesStore = defineStore("profiles", () => {
  async function loadProfile(profileName, tutorialEnabled, isAdd = false, hardcoreMode = false) {
    console.log("loadProfile", profileName, tutorialEnabled, isAdd, hardcoreMode)
    if (!profileName) return false

    const isGarageActive = await lua.extensions.gameplay_garageMode.isActive()
    if (isGarageActive) await lua.extensions.gameplay_garageMode.stop()

    window.bngVue.gotoGameState("fadeScreen", { params: { fadeIn: 0.5, fadeOut: 2, pause: 5 } })

    const fadeTimeout = setTimeout(async () => {
      await lua.career_career.enableTutorial(tutorialEnabled)
      await lua.career_career.enableHardcoreMode(hardcoreMode)
      await lua.career_career.createOrLoadCareerAndStart(profileName)

      const toastrMessage = isAdd ? "added" : "loaded"

      window.globalAngularRootScope.$broadcast("toastrMsg", {
        type: "info",
        msg: $translate.contextTranslate(`ui.career.notification.${toastrMessage}`),
        config: {
          positionClass: "toast-top-right",
          toastClass: "beamng-message-toast",
          timeOut: 5000,
          extendedTimeOut: 1000,
        },
      })
      clearTimeout(fadeTimeout)
    }, 1000)
  }

  return { loadProfile }
})
