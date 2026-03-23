# comfy-health bash completions
#
# Usage:
#   source /path/to/completions/comfy-health.bash
#
# Or add to your ~/.bashrc:
#   source /path/to/completions/comfy-health.bash

_comfy_health() {
    local cur prev words cword
    _init_completion || return

    local subcommands="scan check status show next backlog plan tree viz diff branch doctor help version"

    if [[ $cword -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
        return
    fi

    local subcmd="${words[1]}"

    case "$subcmd" in
        scan)
            COMPREPLY=($(compgen -W "--skip-slow --no-badge --profile" -- "$cur"))
            ;;
        check)
            COMPREPLY=($(compgen -W "--prepare --import" -- "$cur"))
            ;;
        diff|branch)
            COMPREPLY=($(compgen -W "--strict" -- "$cur"))
            ;;
    esac

    # Complete --profile values
    if [[ "$prev" == "--profile" ]]; then
        COMPREPLY=($(compgen -W "objective full ci" -- "$cur"))
    fi
}

complete -F _comfy_health comfy-health
