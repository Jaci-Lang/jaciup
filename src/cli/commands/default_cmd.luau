--!strict
-- Command: jaciup default <toolchain>

local Manager = require("../../toolchain/manager")
local Config = require("../../core/config")
local Term = require("@klur/term")

return function(args: {string}): number
    local channel = args[1]
    if not channel or channel == "" then
        Term.error("Usage: jaciup default <toolchain>")
        return 1
    end

    local clean = channel:gsub("^v", "")
    if not Manager.has(clean) then
        Term.log("Toolchain '" .. clean .. "' is not currently installed. Installing now...")
        local ok = Manager.install(clean)
        if not ok then
            return 1
        end
    end

    Config.setDefaultToolchain(clean)
    Term.success("Default toolchain set to '" .. clean .. "'")
    return 0
end
