--!strict
-- Command: jaciup doctor (environment diagnostics)

local Env = require("../../core/env")
local Config = require("../../core/config")
local Platform = require("../../core/platform")
local Manager = require("../../toolchain/manager")
local Profile = require("../../shell/profile")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Term = require("@klur/term")

local VERSION = "0.1.0"

local failures = 0
local warnings = 0

local function warn(label: string, detail: string?, hint: string?)
    warnings += 1
    print(Term.yellow("  [!] ") .. Term.bold(label) .. (detail and "  " .. detail or ""))
    if hint then
        print("          " .. Term.dim("fix: " .. hint))
    end
end

local function ok(label: string, detail: string?)
    print(Term.green("  [ok] ") .. Term.bold(label) .. (detail and "  " .. detail or ""))
end

local function fail(label: string, detail: string?, hint: string?)
    failures += 1
    print(Term.red("  [x] ") .. Term.bold(label) .. (detail and "  " .. detail or ""))
    if hint then
        print("          " .. Term.dim("fix: " .. hint))
    end
end

return function(_args: {string}): number
    local binDir = Env.getBinDir()
    local ext = Platform.getExecutableSuffix()

    print(Term.bold(Term.cyan("jaciup doctor")) .. Term.dim("  (v" .. VERSION .. ")"))
    print("")

    -- 1. Home & layout
    print(Term.bold("Installation"))
    ok("Jaciup home", Env.getJaciupHome())
    if Fs.isFile(Env.getSettingsPath()) then
        local settings = Config.load()
        if settings.defaultToolchain and settings.defaultToolchain ~= "" then
            ok("Default toolchain", settings.defaultToolchain)
        else
            warn("No default toolchain set", nil, "jaciup default <version>")
        end
        ok("Registry", Config.getRegistryUrl())
    else
        warn("No settings yet", nil, "jaciup init")
    end

    -- 2. Toolchains
    print("")
    print(Term.bold("Toolchains"))
    local installed = Manager.listInstalled()
    if #installed == 0 then
        fail("No toolchains installed", "install one to get started", "jaciup toolchain install latest")
    else
        local active, reason = Manager.resolveActiveToolchain()
        for _, tc in ipairs(installed) do
            local mark = (tc == active) and Term.green("* ") or "  "
            print(mark .. "  " .. tc .. (tc == active and Term.dim("  (active — " .. reason .. ")") or ""))
        end
        local tcDir = Path.join(Env.getToolchainsDir(), active)

        -- 3. Engine
        local engineBin = Path.join(tcDir, "luau" .. ext)
        if not Fs.isFile(engineBin) then
            engineBin = Path.join(tcDir, "luau")
        end
        if Fs.isFile(engineBin) then
            local engineVer = Manager.probeVersion(engineBin, { "--version" })
            ok("Engine", "luau " .. (engineVer ~= "" and engineVer or "ok"))
        else
            fail("Engine missing in active toolchain", active, "jaciup toolchain install " .. active)
        end

        -- 4. KLUR
        local klurBin = Path.join(tcDir, "klur" .. ext)
        if not Fs.isFile(klurBin) then
            klurBin = Path.join(tcDir, "klur")
        end
        if Fs.isFile(klurBin) then
            local klurVer = Manager.probeVersion(klurBin, { "version" })
            ok("KLUR", "v" .. (klurVer ~= "" and klurVer or "ok"))
        else
            warn("KLUR not installed in active toolchain", active, "jaciup toolchain install " .. active)
        end
    end

    -- 5. Shims
    print("")
    print(Term.bold("Shims"))
    ok("Shim directory", binDir)
    local shims = { "luau", "luau-analyze", "luau-compile", "luau-ast", "klur" }
    for _, bin in ipairs(shims) do
        if not Fs.isFile(Path.join(binDir, bin)) and not Fs.isFile(Path.join(binDir, bin .. ".cmd")) then
            fail("Shim missing: " .. bin, nil, "jaciup init")
        end
    end

    -- 6. PATH
    print("")
    print(Term.bold("PATH"))
    local pathEnv = process.env["PATH"] or ""
    if pathEnv:find(binDir, 1, true) ~= nil then
        ok("jaciup bin is on PATH")
    else
        warn("jaciup bin is NOT on the current PATH", Profile.pathHintForShell(binDir), Profile.pathHintForShell(binDir))
    end

    -- 7. Summary
    print("")
    if failures == 0 and warnings == 0 then
        print(Term.green(Term.bold("  All checks passed.")))
    elseif failures == 0 then
        print(Term.yellow(Term.bold("  OK with " .. warnings .. " warning" .. (warnings > 1 and "s" or "") .. ".")))
    else
        print(Term.red(Term.bold("  " .. failures .. " check(s) failed" .. (warnings > 0 and (", " .. warnings .. " warning" .. (warnings > 1 and "s" or "")) or "") .. ".")))
    end
    return failures == 0 and 0 or 1
end
