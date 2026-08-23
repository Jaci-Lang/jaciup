--!strict
-- Command: jaciup toolchain <subcommand>

local Manager = require("../../toolchain/manager")
local Config = require("../../core/config")
local Term = require("@klur/term")

return function(args: {string}): number
    local subcmd = args[1] or "list"

    if subcmd == "list" then
        local installed = Manager.listInstalled()
        local defaultTc = Config.getDefaultToolchain()
        local active, _ = Manager.resolveActiveToolchain()

        if #installed == 0 then
            Term.log("No toolchains installed.")
            return 0
        end

        for _, tc in ipairs(installed) do
            local tags = {}
            if tc == active then table.insert(tags, "active") end
            if tc == defaultTc then table.insert(tags, "default") end

            local tagStr = #tags > 0 and (" (" .. table.concat(tags, ", ") .. ")") or ""
            Term.log(tc .. tagStr)
        end
        return 0

    elseif subcmd == "install" or subcmd == "add" then
        local channel = args[2] or "latest"
        local ok = Manager.install(channel)
        return ok and 0 or 1

    elseif subcmd == "uninstall" or subcmd == "remove" then
        local channel = args[2]
        if not channel or channel == "" then
            Term.error("Usage: jaciup toolchain uninstall <toolchain>")
            return 1
        end
        local ok = Manager.uninstall(channel)
        return ok and 0 or 1

    elseif subcmd == "link" then
        local name = args[2]
        local path = args[3]
        if not name or not path then
            Term.error("Usage: jaciup toolchain link <name> <path>")
            return 1
        end
        local ok = Manager.linkLocal(name, path)
        return ok and 0 or 1

    else
        Term.error("Unknown toolchain subcommand: " .. subcmd)
        Term.log("Available subcommands: list, install, uninstall, link")
        return 1
    end
end
