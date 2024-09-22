-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local function canPay(price)
  for currency, info in pairs(price) do
    if not info.canBeNegative and career_modules_playerAttributes.getAttributeValue(currency) < info.amount then
      return false
    end
  end
  return true
end

local function pay(price, reason)
  if not canPay(price) then return false end
  local change = {}
  for currency, info in pairs(price) do
    change[currency] = -info.amount
  end
  career_modules_playerAttributes.addAttributes(change, reason)
  return true
end


local function reward(price, reason)
  local change = {}
  for currency, info in pairs(price) do
    change[currency] = info.amount
  end
  career_modules_playerAttributes.addAttributes(change, reason)
  return true
end

M.canPay = canPay
M.pay = pay
M.reward = reward

return M