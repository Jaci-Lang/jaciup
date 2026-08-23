--!strict
-- Toolchain lifecycle management, version resolution, and linking for Jaciup

local Env = require("../core/env")
local Config = require("../core/config")
local Platform = require("../core/platform")
local Freeze = require("./freeze")
local Download = require("./download")
local Proxy = require("./proxy")
local Profile = require("../shell/profile")
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

    local installed = Manager.listInstalled()
    if #installed > 0 then
        local defaultTc = Config.getDefaultToolchain()
        if defaultTc and defaultTc ~= "" and Manager.has(defaultTc) then
            return defaultTc, "default toolchain"
        end
        return installed[1], "default toolchain"
    end

    return "", "no toolchains installed"
end

function Manager.runBinary(binPath: string, args: {string}): (boolean, string, string)
    local res = Process.spawn(binPath, args)
    return res.ok, res.stdout or "", res.stderr or ""
end

-- Best-effort version probe for an installed binary ("1.0.0" or "").
function Manager.probeVersion(binPath: string, versionArgs: {string}): string
    local ok, stdout = Manager.runBinary(binPath, versionArgs)
    if not ok or stdout == "" then
        return ""
    end
    local v = stdout:match("(%d+%.%d+%.%d+)")
    return v or stdout:match("([%w%.%-]+)%s*$") or ""
end

-- Install the KLUR layer into a toolchain directory. Supports both release
-- layouts: a self-contained klur binary at the zip root, or a source tree
-- (src/ + bin/) that gets a launcher wrapping the sibling engine.
-- Returns the klur version string, or "" when KLUR could not be installed.
function Manager.installKlur(tcDir: string, channel: string): string
    local settings = Config.load()
    local mirror = settings.mirror or "https://github.com/Jaci-Lang/jaci"

    Term.log("info: syncing KLUR layer for '" .. channel .. "'")
    local ext = Platform.getExecutableSuffix()
    local klurZip = Download.downloadAsset(mirror, channel, {}, "klur")
    if not klurZip then
        Term.warn("KLUR release not found for this platform; engine installed without KLUR.")
        Term.log("Install it later with: " .. Term.cyan("jaciup toolchain klur " .. channel))
        return ""
    end

    local ok = Download.extractZip(klurZip, tcDir)
    if not ok then
        Term.warn("Failed to unpack KLUR archive; engine installed without KLUR.")
        return ""
    end

    -- Binary layout: the zip root carries a self-contained klur executable.
    local klurBinName = "klur" .. (Fs.isFile(Path.join(tcDir, "klur" .. ext)) and ext or "")
    if Fs.isFile(Path.join(tcDir, klurBinName)) then
        local ver = Manager.probeVersion(Path.join(tcDir, klurBinName), { "version" })
        if ver ~= "" then
            return ver
        end
        -- A klur binary that cannot run is a stale or incompatible release
        -- artifact. Remove it so shims and doctor stop trusting it.
        Fs.removeFile(Path.join(tcDir, klurBinName))
        Term.warn("KLUR binary from the registry did not run (stale or incompatible release).")
        Term.log("The engine is installed; the KLUR layer needs a current klur release.")
        return ""
    end

    -- Source layout: wrap the tree with a launcher that uses the sibling engine.
    if Fs.isFile(Path.join(tcDir, "src", "init.luau")) then
        local launcher = Proxy.generateKlurLauncher()
        if Platform.isWindows() then
            Fs.writeFile(Path.join(tcDir, "klur.cmd"), launcher)
        else
            Fs.writeFile(Path.join(tcDir, "klur"), launcher)
            Process.spawn("chmod", { "+x", Path.join(tcDir, "klur") })
        end
        return "bundled"
    end

    Term.warn("KLUR archive did not contain a recognizable layout (no klur binary, no src/init.luau).")
    return ""
end

-- Print a clear post-install summary: what landed, where, and the exact
-- next step for the user's shell.
function Manager.printInstallSummary(tcDir: string, toolchain: string)
    local ext = Platform.getExecutableSuffix()
    local binDir = Env.getBinDir()
    local engineVer = Manager.probeVersion(Path.join(tcDir, "luau" .. ext), { "--version" })
    local klurBin = Path.join(tcDir, "klur" .. ext)
    if not Fs.isFile(klurBin) then
        klurBin = Path.join(tcDir, "klur")
    end
    local klurVer = Fs.isFile(klurBin) and Manager.probeVersion(klurBin, { "version" }) or ""

    print("")
    print(Term.green(Term.bold("  Jaciup install complete")) .. Term.dim("  (toolchain " .. toolchain .. ")"))
    print(string.format("    Engine     luau %s", engineVer ~= "" and engineVer or "unknown"))
    if klurVer ~= "" then
        print(string.format("    KLUR       v%s", klurVer))
    else
        print("    KLUR       " .. Term.yellow("not installed (engine only)"))
    end
    print(string.format("    Shims      %s", binDir))

    local pathEnv = process.env["PATH"] or ""
    local onPath = pathEnv:find(binDir, 1, true) ~= nil
    if onPath then
        print("    PATH       " .. Term.green("configured"))
    else
        print("    PATH       " .. Term.yellow("not in current session PATH"))
    end

    print("")
    print(Term.bold("  Next steps:"))
    if not onPath then
        local cmd = Profile.pathHintForShell(binDir)
        print("    1. " .. Term.cyan(cmd))
        print("    2. Verify:  " .. Term.cyan("luau --version && klur --version"))
        print("    3. Start a project:  " .. Term.cyan("mkdir myapp && cd myapp && klur init"))
    else
        print("    1. Verify:  " .. Term.cyan("luau --version && klur --version"))
        print("    2. Start a project:  " .. Term.cyan("mkdir myapp && cd myapp && klur init"))
    end
    print("")
end

-- Install (or reinstall) only the KLUR layer into the active toolchain.
function Manager.installKlurForActive(channel: string?): boolean
    local active = Manager.resolveActiveToolchain()
    if active == "" then
        Term.error("No toolchain installed. Run: " .. Term.cyan("jaciup toolchain install latest"))
        return false
    end
    local tcDir = Path.join(Env.getToolchainsDir(), active)
    local ver = Manager.installKlur(tcDir, channel or active)
    Proxy.installShims()
    if ver ~= "" then
        Manager.printInstallSummary(tcDir, active)
        return true
    end
    return false
end

function Manager.install(channelOrVersion: string): boolean
    Env.ensureDirectories()
    local version = channelOrVersion:gsub("^v", "")
    local tcDir = Path.join(Env.getToolchainsDir(), version)

    local settings = Config.load()
    local mirror = settings.mirror or "https://github.com/Jaci-Lang/jaci"
    local product = settings.product or "jaci"

    Term.log("info: syncing toolchain channel '" .. version .. "' (product '" .. product .. "') from " .. Config.getRegistryUrl())
    -- The releases API resolves the channel to a concrete release and selects the
    -- artifact for the current platform; candidates are a legacy fallback.
    local candidates = Platform.getAssetCandidates()
    local downloadedZip = Download.downloadAsset(mirror, version, candidates, product)

    if not downloadedZip then
        Term.error("Could not download toolchain release for '" .. version .. "' on " .. process.os .. "-" .. process.arch)
        return false
    end

    Fs.mkdirp(tcDir)
    local ok = Download.extractZip(downloadedZip, tcDir)
    if not ok then
        Term.error("Failed to unpack toolchain archive: " .. downloadedZip)
        return false
    end

    -- KLUR rides along with the engine so the klur shim resolves out of the box.
    local klurVersion = Manager.installKlur(tcDir, version)

    settings.installedToolchains = settings.installedToolchains or {}
    settings.installedToolchains[version] = true
    if not settings.defaultToolchain or settings.defaultToolchain == "latest" then
        settings.defaultToolchain = version
    end
    Config.save(settings)

    Proxy.installShims()
    Manager.printInstallSummary(tcDir, version)
    return true
end

function Manager.uninstall(channelOrVersion: string): boolean
    local cleanVer = channelOrVersion:gsub("^v", "")
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
    if active == "" then return nil end

    local tcDir = Path.join(Env.getToolchainsDir(), active)
    local ext = Platform.getExecutableSuffix()

    -- Search variants (e.g. luau-lsp <-> jaci-lsp)
    local searchNames = { binaryName }
    if binaryName == "luau-lsp" or binaryName == "jaci-lsp" or binaryName == "lsp" then
        searchNames = { "luau-lsp", "jaci-lsp", "lsp" }
    end

    -- 1. Check in active toolchain root and bin/
    for _, name in ipairs(searchNames) do
        local cand1 = Path.join(tcDir, name .. ext)
        local cand2 = Path.join(tcDir, name)
        local cand3 = Path.join(tcDir, "bin", name .. ext)
        local cand4 = Path.join(tcDir, "bin", name)
        for _, c in ipairs({cand1, cand2, cand3, cand4}) do
            if Fs.isFile(c) then
                return c
            end
        end
    end

    -- 2. Check in toolchain-specific extensions and global extensions
    local extDirs = {
        Path.join(Env.getExtensionsDir(), active),
        Env.getExtensionsDir(),
    }
    for _, edir in ipairs(extDirs) do
        for _, name in ipairs(searchNames) do
            local cand1 = Path.join(edir, name .. ext)
            local cand2 = Path.join(edir, name)
            local cand3 = Path.join(edir, "bin", name .. ext)
            local cand4 = Path.join(edir, "bin", name)
            for _, c in ipairs({cand1, cand2, cand3, cand4}) do
                if Fs.isFile(c) then
                    return c
                end
            end
        end
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
