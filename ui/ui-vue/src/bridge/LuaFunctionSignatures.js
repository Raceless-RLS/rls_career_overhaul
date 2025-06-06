import { Any, Integer, run, runRaw } from "./libs/Lua.js"
import { getMockedData } from "../../devutils/mock.js"
import { sendGUIHook } from "../../devutils/browser.js"

const withMocked = (sig, getData) => ((sig.mocked = getData), sig)

// Define Lua function signatures, and normal functions here
//
// Signatures are transformed to proper 'run' calls at runtime, other functions are left untouched -
// this allows for the addition of more complex functions should they be needed
//
// If an arrow function is used, it is expected to return a signature:
//    undefined/falsey - all parameter types will be as passed in arguments
//    String/Number/etc. - all params will be converted to correct type
//    [String, Number, ...] - params will convert according that specified for each one
//
// If a normal function is used, it will not be transformed.
//
// The run & runRaw functions both return Promises, so that you may utilise any return value from the Lua call,
// this is much the same to passing a callback to engineLua in the Angular code
//
// If you want an alternative function to be used if the bngAPI is unavailable, you can build such using 'withMocked'.
// Simply pass your normal function/signature as the first parameter, and the mock function as the second one. The
// mock function will always be treated as a mock function - regardless of whether it is an arrow function. It should
// accept the same paramaeters as the non-mock version. If a mock function does not return a promise, its return value
// will automatically be wrapped in one
//

export default {
  // -- Dev -----------------------------------------------------------------------
  dev: {
    getMockedData: key => String,
  },

  // -- Real ----------------------------------------------------------------------

  // TODO - incomplete, add as neeeded

  getVehicleColor: () => {},
  getVehicleColorPalette: index => Integer,
  resetGamePlay: playerID => Integer,
  quit: () => {},
  checkFSErrors: () => {},

  guihooks: {
    // can take multiple params - just add them individually after the hook name
    trigger: withMocked(hookName => String, sendGUIHook),
  },

  simTimeAuthority: {
    togglePause: () => {},
    getPause: () => {},
  },

  commands: {
    toggleCamera: () => {},
  },

  ui_audio: {
    playEventSound: (soundClass, type) => [String, String],
  },

  career_career: {
    closeAllMenus: () => {},
    isActive: () => {},
    requestPause: state => Boolean,
    sendAllCareerSaveSlotsData: () => {},
    sendCurrentSaveSlotData: () => {},
    enableTutorial: enable => Boolean,
    enableHardcoreMode: enable => Boolean,
    createOrLoadCareerAndStart: id => String,
  },

  career_saveSystem: {
    saveCurrent: () => {},
    removeSaveSlot: id => String,
    renameSaveSlot: (name, newName) => [String, String],
  },

  career_modules_uiUtils: {
    getCareerStatusData: withMocked(
      () => {},
      () => getMockedData("career.status")
    ),
    getCareerSimpleStats: withMocked(
      () => {},
      () => getMockedData("career.simpleStats")
    ),
    getCareerPauseContextButtons: () => {},
    callCareerPauseContextButtons: id => Number,
    getCareerCurrentLevelName: () => {},
  },

  career_modules_fuel: {
    requestRefuelingTransactionData: () => {},
    sendUpdateDataToUI: () => {},
    uiButtonStartFueling: energyType => String,
    uiButtonStopFueling: energyType => String,
    onChangeFlowRate: flowRate => Number,
    payPrice: () => {},
    uiCancelTransaction: () => {},
  },

  career_modules_logbook: {
    getLogbook: withMocked(
      () => {},
      () => getMockedData("logbook.sample")
    ),
    setLogbookEntryRead: (id, state) => [String, Boolean],
  },

  career_modules_milestones_milestones: {
    getMilestones: () => {},
    claim: id => {},
    unclaimedMilestonesCount: () => {},
  },

  career_modules_branches_landing: {
    openBigMapWithMissionSelected: id => String,
    getBranchSkillCardData: id => String,
    getBranchPageData: id => String,
    getLandingPageData: domain => String,
    getCargoProgressForUI: () => {},
  },

  career_modules_partShopping: {
    cancelShopping: () => {},
    applyShopping: () => {},
    installPartByPartShopId: id => Number,
    removePartBySlot: slot => String,
    sendShoppingDataToUI: () => {},
    keepUsedPartBySlot: slot => String
  },

  career_modules_vehicleShopping: {
    showVehicle: id => Number,
    navigateToPos: pos => Object,
    openShop: (seller, computerId) => [Any, Any], // i think this needs to be Any instead of String to also allow nil
    cancelShopping: () => {},
    quickTravelToVehicle: id => Number,
    openPurchaseMenu: (purchaseType, shopId) => [String, Number],
    openInventoryMenuForTradeIn: () => {},
    buyFromPurchaseMenu: (purchaseType, options) => [String, Any],
    cancelPurchase: purchaseType => String,
    getShoppingData: () => {},
    sendPurchaseDataToUi: () => {},
    removeTradeInVehicle: () => {},
    onShoppingMenuClosed: () => {},
  },

  career_modules_testDrive: {
    stop: () => {},
  },

  career_modules_inspectVehicle: {
    startTestDrive: () => {},
    sendUIData: () => {},
    onInspectScreenChanged: enabled => Boolean,
    repairVehicle: () => {},
    stopInspection: () => {},
  },

  career_modules_loanerVehicles: {
    markForSpawning: loanInfo => {},
    spawnAndLoanVehicle: (vehicleInfo, loanInfo) => [Object, Object],
    getLoanedVehiclesByOrg: orgId => String,
    returnVehicle: inventoryId => Number,
  },

  career_modules_inventory: {
    sellVehicle: id => Number,
    sellVehicleFromInventory: id => Number,
    instantSellVehicle: id => Number,
    returnLoanedVehicleFromInventory: id => Number,
    expediteRepairFromInventory: (inventoryId, price) => [Number, Number],
    enterVehicle: id => Number,
    openMenuFromComputer: computerId => String,
    closeMenu: () => {},
    chooseVehicleFromMenu: (vehId, buttonId, repairPrevVeh) => [Number, Number, Boolean],
    setFavoriteVehicle: id => Number,
    sendDataToUi: () => {},
    removeVehicleObject: id => Number,
    getVehicle: id => Number,
    getVehicles: () => {},
    getVehicleUiData: id => Number,
    isEmpty: () => {},
    setLicensePlateText: (inventoryId, text) => [Number, String],
    purchaseLicensePlateText: (inventoryId, text, money) => [Number, String, Number],
    listVehicleForSale: id => Number,
    getVehiclesForSale: () => {},
    removeVehicleFromSale: id => Number,
    requestListedVehicles: () => {},
    deliverVehicle: (id, money) => [Number, Number],
    storeVehicle: id => Number,
  },

  career_modules_vehiclePerformance: {
    startDragTest: id => Number,
    startDragTestFromOutsideMenu: (id, computerId) => [Number, String],
    cancelTest: () => {},
  },

  career_modules_partInventory: {
    openMenu: computerId => Any,
    closeMenu: () => {},
    sendUIData: () => {},
    movePart: (location, partId) => [Number, Number],
    sellParts: ids => Array,
    partInventoryClosed: () => {},
  },

  career_modules_insurance: {
    getProposablePoliciesForVehInv: invVehId => Number,
    changeVehPolicy: (invVehId, policyId) => [Number, Number],
    payBonusReset: policyId => Number,
    purchasePolicy: id => Number,
    calculatePremiumDetails: (policyId, tempPerks) => [Number, Any],
    changePolicyPerks: (policyId, changedPerks) => [Number, Object],
    startRepairInGarage: (vehicleInfo, repairOptionData) => [Object, Object],
    openRepairMenu: (vehicleInfo, originComputerId) => [Object, Any],
    getRepairData: () => {},
    closeMenu: () => {},
    sendUIData: () => {},
    inventoryVehNeedsRepair: inventoryId => Number,
  },

  career_modules_tuning: {
    apply: tuningValues => Object,
    start: (vehId, origin) => [Any, Any],
    getTuningData: () => {},
    close: () => {},
    applyShopping: () => {},
    cancelShopping: () => {},
    removeVarFromShoppingCart: varName => String,
  },

  career_modules_painting: {
    apply: () => {},
    start: (vehId, origin) => [Any, Any],
    getPaintData: () => {},
    close: () => {},
    setPaints: paint => Object,
    getFactoryPaint: () => {},
    onUIOpened: () => {},
  },

  career_modules_questManager: {
    setQuestAsNotNew: id => String,
    claimRewardsById: id => String,
  },

  career_modules_computer: {
    onMenuClosed: () => {},
    getComputerUIData: () => {},
    computerButtonCallback: (buttonId, inventoryId) => [String, Any],
    openComputerMenuById: computerId => String,
  },

  career_modules_delivery_general: {
    setAutomaticRoute: enabled => Boolean,
    setDetailedDropOff: enabled => Boolean,
    setSetting: (key, value) => {},
    getSettings: () => {},
    setDeliveryTimePaused: paused => {},
  },

  career_modules_delivery_cargoScreen: {
    requestCargoDataForUi: (facilityId, parkingSpotPath, updateMaxTimeStamp) => [Any, Any, Any],
    moveCargoFromUi: (cargoId, targetLocation) => [Number, Object],
    commitDeliveryConfiguration: () => {},
    cancelDeliveryConfiguration: () => {},
    exitDeliveryMode: () => {},
    exitCargoOverviewScreen: () => {},
    showCargoRoutePreview: cargoId => Any,
    showVehicleOfferRoutePreview: offerId => Any,
    setCargoRoute: (cargoId, origin) => [Number, Boolean],
    showLocationRoutePreview: (location, asProvider) => {},
    showCargoContainerHelpPopup: () => {},
    setBestRoute: () => {},
    spawnOffer: (offerId, fadeToBlack) => [Number, Any],
    abandonAcceptedOffer: vehId => Number,
    setCargoScreenTab: tab => String,
    unloadCargoPopupClosed: () => {},
    moveMaterialFromUi: () => {},
    requestDropOffData: () => {},
    confirmDropOffData: (data, facId, psPath) => {},
    dropOffPopupClosed: mode => {},
    clearTransientMoveForCargo: cargoId => {},
    clearTransientMovesForStorage: materialType => {},
    applyTransientMoves: () => {},
    toggleOfferForSpawning: id => {},
    tryLoadAll: cargoIds => {},
    showRoutePreview: route => {},
    deliveryScreenExternalButtonPressed: id => Any,
  },

  career_modules_delivery_progress: {
    activateSound: (soundLabel, active) => {},
  },

  career_modules_linearTutorial: {
    introPopup: (key, force) => {},
    wasIntroPopupsSeen: pages => {},
    isLinearTutorialActive: () => {},
  },

  gameplay_drag_general: {
    screenshotTimeslip: () => {},
    getHistory: saveFile => [Object],
  },

  gameplay_drift_general : {
    onMainUIAppMounted: () => {},
    onMainUIAppUnmounted: () => {},
  },

  freeroam_organizations: {
    getUIData: () => {},
    getUIDataForOrg: orgId => String,
  },

  core_replay: {
    onInit: () => {},
    loadFile: filename => String,
    stop: () => {},
    openReplayFolderInExplorer: () => {},
    getRecordings: () => {},
    removeRecording: filename => String,
    togglePlay: () => {},
    toggleRecording: () => {},
    cancelRecording: () => {},
    toggleSpeed: speed => Number,
    pause: () => {},
    seek: positionPercent => Number,
    acceptRename: (oldFilename, newFilename) => [String, String],
  },

  core_gamestate: {
    requestGameState: () => {},
  },

  core_gameContext: {
    getGameContext: withMocked(
      params => {},
      params => getMockedData("gameContext.gameContextData")
    ),
  },

  core_online: {
    requestState: () => {},
  },

  core_hardwareinfo: {
    requestState: () => {},
    getInfo: () => {},
  },

  gameplay_statistic: {
    sendGUIState: () => {},
  },

  core_quickAccess: {
    getUiData: () => {},
    selectItem: (id, buttonDown, actionIndex) => [Number, Boolean, Number],
    contextAction: (id, buttonDown, actionIndex) => [Number, Boolean, Number],
    back: () => {},
    setEnabled: (enabled, level, force) => [Boolean, String, Boolean],
    openFavoriteSelection: index => Number,
    getFavoriteSelectionUIData: () => {},
    addActionToQuickAccess: (level, title, index) => [String, String, Number],
    removeActionFromQuickAccess: index => Number,
  },

  freeroam_bigMapMode: {
    enterBigMap: () => {},
    setBigmapScreenBounds: (windowBounds, mapBounds) => {},
  },

  freeroam_freeroam: {
    startTrackBuilder: mapName => String,
  },

  extensions: {
    load: extensionName => String,
    unload: extensionName => String,
    hook: hook => String,

    tech_license: {
      requestState: () => {},
      isValid: () => {},
    },

    core_input_actionFilter: {
      addAction: (filter, actionName, filtered) => [Number, String, Boolean],
      setGroup: (name, actioNames) => [String, Any],
    },

    core_input_bindings: {
      FFBSafetyDataRequest: () => {},
      resetBindings: () => {},
      resetBindingsForDevice: deviceName => {},
      setMenuActionMapEnabled: state => Boolean,
      getMenuActionMapEnabled: () => {},
      setMenuActionEnabled: (enabled, actionName) => [Boolean, String],
      notifyUI: reason => String,
      saveBindingsToDisk: deviceContents => Object,
    },

    core_vehicle_partmgmt: {
      getConfigList: () => {},
      highlightParts: (parts, vehID) => [Object, Number],
      loadLocal: filename => String,
      resetPartsToLoadedConfig: () => {},
      openConfigFolderInExplorer: () => {},
      removeLocal: configName => String,
      savedefault: () => {},
      saveLocal: filename => String,
      sendDataToUI: () => {},
      selectPart: (part, subparts) => [String, Boolean],
      selectParts: (parts, vehID) => [Object, Number],
      selectReset: () => {},
      setConfigVars: vars => Object,
      setPartsConfig: config => Object, // deprecated
      setPartsTreeConfig: config => Object, // there's also second "respawn" argument for this
      showHighlightedParts: (vehID) => Number,
      setDynamicTextureMaterials: () => { },
      partsSelectorChanged: parts => Object,
      sendPartsSelectorStateToUI: () => { },
    },

    core_vehicle_mirror: {
      getAnglesOffset: () => {},
      focusOnMirror: mirror_name => Any, //optional String
      setAngleOffset: (mirrorName, x, z, v, save) => [String, Number, Number, Boolean, Boolean],
    },

    gameplay_missions_missionScreen: {
      getMissionScreenData: withMocked(
        () => {},
        () => getMockedData("missionDetails.getMissionScreenData")
      ),
      startMissionById: (missionId, userSettings, startingOptions) => [String, Object, Object],
      stopMissionById: id => [String],
      changeUserSettings: (missionId, userSettings) => [String, Object],
      startFromWithinMission: (id, userSettings) => [String, Object],
      getActiveStarsForUserSettings: (id, userSettings) => [String, Object],
      requestStartingOptionsForUserSettings: (id, userSettings) => [String, Object],
      isAnyMissionActive: () => {},
      isMissionStartOrEndScreenActive: () => {},
      openAPMChallenges:(branch, skill) => [String, String],
      navigateToMission: (id) => [String],
      setPreselectedMissionId: (id) => [String],
      showMissionRules: (id) => [String],
      getMissionTiles: () => {},
      activateSound: (soundLabel, active) => {},
      activateSoundBlur: active => {
        Boolean
      },
    },

    gameplay_garageMode: {
      start: () => {},
      isActive: () => {},
      setCamera: view => String,
      setLighting: lights => Array,
      getLighting: () => {},
      setGarageMenuState: state => String,
      stop: () => {},
      testVehicle: () => {},
    },

    ui_dynamicDecals: {
      initialize: () => {},
      exit: () => {},
      requestUpdatedData: () => {},
      setupEditor: () => {},
      loadSaveFile: path => String,
      createSaveFile: () => {},
      saveChanges: filename => {},
      cancelChanges: () => {},
      exportSkin: skinName => String,
      moveSelectedLayer: order => Number,
      setDecalTexture: filePath => String,
      setDecalColor: colorData => Object,
      setDecalScale: decalData => Object,
      setDecalRotation: decalRotation => Number,
      setDecalSkew: decalSkew => Object,
      setDecalApplyMultiple: applyMultiple => Boolean,
      setDecalResetOnApply: resetOnApply => Boolean,
      setDecalPositionX: positionX => Number,
      setDecalPositionY: positionY => Number,
      updateDecalPosition: (positionX, positionY) => [Number, Number],
      toggleApplyingDecal: enable => Boolean,
      toggleActionMap: enable => Boolean,
      toggleDecalVisibility: enable => Boolean,
      redo: () => {},
      undo: () => {},
      createLayer: layerData => Object,
      createFillLayer: fillLayerData => Object,
      createGroupLayer: layerData => Object,
      updateLayer: layerData => Object,
      deleteSelectedLayer: () => {},
      selectLayer: layerUid => String,
      toggleStampActionMap: enable => Boolean,
      toggleLayerHighlight: uid => String,
      toggleLayerVisibility: uid => String,
    },

    ui_liveryEditor: {
      save: (filename) => String,
      setup: () => {},
      deactivate: () => {},
      setDecalTexture: texturePath => String,
      useMousePosition: enable => Boolean,
      useSurfaceNormal: enable => Boolean,
      requestSettingsData: () => {},
    },

    ui_liveryEditor_colorPresets: {
      getPresets: () => {},
      addPreset: () => {},
    },

    ui_liveryEditor_editor: {
      setup: () => {},
      startEditor: () => {},
      exitEditor: () => {},
      startSession: () => {},
      applyDecal: () => {},
      applySkin: () => {},
      createNew: () => {},
      loadFile: path => String,
      save: filename => String,
      applyChanges: () => {},
    },

    ui_liveryEditor_editMode: {
      reapply: () => {},
      requestReapply: () => {},
      cancelReapply: () => {},
      setActiveLayer: layerUid => String,
      setActiveLayerDirection: direction => Number,
      removeAppliedLayer: layerUid => String,
      resetCursorProperties: properties => Array,
      toggleHighlightActive: () => {},
      activate: () => {},
      deactivate: () => {},
      apply: () => {},
      requestApply: () => {},
      cancelRequestApply: () => {},
      toggleRequestApply: () => {},
      saveChanges: params => Object,
      cancelChanges: () => {},
      duplicateActiveLayer: () => {},
    },

    ui_liveryEditor_camera: {
      setOrthographicView: view => String,
      switchOrthographicViewByDirection: (x, y) => [Number, Number],
    },

    ui_liveryEditor_controls: {
      toggleUseMousePos: () => {},
    },

    ui_liveryEditor_history: {
      redo: () => {},
      undo: () => {},
    },

    ui_liveryEditor_layerAction: {
      performAction: action => String,
      toggleEnabledByLayerUid: uid => String,
    },

    ui_liveryEditor_layerEdit: {
      setup: () => {},
      setLayer: layerUid => String,
      editNewDecal: params => Object,
      translateLayer: (x, y) => [Number, Number],
      holdTranslate: (axis, value) => [String, Number],
      holdTranslateScalar: (axis, value) => [String, Number],
      holdScale: (axis, value) => [String, Number],
      holdSkew: (axis, value) => [String, Number],
      holdPrecise: enable => Boolean,
      scaleLayer: (x, y) => [Number, Number],
      skewLayer: (x, y) => [Number, Number],
      rotateLayer: (steps, counterClockwise) => [Number, Boolean],
      setPosition: (x, y) => [Number, Number],
      setScale: (x, y) => [Number, Number],
      setRotation: degrees => Number,
      setSkew: (x, y) => [Number, Number],
      setMirrored: settings => [Boolean, Boolean, Number],
      setLayerMaterials: properties => Object,
      activateStampReapply: () => {},
      cancelStampReapply: () => {},
      requestLayerMaterials: () => {},
      saveChanges: () => {},
      cancelChanges: () => {},
      requestStateData: () => {},
      requestInitialLayerData: () => {},
      requestTransform: () => {},
      endTransform: () => {},
      showCursorOrLayer: show => Boolean,
      requestReposition: () => {},
      cancelReposition: () => {},
      applyReposition: () => {},
      toggleUseMouseOrCursor: () => {},
      setIsRotationPrecise: value => Boolean,
      setAllowRotationAction: value => Boolean,
    },

    ui_liveryEditor_layers: {
      requestInitialData: () => {},
    },

    ui_liveryEditor_layers_cursor: {
      requestData: () => {},
    },

    ui_liveryEditor_layers_decals: {
      addLayer: params => Object,
      setLayer: uid => String,
    },

    ui_liveryEditor_layers_decal: {
      addLayerCentered: params => Object,
    },

    ui_liveryEditor_layers_fill: {
      updateLayer: params => Object,
      saveChanges: () => {},
      restoreLayer: () => {},
      restoreDefault: () => {},
      requestLayerData: () => {},
    },

    ui_liveryEditor_resources: {
      requestData: () => {},
      getDecalTextures: () => {},
      getTextureCategories: () => {},
      getTexturesByCategory: category => String,
    },

    ui_liveryEditor_selection: {
      duplicateSelectedLayer: () => {},
      getSelectedLayersData: () => {},
      setSelected: layerUid => String,
      setMultipleSelected: layerUids => Array,
      clearSelection: () => {},
      toggleSelection: layerIds => {},
      select: (layerIds, highlight) => [Array, Boolean],
      toggleHighlightSelectedLayer: () => {},
      requestInitialData: () => {},
    },

    ui_liveryEditor_tools: {
      useTool: tool => String,
      closeCurrentTool: () => {},
    },

    ui_liveryEditor_tools_material: {
      setColor: rgbaArray => Array,
      setMetallicIntensity: metallicIntensity => Number,
      setNormalIntensity: normalIntensity => Number,
      setRoughnessIntensity: roughnessIntensity => Number,
      setDecal: decalTexture => String,
    },

    ui_liveryEditor_tools_misc: {
      duplicate: () => {},
    },

    ui_liveryEditor_tools_group: {
      moveOrderUp: () => {},
      moveOrderDown: () => {},
      changeOrderToTop: () => {},
      changeOrderToBottom: () => {},
      moveOrderUpById: layerUid => [String],
      moveOrderDownById: layerUid => [String],
      setOrder: order => Number,
      changeOrder: (oldOrder, oldParent, newOrder, newParent) => [Number, String, Number, String],
      groupLayers: () => {},
      ungroupLayer: () => {},
    },

    ui_liveryEditor_tools_transform: {
      translate: (x, y) => [Number, Number],
      setPosition: (x, y) => [Number, Number],
      rotate: degrees => Number,
      scale: (stepsX, stepsY) => [Number, Number],
      setScale: (scaleX, scaleY) => [Number, Number],
      setRotation: degrees => Number,
      skew: (skewX, skewY) => [Number, Number],
      setSkew: (skewX, skewY) => [Number, Number],
      useStamp: () => {},
      cancelStamp: () => {},
    },

    ui_liveryEditor_tools_settings: {
      deleteLayer: () => {},
      setMirrored: (mirrored, flip) => [Boolean, Boolean],
      setVisibility: show => Boolean,
      toggleVisibility: () => {},
      toggleVisibilityById: layerUid => String,
      toggleLock: () => {},
      toggleLockById: layerUid => String,
      setMirrored: (mirrored, flip) => [Boolean, Boolean],
      setMirrorOffset: offset => Number,
      setUseMousePos: value => Boolean,
      setProjectSurfaceNormal: value => Boolean,
      rename: name => String,
    },

    ui_liveryEditor_userData: {
      requestUpdatedData: () => {},
      getSaveFiles: () => {},
      createSaveFile: filename => String,
      renameFile: (filename, newFilename) => [String, String],
      deleteSaveFile: filename => String,
    },

    ui_gameBlur: {
      replaceGroup: (groupName, list) => [String, Object],
    },

    ui_router: {
      push: (routeName, params) => [String, Object],
      push: (replace, params) => [String, Object],
      goPrevious: () => {},
      goNext: () => {},
      setup: () => {},
      addRoute: route => Object,
    },

    editor_api_dynamicDecals: {
      setup: () => {},
      getLayerStack: () => {},
      setLayerNameBuildString: buildString => String,
      onUpdate_: () => {},

      pushDynamicDecalsActionMap: () => {},
      popDynamicDecalsActionMap: () => {},

      addBrushStrokeLayer: () => {},
      highlightLayer: layerTable => {},
      highlightLayerByUid: layerUidString => {},
      disableDecalHighlighting: () => {},
      getHighlightedLayer: () => {},
      setLayerVisibility: (layerUidString, visibilityBool) => [String, Boolean],
      toggleLayerVisibility: layerUidString => String,
      changeDecalSize: (increaseBool, stepNumber) => {},
      changeDecalRotation: (clockwiseBool, stepRadianNumber) => {},
    },
  },

  ActionMap: {
    enableInputCommands: state => Boolean,
  },

  gameplay_markerInteraction: {
    startMissionById: (missionId, userSettings) => [Any, Object],
    closeViewDetailPrompt: force => Boolean,
    changeUserSettings: (missionId, userSettings) => [String, Object],
  },

  ui_missionInfo: {
    performActivityAction: id => {},
    closeDialogue: () => {},
  },

  scenetree: {
    "maincef:setMaxFPSLimit": fps => Integer, // This name is problematic and need to use [] syntax to call - intellisense should pick it up
  },

  settings: {
    notifyUI: () => {},
    setState: state => Object,
    getValue: value => String,
  },

  core_camera: {
    setFOV: (playerId, fovDeg) => [Integer, Number],
  },

  core_modmanager: {
    requestState: () => {},
  },

  core_vehicles: {
    cloneCurrent: () => {},
    getModel: model => String,
    getCurrentVehicleDetails: withMocked(
      () => {},
      () => getMockedData("vehicle.details")
    ),
    getVehicleLicenseText: id => Number, // TODO - not sure if this will be used - may need to send some Lua code directly - consider how to do this
    loadDefault: () => {},
    removeAll: () => {},
    removeAllExceptCurrent: () => {},
    removeCurrent: () => {},
    requestList: () => {},
    requestListEnd: () => {},
    setPlateText: plateText => String,
    setMeshVisibility: state => Number,
    spawnDefault: () => {},
    spawnNewVehicle: (model, args) => [String, Object],
    replaceVehicle: (model, args) => [String, Object],
    getVehicleTiles: () => {},
  },

  core_vehicle_manager: {
    reloadAllVehicles: () => {},
    toggleDebug: () => {},
    getDebug: () => {},
  },

  core_vehicle_colors: {
    setVehicleColor: (index, value) => [Integer, Object],
  },

  core_recoveryPrompt: {
    getUIData: () => {},
    uiPopupButtonPressed: index => [Integer],
    uiPopupCancelPressed: () => {},
    onPopupClosed: () => {},
  },

  core_remoteController: {
    devicesConnected: () => Boolean,
    getQRCode: () => {},
  },

  core_levels: {
    startLevel: () => {},
  },

  bdebug: {
    toggleEnabled: () => {},
    requestState: () => {},
    setState: (state, stateNoReset, notSendBack) => [Object, Object, Boolean],
    resetModes: () => {},
    partsSelectedChanged: () => {},
    syncSelectedPartsWithPartsList: () => {},
    showOnlySelectedPartsMeshChanged: () => {},
  },

  util_screenshotCreator: {
    startWork: workOptions => Any,
  },

  util_groundModelDebug: {
    openWindow: () => {},
  },

  scenario_scenariosLoader: {
    getList: () => {},
    start: scenario => Object,
  },

  WinInput: {
    setForwardRawEvents: state => Boolean,
  },

  Engine: {
    Audio: {
      playOnce: (channel, sound) => [String, String],
    },
    Render: {
      getAdapterType: () => {},
    },
    UI: {
      getUIEngine: () => {},
    },
    Platform: {
      getFSInfo: () => {},
    },
  },

  Steam: {
    showFloatingGamepadTextInput: (type, left, top, width, height) => [Number, Number, Number, Number, Number],
  },

  setCEFTyping: state => Boolean,

  // -- Testing -------------------------------------------------------------------

  // noParams: () => {},
  // oneParam: firstParam => {},
  // manyParams: (first, second, third) => {},
  // singleStringParam: myString => String,
  // multiStringParams: (str1, str2) => [String, String],
  // mixedParamTypes: (int1, str1, int2) => [Number, String, Number],

  // noTransform: function(str) { run('myFunction', [str]) },

  // namespace: {
  //  noParams: () => {},
  //  oneParam: firstParam => {},
  //  manyParams: (first, second, third) => {},
  //  singleStringParam: myString => String,
  //  multiStringParams: (str1, str2) => [String, String],
  //  mixedParamTypes: (int1, str1, int2) => [Number, String, Number],

  //  inner: {
  //    test1: () => {},
  //    test2: param => {},
  //    test3: strParam => String,
  //    test4: (multi1, multi2) => [String, Boolean]
  //  }
  // }

  career_modules_sleep: {
    closeMenu: () => {},
    closeAllMenus: () => {},
    toggleDayNightCycle: toggle => Boolean,
    sleep: time => Number,
    getDayNightCycle: () => {}
  },

  career_modules_assignRole: {
    canPay: () => {},
    startCertification: () => {},
    requestAssignmentData: () => {}
  },

  career_modules_carmeets: {
    rsvpToMeet: attendanceLevel => {},
    decline: () => {},
    closeMenu: () => {},
    openMenu: () => {},
    checkAvailableMeets: () => {},
    requestRSVPData: () => {},
    cancelRSVP: () => {},
    setRoute: () => {},
    updateAttendance: attendanceLevel => {}
  },

  career_modules_garageManager: {
    requestGarageData: () => {},
    canPay: () => {},
    buyGarage: () => {},
    cancelGaragePurchase: () => {},
    getGaragePrice: () => {},
    canSellGarage: () => {},
    sellGarage: () => {}
  },

  gameplay_taxi: {
    prepareTaxiJob: () => {},
    acceptJob: () => {},
    rejectJob: () => {},
    setAvailable: () => {},
    stopTaxiJob: () => {},
    getTaxiJob: () => {},
    requestTaxiState: () => {}
  },

  career_modules_vehicleMarketplace: {
    openMenu: () => {},
    requestInitialData: () => {},
    acceptOffer: (vehicleId, customer) => [String, String],
    declineOffer: (vehicleId, customer) => [String, String],
    toggleNotifications: (newValue) => Boolean
  },

  career_modules_hardcore: {
    isHardcoreMode: () => {}
  },

  gameplay_repo: {
    generateJob: () => {},
    getRepoJobInstance: () => {},
    requestRepoState: () => {},
    cancelJob: () => {},
    completeJob: () => {},
    isRepoVehicle: () => {}
  },

  careerMaps: {
    getOtherAvailableMaps: () => {}
  },

  career_modules_switchMap: {
    switchMap: (level) => {}
  }
}
