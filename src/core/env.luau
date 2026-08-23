--!strict
-- Environment paths and directory structures for Jaciup

local Path = require("@klur/path")
local Fs = require("@klur/fs")

local Env = {}

function Env.getHomeDir(): string
    if process.env["HOME"] and process.env["HOME"] ~= "" then
        return process.env["HOME"]
    end
    if process.env["USERPROFILE"] and process.env["USERPROFILE"] ~= "" then
        return process.env["USERPROFILE"]
    end
    return "."
end

function Env.getJaciupHome(): string
    if process.env["JACIUP_HOME"] and process.env["JACIUP_HOME"] ~= "" then
        return process.env["JACIUP_HOME"]
    end
    return Path.join(Env.getHomeDir(), ".jaciup")
end

function Env.getBinDir(): string
    return Path.join(Env.getJaciupHome(), "bin")
end

function Env.getToolchainsDir(): string
    return Path.join(Env.getJaciupHome(), "toolchains")
end

function Env.getExtensionsDir(): string
    if process.env["JACIUP_EXTENSIONS"] and process.env["JACIUP_EXTENSIONS"] ~= "" then
        return process.env["JACIUP_EXTENSIONS"]
    end
    return Path.join(Env.getJaciupHome(), "extensions")
end

function Env.getDownloadsDir(): string
    return Path.join(Env.getJaciupHome(), "downloads")
end

function Env.getSettingsPath(): string
    return Path.join(Env.getJaciupHome(), "settings.toml")
end

function Env.ensureDirectories()
    Fs.mkdirp(Env.getJaciupHome())
    Fs.mkdirp(Env.getBinDir())
    Fs.mkdirp(Env.getToolchainsDir())
    Fs.mkdirp(Env.getExtensionsDir())
    Fs.mkdirp(Env.getDownloadsDir())
end

return Env
