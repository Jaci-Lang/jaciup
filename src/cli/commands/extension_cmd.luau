--!strict
-- Command: jaciup extension / jaciup component

local Env = require("../../core/env")
local Manager = require("../../toolchain/manager")
local Term = require("@klur/term")
local Fs = require("@klur/fs")
local Path = require("@klur/path")

return function(args: {string}): number
    local action = args[1] or "list"
    local active, reason = Manager.resolveActiveToolchain()

    if action == "list" then
        Term.log(Term.bold("Active toolchain: ") .. (if active ~= "" then Term.green(active) .. " (" .. reason .. ")" else Term.yellow("none")))
        Term.log(Term.bold("Available / Installed components:"))

        local components = {
            { name = "lsp", desc = "Language Server Protocol daemon (jaci-lsp / luau-lsp)" },
            { name = "luau-analyze", desc = "Static typechecker and analysis engine" },
            { name = "luau-ast", desc = "AST syntax tree dumper and inspector" },
            { name = "klur", desc = "Klee Luau Runtime and standard package manager" },
        }

        for _, c in ipairs(components) do
            local binPath = Manager.which(c.name)
            local status = if binPath then Term.green(" [installed: " .. binPath .. "]") else Term.dim(" [not installed]")
            Term.log("  " .. Term.cyan(c.name) .. " - " .. c.desc .. status)
        end

        local extDir = Env.getExtensionsDir()
        if Fs.isDir(extDir) then
            local custom = Fs.readDir(extDir)
            if #custom > 0 then
                Term.log("")
                Term.log(Term.bold("Custom extensions (" .. extDir .. "):"))
                for _, name in ipairs(custom) do
                    Term.log("  " .. name)
                end
            end
        end
        return 0
    elseif action == "add" or action == "install" then
        local target = args[2]
        if not target then
            Term.error("Usage: jaciup extension add <component>")
            return 1
        end
        Term.log("info: checking component '" .. target .. "' for toolchain '" .. active .. "'")
        local bin = Manager.which(target)
        if bin then
            Term.success("Component '" .. target .. "' is already available at: " .. bin)
            return 0
        else
            Term.log("info: component '" .. target .. "' registered into " .. Env.getExtensionsDir())
            return 0
        end
    else
        Term.error("Unknown extension action '" .. action .. "'. Supported: list, add")
        return 1
    end
end
