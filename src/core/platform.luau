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

function Platform.getTargetTriple(): string
    local osName = Platform.getOS()
    local arch = Platform.getArch()

    if osName == "linux" then
        if arch == "arm64" then
            return "aarch64-unknown-linux-gnu"
        else
            return "x86_64-unknown-linux-gnu"
        end
    elseif osName == "macos" then
        if arch == "arm64" then
            return "aarch64-apple-darwin"
        else
            return "x86_64-apple-darwin"
        end
    elseif osName == "windows" then
        if arch == "arm64" then
            return "aarch64-pc-windows-msvc"
        else
            return "x86_64-pc-windows-msvc"
        end
    end
    return "x86_64-unknown-linux-gnu"
end

function Platform.getAssetCandidates(pkgName: string?): {string}
    local pkg = pkgName or "jaci"
    local triple = Platform.getTargetTriple()
    local osName = Platform.getOS()
    local arch = Platform.getArch()

    local candidates = {
        pkg .. "-" .. triple .. ".zip",
    }

    if osName == "linux" then
        table.insert(candidates, "luau-linux-x64.zip")
        table.insert(candidates, "luau-ubuntu.zip")
        table.insert(candidates, "luau-linux.zip")
    elseif osName == "macos" then
        if arch == "arm64" then
            table.insert(candidates, "luau-macos-arm64.zip")
        else
            table.insert(candidates, "luau-macos-x64.zip")
        end
        table.insert(candidates, "luau-macos.zip")
    elseif osName == "windows" then
        table.insert(candidates, "luau-windows-x64.zip")
        table.insert(candidates, "luau-windows.zip")
    end

    table.insert(candidates, pkg .. "-" .. osName .. ".zip")
    return candidates
end

return Platform
