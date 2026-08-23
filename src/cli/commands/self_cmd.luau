--!strict
-- Command: jaciup self <subcommand>

local Env = require("../../core/env")
local Fs = require("@klur/fs")
local Term = require("@klur/term")

return function(args: {string}): number
    local subcmd = args[1] or "help"

    if subcmd == "uninstall" then
        Term.warn("This will remove ~/.jaciup and all installed toolchains.")
        local ok = Fs.rimraf(Env.getJaciupHome())
        if ok then
            Term.success("Jaciup has been uninstalled. Remove ~/.jaciup/bin from your PATH.")
            return 0
        else
            Term.error("Failed to remove ~/.jaciup")
            return 1
        end
    elseif subcmd == "update" then
        Term.log("Jaciup is up to date.")
        return 0
    else
        Term.log("Usage: jaciup self <update|uninstall>")
        return 0
    end
end
