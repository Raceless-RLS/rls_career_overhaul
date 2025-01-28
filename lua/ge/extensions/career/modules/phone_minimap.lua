local M = {}
local updateInterval = 0.1
local lastUpdate = 0
local viewSize = 200

local function sendMapData()
  local mapData = {
    paths = {}
  }
  
  -- Get road network data
  local nodes = map.getMap().nodes or {}
  for id, node in pairs(nodes) do
    if node.links then
      for targetId, link in pairs(node.links) do
        if nodes[targetId] then
          local path = {
            d = string.format("M %.2f %.2f L %.2f %.2f", 
                             -node.pos.x, node.pos.y, 
                             -nodes[targetId].pos.x, nodes[targetId].pos.y),
            color = link.drivability > 0.9 and "#ffffff" or "#666666"
          }
          table.insert(mapData.paths, path)
        end
      end
    end
  end
  
  -- Send initial map data
  guihooks.trigger('phoneMinimapData', mapData)
end

local function onUpdate(dt)
  lastUpdate = lastUpdate + dt
  if lastUpdate < updateInterval then return end
  lastUpdate = 0

  local player = be:getPlayerVehicle(0)
  if not player then return end

  -- Player position only
  local pos = player:getPosition()
  local dir = player:getDirectionVector()
  local rot = math.deg(math.atan2(dir.x, -dir.y))

  local viewData = {
    viewX = -pos.x - viewSize/2,
    viewY = pos.y - viewSize/2,
    viewW = viewSize,
    viewH = viewSize,
    playerRot = rot  -- Removed vehicles array
  }

  guihooks.trigger('phoneMinimapUpdate', viewData)
end

-- Initialization
M.onExtensionLoaded = function()
  sendMapData()
end

M.onUpdate = onUpdate

return M 