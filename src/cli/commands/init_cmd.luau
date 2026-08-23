--!strict
-- Command: jaciup init (bootstrap toolchain & PATH)

local Env = require("../../core/env")
local Proxy = require("../../toolchain/proxy")
local Profile = require("../../shell/profile")
local Manager = require("../../toolchain/manager")
local Term = require("@klur/term")

return function(_args: {string}): number
    Term.log(Term.bold(Term.cyan("Initializing Jaciup Toolchain Manager...")))

    -- 1. Create directories
    Env.ensureDirectories()

    -- 2. Install binary shims
    Proxy.installShims()
    Term.success("Installed universal shims in " .. Env.getBinDir())

    -- 3. Configure shell PATH
    Profile.configurePath()

    -- 4. If no toolchain installed, prompt or install latest
    local installed = Manager.listInstalled()
    if #installed == 0 then
        Term.log("No toolchain installed yet. Installing latest Jaci release...")
        Manager.install("latest")
    end

    Term.success(Term.bold("Jaciup initialization complete!"))
    Term.log("Activate in this shell:  " .. Term.cyan(Profile.pathHintForShell(Env.getBinDir())))
    Term.log("Verify everything:       " .. Term.cyan("jaciup doctor"))
    return 0
end
