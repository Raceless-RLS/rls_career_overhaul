local M = {}

local totalPauseTime = 0
local countPausedTime = false

M.onUpdate = function(dt, dtSim)
  if countPausedTime and dtSim == 0 then
    totalPauseTime = totalPauseTime + dt
  end
end

M.enablePauseCounter = function(enable)
  countPausedTime = enable
  totalPauseTime = 0
end

M.getTotalPauseTime = function() return totalPauseTime end
M.resetPauseTime = function() totalPauseTime = 0 end

return M