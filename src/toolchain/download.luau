--!strict
-- Archive download, checksum verification, and CDN/Releases-API client for Jaciup.
--
-- Talks to the Pop Language Server releases API (https://pop.squareweb.app).
-- Contract (verified against the live server):
--   GET /v1/releases?product=<p>            -> { items: [release, ...] }
--   GET /v1/releases/latest?product=<p>    -> release
--   GET /v1/releases/{version}/manifest?product=<p> -> { artifacts: [artifact, ...] }
--   GET /v1/releases/channels/{c}/manifest?product=<p> -> release manifest
--
-- Each release/artifact exposes:
--   assets[]  { id, name, size, sha256, download_url (relative), source_url }
--   artifacts[] { id, name, target: { os, arch }, archive_format, sha256,
--                 integrity, available, url (relative), supports_byte_ranges }
--
-- The download URLs are RELATIVE (e.g. /v1/releases/0.1.0/artifacts/123/x.zip?product=jaciup)
-- and MUST be resolved against the registry base URL, otherwise they 404.

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

-- Resolve a possibly-relative URL against the configured registry base.
-- The releases API returns relative download URLs; they must be joined to
-- the registry base (https://pop.squareweb.app) to become fetchable.
function Download.resolveUrl(url: string): string
    if not url then return "" end
    if url:match("^https?://") then
        return url
    end
    local base = (Config.getRegistryUrl() or "https://pop.squareweb.app"):gsub("/+$", "")
    if url:sub(1, 1) == "/" then
        return base .. url
    end
    return base .. "/" .. url
end

-- Fetch raw text over HTTP. Prefer the native net global (pure Luau, works
-- inside the single-binary compiler), then curl/wget as fallbacks.
function Download.fetchText(url: string): any
    local target = Download.resolveUrl(url)
    if not target:match("^https?://") then
        target = url
    end

    -- 1. Native net request (pure Luau; available to the embedded runtime).
    local net = (_G :: any).net
    if net and (net.request or net.get) then
        local body, status = pcall(function()
            local res
            if net.request then
                res = net.request({ url = target, method = "GET", headers = {["Accept"] = "application/json, */*"} })
            else
                res = net.get(target, {["Accept"] = "application/json"})
            end
            return res
        end)
        if body and status then
            local res = status
            local bodyText = res.body or res.content or ""
            local code = res.status or res.statusCode or 200
            if code >= 200 and code < 400 and bodyText ~= "" then
                return bodyText, code
            end
        end
    end

    -- 2. curl
    if Process.which("curl") then
        local res = Process.spawn("curl", { "-fsSL", "-H", "Accept: application/json", target })
        if res.ok and res.stdout and #res.stdout > 0 then
            return res.stdout, 200
        end
    end

    -- 3. wget
    if Process.which("wget") then
        local res = Process.spawn("wget", { "-q", "-O", "-", target })
        if res.ok and res.stdout and #res.stdout > 0 then
            return res.stdout, 200
        end
    end

    return nil
end

function Download.fetchJson(url: string): any
    local raw = Download.fetchText(url)
    if not raw then return nil end
    local ok, data = pcall(function()
        return Serde.parseJson(raw)
    end)
    if ok and data then
        return data
    end
    return nil
end

-- Query the releases API. product defaults to "jaci"; prerelease filters to
-- prerelease tags only.
function Download.getLatestRelease(product: string?, prerelease: boolean?): any
    local prod = product or "jaci"
    local url = "/v1/releases/latest?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    return Download.fetchJson(url)
end

function Download.listReleases(product: string?, prerelease: boolean?): {any}
    local prod = product or "jaci"
    local url = "/v1/releases?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    local data = Download.fetchJson(url)
    if data and data.items and type(data.items) == "table" then
        return data.items
    end
    return {}
end

function Download.getManifest(version: string, product: string?, prerelease: boolean?): any
    local prod = product or "jaci"
    local cleanVer = version:gsub("^v", "")
    local url = "/v1/releases/" .. cleanVer .. "/manifest?product=" .. prod
    if prerelease then
        url = url .. "&prerelease=true"
    end
    return Download.fetchJson(url)
end

-- Resolve a channel ("latest", "stable", "dev", ...) to a concrete release.
function Download.resolveChannel(channel: string, product: string?): any
    local prod = product or "jaci"
    if channel == "latest" or channel == "" then
        return Download.getLatestRelease(prod)
    end
    -- Other channels map to /v1/releases/channels/{channel}/manifest
    local url = "/v1/releases/channels/" .. channel .. "/manifest?product=" .. prod
    local manifest = Download.fetchJson(url)
    if manifest and manifest.version then
        return manifest
    end
    return Download.getLatestRelease(prod)
end

-- Fetch a raw file (bytes) into targetPath. Returns true on success.
function Download.downloadFile(url: string, targetPath: string): boolean
    local target = Download.resolveUrl(url)

    -- 1. Native net request streaming to disk.
    local net = (_G :: any).net
    if net and (net.request or net.get) then
        local ok = pcall(function()
            local res
            if net.request then
                res = net.request({ url = target, method = "GET" })
            else
                res = net.get(target, {})
            end
            local code = res.status or res.statusCode or 0
            local body = res.body or res.content or ""
            if code >= 200 and code < 400 and #body > 100 then
                Fs.writeFile(targetPath, body)
                return true
            end
        end)
        if ok then
            if Fs.isFile(targetPath) and (Fs.stat(targetPath) and (Fs.stat(targetPath) :: any).size > 100) then
                return true
            end
        end
    end

    if Process.which("curl") then
        local res = Process.spawn("curl", { "-fSL", "-o", targetPath, target })
        if res.ok and Fs.isFile(targetPath) and (Fs.stat(targetPath) and (Fs.stat(targetPath) :: any).size > 100) then
            return true
        end
    end

    if Process.which("wget") then
        local res = Process.spawn("wget", { "-q", "-O", targetPath, target })
        if res.ok and Fs.isFile(targetPath) and (Fs.stat(targetPath) and (Fs.stat(targetPath) :: any).size > 100) then
            return true
        end
    end

    return false
end

function Download.verifySha256(filePath: string, expectedSha256: string): boolean
    if not expectedSha256 or expectedSha256 == "" then
        return true
    end
    local content = Fs.readFileOpt(filePath)
    if not content then
        return false
    end
    local actualHash = Crypto.sha256Hex(content):lower()
    local expected = expectedSha256:lower():gsub("%s+", "")
    return actualHash == expected
end

-- Pick the best artifact for the current platform from a release/manifest.
-- Accepts either the /v1/releases shape (assets[] with relative download_url)
-- or the /manifest shape (artifacts[] with target:{os,arch} + relative url).
function Download.selectArtifact(release: any): any?
    if not release then return nil end

    local osName = Platform.getOS()        -- linux | macos | windows
    local arch = Platform.getArch()       -- x64 | arm64

    -- Normalize target triple fragments the API uses.
    local function archOf(a: string?): string
        if not a then return "" end
        a = a:lower()
        if a == "x86_64" or a == "x64" or a == "amd64" then return "x64" end
        if a == "aarch64" or a == "arm64" then return "arm64" end
        return a
    end
    local function osOf(o: string?): string
        if not o then return "" end
        o = o:lower()
        if o == "darwin" or o == "macos" then return "macos" end
        if o == "linux" then return "linux" end
        if o == "windows" then return "windows" end
        return o
    end

    local wantOs = osOf(osName)
    local wantArch = archOf(arch)

    -- 1. Prefer the manifest's artifacts[] with explicit target metadata.
    local artifacts = release.artifacts
    if artifacts and type(artifacts) == "table" and #artifacts > 0 then
        local fallback = nil
        for _, art in ipairs(artifacts) do
            if art.available ~= false and art.url and art.url ~= "" then
                local name = art.name or ""
                if name:lower():match("%.zip$") then
                    local t = art.target or {}
                    local tOs = osOf(t.os)
                    local tArch = archOf(t.arch)
                    local matches = (tOs == "" or tOs == wantOs) and (tArch == "" or tArch == wantArch)
                    if matches then
                        return art
                    end
                    -- Remember a generic (null-target) zip as a fallback.
                    if not fallback and (tOs == "" or tArch == "") then
                        fallback = art
                    end
                end
            end
        end
        if fallback then return fallback end
    end

    -- 2. Fall back to release.assets[] (the /v1/releases list shape),
    --    matching by target triple embedded in the asset name.
    local assets = release.assets
    if assets and type(assets) == "table" then
        local triple = Platform.getTargetTriple()        -- e.g. x86_64-unknown-linux-gnu
        local tripleArch = triple:match("^(x86_64|aarch64)") or wantArch
        local best = nil
        for _, asset in ipairs(assets) do
            local name = asset.name or ""
            if name:lower():match("%.zip$") then
                local lower = name:lower()
                local hasArch = lower:find(tripleArch:lower(), 1, true) ~= nil
                local hasOs = lower:find(wantOs, 1, true) ~= nil or triple:find(wantOs, 1, true) ~= nil
                if hasArch and (hasOs or triple:find(wantOs, 1, true) ~= nil) then
                    return asset
                end
                if not best and (hasArch or hasOs) then
                    best = asset
                end
            end
        end
        if best then return best end
    end

    return nil
end

-- Download the platform-specific archive for a version/channel via the
-- releases API. Returns the local path of the downloaded archive, or nil.
function Download.downloadAsset(repoUrl: string?, version: string, candidates: {string}, product: string?): string?
    Env.ensureDirectories()
    local prod = product or "jaci"
    local cleanTag = version:gsub("^v", "")
    local downloadsDir = Env.getDownloadsDir()

    -- Resolve the channel to a concrete release, then fetch its manifest.
    local release = Download.resolveChannel(cleanTag, prod)
    if not release then
        Term.error("Could not reach releases API for product '" .. prod .. "' channel '" .. cleanTag .. "'")
        return nil
    end

    local rv = release.version or release.tag
    local cleanVersion = tostring(rv or cleanTag):gsub("^v", "")
    local manifest = Download.getManifest(cleanVersion, prod) or release

    local artifact = Download.selectArtifact(manifest) or Download.selectArtifact(release)
    if not artifact or not artifact.url then
        Term.error("No matching release artifact for " .. Platform.getTargetTriple() .. " (product '" .. prod .. "')" )
        return nil
    end

    local name = artifact.name or (prod .. "-" .. cleanVersion .. ".zip")
    local targetPath = Path.join(downloadsDir, name)
    Term.log("info: downloading " .. name .. " from " .. Download.resolveUrl(artifact.url))

    local ok = Download.downloadFile(artifact.url, targetPath)
    if not ok then
        Term.error("Failed to download " .. name)
        return nil
    end

    local sha = artifact.sha256 or ""
    if sha ~= "" then
        Term.log("info: verifying SHA-256 checksum...")
        if not Download.verifySha256(targetPath, sha) then
            Term.error("Checksum verification failed for " .. name)
            Fs.removeFile(targetPath)
            return nil
        end
        Term.success("Checksum verified: " .. sha:sub(1, 16) .. "...")
    end

    return targetPath
end

-- Extract a zip/tar archive to destDir using available tools (no symlink
-- dependency). Pure cross-platform via tar/unzip/powershell.
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
