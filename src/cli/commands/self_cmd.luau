--!strict
-- Command: jaciup self <action>
--
-- Manages the jaciup bootstrap itself (not the toolchains it manages).
-- "jaciup self update" fetches the latest jaciup release from the Pop
-- releases API (https://pop.squareweb.app/v1/releases?product=jaciup) and
-- reinstalls it in place. No full CLI re-install / network mirror is required
-- beyond the single releases API + the artifact download.

local Env = require("../../core/env")
local Config = require("../../core/config")
local Download = require("../../toolchain/download")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Term = require("@klur/term")

local Self = {}

-- Locate the directory that holds the running jaciup bootstrap (bin/).
function Self.getSelfDir(): string?
    -- Prefer the JACIUP_BIN env set by the launcher; fall back to process.args[0].
    if process.env["JACIUP_BIN"] then
        return Path.dirname(process.env["JACIUP_BIN"])
    end
    if process.args and #process.args > 0 then
        local a0 = process.args[1]
        if a0 and a0 ~= "" then
            return Path.dirname(a0)
        end
    end
    return Env.getBinDir()
end

-- Pull the latest jaciup release for the current platform and install it.
function Self.update(): boolean
    local settings = Config.load()
    local registry = Config.getRegistryUrl()
    Term.log("info: querying releases API at " .. registry .. " for the latest jaciup release...")

    local release = Download.getLatestRelease("jaciup")
    if not release then
        Term.error("Could not reach the releases API.")
        return false
    end

    local version = release.version or release.tag
    local artifact = Download.selectArtifact(release)
    if not artifact or not artifact.url then
        Term.error("No jaciup artifact available for " .. (require("../core/platform").getTargetTriple()))
        return false
    end

    Env.ensureDirectories()
    Term.log("info: downloading jaciup " .. tostring(version) .. "...")
    local archive = Download.downloadAsset(nil, tostring(version), {}, "jaciup")
    if not archive then
        Term.error("Failed to download the jaciup release.")
        return false
    end

    local selfDir = Self.getSelfDir() or Env.getBinDir()
    local tmpExtract = Path.join(Env.getDownloadsDir(), "jaciup-self-update")
    Fs.rimraf(tmpExtract)
    Fs.mkdirp(tmpExtract)

    if not Download.extractZip(archive, tmpExtract) then
        Term.error("Failed to extract the jaciup release archive.")
        return false
    end

    -- Install over the current bootstrap directory.
    -- The archive contains a bin/ (jaciup launcher + shims) and src/ tree.
    local ok = Fs.copyDir(tmpExtract, selfDir)
    if ok then
        Term.success("jaciup updated to " .. tostring(version) .. " in " .. selfDir)
    else
        Term.error("Failed to install the updated jaciup into " .. selfDir)
        return false
    end

    return ok
end

return function(args: {string}): number
    local subcmd = args[1] or "help"

    if subcmd == "uninstall" then
        Term.warn("This will remove ~/.jaciup and all installed toolchains.")
        local ok = Fs.rimraf(Env.getJaciupHome())
        if ok then
            Term.success("Jaciup has been uninstalled. Remove ~/.jaciup/bin from your PATH.")
            return 0
        end
        Term.error("Failed to remove ~/.jaciup")
        return 1
    elseif subcmd == "update" then
        return Self.update() and 0 or 1
    elseif subcmd == "info" or subcmd == "version" then
        print("jaciup 0.1.0")
        return 0
    else
        Term.log("Usage: jaciup self <update|uninstall|info>")
        return 0
    end
end
