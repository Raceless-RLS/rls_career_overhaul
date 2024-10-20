local M = {}


local function onReset()
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
  electrics.values['lifter1'] = math.min(1, math.max(-0.1, (electrics.values['lifter1'] + electrics.values['lifter_input1'] * dt * 0.5)))
  
  electrics.values['lifter2'] = math.min(0.2, math.max(-1, (electrics.values['lifter2'] + electrics.values['lifter_input2'] * dt * 0.2)))

  electrics.values['telescopr'] = math.min(1, math.max(-0.0, (electrics.values['telescopr'] + electrics.values['telescop_input'] * dt * 0.2)))

  electrics.values['hand_steering'] = math.min(0.5, math.max(-0.5, (electrics.values['hand_steering'] + electrics.values['hand_input'] * dt * 0.2)))

  electrics.values['telescoper_winch'] = math.min(1, math.max(-1, (electrics.values['telescoper_winch'] + electrics.values['telescop_w_input'] * dt * 0.2)))

end


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
M.onInit    = onReset
M.onReset   = onReset
M.updateGFX = updateGFX
M.liftboom1 = liftboom1
M.liftboom2 = liftboom2
M.tele_trger = tele_trger
M.hand_out = hand_out
M.tele_w_trger = tele_w_trger

return M
