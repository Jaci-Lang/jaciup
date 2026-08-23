--!strict
-- Toolchain lifecycle management, version resolution, and linking for Jaciup

local Env = require("../core/env")
local Config = require("../core/config")
local Platform = require("../core/platform")
local Freeze = require("./freeze")
local Download = require("./download")
local Proxy = require("./proxy")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Process = require("@klur/process")
local Term = require("@klur/term")

local Manager = {}

function Manager.listInstalled(): {string}
    Env.ensureDirectories()
    local tcDir = Env.getToolchainsDir()
    local entries = Fs.readDir(tcDir)
    local toolchains: {string} = {}

    for _, name in ipairs(entries) do
        local p = Path.join(tcDir, name)
        if Fs.isDir(p) then
            table.insert(toolchains, name)
        end
    end

    table.sort(toolchains)
    return toolchains
end

function Manager.has(toolchainName: string): boolean
    local tcDir = Env.getToolchainsDir()
    local p = Path.join(tcDir, toolchainName)
    return Fs.isDir(p)
end

function Manager.resolveActiveToolchain(dir: string?): (string, string)
    -- 1. Check environment variable override
    local envOverride = process.env["JACIUP_TOOLCHAIN"]
    if envOverride and envOverride ~= "" then
        return envOverride, "environment override (JACIUP_TOOLCHAIN)"
    end

    -- 2. Check project directory toolchain file (jaciup-toolchain.toml)
    local pinned = Freeze.detectPinnedToolchain(dir)
    if pinned and pinned ~= "" then
        return pinned, "directory override (jaciup-toolchain.toml)"
    end

    -- 3. Check default toolchain from settings.toml
    local defaultTc = Config.getDefaultToolchain()
    if defaultTc and defaultTc ~= "" then
        return defaultTc, "default toolchain"
    end

    -- 4. Fallback to first installed toolchain
    local installed = Manager.listInstalled()
    if #installed > 0 then
        return installed[1], "first installed fallback"
    end

    return "latest", "default fallback"
end

function Manager.install(channelOrVersion: string): boolean
    Env.ensureDirectories()
    local version = channelOrVersion:gsub("^v", "")
    local tcDir = Path.join(Env.getToolchainsDir(), version)

    local settings = Config.load()
    local mirror = settings.mirror or "https://github.com/klee-spec/jaci"

    Term.log("Installing Jaci toolchain '" .. version .. "'...")
    local ok = Download.fetchReleaseArchive(mirror, version, tcDir)
    if not ok then
        return false
    end

    -- Update settings
    settings.installedToolchains = settings.installedToolchains or {}
    settings.installedToolchains[version] = true
    if not settings.defaultToolchain or settings.defaultToolchain == "latest" or settings.defaultToolchain == "" then
        settings.defaultToolchain = version
    end
    Config.save(settings)

    -- Ensure universal shims are installed in ~/.jaciup/bin
    Proxy.installShims()

    Term.success("Toolchain '" .. version .. "' installed successfully!")
    return true
end

function Manager.uninstall(version: string): boolean
    local cleanVer = version:gsub("^v", "")
    local tcDir = Path.join(Env.getToolchainsDir(), cleanVer)

    if not Fs.isDir(tcDir) then
        Term.warn("Toolchain '" .. cleanVer .. "' is not installed.")
        return false
    end

    Fs.rimraf(tcDir)

    local settings = Config.load()
    if settings.installedToolchains then
        settings.installedToolchains[cleanVer] = nil
    end
    if settings.defaultToolchain == cleanVer then
        local remaining = Manager.listInstalled()
        settings.defaultToolchain = #remaining > 0 and remaining[1] or "latest"
    end
    Config.save(settings)

    Term.success("Toolchain '" .. cleanVer .. "' uninstalled successfully.")
    return true
end

function Manager.linkLocal(name: string, sourceDir: string): boolean
    Env.ensureDirectories()
    local resolvedSource = Path.resolve(sourceDir)
    if not Fs.isDir(resolvedSource) then
        Term.error("Source directory does not exist: " .. resolvedSource)
        return false
    end

    local targetDir = Path.join(Env.getToolchainsDir(), name)
    Fs.rimraf(targetDir)

    if Platform.isWindows() then
        Fs.copyDir(resolvedSource, targetDir)
    else
        local res = Process.spawn("ln", { "-sfn", resolvedSource, targetDir })
        if not res.ok then
            Fs.copyDir(resolvedSource, targetDir)
        end
    end

    local settings = Config.load()
    settings.installedToolchains = settings.installedToolchains or {}
    settings.installedToolchains[name] = true
    Config.save(settings)

    Proxy.installShims()
    Term.success("Linked custom toolchain '" .. name .. "' -> " .. resolvedSource)
    return true
end

function Manager.which(binaryName: string, dir: string?): string?
    local active, _reason = Manager.resolveActiveToolchain(dir)
    local tcDir = Path.join(Env.getToolchainsDir(), active)
    local ext = Platform.getExecutableSuffix()

    local candidate = Path.join(tcDir, binaryName .. ext)
    if Fs.isFile(candidate) then
        return candidate
    end

    -- Also check in case binary is directly inside root without extension or with .exe
    local candidateNoExt = Path.join(tcDir, binaryName)
    if Fs.isFile(candidateNoExt) then
        return candidateNoExt
    end

    return nil
end

function Manager.run(toolchain: string, binaryName: string, args: {string}): number
    local tcDir = Path.join(Env.getToolchainsDir(), toolchain)
    local ext = Platform.getExecutableSuffix()
    local binPath = Path.join(tcDir, binaryName .. ext)

    if not Fs.isFile(binPath) then
        binPath = Path.join(tcDir, binaryName)
    end

    if not Fs.isFile(binPath) then
        Term.error("Binary '" .. binaryName .. "' not found in toolchain '" .. toolchain .. "'")
        return 1
    end

    local res = Process.spawn(binPath, args)
    if res.stdout and res.stdout ~= "" then
        print(res.stdout:gsub("\n$", ""))
    end
    if res.stderr and res.stderr ~= "" then
        process.exit(res.exitCode)
    end
    return res.exitCode
end

return Manager
