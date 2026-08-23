--!strict
-- Shell profile configuration and PATH modification for Jaciup

local Env = require("../core/env")
local Platform = require("../core/platform")
local Fs = require("@klur/fs")
local Path = require("@klur/path")
local Process = require("@klur/process")
local Term = require("@klur/term")

local Profile = {}

function Profile.getShellType(): string
    local shellEnv = process.env["SHELL"] or ""
    if shellEnv:match("zsh") then
        return "zsh"
    elseif shellEnv:match("fish") then
        return "fish"
    elseif shellEnv:match("bash") then
        return "bash"
    end

    if Platform.isWindows() then
        return "powershell"
    end
    return "bash"
end

-- Exact command to put binDir on PATH in the user's current shell, for
-- post-install hints.
function Profile.pathHintForShell(binDir: string): string
    if Platform.isWindows() then
        return string.format('$env:Path = "%s;$env:Path"', binDir)
    end
    local shellType = Profile.getShellType()
    if shellType == "fish" then
        return string.format('fish_add_path "%s"', binDir)
    end
    return string.format('export PATH="%s:$PATH"', binDir)
end

function Profile.configurePath(): boolean
    local home = Env.getHomeDir()
    local binDir = Env.getBinDir()
    local shellType = Profile.getShellType()
    local updatedFiles: {string} = {}

    if Platform.isWindows() then
        -- Add to User PATH via PowerShell
        local psCmd = string.format([[$curr = [Environment]::GetEnvironmentVariable("Path", "User"); if ($curr -notlike "*%s*") { [Environment]::SetEnvironmentVariable("Path", "$curr;%s", "User") }]], binDir, binDir)
        Process.spawn("powershell", { "-NoProfile", "-Command", psCmd })
        Term.success("Added " .. binDir .. " to Windows User PATH")
        return true
    end

    local posixSnippet = string.format('\n# Jaciup toolchain environment\nexport PATH="%s:$PATH"\n', binDir)
    local fishSnippet = string.format('\n# Jaciup toolchain environment\nfish_add_path "%s"\n', binDir)

    local targetRcFiles: {string} = {}

    if shellType == "zsh" then
        table.insert(targetRcFiles, Path.join(home, ".zshrc"))
        table.insert(targetRcFiles, Path.join(home, ".zprofile"))
    elseif shellType == "fish" then
        local fishDir = Path.join(home, ".config", "fish")
        Fs.mkdirp(fishDir)
        table.insert(targetRcFiles, Path.join(fishDir, "config.fish"))
    else
        table.insert(targetRcFiles, Path.join(home, ".bashrc"))
        table.insert(targetRcFiles, Path.join(home, ".profile"))
    end

    for _, rcFile in ipairs(targetRcFiles) do
        local content = Fs.readFileOpt(rcFile) or ""
        if not content:find(".jaciup/bin", 1, true) then
            local snippet = (shellType == "fish") and fishSnippet or posixSnippet
            Fs.writeFile(rcFile, content .. snippet)
            table.insert(updatedFiles, rcFile)
        end
    end

    if #updatedFiles > 0 then
        Term.success("Configured PATH in: " .. table.concat(updatedFiles, ", "))
    else
        Term.log("PATH is already configured for Jaciup.")
    end

    return true
end

return Profile
