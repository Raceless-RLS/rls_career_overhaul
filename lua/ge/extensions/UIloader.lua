local M = {}

local function onExtensionLoaded()
  -- Add a small delay before reloading UI
  guihooks.trigger('reloadUI', {}, 500)
  print("RLS Career Overhaul UI loaded")
end

M.onExtensionLoaded = onExtensionLoaded

return M