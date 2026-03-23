#compdef comfy-health
#
# comfy-health zsh completions
#
# Usage:
#   source /path/to/completions/comfy-health.zsh
#
# Or place in your $fpath as _comfy-health

_comfy_health() {
    local -a subcommands
    subcommands=(
        'scan:Run all detectors, update state, show diff'
        'check:Run subjective review'
        'status:Full project dashboard'
        'show:Dig into issues by file, directory, detector, or ID'
        'next:Show next priority item'
        'backlog:Show broader backlog items'
        'plan:View/update the living plan'
        'tree:Annotated codebase tree'
        'viz:Generate interactive HTML treemap'
        'diff:Scan files changed since REF'
        'branch:Scan files changed vs BASE branch'
        'doctor:Self-check deps, config, project setup'
        'help:Show usage'
        'version:Show version'
    )

    if (( CURRENT == 2 )); then
        _describe -t subcommands 'comfy-health subcommand' subcommands
        return
    fi

    local subcmd="${words[2]}"

    case "$subcmd" in
        scan)
            _arguments \
                '--skip-slow[Skip slow detectors]' \
                '--no-badge[Skip scorecard image generation]' \
                '--profile[Detector profile]:profile:(objective full ci)'
            ;;
        check)
            _arguments \
                '--prepare[Prepare review]' \
                '--import[Import review]'
            ;;
        diff|branch)
            _arguments \
                '--strict[Strict mode]'
            ;;
    esac
}

compdef _comfy_health comfy-health
