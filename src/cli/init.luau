--!strict
-- Main CLI router and help output for Jaciup

local Args = require("./args")
local Term = require("@klur/term")
local Manager = require("../toolchain/manager")

local VERSION = "0.1.0"

local showCmd = require("./commands/show_cmd")
local defaultCmd = require("./commands/default_cmd")
local toolchainCmd = require("./commands/toolchain_cmd")
local updateCmd = require("./commands/update_cmd")
local whichCmd = require("./commands/which_cmd")
local runCmd = require("./commands/run_cmd")
local initCmd = require("./commands/init_cmd")
local completionsCmd = require("./commands/completions_cmd")
local selfCmd = require("./commands/self_cmd")
local extensionCmd = require("./commands/extension_cmd")

local function printHelp()
    local active, reason = Manager.resolveActiveToolchain()
    local statusLine = if active ~= ""
        then Term.green(active) .. " (" .. reason .. ")"
        else Term.yellow("none") .. " (run 'jaciup toolchain install latest' to install)"

    print(string.format([[
%s %s - The official Jaci & Luau toolchain manager

%s
    jaciup [COMMAND] [OPTIONS]

%s
    show                 Show the active and installed toolchains
    default <toolchain>  Set the default toolchain
    update [toolchain]   Update installed toolchains
    toolchain <action>   Manage toolchains (install, uninstall, list, link)
    extension <action>   Manage toolchain extensions & components (lsp, docs, sidecars)
    which <binary>       Display the binary path for the active toolchain (e.g. luau-lsp)
    run <tc> <cmd...>    Run a command with a specific toolchain
    init                 Initialize jaciup directory, shims, and shell PATH
    completions <shell>  Generate shell completion scripts (bash, zsh, fish, powershell)
    self <action>        Manage jaciup installation (update, uninstall)

%s
    -h, --help           Print this help message
    -v, --version        Print version info

%s
    Active toolchain: %s
    Host architecture: %s-%s
]],
    Term.bold(Term.cyan("jaciup")),
    VERSION,
    Term.bold("USAGE:"),
    Term.bold("COMMANDS:"),
    Term.bold("OPTIONS:"),
    Term.bold("STATUS:"),
    statusLine,
    process.os,
    process.arch
    ))
end

local CLI = {}

function CLI.run(rawArgs: {string}): number
    local parsed = Args.parse(rawArgs)

    if parsed.flags["v"] or parsed.flags["version"] then
        print("jaciup " .. VERSION)
        return 0
    end

    if parsed.flags["h"] or parsed.flags["help"] or parsed.command == "help" or not parsed.command then
        printHelp()
        return 0
    end

    local cmd = parsed.command
    if cmd == "show" then
        return showCmd(parsed.args)
    elseif cmd == "default" then
        return defaultCmd(parsed.args)
    elseif cmd == "toolchain" then
        return toolchainCmd(parsed.args)
    elseif cmd == "extension" or cmd == "component" or cmd == "extensions" or cmd == "components" then
        return extensionCmd(parsed.args)
    elseif cmd == "update" then
        return updateCmd(parsed.args)
    elseif cmd == "which" then
        return whichCmd(parsed.args)
    elseif cmd == "run" then
        return runCmd(parsed.args)
    elseif cmd == "init" then
        return initCmd(parsed.args)
    elseif cmd == "completions" or cmd == "completion" then
        return completionsCmd(parsed.args)
    elseif cmd == "self" then
        return selfCmd(parsed.args)
    else
        Term.error("Unknown command '" .. cmd .. "'. Run 'jaciup --help' for available commands.")
        return 1
    end
end

return CLI
