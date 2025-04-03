-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.class = 'emergency'
  self.keepActionOnRefresh = false
  self.personalityModifiers = {
    aggression = {offset = 0.1}
  }
  self.veh.drivability = 0.5
  self.targetPursuitMode = 0
  self.avoidSpeed = 40 -- speed difference at which the police vehicle will try to dodge the target vehicle
  self.sirenTimer = -1
  self.cooldownTimer = -1
  self.driveInLane = true
  self.validTargets = {}
  self.actions = {
    pursuitStart = function (args)
      local firstMode = 'chase'
      local modeNum = 0
      local obj = getObjectByID(self.veh.id)

      if self.veh.isAi then
        obj:queueLuaCommand('ai.setSpeedMode("off")')
        obj:queueLuaCommand('ai.driveInLane("on")')

        if args.targetId then
          local targetVeh = gameplay_traffic.getTrafficData()[args.targetId]
          if targetVeh then
            modeNum = targetVeh.pursuit.mode
            firstMode = modeNum <= 1 and 'follow' or 'chase'
          end
        end

        if modeNum == 1 then -- passive
          self.veh:setAiMode('follow', true)
          self.veh:useSiren(0.5 + math.random())
          self.sirenTimer = 2 + math.random() * 2
        else -- aggressive
          self.veh:setAiMode('chase', true)
          obj:queueLuaCommand('electrics.set_lightbar_signal(2)')
          self.sirenTimer = -1
        end
      end

      self.targetPursuitMode = modeNum
      self.state = firstMode
      self.driveInLane = true
      self.flags.roadblock = nil
      self.flags.busy = 1
      self.cooldownTimer = -1
      self.avoidSpeed = math.random(18, 24) * modeNum -- speed difference for crash avoidance
      -- NOTE: maybe this crash avoidance should be in ai.lua

      if not self.flags.pursuit then -- only gets triggered once
        self.veh:modifyRespawnValues(500)
        self.flags.pursuit = 1
      end
    end,
    pursuitEnd = function ()
      if self.veh.isAi then
        self.veh:setAiMode('stop', true)
        getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(1)')
        self:setAggression()
      end
      self.flags.pursuit = nil
      self.flags.reset = 1
      self.flags.cooldown = 1
      self.cooldownTimer = 10
      self.state = 'stop'

      self.targetPursuitMode = 0
    end,
    chaseTarget = function ()
      self.veh:setAiMode('chase', true)
      getObjectByID(self.veh.id):queueLuaCommand('ai.driveInLane("off")')
      self.driveInLane = false
      self.state = 'chase'
    end,
    avoidTarget = function ()
      self.veh:setAiMode('flee', true)
      getObjectByID(self.veh.id):queueLuaCommand('ai.driveInLane("on")')
      self.driveInLane = true
      self.state = 'flee'
    end,
    roadblock = function ()
      if self.veh.isAi then
        self.veh:setAiMode('stop', true)
        getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(2)')
      end
      self.flags.roadblock = 1
      self.state = 'stop'
      self.veh:modifyRespawnValues(300, 40)
    end
  }

  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil
end

function C:checkTarget() -- returns the ideal target id, comparing the pursuit scores of all vehicles
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

  if self.flags.reset then
    self:resetAction()
  end

  local targetId = self:checkTarget()
  if targetId then
    self:setTarget(targetId)
    self.flags.targetVisible = nil
    local targetVeh = gameplay_traffic.getTrafficData()[targetId]
    if not targetVeh.pursuit.roadblockPos or (targetVeh.pursuit.roadblockPos and getObjectByID(self.veh.id):getPosition():squaredDistance(targetVeh.pursuit.roadblockPos) > 400) then
      -- ignores this if vehicle is at a roadblock
      self:setAction('pursuitStart', {targetId = targetId})
    end
    self.veh:modifyRespawnValues(750 - self.targetPursuitMode * 150)
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
      local interDist = self.veh:getInteractiveDistance(veh.pos, true) -- distance from this vehicle's look ahead point to the target vehicle

      self.validTargets[id].dist = self.veh.pos:squaredDistance(veh.pos)
      self.validTargets[id].interDist = interDist
      self.validTargets[id].visible = interDist <= 10000 and self:checkTargetVisible(id)

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

  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]
  if self.veh.isAi and targetVeh and self.state ~= 'disabled' and self.veh.state == 'active' then
    if self.flags.pursuit then
      if self.driveInLane and self.state ~= 'flee' and (self.veh.speed <= 1 or self.flags.targetVisible) then -- use all available lanes and racing lines
        -- TODO: this is a hack; we should enable the vehicle AI to naturally overtake traffic in lane mode
        getObjectByID(self.veh.id):queueLuaCommand('ai.driveInLane("off")')
        self.driveInLane = false
      end

      if self.validTargets[self.targetId].interDist <= 2500 then -- within 50 m of focus point of police vehicle
        self.avoidSpeed = self.avoidSpeed or 40
        if self.veh.speed >= 8 and targetVeh.speed >= 8 and self.veh.speed + targetVeh.speed >= self.avoidSpeed
        and targetVeh.driveVec:dot(self.veh.driveVec) <= -0.707 and (targetVeh.pos - self.veh.pos):normalized():dot(self.veh.driveVec) >= 0.707 then
          if self.state == 'chase' then
            self:setAction('avoidTarget') -- dodge target vehicle to avoid a head on collision
            self.actionTimer = 3
          end
        end
      end
    end

    if self.veh.damage > self.veh.damageLimits[3] then -- wrecked self during pursuit
      self:setAction('disabled')
      if self.flags.pursuit and self.veh.pos:squaredDistance(targetVeh.pos) <= 400 then
        targetVeh.pursuit.policeWrecks = targetVeh.pursuit.policeWrecks + 1
      end
    end
  end

  if self.enableTrafficSignalsChange and self.veh.speed >= 6 and next(map.objects[self.veh.id].states) then -- lightbar triggers all traffic lights to change to the red state
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
  local targetVeh = self.targetId and gameplay_traffic.getTrafficData()[self.targetId]

  if self.sirenTimer ~= -1 then
    if self.sirenTimer <= 0 then
      if self.veh.isAi and self.flags.pursuit and targetVeh and targetVeh.pursuit.mode >= 1 then
        local minSpeed = targetVeh.pursuit.initialSpeed or 0
        if targetVeh.pursuit.timers.main >= 8 or targetVeh.speed >= minSpeed + 5 then -- target is still driving, or target gained speed
          getObjectByID(self.veh.id):queueLuaCommand('electrics.set_lightbar_signal(2)') -- fully turn on lights and sirens
          self.sirenTimer = -1
        else
          if targetVeh.speed >= 2.5 then -- target is not fully stopped yet
            self.veh:useSiren(0.5 + math.random()) -- pulse lights and sirens
            self.sirenTimer = 2 + math.random() * 2
          end
        end
      else
        self.sirenTimer = -1
      end
    else
      self.sirenTimer = self.sirenTimer - dt
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

  if not self.flags.pursuit or self.state == 'none' then return end
  if not targetVeh or (targetVeh and not targetVeh.role.flags.flee) then
    self:resetAction()
    return
  end

  if self.veh.isAi then
    if self.state == 'disabled' then return end

    local distSq = self.veh.pos:squaredDistance(targetVeh.pos)
    local brakeDistSq = square(self.veh:getBrakingDistance(self.veh.speed, 1) + 20)
    local targetVisible = self.validTargets[self.targetId or 0] and self.validTargets[self.targetId].visible

    if self.actionTimer > 0 then
      self.actionTimer = self.actionTimer - dtSim
    end

    if self.flags.pursuit and self.state ~= 'none' and self.state ~= 'disabled' and self.veh.vars.aiMode == 'traffic' then
      if self.flags.roadblock then
        if targetVeh.pursuit.timers.evadeValue >= 0.5 or targetVeh.vel:dot((targetVeh.pos - targetVeh.pursuit.roadblockPos):normalized()) >= 9 then
          self:setAction('chaseTarget') -- exit roadblock mode
          self.flags.roadblock = nil
        end
      else
        local minSpeed = (4 - self.targetPursuitMode) * 3
        if self.targetPursuitMode < 3 and targetVisible and targetVeh.speed <= minSpeed and self.veh.speed >= 8 then
          if self.state == 'chase' and distSq <= brakeDistSq and targetVeh.driveVec:dot(targetVeh.pos - self.veh.pos) > 0 then -- pull over near target vehicle
            self:setAction('pullOver')
            self.actionTimer = gameplay_police.getPursuitVars().arrestTime + 5
          end
        else
          if self.state == 'pullOver' and (not targetVisible or targetVeh.speed > minSpeed) then
            self.actionTimer = 0
          end
        end

        if (self.state == 'flee' or self.state == 'pullOver') and self.actionTimer <= 0 then -- time out for other actions
          self:setAction('chaseTarget')
        end
      end
    end
  end
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end