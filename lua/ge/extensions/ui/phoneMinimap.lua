local M = {}

local onlyShowPlayer = true

local function getNodes()
  local tmpmap = map.getMap()
  local newNodes = {}
  
  if not tmpmap or not tmpmap.nodes then 
    return newNodes 
  end

  for k, v in pairs(tmpmap.nodes) do
    if not v.hiddenInNavi then
      newNodes[k] = {
        pos = {v.pos.x, v.pos.y},
        radius = v.radius,
        links = {}
      }
      for j, w in pairs(v.links or {}) do
        local targetNode = tmpmap.nodes[j]
        if targetNode and not targetNode.hiddenInNavi and not w.hiddenInNavi then
          newNodes[k].links[j] = {
            drivability = w.drivability or 1,
            oneWay = w.oneWay or false
          }
        end
      end
    end
  end
  return newNodes
end

local function requestPhoneMap()
  local d = {
    nodes = getNodes(),
    terrainTiles = {}
  }

  local terr = getObjectByClass("TerrainBlock")
  if terr then
    local blockSize = terr:getWorldBlockSize()
    local minimapImage = terr.minimapImage
    if minimapImage:startswith("/") then
      minimapImage = minimapImage:sub(2)
    end
    
    d.terrainTiles = {{
      size = {terr:getWorldBlockSize(), terr:getWorldBlockSize()},
      offset = {terr:getPosition().x, terr:getPosition().y + blockSize},
      file = minimapImage
    }}
  end

  guihooks.trigger('PhoneMinimapData', d)
end

local function onGuiUpdate()
  local controlId = be:getPlayerVehicleID(0)
  if not controlId then return end

  local tracked = map.getTrackedObjects()
  local isFreeCam = commands.isFreeCamera() or (gameplay_walk and gameplay_walk.isWalking())
  local camPos = core_camera.getPosition() or vec3()
  local camForward = core_camera.getForward() or vec3()

  local data = {
    controlID = controlId,
    isFreeCam = isFreeCam,
    camPosition = { x = camPos.x, y = camPos.y },
    camRotationZ = math.atan2(camForward.x, -camForward.y) * 180 / math.pi,
    objects = {}
  }

  if tracked then
    for id, obj in pairs(tracked) do
      if obj.pos and obj.dirVec and (not onlyShowPlayer or id == controlId) then
        data.objects[id] = {
          posX = -obj.pos.x,
          posY = obj.pos.y,
          rot = math.floor(-math.deg(math.atan2(
            obj.dirVec:dot(vec3(1,0,0)), 
            obj.dirVec:dot(vec3(0,-1,0))
          ))),
          speed = obj.speed or 0,
          isPlayer = id == controlId
        }
      end
    end
  end

  guihooks.trigger('PhoneMinimapUpdate', data)
end

M.onGuiUpdate = onGuiUpdate
M.requestPhoneMap = requestPhoneMap
M.onExtensionLoaded = function() 
  requestPhoneMap()
end

return M