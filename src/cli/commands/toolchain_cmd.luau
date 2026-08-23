--!strict
-- Command: jaciup toolchain <subcommand>

local Manager = require("../../toolchain/manager")
local Config = require("../../core/config")
local Term = require("@klur/term")

local function printHelp()
    Term.log(Term.bold("Usage: jaciup toolchain <action> [options]"))
    Term.log("")
    Term.log("Actions:")
    Term.log("  install [channel]    Install a toolchain. Channel defaults to latest.")
    Term.log("                       Examples: 'latest', 'dev', '0.313.0'")
    Term.log("                       'klur' (re)installs the KLUR layer instead.")
    Term.log("  list                 List installed toolchains.")
    Term.log("  klur [channel]       (Re)install the KLUR layer for the active toolchain.")
    Term.log("  uninstall <name>     Remove an installed toolchain.")
    Term.log("  link <name> <path>   Link a local directory as a toolchain.")
    Term.log("")
    Term.log("Set the default with: " .. Term.cyan("jaciup default <name>"))
    Term.log("")
    Term.log("Examples:")
    Term.log("  " .. Term.cyan("jaciup toolchain install") .. "        Install the latest toolchain")
    Term.log("  " .. Term.cyan("jaciup toolchain link dev .") .. "      Use a local engine checkout")
end

return function(args: {string}): number
    local subcmd = args[1]

    if subcmd == nil or subcmd == "" or subcmd == "help" or subcmd == "-h" or subcmd == "--help" then
        printHelp()
        return 0
    end

    if subcmd == "list" then
        local installed = Manager.listInstalled()
        local defaultTc = Config.getDefaultToolchain()
        local active, _ = Manager.resolveActiveToolchain()

        if #installed == 0 then
            Term.log("No toolchains installed.")
            Term.log("")
            Term.log("Install one: " .. Term.cyan("jaciup toolchain install latest"))
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
        if channel == "klur" then
            -- 'klur' is a product (the KLUR layer), not an engine channel.
            -- Route the common mistake to the layer (re)install.
            Term.log("info: 'klur' is the KLUR product, not a toolchain channel — (re)installing the KLUR layer")
            local ok = Manager.installKlurForActive(nil)
            return ok and 0 or 1
        end
        local ok = Manager.install(channel)
        return ok and 0 or 1

    elseif subcmd == "klur" then
        local channel = args[2]
        local ok = Manager.installKlurForActive(channel)
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
        Term.error("Unknown toolchain action: " .. subcmd)
        Term.log("Run '" .. Term.cyan("jaciup toolchain help") .. "' for available actions.")
        return 1
    end
end
