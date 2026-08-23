--!strict
-- Command: jaciup update

local Manager = require("../../toolchain/manager")
local Config = require("../../core/config")
local Term = require("@klur/term")

return function(args: {string}): number
    local channel = args[1]
    if channel and channel ~= "" then
        Term.log("Updating toolchain '" .. channel .. "'...")
        local ok = Manager.install(channel)
        return ok and 0 or 1
    end

    local defaultTc = Config.getDefaultToolchain() or "latest"
    Term.log("Updating default toolchain '" .. defaultTc .. "'...")
    local ok = Manager.install(defaultTc)
    return ok and 0 or 1
end
