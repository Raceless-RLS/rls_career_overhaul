-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Pursuit Information'
C.description = 'Gives information about the pursuit state.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'repeat_instant'
C.tags = {'police', 'cops', 'pursuit', 'chase', 'info', 'traffic', 'ai'}


C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id to get information from; if none given, uses the player vehicle.'},

  {dir = 'out', type = 'flow', name = 'active', description = 'Sends flow while the target is being chased.'},
  {dir = 'out', type = 'flow', impulse = true, name = 'arrest', description = 'Sends an impulse when the target is busted.'},
  {dir = 'out', type = 'flow', impulse = true, name = 'evade', description = 'Sends an impulse when the target evades the police.'},
  {dir = 'out', type = 'number', name = 'mode', description = 'Pursuit mode; 0 = off, 1 - 3 = chase (heat levels), -1 = busted.'},
  {dir = 'out', type = 'number', name = 'pitTimer', description = 'Time until PIT maneuver is approved.'},
  {dir = 'out', type = 'number', name = 'score', description = 'Pursuit score.'},
  {dir = 'out', type = 'number', name = 'sightValue', hidden = true, description = 'Visibility to nearest police vehicle (from 0 to 1)'},
  {dir = 'out', type = 'number', name = 'arrestValue', hidden = true, description = 'Arrest progress (from 0 to 1)'},
  {dir = 'out', type = 'number', name = 'evadeValue', hidden = true, description = 'Evade progress (from 0 to 1)'},
  {dir = 'out', type = 'number', name = 'timeElapsed', description = 'Time duration of pursuit.'},
  {dir = 'out', type = 'number', name = 'roadblocks', hidden = true, description = 'Number of police roadblocks encountered.'},
  {dir = 'out', type = 'number', name = 'collisions', hidden = true, description = 'Number of vehicle collisions.'},
  {dir = 'out', type = 'number', name = 'policeWrecks', hidden = true, description = 'Number of police vehicles wrecked.'},
  {dir = 'out', type = 'number', name = 'offenses', hidden = true, description = 'Number of total pursuit offenses.'},
  {dir = 'out', type = 'number', name = 'uniqueOffenses', hidden = true, description = 'Number of total unique pursuit offenses (e.g. only counts the first traffic collision).'},
  {dir = 'out', type = 'table', name = 'offensesList', tableType = 'pursuitOffenses', hidden = true, description = 'Array of pursuit offenses.'}
}

function C:init()
  self:reset()
end

function C:_executionStopped()
  self:reset()
end

function C:reset()
  self.vehId = nil
  self.pinOut.active.value = false
  self.pinOut.arrest.value = false
  self.pinOut.evade.value = false
  self.arrestFlag = false
  self.evadeFlag = false
end

function C:work()
  self.vehId = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  local pursuit = gameplay_police.getPursuitData(self.vehId)
  
  if not pursuit or pursuit.mode <= 0 then 
    self:reset()  -- Clear all data if there's no active pursuit
    return 
  end

  -- Update data only for active pursuits
  self.pinOut.active.value = true
  self.pinOut.mode.value = pursuit.mode
  self.pinOut.score.value = pursuit.score
  self.pinOut.sightValue.value = pursuit.sightValue
  self.pinOut.arrestValue.value = pursuit.timers.arrestValue
  self.pinOut.evadeValue.value = pursuit.timers.evadeValue
  self.pinOut.timeElapsed.value = pursuit.timers.main
  self.pinOut.roadblocks.value = pursuit.roadblocks
  self.pinOut.collisions.value = pursuit.hitCount
  self.pinOut.policeWrecks.value = pursuit.policeWrecks
  self.pinOut.offenses.value = pursuit.offensesCount
  self.pinOut.uniqueOffenses.value = pursuit.uniqueOffensesCount
  self.pinOut.offensesList.value = pursuit.offensesList
  self.pinOut.pitTimer.value = pursuit.pitTimer or 0

  -- Handle arrest and evade events
  self.pinOut.arrest.value = self.arrestFlag
  self.pinOut.evade.value = self.evadeFlag
  self.arrestFlag, self.evadeFlag = false, false
end

function C:onPursuitAction(id, data)
  if id == self.vehId then
    if data.type == 'arrest' then
      self.arrestFlag = true
    elseif data.type == 'evade' then
      self.evadeFlag = true
    end
  end
end

return _flowgraph_createNode(C)