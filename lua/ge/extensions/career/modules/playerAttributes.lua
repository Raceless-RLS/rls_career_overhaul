-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local dlog = function(m) log("D","",m) end -- set to nop to disable loggin

M.dependencies = {'career_career', "career_modules_log"}

local attributes
local attributeLog
local baseAttribute = {value = 0, gains = {}, losses = {}}

local function init()
  attributeLog = {}
  attributes = {}
  attributes["beamXP"] = deepcopy(baseAttribute)
  attributes["money"] = deepcopy(baseAttribute)
  attributes["bonusStars"] = deepcopy(baseAttribute)
  for _, branch in ipairs(career_branches.getSortedBranches()) do
    attributes[branch.attributeKey] = deepcopy(baseAttribute)
    attributes[branch.attributeKey].value = branch.defaultValue or baseAttribute.value
  end
  local startingCapital = 17500
  if not career_career.tutorialEnabled then
    startingCapital = startingCapital + 5500
  end
  M.setAttributes({money=startingCapital}, {label="Starting Capital"})
end

local function addAttributes(change, reason)

  -- make sure a reason exists!
  if not reason then
    reason = {
      label = "Unknown Reason",
      origin = debug.tracesimple()
    }
    log("W","",string.format("Changed attributes '%s' without giving a reason!", table.concat( tableKeysSorted(change), ", ")))
  end

  -- convert tags into LUT
  if not reason.tags then reason.tags = {} end
  reason.tags = tableValuesAsLookupDict(reason.tags)

  -- make statistic
  for attributeName, value in pairs(change) do
    attributes[attributeName] = attributes[attributeName] or deepcopy(baseAttribute)
    local attribute = attributes[attributeName]
    attribute.value = attribute.value + value
    for tag, en in pairs(reason.tags) do
      if en and value > 0 then
        attribute.gains[tag] = (attribute.gains[tag] or 0) + value
      end
      if en and value < 0 then
        attribute.losses[tag] = (attribute.losses[tag] or 0) + value
      end
    end
    if value > 0 then
      attribute.gains.all = (attribute.gains.all or 0) + value
    end
    if value < 0 then
      attribute.losses.all = (attribute.losses.all or 0) + value
    end
  end

  -- log change for logbook etc
  table.insert(attributeLog, {
    attributeChange = change,
    reason = reason,
    time = os.time()
  })

  -- always use the internal log system
  career_modules_log.addLog(reason.label, "playerAttributes")

  -- notify other systems
  extensions.hook("onPlayerAttributesChanged",change, reason)
end

local function setAttributes(newValues, reason)
  local ch = {}
  for attributeName, newValue in pairs(newValues) do
    local attribute = attributes[attributeName] or deepcopy(baseAttribute)
    ch[attributeName] = newValues[attributeName] - attribute.value
  end
  M.addAttributes(ch, reason)
end

local function getAttribute(attributeName)
  return attributes[attributeName]
end
local function getAttributeValue(attributeName)
  return (attributes[attributeName] or baseAttribute).value
end

local function getAllAttributes()
  return attributes
end

local function onExtensionLoaded()
  if not career_career.isActive() then return false end
  if not attributes then
    init()
  end

  -- load from saveslot
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  local jsonData = (savePath and jsonReadFile(savePath .. "/career/playerAttributes.json")) or {}

  for name, data in pairs(jsonData) do
    attributes[name] = attributes[name] or deepcopy(baseAttribute)
    for k,v in pairs(data) do
      attributes[name][k] = v
    end
  end

  attributeLog = (savePath and jsonReadFile(savePath .. "/career/attributeLog.json")) or attributeLog
end

-- this should only be loaded when the career is active
local function onSaveCurrentSaveSlot(currentSavePath)
  career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/playerAttributes.json", attributes, true)
  career_saveSystem.jsonWriteFileSafe(currentSavePath .. "/career/attributeLog.json", attributeLog, true)
end



-- logbook integration
local function onLogbookGetEntries(list)

  local financialsText = '<span>Below is an overview of how you spent and earned money.<ul><li><b>Earn money</b> by playing Challenges and completing new Objectives, or by selling Vehicles and Parts.</li><li><b>Spend your Money</b> on new Vehicles and Parts, Insurances and Repairs, or by taking a Taxi.</li></ul><span><i>Disclaimer: Financial values are not balanced yet across the whole of career mode. So you might end up with too much or too little money in the long run.</i></span></span>'
  local financialsTable = {
    headers = {'Reason','Change','Time'},
    rows = {}
  }
  for _, change in ipairs(arrayReverse(deepcopy(attributeLog))) do
    if change.attributeChange.money then
      --local changeText = ""
      --local key = "money"
      --changeText = changeText .. string.format('<span><b>%s</b>: %s%0.2f</span>', key, change.attributeChange[key] > 0 and "+" or "", change.attributeChange[key])

      table.insert(financialsTable.rows,
        {change.reason.label, {type="rewards", rewards = {{attributeKey ="money", rewardAmount=change.attributeChange.money}}}, os.date("%c",change.time)}
      )
    end
  end

  local formattedFinancials = {
    entryId = "playerAttributeFinancials",
    type = "progress",
    cardTypeLabel = "ui.career.poiCard.generic",
    title = "Financial History",
    text = financialsText,
    time = os.time(),
    hideInRecent = true,
    tables = {financialsTable}
  }
  table.insert(list, formattedFinancials)

  local gameplayText = '<span style="margin-bottom:0.5em">Below is an overview of rewards you earned from Challenges, Milestones and Deliveries.<ul><li><b>Money</b> can be used to make purchases.</li><li><b>Beam XP</b> is a measure of your overall general progress, but has no use in game currently.</li><li><b>Branch XP</b> for the four branches will let you reach the next tier of that branch, unlocking new missions.</li><li><b>Bonus Stars</b> can currently only be used for fast repairs.</li></ul></span>'
  local gameplayTable = {
    headers = {'Reason','Change','Time'},
    rows = {}
  }
  for _, change in ipairs(arrayReverse(deepcopy(attributeLog))) do
    if change.reason.tags.gameplay then
      --local changeText = ""
      local rewards = {}
      for _, key in ipairs(career_branches.orderAttributeKeysByBranchOrder(tableKeys(change.attributeChange))) do
        table.insert(rewards, {attributeKey = key, rewardAmount = change.attributeChange[key] })
      --  changeText = changeText .. string.format('<span><b>%s</b>: %s%0.2f</span><br>', key, change.attributeChange[key] > 0 and "+" or "", change.attributeChange[key])
      end
      table.insert(gameplayTable.rows,
        {change.reason.label, {type="rewards", rewards = rewards}, os.date("%c",change.time)}
      )
    end
  end

  local formattedGameplay = {
    entryId = "playerAttributeGameplay",
    type = "progress",
    cardTypeLabel = "ui.career.poiCard.generic",
    title = "Rewards History",
    text = gameplayText,
    time = os.time()-1,
    hideInRecent = true,
    tables = {gameplayTable}
  }
  table.insert(list, formattedGameplay)

end

M.addAttributes = addAttributes
M.setAttributes = setAttributes
M.getAttribute = getAttribute
M.getAttributeValue = getAttributeValue
M.getAllAttributes = getAllAttributes
M.getAttributeLog = function() return attributeLog end

M.logAttributeChange = logAttributeChange
M.onLogbookGetEntries = onLogbookGetEntries
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onExtensionLoaded = onExtensionLoaded
return M