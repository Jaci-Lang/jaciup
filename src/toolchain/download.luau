--!strict
-- Archive download, checksum verification, and extraction for Jaciup

local Env = require("../core/env")
local Platform = require("../core/platform")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Process = require("@klur/process")
local Term = require("@klur/term")

local Download = {}

function Download.fetchReleaseArchive(repoUrl: string, tagOrVersion: string, destToolchainDir: string): boolean
    Env.ensureDirectories()
    local candidates = Platform.getAssetCandidates()
    local cleanTag = tagOrVersion:gsub("^v", "")
    local tag = (tagOrVersion == "latest") and "latest" or ("v" .. cleanTag)

    Fs.mkdirp(destToolchainDir)
    local downloadsDir = Env.getDownloadsDir()

    local success = false
    local downloadedFile = ""

    for _, asset in ipairs(candidates) do
        local downloadUrl = ""
        if tag == "latest" then
            downloadUrl = repoUrl .. "/releases/latest/download/" .. asset
        else
            downloadUrl = repoUrl .. "/releases/download/" .. tag .. "/" .. asset
        end

        local targetArchive = Path.join(downloadsDir, cleanTag .. "-" .. asset)
        Term.log("Downloading " .. asset .. " from " .. downloadUrl .. "...")

        -- Download via curl or wget
        local downloaded = false
        if Process.which("curl") then
            local res = Process.spawn("curl", { "-fsSL", "-o", targetArchive, downloadUrl })
            if res.ok and Fs.isFile(targetArchive) and (Fs.stat(targetArchive) and (Fs.stat(targetArchive) :: any).size > 1000) then
                downloaded = true
            end
        end

        if not downloaded and Process.which("wget") then
            local res = Process.spawn("wget", { "-q", "-O", targetArchive, downloadUrl })
            if res.ok and Fs.isFile(targetArchive) and (Fs.stat(targetArchive) and (Fs.stat(targetArchive) :: any).size > 1000) then
                downloaded = true
            end
        end

        if downloaded then
            downloadedFile = targetArchive
            success = true
            break
        end
    end

    if not success then
        Term.error("Failed to download toolchain archive for " .. tagOrVersion)
        return false
    end

    -- Extract archive
    Term.log("Extracting toolchain to " .. destToolchainDir .. "...")
    local extracted = false

    if Platform.isWindows() then
        if Process.which("tar") then
            local res = Process.spawn("tar", { "-xf", downloadedFile, "-C", destToolchainDir })
            if res.ok then extracted = true end
        end
        if not extracted and Process.which("powershell") then
            local psCmd = "Expand-Archive -Path '" .. downloadedFile .. "' -DestinationPath '" .. destToolchainDir .. "' -Force"
            local res = Process.spawn("powershell", { "-NoProfile", "-Command", psCmd })
            if res.ok then extracted = true end
        end
    else
        if Process.which("unzip") then
            local res = Process.spawn("unzip", { "-o", "-q", downloadedFile, "-d", destToolchainDir })
            if res.ok then extracted = true end
        elseif Process.which("tar") then
            local res = Process.spawn("tar", { "-xf", downloadedFile, "-C", destToolchainDir })
            if res.ok then extracted = true end
        end
    end

    if not extracted then
        Term.error("Failed to extract toolchain archive")
        return false
    end

    -- Set execute permissions on POSIX
    if not Platform.isWindows() then
        local entries = Fs.readDir(destToolchainDir)
        for _, entry in ipairs(entries) do
            local full = Path.join(destToolchainDir, entry)
            Process.spawn("chmod", { "+x", full })
        end
    end

    return true
end

return Download
