local M = {}

local function onReset()
  -- Original pickup bed controls
  electrics.values['tilt'] = 0
  electrics.values['tilt_input'] = 0
  electrics.values['extend'] = 0
  electrics.values['extend_input'] = 0
  electrics.values['feet'] = 0
  electrics.values['feet_input'] = 0

  -- Crane controls
  electrics.values['lifter1'] = 0.5
  electrics.values['lifter_input1'] = 0
  electrics.values['lifter2'] = 0
  electrics.values['lifter_input2'] = -1
  electrics.values['telescopr'] = 0
  electrics.values['telescop_input'] = 0
  electrics.values['hand_steering'] = 0
  electrics.values['hand_input'] = 0
  electrics.values['telescoper_winch'] = 0
  electrics.values['telescop_w_input'] = 0
end

local function updateGFX(dt) -- ms
  -- Original pickup bed controls
  electrics.values['tilt'] = math.min(1, math.max(-0.0, (electrics.values['tilt'] + electrics.values['tilt_input'] * dt * 0.25)))
  electrics.values['extend'] = math.min(1, math.max(-0.0, (electrics.values['extend'] + electrics.values['extend_input'] * dt * 0.25)))
  electrics.values['feet'] = math.min(1, math.max(-0.0, (electrics.values['feet'] + electrics.values['feet_input'] * dt * 1.25)))

  -- Crane controls
  electrics.values['lifter1'] = math.min(1, math.max(-0.1, (electrics.values['lifter1'] + electrics.values['lifter_input1'] * dt * 0.5)))
  electrics.values['lifter2'] = math.min(0.2, math.max(-1, (electrics.values['lifter2'] + electrics.values['lifter_input2'] * dt * 0.2)))
  electrics.values['telescopr'] = math.min(1, math.max(-0.0, (electrics.values['telescopr'] + electrics.values['telescop_input'] * dt * 0.2)))
  electrics.values['hand_steering'] = math.min(0.5, math.max(-0.5, (electrics.values['hand_steering'] + electrics.values['hand_input'] * dt * 0.2)))
  electrics.values['telescoper_winch'] = math.min(1, math.max(-1, (electrics.values['telescoper_winch'] + electrics.values['telescop_w_input'] * dt * 0.2)))
end

-- Original pickup bed functions
local function tiltBed(value)
  electrics.values.tilt_input = value
end

local function extendBed(value)
  electrics.values.extend_input = value
end

local function extendFeet(value)
  electrics.values.feet_input = value
end

-- Crane functions
local function liftboom1(value)
  electrics.values.lifter_input1 = value
end

local function liftboom2(value)
  electrics.values.lifter_input2 = value
end

local function tele_trger(value)
  electrics.values.telescop_input = value
end

local function hand_out(value)
  electrics.values.hand_input = value
end

local function tele_w_trger(value)
  electrics.values.telescop_w_input = value
end

-- public interface
M.onInit = onReset
M.onReset = onReset
M.updateGFX = updateGFX

-- Original pickup bed exports
M.tiltBed = tiltBed
M.extendBed = extendBed
M.extendFeet = extendFeet

-- Crane exports
M.liftboom1 = liftboom1
M.liftboom2 = liftboom2
M.tele_trger = tele_trger
M.hand_out = hand_out
M.tele_w_trger = tele_w_trger

return M