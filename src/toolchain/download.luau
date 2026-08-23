--!strict
-- Archive download, checksum verification, and CDN/API client for Jaciup

local Env = require("../core/env")
local Config = require("../core/config")
local Platform = require("../core/platform")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Process = require("@klur/process")
local Crypto = require("@klur/crypto")
local Serde = require("@klur/serde")
local Term = require("@klur/term")

local Download = {}

function Download.fetchJson(url: string): any
    if Process.which("curl") then
        local res = Process.spawn("curl", { "-fsSL", "-H", "Accept: application/json", url })
        if res.ok and res.stdout and #res.stdout > 0 then
            local ok, data = pcall(function()
                return Serde.json.parse(res.stdout)
            end)
            if ok and data then
                return data
            end
        end
    end
    return nil
end

function Download.getLatestRelease(product: string?, prerelease: boolean?): any
    local prod = product or "jaci"
    local base = Config.getRegistryUrl():gsub("/+$", "")
    local url = base .. "/v1/releases/latest?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    return Download.fetchJson(url)
end

function Download.listReleases(product: string?, prerelease: boolean?): any
    local prod = product or "jaci"
    local base = Config.getRegistryUrl():gsub("/+$", "")
    local url = base .. "/v1/releases?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    return Download.fetchJson(url)
end

function Download.getManifest(version: string, product: string?, prerelease: boolean?): any
    local prod = product or "jaci"
    local base = Config.getRegistryUrl():gsub("/+$", "")
    local cleanVer = version:gsub("^v", "")
    local url = base .. "/v1/releases/" .. cleanVer .. "/manifest?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    return Download.fetchJson(url)
end

function Download.downloadFile(url: string, targetPath: string): boolean
    if Process.which("curl") then
        local res = Process.spawn("curl", { "-fSL", "-o", targetPath, url })
        if res.ok and Fs.isFile(targetPath) and (Fs.stat(targetPath) and (Fs.stat(targetPath) :: any).size > 100) then
            return true
        end
    end

    if Process.which("wget") then
        local res = Process.spawn("wget", { "-q", "-O", targetPath, url })
        if res.ok and Fs.isFile(targetPath) and (Fs.stat(targetPath) and (Fs.stat(targetPath) :: any).size > 100) then
            return true
        end
    end

    return false
end

function Download.verifySha256(filePath: string, expectedSha256: string): boolean
    if expectedSha256 == "" or not expectedSha256 then
        return true
    end
    local content = Fs.readFile(filePath)
    local actualHash = Crypto.sha256Hex(content):lower()
    local expected = expectedSha256:lower():gsub("%s+", "")
    return actualHash == expected
end

function Download.downloadAsset(repoUrl: string, version: string, candidates: {string}, product: string?): string?
    Env.ensureDirectories()
    local prod = product or "jaci"
    local cleanTag = version:gsub("^v", "")
    local downloadsDir = Env.getDownloadsDir()
    local targetTriple = Platform.getTargetTriple()

    -- 1. Try fetching manifest from CDN / Releases API
    Term.log("info: querying releases API for product '" .. prod .. "' version '" .. cleanTag .. "'...")
    local manifest = Download.getManifest(cleanTag, prod)
    if not manifest and cleanTag == "latest" then
        manifest = Download.getLatestRelease(prod)
    end

    if manifest and manifest.artifacts and type(manifest.artifacts) == "table" then
        local artifactInfo = manifest.artifacts[targetTriple]
        if artifactInfo and artifactInfo.url then
            local archiveName = prod .. "-" .. cleanTag .. "-" .. targetTriple .. ".zip"
            local targetPath = Path.join(downloadsDir, archiveName)

            Term.log("info: downloading artifact from CDN: " .. artifactInfo.url)
            local ok = Download.downloadFile(artifactInfo.url, targetPath)
            if ok then
                if artifactInfo.sha256 and artifactInfo.sha256 ~= "" then
                    Term.log("info: verifying SHA-256 checksum...")
                    if not Download.verifySha256(targetPath, artifactInfo.sha256) then
                        Term.error("Checksum verification failed for " .. archiveName)
                        Fs.removeFile(targetPath)
                        return nil
                    end
                    Term.success("Checksum verified: " .. artifactInfo.sha256:sub(1, 16) .. "...")
                end
                return targetPath
            end
        end
    end

    -- 2. Fallback to direct mirror / GitHub Releases download
    local tag = (cleanTag == "latest") and "latest" or ("v" .. cleanTag)
    Term.log("info: CDN manifest not found, falling back to direct mirror: " .. repoUrl)

    for _, asset in ipairs(candidates) do
        local downloadUrl = ""
        if tag == "latest" then
            downloadUrl = repoUrl .. "/releases/latest/download/" .. asset
        else
            downloadUrl = repoUrl .. "/releases/download/" .. tag .. "/" .. asset
        end

        local targetArchive = Path.join(downloadsDir, cleanTag .. "-" .. asset)
        Term.log("Downloading " .. asset .. " from " .. downloadUrl .. "...")

        local ok = Download.downloadFile(downloadUrl, targetArchive)
        if ok then
            return targetArchive
        end
    end

    return nil
end

function Download.extractZip(downloadedFile: string, destDir: string): boolean
    Term.log("Extracting archive to " .. destDir .. "...")
    Fs.mkdirp(destDir)
    local extracted = false

    if Platform.isWindows() then
        if Process.which("tar") then
            local res = Process.spawn("tar", { "-xf", downloadedFile, "-C", destDir })
            if res.ok then extracted = true end
        end
        if not extracted and Process.which("powershell") then
            local psCmd = "Expand-Archive -Path '" .. downloadedFile .. "' -DestinationPath '" .. destDir .. "' -Force"
            local res = Process.spawn("powershell", { "-NoProfile", "-Command", psCmd })
            if res.ok then extracted = true end
        end
    else
        if Process.which("unzip") then
            local res = Process.spawn("unzip", { "-o", "-q", downloadedFile, "-d", destDir })
            if res.ok then extracted = true end
        elseif Process.which("tar") then
            local res = Process.spawn("tar", { "-xf", downloadedFile, "-C", destDir })
            if res.ok then extracted = true end
        end
    end

    return extracted
end

return Download
