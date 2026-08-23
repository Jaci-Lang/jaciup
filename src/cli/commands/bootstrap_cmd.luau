--!strict
-- Command: jaciup bootstrap [version]
--
-- Install (or update) the jaciup bootstrap itself from the Pop releases API.
-- This is the "real bootstrap": it pulls a single platform artifact for the
-- current OS/arch, verifies its SHA-256, extracts it, and installs the jaciup
-- binary + shims in place -- without re-installing the whole CLI or a
-- network mirror. The same code path powers 'jaciup self update'.

local Env = require("../../core/env")
local Config = require("../../core/config")
local Download = require("../../toolchain/download")
local Platform = require("../../core/platform")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Term = require("@klur/term")

return function(args: {string}): number
    Env.ensureDirectories()
    local registry = Config.getRegistryUrl()
    local version = args[1]
    local prerelease = args[2] == "prerelease" or (args.flags and args.flags["prerelease"])

    if not version or version == "latest" or version == "stable" then
        Term.log("info: querying releases API at " .. registry .. " for the latest jaciup release...")
    else
        Term.log("info: fetching jaciup " .. version .. " from the releases API...")
    end

    local release = Download.resolveChannel(version or "latest", "jaciup")
    if not release then
        Term.error("Could not reach the releases API for jaciup.")
        return 1
    end

    local resolved = release.version or release.tag
    local artifact = Download.selectArtifact(release)
    if not artifact or not artifact.url then
        Term.error("No jaciup artifact available for " .. Platform.getTargetTriple())
        return 1
    end

    Term.log("info: downloading jaciup " .. tostring(resolved) .. " (" .. artifact.name .. ")...")
    local archive = Download.downloadAsset(nil, tostring(resolved), {}, "jaciup")
    if not archive then
        Term.error("Failed to download the jaciup release.")
        return 1
    end

    -- Install into the current bootstrap directory (or ~/.jaciup/bin fallback).
    local selfDir
    if process.env["JACIUP_BIN"] then
        selfDir = Path.dirname(process.env["JACIUP_BIN"])
    elseif process.args and #process.args > 0 and process.args[1] then
        selfDir = Path.dirname(process.args[1])
    end
    if not selfDir or selfDir == "" then
        selfDir = Env.getBinDir()
    end

    local tmpExtract = Path.join(Env.getDownloadsDir(), "jaciup-bootstrap")
    Fs.rimraf(tmpExtract)
    Fs.mkdirp(tmpExtract)

    if not Download.extractZip(archive, tmpExtract) then
        Term.error("Failed to extract the jaciup release archive.")
        return 1
    end

    if not Fs.copyDir(tmpExtract, selfDir) then
        Term.error("Failed to install jaciup into " .. selfDir)
        return 1
    end

    Term.success("jaciup bootstrap " .. tostring(resolved) .. " installed in " .. selfDir)
    Term.log("Run 'jaciup init' to configure your shell PATH and shims.")
    return 0
end
