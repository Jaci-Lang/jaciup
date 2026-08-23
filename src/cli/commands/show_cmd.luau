--!strict
-- Command: jaciup show

local Manager = require("../../toolchain/manager")
local Config = require("../../core/config")
local Term = require("@klur/term")

return function(_args: {string}): number
    local installed = Manager.listInstalled()
    local defaultTc = Config.getDefaultToolchain() or "none"
    local active, reason = Manager.resolveActiveToolchain()

    Term.log(Term.bold("Default host: ") .. process.os .. "-" .. process.arch)
    Term.log(Term.bold("Installed toolchains:"))

    if #installed == 0 then
        Term.log("  (no toolchains installed)")
    else
        for _, tc in ipairs(installed) do
            local marker = ""
            if tc == active then
                marker = Term.green(" (active, " .. reason .. ")")
            elseif tc == defaultTc then
                marker = Term.cyan(" (default)")
            end
            Term.log("  " .. tc .. marker)
        end
    end

    Term.log("")
    Term.log(Term.bold("Active toolchain: ") .. Term.green(active) .. " (" .. reason .. ")")
    return 0
end
