-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function getGameContext(...)
  if not gameplay_markerInteraction then
    extensions.load('gameplay_markerInteraction')
  end
  if gameplay_markerInteraction then
    return gameplay_markerInteraction.getGameContext(...)
  end
  return {}
end

local function toggleMenues()

end

local function onAnyMissionChanged(state, mission)
  guihooks.trigger('onAnyMissionChanged', state, mission and mission.id)
end

local function getWIPWarningLabel()
  if gameplay_missions_missionManager.getForegroundMissionId() then
    local m = gameplay_missions_missions.getMissionById(gameplay_missions_missionManager.getForegroundMissionId())
    if m then
      if m.missionType == 'rallyStage' then
          return "ui.rally.experimentalWarning"
        end
      end
    end
  if career_career.isActive() then
    return "RLS Career Overhaul v2.3.1.2 - WIP"
  end
  return nil
end
M.getWIPWarningLabel = getWIPWarningLabel

M.onAnyMissionChanged = onAnyMissionChanged

M.getGameContext = getGameContext
M.toggleMenues = toggleMenues
return M
