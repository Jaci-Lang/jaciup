--!strict
-- Command: jaciup run <toolchain> <command> [args...]

local Manager = require("../../toolchain/manager")
local Term = require("@klur/term")

return function(args: {string}): number
    local toolchain = args[1]
    local command = args[2]

    if not toolchain or not command then
        Term.error("Usage: jaciup run <toolchain> <command> [args...]")
        return 1
    end

    local restArgs: {string} = {}
    for i = 3, #args do
        table.insert(restArgs, args[i])
    end

    return Manager.run(toolchain, command, restArgs)
end
