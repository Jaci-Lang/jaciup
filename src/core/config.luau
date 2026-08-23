--!strict
-- Settings and Configuration Management for Jaciup

local Env = require("./env")
local Fs = require("@klur/fs")
local Serde = require("@klur/serde")

export type Settings = {
    defaultToolchain: string?,
    mirror: string?,
    autoUpdate: boolean?,
    installedToolchains: {[string]: boolean}?,
}

local Config = {}

local DEFAULT_SETTINGS: Settings = {
    defaultToolchain = "latest",
    mirror = "https://github.com/klee-spec/jaci",
    autoUpdate = true,
    installedToolchains = {},
}

function Config.load(): Settings
    Env.ensureDirectories()
    local path = Env.getSettingsPath()
    local raw = Fs.readFileOpt(path)
    if not raw or raw == "" then
        return table.clone(DEFAULT_SETTINGS)
    end

    local parsed = Serde.toml.parse(raw)
    local settings: Settings = {
        defaultToolchain = parsed.default_toolchain or parsed.defaultToolchain or DEFAULT_SETTINGS.defaultToolchain,
        mirror = parsed.mirror or DEFAULT_SETTINGS.mirror,
        autoUpdate = (parsed.auto_update ~= nil and parsed.auto_update) or (parsed.autoUpdate ~= nil and parsed.autoUpdate) or true,
        installedToolchains = {},
    }

    if parsed.toolchains and type(parsed.toolchains) == "table" then
        for k, v in pairs(parsed.toolchains) do
            if v == true then
                settings.installedToolchains[k] = true
            end
        end
    end

    return settings
end

function Config.save(settings: Settings): boolean
    Env.ensureDirectories()
    local path = Env.getSettingsPath()
    local tbl: {[string]: any} = {
        default_toolchain = settings.defaultToolchain or "latest",
        mirror = settings.mirror or DEFAULT_SETTINGS.mirror,
        auto_update = settings.autoUpdate ~= false,
        toolchains = settings.installedToolchains or {},
    }

    local tomlStr = Serde.toml.encode(tbl)
    return Fs.atomicWrite(path, tomlStr)
end

function Config.getDefaultToolchain(): string?
    local s = Config.load()
    return s.defaultToolchain
end

function Config.setDefaultToolchain(channel: string): boolean
    local s = Config.load()
    s.defaultToolchain = channel
    return Config.save(s)
end

return Config
