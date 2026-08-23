--!strict
-- Settings and Configuration Management for Jaciup

local Env = require("./env")
local Fs = require("@klur/fs")
local Serde = require("@klur/serde")

export type Settings = {
    defaultToolchain: string?,
    registryUrl: string?,
    mirror: string?,
    autoUpdate: boolean?,
    installedToolchains: {[string]: boolean}?,
}

local Config = {}

local DEFAULT_SETTINGS: Settings = {
    defaultToolchain = "latest",
    registryUrl = "https://cdn.jaci.dev",
    mirror = "https://github.com/klee-spec/jaci",
    autoUpdate = true,
    installedToolchains = {},
}

function Config.getRegistryUrl(): string
    if process.env["JACI_CDN_URL"] and process.env["JACI_CDN_URL"] ~= "" then
        return process.env["JACI_CDN_URL"]
    end
    if process.env["JACIUP_REGISTRY_URL"] and process.env["JACIUP_REGISTRY_URL"] ~= "" then
        return process.env["JACIUP_REGISTRY_URL"]
    end
    local settings = Config.load()
    return settings.registryUrl or DEFAULT_SETTINGS.registryUrl or "https://cdn.jaci.dev"
end

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
        registryUrl = parsed.registry_url or parsed.registryUrl or DEFAULT_SETTINGS.registryUrl,
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
        registry_url = settings.registryUrl or DEFAULT_SETTINGS.registryUrl,
        mirror = settings.mirror or DEFAULT_SETTINGS.mirror,
        auto_update = settings.autoUpdate ~= false,
        toolchains = settings.installedToolchains or {},
    }

    local tomlStr = Serde.toml.stringify(tbl)
    return Fs.writeFile(path, tomlStr)
end

function Config.getDefaultToolchain(): string?
    local s = Config.load()
    return s.defaultToolchain
end

function Config.setDefaultToolchain(name: string): boolean
    local s = Config.load()
    s.defaultToolchain = name
    return Config.save(s)
end

return Config
