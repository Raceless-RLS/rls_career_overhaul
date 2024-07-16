-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')

local function onBeamNGTrigger(data)

  if data.event == 'enter' and data.triggerName == 'confetti_trigger' then

  local confettiCanon0 = scenetree.findObject('confetti_canon0')
  local confettiCanon1 = scenetree.findObject('confetti_canon1')

  confettiCanon0.active = true
  confettiCanon1.active = true

  end
end

local function onScenarioRestarted()

  local confettiCanon0 = scenetree.findObject('confetti_canon0')
  local confettiCanon1 = scenetree.findObject('confetti_canon1')

  confettiCanon0.active = false
  confettiCanon1.active = false

end

local function onRaceWaypointReached(data, goal)

  if data.waypointName == 'wp27' then
    helper.flashUiMessage('scenarios.west_coast_usa.wcaAutobelloShowcase.tip_reverse', 4)
  end

end

M.onBeamNGTrigger = onBeamNGTrigger
M.onScenarioRestarted = onScenarioRestarted
M.onRaceWaypointReached = onRaceWaypointReached

return M