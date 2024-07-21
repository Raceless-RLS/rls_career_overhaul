-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min = math.min
local max = math.max
local abs = math.abs
local random = math.random
local huge = math.huge

local C = {}

local logTag = 'traffic'
local daylightValues = {0.22, 0.78} -- sunset & sunrise
local damageLimits = {25, 1000, 30000}
local baseSightDirValue = 200
local baseSightStrength = 500
local lowSpeed = 2.5
local tickTime = 0.25
local tempVec = vec3()

-- const vectors --
local vecUp = vec3(0, 0, 1)

function C:init(id, role)
  id = id or 0
  local obj = be:getObjectByID(id)
  if not obj then
    log('E', logTag, 'Unable to add vehicle object with id ['..id..'] to traffic!')
    return
  end

  local modelData = core_vehicles.getModel(obj.jbeam).model
  local modelType = modelData and string.lower(modelData.Type) or 'none'
  if obj.jbeam == 'unicycle' and obj:isPlayerControlled() then modelType = 'custom' end
  if not modelData or not arrayFindValueIndex({'car', 'truck', 'automation', 'traffic', 'custom'}, modelType) or obj.ignoreTraffic then
    log('W', logTag, 'Invalid vehicle type for traffic, now ignoring id ['..id..']')
    return
  end

  be:getObjectByID(id):setMeshAlpha(1, '') -- force vehicle to be visible

  self.vars = gameplay_traffic.getTrafficVars()
  self.policeVars = gameplay_police.getPoliceVars()
  self.damageLimits = damageLimits
  self.collisions = {}
  self.zones = {}
  self.playerData = {}

  self.id = id
  self.state = 'reset'
  self.enableRespawn = true
  self.enableTracking = true
  self.enableAutoPooling = true
  self.camVisible = true
  self.headlights = false
  self.isAi = false
  self.isPlayerControlled = obj:isPlayerControlled()

  self:resetAll()
  self:applyModelConfigData()
  self:setRole(role or self.autoRole)

  if core_trailerRespawn and core_trailerRespawn.getTrailerData()[id] then -- assumes that this vehicle will always respawn with a trailer attached
    self.hasTrailer = true
  end

  self.debugLine = true
  self.debugText = true

  self.pos, self.focusPos, self.dirVec, self.vel, self.driveVec = vec3(), vec3(), vec3(), vec3(), vec3()
  self.dist = 0
  self.distCam = 0
  self.damage = 0
  self.prevDamage = 0
  self.crashDamage = 0
  self.speed = 0
  self.alpha = 1
  self.respawnCount = 0
  self.tickTimer = 0
  self.activeProbability = 1
end

function C:applyModelConfigData() -- sets data that depends on the vehicle model & config, and returns the generated vehicle role
  local role = 'standard'
  local obj = be:getObjectByID(self.id)
  local modelData = core_vehicles.getModel(obj.jbeam).model
  local _, configKey = path.splitWithoutExt(obj.partConfig)
  local configData = core_vehicles.getModel(obj.jbeam).configs[configKey]

  local modelName = obj.jbeam
  local vehType = modelData.Type
  local configType = configData and configData['Config Type']
  local paintMode = 0
  local width = obj.initialNodePosBB:getExtents().x
  local length = obj.initialNodePosBB:getExtents().y

  if modelData.Name then
    modelName = modelData.Brand and modelData.Brand..' '..modelData.Name or modelData.Name
  end

  if modelData.paints and next(modelData.paints) and (not configType or configType == 'Factory' or vehType == 'Traffic') then
    paintMode = 1
  end

  local drivability = 0.25
  local offRoadScore = configData and configData['Off-Road Score']
  if offRoadScore then
    drivability = clamp(10 / max(1e-12, offRoadScore - 4 * max(0, width - 2) - 4 * max(0, length - 5)), 0, 1) -- minimum drivability
    -- large vehicles lower this value even more
  end

  local configTypeLower = string.lower(configType or '')
  if configTypeLower == 'police' or string.find(string.lower(obj.partConfig), 'police') then
    role = 'police'
  elseif configTypeLower == 'service' then -- TODO: check vehicle tags
    role = 'service'
  end

  self.autoRole = role
  self.model = {
    key = obj.jbeam,
    name = modelName,
    tags = configData and configData.Tags or {},
    paintMode = paintMode, -- paint action after respawning (0 = none, 1 = common, 2 = any)
    paintPaired = tostring(obj.color) == tostring(obj.colorPalette0) -- matching dual paint style (i.e. roamer)
  }
  self.width = width
  self.length = length
  self.drivability = drivability
  self.isPerson = obj.jbeam == 'unicycle'
end

function C:resetPursuit()
  if self.pursuit and self.pursuit.mode ~= 0 then
    gameplay_police.setPursuitMode(0, self.id)
  end
  self.pursuit = {mode = 0, score = 0, addScore = 0, policeCount = 0, hitCount = 0, offensesCount = 0, uniqueOffensesCount = 0, sightValue = 0,
  offenses = {}, offensesList = {}, roadblocks = 0, policeWrecks = 0, timers = {main = 0, arrest = 0, evade = 0, roadblock = 0, arrestValue = 0, evadeValue = 0}}
end

function C:resetTracking()
  self.tracking = {isOnRoad = true, isPublicRoad = true, side = 1, lastSide = 1, driveScore = 1, directionScore = 1, speedScore = 1, speedLimit = 20, collisions = 0, delay = -1}
end

function C:resetValues()
  self.pos = self.pos or be:getObjectByID(self.id):getPosition()
  self.respawn = {
    sightDirValue = baseSightDirValue, -- smoothed sight direction value, from -200 (behind you) to 200 (ahead of you)
    sightStrength = clamp(self.pos:distance(core_camera.getPosition()), baseSightStrength, baseSightStrength * 5), -- based on camera distance
    spawnDirBias = self.vars.spawnDirBias, -- probability of direction of next respawn, from -1 (towards you) to 1 (away from you)
    spawnRandomization = 1, -- spawn point search randomization (from 0 to 1; 0 = straight ahead, 1 = branching and scattering)
    spawnValue = self.vars.spawnValue, -- respawnability coefficient, from 0 (slow) to 3 (rapid); exactly 0 disables respawning
    spawnCoef = 1, -- coefficient for value in previous line
    finalSpawnValue = 1, -- calculated spawn value
    extraRadius = 0, -- additional radius to keep the vehicle from respawning
    finalRadius = 80 -- calculated radius to compare with player vehicle position and camera position
  }
  self.queuedFuncs = {} -- keys: timer, func, args, vLua (vLua string overrides func and args)
end

function C:resetElectrics()
  local obj = be:getObjectByID(self.id)
  obj:queueLuaCommand('electrics.set_lightbar_signal(0)')
  obj:queueLuaCommand('electrics.set_warn_signal(0)')
  obj:queueLuaCommand('electrics.horn(false)')
end

function C:resetAll() -- resets everything
  table.clear(self.collisions)
  self:resetPursuit()
  self:resetTracking()
  self:resetValues()
end

function C:honkHorn(duration) -- set horn with duration
  be:getObjectByID(self.id):queueLuaCommand('electrics.horn(true)')
  self.queuedFuncs.horn = {timer = duration or 1, vLua = 'electrics.horn(false)'}
end

function C:setAiMode(mode) -- sets the AI mode
  mode = mode or self.vars.aiMode

  local obj = be:getObjectByID(self.id)
  obj:queueLuaCommand('ai.setMode("'..mode..'")')
  obj:queueLuaCommand('ai.reset()')
  if mode == 'traffic' then
    obj:queueLuaCommand('ai.setAggression('..self.vars.baseAggression..')')
    obj:queueLuaCommand('ai.setSpeedMode("legal")')
    obj:queueLuaCommand('ai.driveInLane("on")')
  end

  self.isAi = mode ~= 'disabled'
end

function C:setAiAware(mode) -- sets the AI awareness
  mode = mode or self.vars.aiAware

  be:getObjectByID(self.id):queueLuaCommand('ai.setAvoidCars("'..mode..'")')
  be:getObjectByID(self.id):queueLuaCommand('ai.reset()') -- this is called to reset the AI plan
end

function C:setRole(roleName) -- sets the driver role
  roleName = roleName or 'standard'
  local prevName
  local roleClass = gameplay_traffic.getRoleConstructor(roleName)
  if roleClass then
    if self.role then -- only if there is a previous role
      prevName = self.role.name
      self.role:onRoleEnded()
    end

    self.role = roleClass({veh = self, name = roleName})
    self.role:onRoleStarted()
    extensions.hook('onTrafficAction', self.id, {targetId = self.role.targetId or 0, name = 'role'..string.sentenceCase(roleName), prevName = prevName and 'role'..string.sentenceCase(prevName), data = {}})
  end
end

function C:getInteractiveDistance(pos, squared) -- returns the distance of the "look ahead" point from this vehicle
  if pos then
    return squared and (self.focusPos):squaredDistance(pos) or (self.focusPos):distance(pos)
  else
    return huge
  end
end

function C:modifyRespawnValues(addSightStrength, addExtraRadius, addSpawnDirBias) -- instantly modifies respawn values (can be used to keep a vehicle active for longer)
  self.respawn.sightStrength = self.respawn.sightStrength + (addSightStrength or 0)
  self.respawn.extraRadius = self.respawn.extraRadius + (addExtraRadius or 0)
  self.respawn.spawnDirBias = clamp(self.respawn.spawnDirBias + (addSpawnDirBias or 0), -1, 1)
end

function C:getBrakingDistance(speed, accel) -- gets estimated braking distance
  -- prevents division by zero gravity
  local gravity = core_environment.getGravity()
  gravity = max(0.1, abs(gravity)) * sign2(gravity)

  return square(speed or self.speed) / (2 * (accel or self.role.driver.aggression) * abs(gravity))
end

function C:checkCollisions() -- checks for contact with other tracked vehicles
  for id, veh in pairs(map.objects) do
    if self.id ~= id then
      local isCurrentCollision = map.objects[id] and map.objects[id].objectCollisions[self.id] == 1

      if not self.collisions[id] and isCurrentCollision then -- init collision table
        local bb1 = be:getObjectByID(self.id):getSpawnWorldOOBB()
        local bb2 = be:getObjectByID(id):getSpawnWorldOOBB()

        if overlapsOBB_OBB(bb1:getCenter(), bb1:getAxis(0) * bb1:getHalfExtents().x, bb1:getAxis(1) * bb1:getHalfExtents().y, bb1:getAxis(2) * bb1:getHalfExtents().z, bb2:getCenter(), bb2:getAxis(0) * bb2:getHalfExtents().x, bb2:getAxis(1) * bb2:getHalfExtents().y, bb2:getAxis(2) * bb2:getHalfExtents().z) then
          self.collisions[id] = {state = 'active', inArea = false, speed = self.speed, vehDist = 0, damage = 0, dot = 0, count = 0, stop = 0}
        end
      end

      local collision = self.collisions[id]
      if collision then -- update existing collision table
        local dist = self.pos:squaredDistance(veh.pos)
        if isCurrentCollision then collision.damage = max(collision.damage, self.damage - self.prevDamage) end -- update damage value while in contact

        if not isCurrentCollision and dist > square(collision.vehDist + 1) then
          collision.inArea = false
        elseif isCurrentCollision and not collision.inArea then
          collision.vehDist = self.pos:distance(veh.pos)
          collision.inArea = true
          collision.count = collision.count + 1
          collision.dot = self.driveVec:dot((veh.pos - self.pos):normalized())
          if self.enableTracking then self.tracking.collisions = self.tracking.collisions + 1 end
          self.role:onCollision(id, collision)

          for otherId, otherVeh in pairs(gameplay_traffic.getTrafficData()) do -- notify other traffic vehicles of collision
            if not otherVeh.otherCollisionFlag and otherId ~= self.id and otherId ~= id then
              otherVeh.role:onOtherCollision(self.id, id, collision)
              otherVeh.otherCollisionFlag = true
            end
          end
        end

        if self.isAi then
          veh = gameplay_traffic.getTrafficData()[id]
          if veh and veh.isPerson then
            if isCurrentCollision and not self.role.flags.pullOver then
              self.role:setAction('pullOver')
            elseif not isCurrentCollision and self.role.flags.pullOver and dist > square(collision.vehDist + 3) then
              self.role:resetAction()
            end
          end
        end
      end
    else
      self.collisions[id] = nil
    end
  end
end

function C:trackCollision(otherId, dt) -- track and alter the state of the collision with other vehicle id
  otherId = otherId or 0
  local collision = self.collisions[otherId]
  local otherVeh = map.objects[otherId]
  if not collision or not otherVeh then return end

  local dist = self.pos:squaredDistance(otherVeh.pos)

  if collision.state == 'active' then
    if dist <= 2500 and self.speed <= lowSpeed then -- waiting near site of collision
      collision.stop = collision.stop + dt
      if collision.stop >= 5 then
        collision.state = 'resolved'
      end
    elseif dist > 2500 and self.speed > lowSpeed and self.driveVec:dot(self.pos - otherVeh.pos) > 0 then -- leaving site of collision
      collision.state = 'abandoned'
    end
  end
  if (collision.state == 'resolved' or collision.state == 'abandoned') and dist >= 14400 then -- clear collision data
    self.collisions[otherId] = nil
  end
end

function C:fade(rate, isFadeOut) -- fades vehicle mesh
  self.alpha = clamp(self.alpha + (rate or 0.1) * (isFadeOut and -1 or 1), 0, 1)
  be:getObjectByID(self.id):setMeshAlpha(self.alpha, '')

  if isFadeOut and self.alpha == 0 then
    self.state = 'queued'
  elseif not isFadeOut and self.alpha == 1 then
    self.state = 'active'
  end
end

function C:checkRayCast(startPos, endPos) -- returns true if ray reaches position, or false if hit detected
  startPos = startPos or self.pos
  endPos = endPos or self.pos
  tempVec:setSub2(endPos, startPos)
  local vecLen = tempVec:length()
  tempVec:setScaled(1 / max(1e-12, vecLen))
  return castRayStatic(startPos, tempVec, vecLen) >= vecLen
end

function C:tryRespawn(queueCoef) -- tests if the vehicle is out of sight and ready to respawn
  if not self.enableRespawn or self.respawn.finalSpawnValue <= 0 then
    self.respawn.sightDirValue = baseSightDirValue
    self.respawn.sightStrength = baseSightStrength
    return
  end

  if be:getObjectActive(self.id) then
    queueCoef = queueCoef or 1 -- used as a coefficient if method is called on a cycle (not every frame)
    self.respawn.playerRadius = clamp(self.respawn.finalRadius, 40, 200) -- base radius for active area
    tempVec:setSub2(self.pos, self.playerData.camPos)
    tempVec:normalize()
    local dotDirVecFromCam = self.playerData.camDirVec:dot(tempVec) -- directionality from camera
    local heightValue = max(0, square(self.playerData.camPos.z - self.pos.z) / 8 * dotDirVecFromCam) -- camera height augments final distance if generally looking at vehicle

    local sightCoef = -1 -- negative value reduces sight value until vehicle might respawn
    if self.camVisible then
      sightCoef = self.respawn.sightStrength <= 0 and 1 or 0
    end

    self.respawn.sightDirValue = lerp(self.respawn.sightDirValue, dotDirVecFromCam * 200, 0.01 * queueCoef) -- sight direction smoothing
    self.respawn.sightStrength = max(-self.respawn.playerRadius, self.respawn.sightStrength + sightCoef * queueCoef) -- updated sight strength value
    self.respawn.camRadius = self.respawn.playerRadius + max(0, self.respawn.sightDirValue + self.respawn.sightStrength + heightValue) -- maximum radius to check if the vehicle should stay active

    -- player radius, camera sight virtual radius
    if self.dist >= self.respawn.playerRadius and self.distCam >= self.respawn.camRadius then
      self.state = 'fadeOut'
    end
  else
    self.state = 'queued'
  end
end

function C:trackDriving(dt, fullTracking) -- basic tracking for how a vehicle drives on the road
  -- full tracking is heavier but tracks more driving data on the road
  -- this kind of functionality could be used in its own module
  local mapNodes = map.getMap().nodes
  local mapRules = map.getRoadRules()

  local n1, n2 = map.findClosestRoad(self.pos) -- may not be accurate at junctions
  local legalSide = mapRules.rightHandDrive and -1 or 1
  if n1 and mapNodes[n1] then
    local link = mapNodes[n1].links[n2] or mapNodes[n2].links[n1]
    self.tracking.isPublicRoad = link.type ~= 'private' and link.drivability >= self.vars.minRoadDrivability
    self.tracking.speedLimit = max(5.556, link.speedLimit)
    local overSpeedValue = clamp(self.speed / self.tracking.speedLimit, 1, 3) * dt * 0.1

    if self.tracking.isPublicRoad and self.speed >= self.tracking.speedLimit * 1.2 then
      self.tracking.speedScore = max(0, self.tracking.speedScore - overSpeedValue)
    else
      self.tracking.speedScore = min(1, self.tracking.speedScore + overSpeedValue)
    end

    if fullTracking then
      if (link.oneWay and link.inNode == n2) or (not link.oneWay and (mapNodes[n2].pos - mapNodes[n1].pos):dot(self.driveVec) < 0) then
        n1, n2 = n2, n1
      end

      local p1, p2 = mapNodes[n1].pos, mapNodes[n2].pos
      local dir = (p2 - p1):z0():normalized()
      local xnorm = clamp(self.pos:xnormOnLine(p1, p2), 0, 1)
      local roadPos = linePointFromXnorm(p1, p2, xnorm)
      local radius = lerp(mapNodes[n1].radius, mapNodes[n2].radius, xnorm)
      self.tracking.isOnRoad = self.pos:squaredDistance(roadPos) <= square(radius + 1)

      if self.tracking.isPublicRoad then
        local dirDot = self.driveVec:dot(dir)
        if self.speed > lowSpeed * 2 and self.tracking.isOnRoad and abs(dirDot) > 0.707 then -- player is driving parallel on the road
          if not link.oneWay then
            self.tracking.side = self.driveVec:z0():cross(vecUp):dot((self.pos - roadPos):z0()) * legalSide > 0 and 1 or -1 -- legal or illegal side
          else
            self.tracking.side = dirDot > 0 and 1 or -2 -- legal or illegal direction
          end
        else
          self.tracking.side = 1
        end

        -- reduces score if player is driving at speed on wrong side of the road (no logic for overtaking yet)
        -- TODO: in the future, track wrong side and wrong way separately
        if self.tracking.side < 0 then
          local speedCoef = (self.speed / self.tracking.speedLimit) * 0.08
          self.tracking.directionScore = max(0, self.tracking.directionScore + self.tracking.side * dt * speedCoef) -- decreases faster if wrong way on oneWay
        else
          self.tracking.directionScore = min(1, self.tracking.directionScore + dt * 0.05)
        end

        -- reduces score if player is driving recklessly (rapidly crossing lanes, doing donuts, etc.)
        if self.tracking.side ~= self.tracking.lastSide then
          self.tracking.driveScore = max(0, self.tracking.driveScore - 0.05) -- decreases per instance of side switch
        else
          self.tracking.driveScore = min(1, self.tracking.driveScore + dt * 0.02)
        end
      else
        self.tracking.driveScore, self.tracking.directionScore = 1, 1
      end

      if core_trafficSignals then
        if self.tracking.signalFault then
          self.tracking.signalFault = nil -- resets after one frame
        end

        local mapNodeSignals = core_trafficSignals.getMapNodeSignals()
        if not self.tracking.signal and mapNodeSignals[n1] and mapNodeSignals[n1][n2] then
          for _, signal in ipairs(mapNodeSignals[n1][n2]) do -- get best signal from current road segment
            local bestDist = 400
            if signal.target then
              local dist = self.pos:squaredDistance(signal.pos)
              if dist < bestDist then
                bestDist = dist
                self.tracking.signal = signal
                self.tracking.signalAction = nil
                self.tracking.signalFault = nil
              end
            end
          end
        end

        local signal = self.tracking.signal
        if signal then
          local instance = core_trafficSignals.getSignalByName(signal.instance)
          if instance and instance.targetPos then
            if (self.pos - instance.pos):dot(instance.dir) > 0 then
              if not self.tracking.signalAction then
                self.tracking.signalAction = signal.action

                if signal.action == 3 and self.speed > 5 then -- if speed is high enough at this moment, then the vehicle ignored the stop sign
                  self.tracking.signalFault = 1
                end
              end
            end
            if not instance:isVehAfterSignal(self.id) then -- vehicle exited signal bounds
              if self.tracking.signalAction == 2 then
                if self.speed > 14 then -- if speed is high enough, always trigger the red light violation
                  self.tracking.signalFault = 1
                else -- otherwise, check if the vehicle made a turn
                  local testDir = instance.dir:cross(vecUp)
                  testDir:setScaled(-legalSide)
                  testDir:setAdd(instance.dir)
                  testDir:normalize()
                  if self.driveVec:dot(testDir) > 0 then
                    self.tracking.signalFault = 1
                  end
                end
              end

              if self.tracking.signalAction or self.driveVec:dot(instance.dir) < 0 then -- invalidates current signal tracking
                self.tracking.signal = nil
              end
            end
          end
        end
      end
    else
      self.tracking.driveScore = 1
      self.tracking.directionScore = 1
      self.tracking.signalFault = nil
    end
  end
  self.tracking.lastSide = self.tracking.side

  if self.tracking.delay < 0 then
    self.tracking.delay = min(0, self.tracking.delay + dt)
  end
end

function C:triggerOffense(data) -- triggers a pursuit offense
  if not data or not data.key then return end
  data.score = data.score or 100
  if self.isAi then data.score = data.score * 0.5 end -- half score if the vehicle is AI controlled
  local key = data.key
  data.key = nil

  if not self.pursuit.offenses[key] then
    self.pursuit.offenses[key] = data
    table.insert(self.pursuit.offensesList, key)
    self.pursuit.uniqueOffensesCount = self.pursuit.uniqueOffensesCount + 1

    local tempData = deepcopy(data)
    tempData.key = key
    extensions.hook('onPursuitOffense', self.id, tempData)
  end
  self.pursuit.offensesCount = self.pursuit.offensesCount + 1
  self.pursuit.offenseFlag = true
  self.pursuit.addScore = self.pursuit.addScore + data.score
end

function C:checkOffenses() -- tests for vechicle offenses for police
  -- Offenses: speeding, racing, hitPolice, hitTraffic, reckless, wrongWay, intersection
  if self.policeVars.strictness <= 0 then return end
  local pursuit = self.pursuit
  local minScore = clamp(self.policeVars.strictness, 0, 0.8) -- offense threshold

  if self.tracking.speedScore <= minScore then
    if self.speed >= max(16.7, self.tracking.speedLimit * 1.2) and not pursuit.offenses.speeding then -- at least 60 km/h
      self:triggerOffense({key = 'speeding', value = self.speed, maxLimit = self.tracking.speedLimit, score = 100})
    end
    if self.speed >= max(27.8, self.tracking.speedLimit * 2) and not pursuit.offenses.racing then -- at least 100 km/h
      self:triggerOffense({key = 'racing', value = self.speed, maxLimit = self.tracking.speedLimit, score = 200})
    end
  end
  if self.tracking.driveScore <= minScore and not pursuit.offenses.reckless then
    self:triggerOffense({key = 'reckless', value = self.tracking.driveScore, minLimit = minScore, score = 250})
  end
  if self.tracking.directionScore <= minScore and not pursuit.offenses.wrongWay then
    self:triggerOffense({key = 'wrongWay', value = self.tracking.directionScore, minLimit = minScore, score = 150})
  end
  if self.tracking.signalFault and not pursuit.offenses.intersection then
    self:triggerOffense({key = 'intersection', value = 1, minLimit = 1, score = 200})
  end

  for id, coll in pairs(self.collisions) do
    local veh = gameplay_traffic.getTrafficData()[id]
    if veh then
      local validCollision = coll.dot >= 0.2 -- simple comparison to check if current vehicle is at fault for collision
      if veh.role.targetId ~= nil and veh.role.targetId ~= self.id then validCollision = false end -- ignore collision if other vehicle is targeting a different vehicle
      if self.isPerson then
        local center = vec3(be:getObjectOOBBCenterXYZ(id)) -- for accuracy
        validCollision = self.pos:z0():squaredDistance(center:z0()) < square(veh.width * 0.6) or coll.count >= 3 -- jumping on car, or multiple hits
      end

      if not coll.offense and validCollision then
        if veh.role.name == 'police' and coll.inArea then -- always triggers if police was hit
          self:triggerOffense({key = 'hitPolice', value = id, score = 200})
          pursuit.hitCount = pursuit.hitCount + 1
          coll.offense = true
        elseif pursuit.mode > 0 or coll.state == 'abandoned' then -- fleeing in a pursuit, or abandoning an accident
          self:triggerOffense({key = 'hitTraffic', value = id, score = 100})
          pursuit.hitCount = pursuit.hitCount + 1
          coll.offense = true
        end
      end
    end
  end
end

function C:pullOver()
  self.tracking.pullOver = 1
end

function C:checkTimeOfDay() -- checks time of day
  local timeObj = core_environment.getTimeOfDay()
  local isDaytime = true
  if timeObj and timeObj.time then
    isDaytime = (timeObj.time <= daylightValues[1] or timeObj.time >= daylightValues[2])
  end

  return isDaytime
end

function C:checkZones() -- tests vehicle position in zones
  if not gameplay_city then return end
  local sites = gameplay_city.getSites()
  if not sites or not sites.tagsToZones.traffic then return end
end

function C:onVehicleResetted() -- triggers whenever vehicle resets (automatically or manually)
  if self.role.flags.freeze then
    be:getObjectByID(self.id):queueLuaCommand('controller.setFreeze(0)')
    self.role.flags.freeze = false
  end
  self:resetTracking()
  self.crashDamage = 0
end

function C:onRespawn() -- triggers after vehicle respawns in traffic
  if self.model.paintMode and self.model.paintMode >= 1 then
    local paint
    if self.model.definedPaints then
      paint = self.model.definedPaints[random(#self.model.definedPaints)]
    else
      paint = getRandomPaint(self.id, self.model.paintMode == 1 and 0.75 or 0)
    end
    core_vehicle_manager.setVehiclePaintsNames(self.id, {paint, self.model.paintPaired and paint})
  end

  self.respawnCount = self.respawnCount + 1
  self.respawnActive = true
  self.crashActive = nil
  self.state = 'reset'
end

function C:onRefresh() -- triggers whenever vehicle data needs to be refreshed
  if self.isAi then
    local obj = be:getObjectByID(self.id)
    obj.uiState = settings.getValue('trafficMinimap') and 1 or 0

    self.vars = gameplay_traffic.getTrafficVars()
    self.policeVars = gameplay_police.getPoliceVars()
    self:resetAll()

    self:modifyRespawnValues(math.random(400)) -- randomly keeps some vehicles active for longer

    if self.vars.aiDebug == 'traffic' then
      obj:queueLuaCommand('ai.setVehicleDebugMode({debugMode = "off"})')
    else
      obj:queueLuaCommand('ai.setVehicleDebugMode({debugMode = "'..self.vars.aiDebug..'"})')
    end

    local isDaytime = self:checkTimeOfDay()

    if not isDaytime then
      self.respawn.spawnCoef = self.respawn.spawnCoef * 0.5
    end
    self.state = self.alpha == 1 and 'active' or 'fadeIn'

    if self.vars.aiMode ~= 'traffic' then -- disable traffic actions if AI mode is set to other than traffic
      self.role:resetAction()
      return
    end

    if self.tempRole then -- temp role gets cleared after vehicle gets refreshed
      self:setRole(self.autoRole)
      self.tempRole = nil
    end

    if not self.role.keepActionOnRefresh then
      self.role:resetAction()
    end
    if not self.role.keepPersonalityOnRefresh then
      self.role:applyPersonality(self.role:generatePersonality())
    end

    if self.vars.speedLimit then -- needs to be done after role stuff
      if self.vars.speedLimit >= 0 then
        obj:queueLuaCommand('ai.setSpeedMode("limit")')
        obj:queueLuaCommand('ai.setSpeed('..self.vars.speedLimit..')')
      else -- force legal speed
        obj:queueLuaCommand('ai.setSpeedMode("legal")')
      end
    end

    if self.vars.aiMode == 'traffic' and not self.vars.enablePrivateRoads then
      -- TODO: add this directly into ai.lua for traffic mode
      obj:queueLuaCommand('ai.setParameters({turnForceCoef = 0.02, awarenessForceCoef = 0.1})') -- improves driving
    end
  end

  self.tickTimer = 0
  self._teleport = nil
  self.role:onRefresh()
end

function C:onTrafficTick(tickTime)
  if self.enableTracking and not self.isPerson then
    self:trackDriving(tickTime, not self.isAi)
  else
    self.tracking.delay = 0
  end

  if self.state == 'active' and self.alpha < 1 then
    log('W', logTag, 'Vehicle that should be visible is invisible: '..tostring(self.id))
  end

  if self.isAi then
    self.camVisible = self:checkRayCast(self.playerData.camPos)

    local isDaytime = self:checkTimeOfDay()
    local terrainHeight = core_terrain.getTerrain() and core_terrain.getTerrainHeight(self.pos) or 0
    local terrainHeightDefault = core_terrain.getTerrain() and core_terrain.getTerrain():getPosition().z or 0
    local isTunnel = self.pos.z < terrainHeight
    if terrainHeight == terrainHeightDefault then -- no terrain, or out of terrain bounds
      local raisedPos = self.pos + vecUp * 10
      local sideVec = map.objects[self.id].dirVec:cross(map.objects[self.id].dirVecUp) * 5
      isTunnel = not self:checkRayCast(nil, raisedPos) and not self:checkRayCast(nil, raisedPos - sideVec) and not self:checkRayCast(nil, raisedPos + sideVec)
    end
    if (isTunnel or not isDaytime) and not self.headlights then
      if self.state == 'active' then
        self.queuedFuncs.headlights = {timer = 1 + random() * 4, vLua = 'electrics.setLightsState(1)'}
      else
        be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(1)')
      end
      self.headlights = true
    elseif (not isTunnel and isDaytime) and self.headlights then
      self.queuedFuncs.headlights = nil
      be:getObjectByID(self.id):queueLuaCommand('electrics.setLightsState(0)')
      self.headlights = false
    end
  end

  local tickDamage = self.damage - self.prevDamage
  self.crashDamage = max(self.crashDamage, tickDamage) -- highest tick damage experienced

  if tickDamage >= damageLimits[2] then
    self.role:onCrashDamage({speed = self.speed, damage = self.damage, tickDamage = tickDamage})

    for id, veh in pairs(gameplay_traffic.getTrafficData()) do
      if id ~= self.id then
        veh.role:onOtherCrashDamage(self.id, {speed = self.speed, damage = self.damage, tickDamage = tickDamage})
      end
    end

    if not self.crashActive then
      self:modifyRespawnValues(1000)
      self.crashActive = true
    end
  end

  self.prevDamage = self.damage

  self.role:onTrafficTick(tickTime)
end

function C:onUpdate(dt, dtSim)
  if not map.objects[self.id] then return end

  self.pos = map.objects[self.id].pos
  self.dirVec = map.objects[self.id].dirVec
  self.vel = map.objects[self.id].vel
  self.speed = self.isPerson and self.vel:z0():length() or self.vel:length()

  self.distCam = self.pos:distance(self.playerData.camPos)
  self.dist = self.playerData.pos ~= self.playerData.camPos and self.pos:distance(self.playerData.pos) or self.distCam

  if self.speed < 1 then
    self.driveVec = self.dirVec
  else
    self.driveVec:setScaled2(self.vel, 1 / (self.speed + 1e-12))
  end
  self.focusPos:setScaled2(self.driveVec, clamp(self.speed * 2, 20, 50))
  self.focusPos:setAdd2(self.pos, self.focusPos) -- virtual point ahead of vehicle trajectory, dependent on speed

  if (not be:getObjectActive(self.id) or self.state == 'active') and not self.enableRespawn then
    self.state = 'locked'
  elseif self.state == 'locked' and self.enableRespawn then
    self.state = 'reset'
  end

  if be:getObjectActive(self.id) then
    self.damage = map.objects[self.id].damage

    if self.isAi then
      if self.state == 'fadeOut' or self.state == 'fadeIn' then
        if self.state == 'fadeIn' then
          if self.respawnSpeed then
            -- obj:queueLuaCommand('thrusters.applyVelocity(obj:getDirectionVector() * '..(self.respawnSpeed * self.alpha)..')') -- makes vehicle start at speed
          end
          if self.damage >= 1000 and self.respawnActive and self.alpha > 0 then
            log('W', logTag, string.format('Traffic vehicle with id [%d] respawned with big damage! (%.1f, %.1f, %.1f)', self.id, self.pos.x, self.pos.y, self.pos.z))
            self:fade(1)
          end
        end
        self:fade(dtSim * 5, self.state == 'fadeOut')
      end

      if self.state == 'active' then
        if self.respawnActive then
          self.respawnActive = nil
          self.respawnSpeed = nil
        end

        self.respawn.finalSpawnValue = clamp(self.respawn.spawnValue * self.respawn.spawnCoef, 0, 3)
        self.respawn.finalRadius = self.respawn.extraRadius + 20 + 60 / (self.respawn.finalSpawnValue + 1e-12)
        if self.respawn.sightStrength > 0 then
          self.respawn.sightStrength = max(0, self.respawn.sightStrength - dtSim * self.respawn.finalSpawnValue * 40) -- linear reduce base sight strength
        end
      end
    end

    if self.vars.aiMode ~= 'traffic' then return end -- if main AI mode is not traffic, ignore everything below meant for traffic

    if self.enableTracking and self.tracking.delay == 0 then
      self:checkCollisions()

      for id, _ in pairs(self.collisions) do
        self:trackCollision(id, dtSim)
      end

      if self.role.name ~= 'police' and self.pursuit.policeVisible and not self.pursuit.cooldown then
        self:checkOffenses()
      end
    end

    self.tickTimer = self.tickTimer + dtSim
    if self.tickTimer >= tickTime then
      self:onTrafficTick(tickTime)
      self.tickTimer = self.tickTimer - tickTime
    end

    -- queued functions
    for k, v in pairs(self.queuedFuncs) do
      if not v.timer then v.timer = 0 end
      v.timer = v.timer - dtSim
      if v.timer <= 0 then
        if not v.vLua then
          v.func(unpack(v.args))
        else
          be:getObjectByID(self.id):queueLuaCommand(v.vLua)
        end
        self.queuedFuncs[k] = nil
      end
    end

    self.role:onUpdate(dt, dtSim)
  else
    self.camVisible = false
  end
end

function C:onSerialize()
  local data = {
    id = self.id,
    isAi = self.isAi,
    respawnCount = self.respawnCount,
    enableRespawn = self.enableRespawn,
    enableTracking = self.enableTracking,
    enableAutoPooling = self.enableAutoPooling,
    activeProbability = self.activeProbability,
    role = self.role:onSerialize()
  }

  return data
end

function C:onDeserialized(data)
  self.id = data.id
  self.isAi = data.isAi
  self.respawnCount = data.respawnCount
  self.enableRespawn = data.enableRespawn
  self.enableTracking = data.enableTracking
  self.enableAutoPooling = data.enableAutoPooling
  self.activeProbability = data.activeProbability

  self:applyModelConfigData()
  self:setRole(data.role.name)
  self:onRefresh()
  self.role:onDeserialized(data.role)
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  C.__index = C
  o:init(o.id)
  return o.model and o -- returns nil if invalid object
end