--!strict
-- Command: jaciup bootstrap [version]
--
-- Install (or update) jaciup itself from the Pop releases API. Pulls the
-- platform binary for the current OS/arch, verifies its SHA-256 (via the
-- release manifest), extracts it, and installs it into ~/.jaciup/bin in
-- place. The same code path powers 'jaciup self update'.

local Env = require("../../core/env")
local Download = require("../../toolchain/download")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Term = require("@klur/term")

return function(args: {string}): number
    Env.ensureDirectories()
    local version = args[1]
    if not version or version == "latest" or version == "stable" then
        Term.log("info: querying the releases API for the latest jaciup release...")
    else
        Term.log("info: fetching jaciup " .. version .. " from the releases API...")
    end

    local release = Download.resolveChannel(version or "latest", "jaciup")
    if not release then
        Term.error("Could not reach the releases API for jaciup.")
        return 1
    end
    local resolved = tostring(release.version or release.tag)

    -- downloadAsset resolves the release manifest (artifacts with url and
    -- sha256) and verifies the checksum after download.
    Term.log("info: downloading jaciup " .. resolved .. "...")
    local archive = Download.downloadAsset(nil, resolved, {}, "jaciup")
    if not archive then
        Term.error("Failed to download the jaciup release.")
        return 1
    end

    -- The jaciup binary always lives in ~/.jaciup/bin (the PATH directory).
    local selfDir = Env.getBinDir()

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

    Term.success("jaciup bootstrap " .. resolved .. " installed in " .. selfDir)
    Term.log("Run 'jaciup init' to configure your shell PATH and shims.")
    return 0
end
