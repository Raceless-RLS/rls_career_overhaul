local M = {}

local maxAssets = 6
local maxActiveAssets = 2
local ActiveAssets = {}
ActiveAssets.__index = ActiveAssets

local activeAssets = nil

function ActiveAssets.new()
    local self = setmetatable({}, ActiveAssets)
    self.assets = {} -- Ensure this is always initialized as an empty table
    return self
end

function ActiveAssets:addAssetList(triggerName, newAssets)
    if not self.assets then
        self.assets = {} -- Reinitialize if it's somehow nil
    end
    -- Create a new asset list for this trigger
    local assetList = {
        triggerName = triggerName,
        assets = newAssets
    }

    -- Add the new asset list
    table.insert(self.assets, assetList)

    -- If we exceed maxActiveAssets, remove and hide the oldest asset list
    if #self.assets > maxActiveAssets then
        local oldestAssetList = table.remove(self.assets, 1)
        self:hideAssetList(oldestAssetList)
    end
end

function ActiveAssets:hideAssetList(assetList)
    if assetList and assetList.assets then
        for _, asset in ipairs(assetList.assets) do
            if asset then
                asset:setHidden(true)
            end
        end
    end
end

function ActiveAssets:hideAllAssets()
    if not self.assets then
        self.assets = {} -- Reinitialize if it's nil
        return
    end
    for _, assetList in ipairs(self.assets) do
        self:hideAssetList(assetList)
    end
    self.assets = {}
end

function ActiveAssets:getOldestAssetList()
    if not self.assets or #self.assets == 0 then
        return nil
    end
    return self.assets[1]
end

-- Function to display assets
local function displayAssets(data, activeAssets)
    local triggerName = data.triggerName
    local newAssets = {}

    -- Unhide assets and add them to newAssets table
    for i = 0, maxAssets - 1 do
        local assetName = triggerName .. "asset" .. i
        local asset = scenetree.findObject(assetName)
        if asset then
            asset:setHidden(false)
            table.insert(newAssets, asset)
        else
            break -- Stop if an asset is not found
        end
    end

    if #newAssets == 0 then
        return
    end

    activeAssets:addAssetList(triggerName, newAssets)

    if #activeAssets.assets == maxActiveAssets then
        local oldestAssetList = activeAssets:getOldestAssetList()
    end

end

local function onInit()
    print("Initializing Active Assets")
    activeAssets = ActiveAssets.new()
end


M.onInit = onInit
M.displayAssets = displayAssets
M.ActiveAssets = ActiveAssets

return M