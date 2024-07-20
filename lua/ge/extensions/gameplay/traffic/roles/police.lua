-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.class = 'emergency'
  self.keepActionOnRefresh = true
  self.personalityModifiers = {
    aggression = {median = 0.2}
  }
  self.veh.drivability = clamp(0.25, self.veh.vars.minRoadDrivability, 1)
  self.cooldownTimer = -1
  self.validTargets = {}
  self.actions = {
    pursuitStart = function (args)
      local firstMode = 'chase'
      local modeNum = 0
      local obj = be:getObjectByID(self.veh.id)

      if self.veh.isAi then
        obj:queueLuaCommand('ai.setSpeedMode("off")')
        obj:queueLuaCommand('electrics.set_lightbar_signal(2)')

        if args.targetId then
          local targetVeh = gameplay_traffic.getTrafficData()[args.targetId]
          if targetVeh then
            modeNum = targetVeh.pursuit.mode
            firstMode = modeNum <= 1 and 'follow' or 'chase'
          end
        end

        if modeNum < 3 then -- passive
          obj:queueLuaCommand('ai.setMode("follow")')
          obj:queueLuaCommand('ai.driveInLane("off")')
        else -- aggressive
          obj:queueLuaCommand('ai.setMode("chase")')
          obj:queueLuaCommand('ai.driveInLane("off")')
        end
      end

      self.targetPursuitMode = modeNum
      self.state = firstMode
      self.flags.roadblock = nil
      self.flags.busy = 1
      self.cooldownTimer = -1

      if not self.flags.pursuit then
        self.veh:modifyRespawnValues(600, 50, -0.6)
        self.flags.pursuit = 1
      end
    end,
    pursuitEnd = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(1)')
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setAggression('..self.driver.aggression..')')
      end
      self.flags.pursuit = nil
      self.flags.reset = 1
      self.flags.cooldown = 1
      self.cooldownTimer = 10
      self.state = 'stop'

      self.targetPursuitMode = 0
    end,
    disabled = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(0)')
      end
      self.state = 'disabled'
    end,
    roadblock = function ()
      if self.veh.isAi then
        be:getObjectByID(self.veh.id):queueLuaCommand('ai.setMode("stop")')
        be:getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(2)')
      end
      self.flags.roadblock = 1
      self.state = 'stop'
      self.veh:modifyRespawnValues(300)
    end
  }

  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil

  self.targetPursuitMode = 0
end

function C:checkTarget()
  local traffic = gameplay_traffic.getTrafficData()
  local targetId
  local bestScore = 0

  for id, veh in pairs(traffic) do
    if id ~= self.veh.id and veh.role.name ~= 'police' then
      if veh.pursuit.mode >= 1 and veh.pursuit.score > bestScore then
        bestScore = veh.pursuit.score
        targetId = id
      end
    end
  end

  return targetId
end

function C:onRefresh()
  if self.state == 'disabled' then self.state = 'none' end
  self.actionTimer = 0
  self.preventPullOver = nil

  if self.flags.reset then
    self:resetAction()
  end

  local targetId = self:checkTarget()
  if targetId then
    self:setTarget(targetId)
    self.flags.targetVisible = nil
    local targetVeh = gameplay_traffic.getTrafficData()[targetId]
    if not targetVeh.pursuit.roadblockPos or (targetVeh.pursuit.roadblockPos and be:getObjectByID(self.veh.id):getPosition():squaredDistance(targetVeh.pursuit.roadblockPos) > 400) then
      -- ignores this if vehicle is at a roadblock
      self:setAction('pursuitStart', {targetId = targetId})
    end
    self.veh:modifyRespawnValues(750 - self.targetPursuitMode * 150, 50, -0.6)
  else
    if self.flags.pursuit then
      self:resetAction()
    end
  end

  if self.flags.pursuit then
    self.veh.respawn.spawnRandomization = 0.25
  end
end

function C:onTrafficTick(dt)
  for id, veh in pairs(gameplay_traffic.getTrafficData()) do -- update data of potential targets
    if id ~= self.veh.id and veh.role.name ~= 'police' and not veh.ignorePolice then
      if not self.validTargets[id] then self.validTargets[id] = {} end
      local interDist = self.veh:getInteractiveDistance(veh.pos, true)

      self.validTargets[id].dist = self.veh.pos:squaredDistance(veh.pos)
      self.validTargets[id].interDist = interDist
      self.validTargets[id].visible = interDist <= 10000 and self:checkTargetVisible(id) -- between 150 m ahead and 50 m behind target

      if self.flags.pursuit and self.validTargets[id].visible and not self.flags.targetVisible then
        local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
        if targetVeh then
          targetVeh.pursuit.policeCount = targetVeh.pursuit.policeCount + 1
          self.flags.targetVisible = 1
        end
      end
    else
      self.validTargets[id] = nil
    end
  end

  if self.veh.isAi and self.targetId and self.state ~= 'disabled' and self.veh.state == 'active' and self.veh.damage > self.veh.damageLimits[3] then
    -- wreck during pursuit
    self:setAction('disabled')
    if self.flags.pursuit then
      local targetVeh = gameplay_traffic.getTrafficData()[self.targetId]
      if targetVeh and self.veh.pos:squaredDistance(targetVeh.pos) <= 400 then
        targetVeh.pursuit.policeWrecks = targetVeh.pursuit.policeWrecks + 1
      end
    end
  end

  if self.cooldownTimer <= 0 then
    if self.cooldownTimer ~= -1 then
      self.cooldownTimer = -1
      self.flags.reset = nil
      self.flags.busy = nil
      self.flags.cooldown = nil
    end
  else
    self.cooldownTimer = self.cooldownTimer - dt
  end

  if self.veh.speed >= 6 and next(map.objects[self.veh.id].states) then -- lightbar triggers all traffic lights to change to the red state
    if map.objects[self.veh.id].states.lightbar then
      self:freezeTrafficSignals(true)
    else
      if self.flags.freezeSignals then
        self:freezeTrafficSignals(false)
      end
    end
  else
    if self.flags.freezeSignals then
      self:freezeTrafficSignals(false)
    end
  end
end

function C:onUpdate(dt, dtSim)
  if not self.flags.pursuit or self.state == 'none' then return end
  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
  if not targetVeh or (targetVeh and not targetVeh.role.flags.flee) then
    self:resetAction()
    return
  end

  local pursuitData = gameplay_police.getPursuitData(self.targetId)
  if not pursuitData or (pursuitData.lastUpdated and os.clock() - pursuitData.lastUpdated > 1) then
    -- Pursuit data is stale or non-existent, end pursuit
    self:endPursuit()
    return
  end

  if self.veh.isAi then
    if self.state == 'disabled' then return end

    local obj = be:getObjectByID(self.veh.id)
    local distSq = self.veh.pos:squaredDistance(targetVeh.pos)
    local brakeDistSq = square(self.veh:getBrakingDistance(self.veh.speed, 1) + 20)
    local targetVisible = self.validTargets[self.targetId or 0] and self.validTargets[self.targetId].visible

    if self.actionTimer > 0 then
      self.actionTimer = self.actionTimer - dtSim
    end

    if self.flags.pursuit and self.state ~= 'none' and self.state ~= 'disabled' and self.veh.vars.aiMode == 'traffic' then
      local pursuitData = gameplay_police.getPursuitData(self.targetId)
      local canPIT = pursuitData and pursuitData.pitTimer and pursuitData.pitTimer <= 0
      local minSpeed = (4 - targetVeh.pursuit.mode) * 3
      if self.flags.roadblock == 1 then minSpeed = 0 end

      if (self.flags.roadblock and targetVeh.vel:dot((targetVeh.pos - targetVeh.pursuit.roadblockPos):normalized()) >= 9)
      or targetVeh.pursuit.timers.evadeValue >= 0.5 then
        obj:queueLuaCommand('ai.setSpeedMode("off")')
        if canPIT then
          obj:queueLuaCommand('ai.setMode("chase")')
        else
          obj:queueLuaCommand('ai.setMode("follow")')
        end
        obj:queueLuaCommand('ai.setAggressionMode("rubberBand")')
        obj:queueLuaCommand('ai.setAggression(1)')
        self.state = 'chase'
        self.flags.roadblock = nil
      end

      if self.preventPullOver then 
        self.preventPullOver = false
        return
      end

      if targetVeh.pursuit.mode < 3 and targetVisible and targetVeh.speed <= minSpeed then
        if self.state == 'chase' and distSq <= brakeDistSq and targetVeh.driveVec:dot(targetVeh.pos - self.veh.pos) > 0 then -- pull over near target vehicle
          self:setAction('pullOver')
          self.actionTimer = gameplay_police.getPursuitVars().arrestLimit + 2
        end
      else
        if self.state == 'pullOver' then
          if canPIT then
            obj:queueLuaCommand('ai.setMode("chase")')
            self.state = 'chase'
          else
            obj:queueLuaCommand('ai.setMode("follow")')
            self.state = 'follow'
          end
        end
      end
      
      if self.state == 'pullOver' and self.actionTimer <= 0 then -- pull over time out
        if canPIT then
          obj:queueLuaCommand('ai.setMode("chase")')
          self.state = 'chase'
          self.preventPullOver = true -- no more acting nice and pulling over until this vehicle resets
        else
          obj:queueLuaCommand('ai.setMode("follow")')
          self.state = 'follow'
        end
      end
      
      -- Update AI mode based on PIT timer
      if self.state == 'chase' and not canPIT then
        obj:queueLuaCommand('ai.setMode("follow")')
        self.state = 'follow'
      elseif self.state == 'follow' and canPIT then
        obj:queueLuaCommand('ai.setMode("chase")')
        self.state = 'chase'
      end
    end
  end
end

function C:endPursuit()
  self.flags.pursuit = nil
  self.targetId = nil
  self.state = 'none'
  -- Reset any other relevant state
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end