--!strict
-- Jaciup: Official Pure Luau Toolchain Manager for Jaci & Luau

local CLI = require("./cli/init")

local rawArgs = process.args or {}
local args = {}
local startIndex = 1

if #rawArgs > 0 then
    local first = rawArgs[1]
    local isSubcmd = (first == "show" or first == "default" or first == "update" or first == "toolchain" or first == "which" or first == "run" or first == "init" or first == "completions" or first == "self")
    if not isSubcmd and not first:match("^%-") and (first:find("jaciup", 1, true) or first:find("luau", 1, true) or first:sub(1, 1) == "/") then
        startIndex = 2
    end
end

for i = startIndex, #rawArgs do
    table.insert(args, rawArgs[i])
end

local code = CLI.run(args)
process.exit(code)
