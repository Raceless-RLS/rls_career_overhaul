local M = {}

local function onExtensionLoaded()
  -- Add a small delay before reloading UI
  reloadUI()
  if career_career.isActive() then
    guihooks.trigger('ChangeState', {state = 'play', params = {}})
  end
  print("RLS Career Overhaul UI loaded")
end

M.onExtensionLoaded = onExtensionLoaded

return M