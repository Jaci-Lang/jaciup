--!strict
-- Platform, Architecture, and Asset Resolution for Jaciup

local Platform = {}

function Platform.getOS(): string
    local osName = process.os or "linux"
    if osName == "darwin" or osName == "macos" then
        return "macos"
    elseif osName == "windows" then
        return "windows"
    end
    return "linux"
end

function Platform.getArch(): string
    local arch = process.arch or "x64"
    if arch == "arm64" or arch == "aarch64" then
        return "arm64"
    end
    return "x64"
end

function Platform.isWindows(): boolean
    return Platform.getOS() == "windows"
end

function Platform.isMacOS(): boolean
    return Platform.getOS() == "macos"
end

function Platform.isLinux(): boolean
    return Platform.getOS() == "linux"
end

function Platform.getExecutableSuffix(): string
    return Platform.isWindows() and ".exe" or ""
end

function Platform.getAssetCandidates(): {string}
    local osName = Platform.getOS()
    local arch = Platform.getArch()

    if osName == "linux" then
        return {
            "luau-linux-x64.zip",
            "luau-ubuntu.zip",
            "luau-linux.zip",
        }
    elseif osName == "macos" then
        if arch == "arm64" then
            return {
                "luau-macos-arm64.zip",
                "luau-macos.zip",
            }
        else
            return {
                "luau-macos-x64.zip",
                "luau-macos.zip",
            }
        end
    elseif osName == "windows" then
        return {
            "luau-windows-x64.zip",
            "luau-windows.zip",
        }
    end
    return { "luau-" .. osName .. ".zip" }
end

return Platform
