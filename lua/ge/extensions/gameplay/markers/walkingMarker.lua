local C = {}
-- icon renderer
local iconRendererName = "markerIconRenderer"
local markerIndexCorrection = { { 3, 4, 2, 1 }, { 1, 2, 4, 3 } }
local vecZero = vec3(0,0,0)
local vecOne = vec3(1,1,1)
local quatZero = quat(0,0,0,0)
local vecX = vec3(1,0,0)
local vecY = vec3(0,1,0)
local vecZ = vec3(0,0,1)
local lineColorF = ColorF(1,1,1,1)
local playModeColorI = ColorI(255,255,255,255)
local iconHeightBottom = 1.25
local iconHeightTop = 2.5
local iconRendererObj
local iconWorldSize = 20
local tmpVec = vec3()
local maxVisibleDistance = 15
local screenObjTemp = nil
function C:init()
  self.visible = true
end

function C:setup(cluster)
  self.pos = cluster.pos or vecZero
  self.rot = cluster.rot or quatZero
  self.scl = cluster.scl or vecZero

  self.cluster = cluster
  -- default values for doors
  self.iconOffsetHeight = 1.45
  self.iconLift = 0.25

  self.doors = {}
  self.iconLift = cluster.iconLift or 0.25
  self.iconOffsetHeight = cluster.iconOffsetHeight or 1.45

  iconRendererObj = scenetree.findObjectById(self.iconRendererId)
  for idx, ntuple in ipairs(cluster.doors or {}) do
    local area = scenetree.findObject(ntuple[1])
    local icon = scenetree.findObject(ntuple[2])
    if area and icon then
      local pos, rot, scl = area:getPosition(), quat(area:getRotation()), area:getScale()
      local zVec, yVec, xVec = rot*vecZ*scl.z, rot*vecY*scl.y, rot*vecX*scl.x
      local iconPos = icon:getPosition()

      local doorData = {
         areaPos = pos,
         xVec = xVec, yVec = yVec, zVec = zVec,
         iconPos = iconPos,
         iconPosSmoother = newTemporalSmoothingNonLinear(10,10),
         iconAlphaSmoother = newTemporalSmoothingNonLinear(20,20),
         overlap = false,
         maxVisibleDistance = ntuple[3] or maxVisibleDistance
      }
      if (cluster.screens or {})[idx] then
        local screenObj = scenetree.findObject((cluster.screens or {})[idx])
        if screenObj then
          doorData.screenObjId = screenObj:getId()
          doorData.screenTimer = 0
          screenObj:setHidden(true)
        end
      end

      if iconRendererObj then
        local iconId = iconRendererObj:addIcon(string.format("%s-gsIcon-%d",cluster.id, idx), cluster.icon, iconPos)
        local iconInfo = iconRendererObj:getIconById(iconId)
        iconInfo.color = ColorI(255,255,255,255)
        iconInfo.customSize = iconWorldSize
        iconInfo.drawIconShadow = false

        doorData.iconId = iconId
        doorData.iconInfo = iconInfo

      end

      table.insert(self.doors, doorData)
    end
  end
end

function C:update(data)
  if not self.visible or not data.veh then return end

  local anyOverlap = false
  for idx, area in ipairs(self.doors or {}) do
    --simpleDebugText3d(idx, area.iconPos, 0.25)
    screenObjTemp = scenetree.findObjectById(area.screenObjId) or nil

    local overlap = data.isWalking and (data.cruisingSpeedFactor < 1) and overlapsOBB_OBB(data.bbCenter, data.bbHalfAxis0, data.bbHalfAxis1, data.bbHalfAxis2, area.areaPos, area.xVec, area.yVec, area.zVec)
    anyOverlap = anyOverlap or overlap
    if overlap and not area.overlap then
      if screenObjTemp then
        Engine.Audio.playOnce('AudioGui','event:>UI>Career>Computer', {position = vec3(self.pos.x, self.pos.y, self.pos.z)})
        if self.cluster.garageId and career_career.isActive() then
          career_modules_extraSaveData.addDiscoveredGarage(self.cluster.garageId)
        end
      end
      area.overlap = true
    end
    if not overlap and area.overlap then
      area.overlap = false
    end
    if screenObjTemp then
      if area.overlap then
        area.screenTimer = 5
      end
      --simpleDebugText3d(area.screenTimer, screenObjTemp:getPosition())
      area.screenTimer = area.screenTimer - data.dt
      screenObjTemp:setHidden(area.screenTimer < 0)
    end

    area.overlap = overlap

    local iconInfo = area.iconInfo
    if iconInfo then
      local iconPos = iconInfo.worldPosition
      tmpVec:set(data.camPos)
      tmpVec:setSub(iconPos)
      local rayLength = tmpVec:length()

      local visible = rayLength < area.maxVisibleDistance and castRayStatic(iconPos, tmpVec, rayLength, nil) >= rayLength

      local smootherVal = area.iconPosSmoother:get((not data.bigMapActive and overlap) and 1 or 0, data.dt)
      tmpVec:set(0,0,self.iconOffsetHeight + smootherVal*self.iconLift)
      tmpVec:setAdd(area.iconPos)
      iconInfo.worldPosition = tmpVec
      playModeColorI.alpha = area.iconAlphaSmoother:get((not data.bigMapActive and visible) and 1 or 0, data.dt) * 255
      iconInfo.color = playModeColorI
      if smootherVal > 0.1 then
        --lineColorF.a = area.iconAlphaSmoother:value()
        debugDrawer:drawLine(area.iconPos + vec3(0,0,self.iconOffsetHeight - smootherVal * self.iconOffsetHeight), tmpVec, lineColorF)
      end
    end
  end

  self.anyOverlap = anyOverlap

end


function C:createObjects()
  self:clearObjects()
  iconRendererObj = scenetree.findObject(iconRendererName)
  if not iconRendererObj then
    iconRendererObj = createObject("BeamNGWorldIconsRenderer")
    iconRendererObj:registerObject(iconRendererName);
    iconRendererObj.maxIconScale = 2
    iconRendererObj.mConstantSizeIcons = true
    iconRendererObj.canSave = false
    iconRendererObj:loadIconAtlas("core/art/gui/images/iconAtlas.png", "core/art/gui/images/iconAtlas.json");
  end
  self.iconRendererId = iconRendererObj:getId()
end

function C:hide()
  if not self.visible then return end
  self.visible = false
  if self.iconRendererId then
    iconRendererObj = scenetree.findObject(self.iconRendererId)
    if iconRendererObj then
      for idx, area in ipairs(self.doors or {}) do
        playModeColorI.alpha = 0
        area.iconInfo.color = playModeColorI
      end
    end
  end
  for idx, area in ipairs(self.doors or {}) do
    if area.screenObjId then
      screenObjTemp = scenetree.findObjectById(area.screenObjId)
      if screenObjTemp then screenObjTemp:setHidden(true) end
    end
  end
end

function C:show()
  if self.visible then return end
  self.visible = true
end

function C:clearObjects()
  if self.iconRendererId then
    iconRendererObj = scenetree.findObject(self.iconRendererId)
    if iconRendererObj then
      for idx, area in ipairs(self.doors or {}) do
        iconRendererObj:removeIconById(area.iconId)
      end
    end
  end
  for idx, area in ipairs(self.doors or {}) do
    if area.screenObjId then
      screenObjTemp = scenetree.findObjectById(area.screenObjId)
      if screenObjTemp then screenObjTemp:setHidden(true) end
    end
  end
  self.doors = nil
end

function C:interactInPlayMode(interactData, interactableElements)
  if interactData.canInteract and self.anyOverlap then
      local garageId = self.cluster.garageId
      if garageId then
        if career_career.isActive() then
          if not career_modules_extraSaveData.isPurchasedGarage(garageId) then
          -- Don't add interaction elements if garage isn't purchased
          return
          end
        end
      end
    for _, elem in ipairs(self.cluster.elemData) do
      table.insert(interactableElements, elem)
    end
  end
end



function C:instantFade(visible)
end


function C:drawAxisBox(corner, x, y, z, clr)
  clr = clr or ColorI(128,64,64,32)
  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), ColorF(0,0,0,0.75))
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end


local function create(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

-- walkingmarker are clustered if the area and icon names are identical
local function cluster(pois, allClusters)
  local poisByObjectNames = {}
  for _, poi in ipairs(pois) do
    local name = {}
    for _, door in ipairs(poi.markerInfo.walkingMarker.doors) do
      table.insert(name, door[1]..door[2])
    end
    table.sort(name)
    name = table.concat(name)
    poisByObjectNames[name] = poisByObjectNames[name] or {}
    table.insert(poisByObjectNames[name], poi)
  end
  for key, poisInCluster in pairs(poisByObjectNames) do
    local wm = poisInCluster[1].markerInfo.walkingMarker
    local cluster = {
      id = 'walkingMarker#'..key,
      doors = wm.doors,
      iconLift = wm.iconLift,
      icon = wm.icon or "poi_exclamationmark_round",
      iconOffsetHeight = wm.iconOffsetHeight,
      visibilityPos = wm.pos,
      visibilityRadius = wm.radius,
      screens = wm.screens,
      elemData = {},
      create = create,
      garageId = wm.garageId
    }
    for _, poi in ipairs(poisInCluster) do
      table.insert(cluster.elemData, poi.data)
    end
    table.insert(allClusters, cluster)
  end
end

return {
  create = create,
  cluster = cluster
}
