local M = {}

M.dependencies = {"career_career"}

local function openMenuFromComputer(computerId)
    print("Open sleep menu from computer: " .. computerId)
    if scenetree.tod then
        scenetree.tod.time = 0.775
        print("Set tod time to 0.775")
    end
end

local function onComputerAddFunctions(menuData, computerFunctions)
    if not menuData.computerFacility.functions["sleep"] then
        return
    end

    local computerFunctionData = {
        id = "sleep",
        label = "Sleep",
        callback = function()
            openMenuFromComputer(menuData.computerFacility.id)
        end,
        order = 20
    }

    computerFunctions.general[computerFunctionData.id] = computerFunctionData
end

M.onComputerAddFunctions = onComputerAddFunctions
return M
