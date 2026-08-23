--!strict
-- Command: jaciup which <binary>

local Manager = require("../../toolchain/manager")
local Term = require("@klur/term")

return function(args: {string}): number
    local binaryName = args[1]
    if not binaryName or binaryName == "" then
        Term.error("Usage: jaciup which <binary>")
        return 1
    end

    local found = Manager.which(binaryName)
    if not found then
        Term.error("Binary '" .. binaryName .. "' not found in active toolchain")
        return 1
    end

    print(found)
    return 0
end
