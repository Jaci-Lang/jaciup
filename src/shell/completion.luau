--!strict
-- Shell completion scripts generation for Jaciup

local Completion = {}

function Completion.generateBash(): string
    return [[
_jaciup_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="show default update toolchain which run completions self init --help --version"

    case "${prev}" in
        toolchain)
            COMPREPLY=( $(compgen -W "install uninstall list link help" -- ${cur}) )
            return 0
            ;;
        default|run)
            local installed=$(jaciup toolchain list 2>/dev/null | awk '{print $1}')
            COMPREPLY=( $(compgen -W "${installed}" -- ${cur}) )
            return 0
            ;;
        completions)
            COMPREPLY=( $(compgen -W "bash zsh fish powershell" -- ${cur}) )
            return 0
            ;;
        which)
            COMPREPLY=( $(compgen -W "luau luau-analyze luau-compile luau-ast klur" -- ${cur}) )
            return 0
            ;;
        *)
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            return 0
            ;;
    esac
}
complete -F _jaciup_completions jaciup
]]
end

function Completion.generateZsh(): string
    return [[
#compdef jaciup

_jaciup() {
    local -a commands
    commands=(
        'show:Show the active and installed toolchains'
        'default:Set the default toolchain'
        'update:Update installed toolchains'
        'toolchain:Manage toolchains (install, uninstall, list, link)'
        'which:Display the binary path for the active toolchain'
        'run:Run a command with a specific toolchain'
        'completions:Generate shell completions'
        'self:Manage jaciup installation'
        'init:Initialize jaciup environment and PATH'
    )

    _arguments -C \
        '--version[Print version info]' \
        '--help[Print help info]' \
        '1: :->cmd' \
        '*:: :->args'

    case $state in
        cmd)
            _describe -t commands 'jaciup command' commands
            ;;
    esac
}

_jaciup "$@"
]]
end

function Completion.generateFish(): string
    return [[
complete -c jaciup -n "__fish_use_subcommand" -a "show" -d "Show active and installed toolchains"
complete -c jaciup -n "__fish_use_subcommand" -a "default" -d "Set default toolchain"
complete -c jaciup -n "__fish_use_subcommand" -a "update" -d "Update installed toolchains"
complete -c jaciup -n "__fish_use_subcommand" -a "toolchain" -d "Manage toolchains"
complete -c jaciup -n "__fish_use_subcommand" -a "which" -d "Display binary path for active toolchain"
complete -c jaciup -n "__fish_use_subcommand" -a "run" -d "Run command with specific toolchain"
complete -c jaciup -n "__fish_use_subcommand" -a "completions" -d "Generate shell completions"
complete -c jaciup -n "__fish_use_subcommand" -a "self" -d "Manage jaciup installation"
complete -c jaciup -n "__fish_use_subcommand" -a "init" -d "Initialize jaciup environment and PATH"
]]
end

function Completion.generatePowerShell(): string
    return [[
Register-ArgumentCompleter -Native -CommandName jaciup -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $commands = @("show", "default", "update", "toolchain", "which", "run", "completions", "self", "init", "--help", "--version")
    $commands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
]]
end

function Completion.generate(shell: string): string
    if shell == "zsh" then
        return Completion.generateZsh()
    elseif shell == "fish" then
        return Completion.generateFish()
    elseif shell == "powershell" or shell == "ps" then
        return Completion.generatePowerShell()
    else
        return Completion.generateBash()
    end
end

return Completion
