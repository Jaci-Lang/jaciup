--!strict
-- Project-level toolchain freezing and discovery (jaciup-toolchain.toml)

local Path = require("@klur/path")
local Fs = require("@klur/fs")
local Serde = require("@klur/serde")

export type ToolchainFile = {
    channel: string,
    components: {string}?,
    targets: {string}?,
}

local Freeze = {}

local TOOLCHAIN_FILENAMES = {
    "jaciup-toolchain.toml",
    "jaci-toolchain.toml",
    "toolchain.toml",
}

function Freeze.findToolchainFile(startDir: string?): string?
    local current = startDir or process.cwd()
    current = Path.resolve(current)

    while true do
        for _, filename in ipairs(TOOLCHAIN_FILENAMES) do
            local candidate = Path.join(current, filename)
            if Fs.isFile(candidate) then
                return candidate
            end
        end

        local parent = Path.dirname(current)
        if parent == current or parent == "." or parent == "" then
            break
        end
        current = parent
    end

    return nil
end

function Freeze.readToolchainFile(filePath: string): ToolchainFile?
    local content = Fs.readFileOpt(filePath)
    if not content or content == "" then
        return nil
    end

    local parsed = Serde.toml.parse(content)
    local toolchainSection = parsed.toolchain or parsed
    local channel = toolchainSection.channel or toolchainSection.version

    if not channel or type(channel) ~= "string" then
        return nil
    end

    return {
        channel = channel,
        components = toolchainSection.components,
        targets = toolchainSection.targets,
    }
end

function Freeze.detectPinnedToolchain(dir: string?): string?
    local file = Freeze.findToolchainFile(dir)
    if not file then return nil end
    local tf = Freeze.readToolchainFile(file)
    return tf and tf.channel or nil
end

function Freeze.writeToolchainFile(dir: string, channel: string): boolean
    local targetPath = Path.join(dir, "jaciup-toolchain.toml")
    local data = {
        toolchain = {
            channel = channel,
        }
    }
    local tomlStr = Serde.toml.encode(data)
    return Fs.writeFile(targetPath, tomlStr)
end

return Freeze
