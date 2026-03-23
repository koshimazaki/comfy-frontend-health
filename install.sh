#!/usr/bin/env bash
set -euo pipefail

# comfy-frontend-health installer
# Installs the desloppify fork + copies Claude Code agents/skills into target project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Argument parsing ---
DIFF_ONLY=false
TARGET="."
for arg in "$@"; do
    case "$arg" in
        --diff) DIFF_ONLY=true ;;
        *)      TARGET="$arg" ;;
    esac
done

# --- Sync tracking ---
ADDED=0
CHANGED=0
UNCHANGED=0
BACKUP_DIR=""
BACKUP_CREATED=false

# Create backup directory (once, lazily — only when first needed)
ensure_backup_dir() {
    local base="$1"
    if [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$base/.claude/.backup-$(date +%Y%m%d-%H%M%S)"
    fi
    if ! $BACKUP_CREATED; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_CREATED=true
    fi
}

# Install a single file: backup if exists and differs, then copy.
# Usage: install_file <src> <dst> <backup_base>
#   backup_base: the project root whose .claude/.backup-*/ holds backups
install_file() {
    local src="$1" dst="$2" backup_base="$3"

    if [[ ! -e "$dst" ]]; then
        # New file
        if $DIFF_ONLY; then
            echo "    + $(basename "$dst")  (new)"
        else
            mkdir -p "$(dirname "$dst")"
            cp "$src" "$dst"
        fi
        ADDED=$((ADDED + 1))
    elif diff -q "$src" "$dst" &>/dev/null; then
        # Identical
        UNCHANGED=$((UNCHANGED + 1))
    else
        # Changed
        if $DIFF_ONLY; then
            echo "    ~ $(basename "$dst")  (modified)"
            diff -u "$dst" "$src" --label "installed" --label "incoming" 2>/dev/null || true
            echo ""
        else
            ensure_backup_dir "$backup_base"
            # Preserve relative path inside backup
            local rel="${dst#$backup_base/.claude/}"
            local backup_path="$BACKUP_DIR/$rel"
            mkdir -p "$(dirname "$backup_path")"
            cp "$dst" "$backup_path"
            cp "$src" "$dst"
        fi
        CHANGED=$((CHANGED + 1))
    fi
}

# Walk a source directory tree and install every file.
# Usage: install_tree <src_dir> <dst_dir> <backup_base>
install_tree() {
    local src_dir="$1" dst_dir="$2" backup_base="$3"
    # Use find to get every regular file, preserving directory structure
    while IFS= read -r src_file; do
        local rel="${src_file#$src_dir/}"
        install_file "$src_file" "$dst_dir/$rel" "$backup_base"
    done < <(find "$src_dir" -type f 2>/dev/null | sort)
}

echo "comfy-frontend-health installer"
echo "================================"
if $DIFF_ONLY; then
    echo "(--diff mode: showing what would change, nothing will be copied)"
fi

# 1. Install the desloppify fork
echo ""
echo "[1/5] Installing comfy-desloppify..."
if $DIFF_ONLY; then
    echo "  (skipped in --diff mode)"
elif command -v pip3 &>/dev/null; then
    pip3 install -e "$SCRIPT_DIR/desloppify-fork" 2>/dev/null || {
        echo "  editable install failed, trying regular install..."
        pip3 install "$SCRIPT_DIR/desloppify-fork"
    }
else
    echo "  pip3 not found. Install manually: pip install -e $SCRIPT_DIR/desloppify-fork"
fi

# 2. Copy Claude Code agents/skills/commands into the target project
echo ""
echo "[2/5] Installing Claude Code agents and skills into $TARGET/.claude/..."

if ! $DIFF_ONLY; then
    mkdir -p "$TARGET/.claude/agents"
    mkdir -p "$TARGET/.claude/skills"
    mkdir -p "$TARGET/.claude/commands"
fi

# Agents
echo "  agents:"
install_tree "$SCRIPT_DIR/claude/agents" "$TARGET/.claude/agents" "$TARGET"

# Skills (preserve directory structure)
echo "  skills:"
install_tree "$SCRIPT_DIR/claude/skills" "$TARGET/.claude/skills" "$TARGET"

# Commands
echo "  commands:"
for src_file in "$SCRIPT_DIR/claude/commands/"*.md; do
    [[ -f "$src_file" ]] || continue
    install_file "$src_file" "$TARGET/.claude/commands/$(basename "$src_file")" "$TARGET"
done

# Global command
echo ""
echo "[3/5] Installing /comfy-deslop global command..."
if ! $DIFF_ONLY; then
    mkdir -p "$HOME/.claude/commands"
fi
install_file "$SCRIPT_DIR/claude/commands/comfy-deslop.md" "$HOME/.claude/commands/comfy-deslop.md" "$HOME"

# 4. Symlink comfy-health CLI wrapper
echo ""
echo "[4/5] Installing comfy-health CLI..."
if $DIFF_ONLY; then
    echo "  (skipped in --diff mode)"
else
    WRAPPER="$SCRIPT_DIR/comfy-health"
    if [[ -x "$WRAPPER" ]]; then
        LINK_DIR="${HOME}/.local/bin"
        mkdir -p "$LINK_DIR"
        ln -sf "$WRAPPER" "$LINK_DIR/comfy-health"
        echo "  comfy-health symlinked to $LINK_DIR/comfy-health"
        if ! echo "$PATH" | grep -q "$LINK_DIR"; then
            echo "  (add $LINK_DIR to your PATH if not already there)"
        fi
    else
        echo "  comfy-health wrapper not found, skipping"
    fi
fi

# 5. Install shell completions
echo ""
echo "[5/5] Installing shell completions..."
if $DIFF_ONLY; then
    echo "  (skipped in --diff mode)"
else
    COMP_DIR="$SCRIPT_DIR/completions"
    if [[ -f "$COMP_DIR/comfy-health.bash" ]]; then
        # Try system completion dir first, fall back to user dir
        if [[ -d "/etc/bash_completion.d" ]] && [[ -w "/etc/bash_completion.d" ]]; then
            cp "$COMP_DIR/comfy-health.bash" /etc/bash_completion.d/comfy-health
            echo "  bash completions installed to /etc/bash_completion.d/"
        elif [[ -d "${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}" ]]; then
            user_comp="${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}"
            mkdir -p "$user_comp"
            cp "$COMP_DIR/comfy-health.bash" "$user_comp/comfy-health"
            echo "  bash completions installed to $user_comp/"
        else
            echo "  bash completions available at: source $COMP_DIR/comfy-health.bash"
        fi
    fi
    if [[ -f "$COMP_DIR/comfy-health.zsh" ]]; then
        zsh_comp="${HOME}/.zsh/completions"
        mkdir -p "$zsh_comp"
        cp "$COMP_DIR/comfy-health.zsh" "$zsh_comp/_comfy-health"
        echo "  zsh completions installed to $zsh_comp/"
        echo "  (add 'fpath=(~/.zsh/completions \$fpath)' to .zshrc if needed)"
    fi
fi

# --- Summary ---
echo ""
echo "================================"
TOTAL=$((ADDED + CHANGED + UNCHANGED))
if $DIFF_ONLY; then
    echo "Diff complete: $TOTAL files checked"
else
    echo "Install complete: $TOTAL files synced"
fi
echo "  $ADDED added  |  $CHANGED changed  |  $UNCHANGED unchanged"
if [[ $CHANGED -gt 0 ]] && ! $DIFF_ONLY; then
    echo "  backups: $BACKUP_DIR"
fi

if ! $DIFF_ONLY; then
    echo ""
    echo "Available commands:"
    echo ""
    echo "  CLI:"
    echo "    comfy-health scan              Full repo health scan"
    echo "    comfy-health scan --skip-slow  Skip duplicate detection"
    echo "    comfy-health check             Assess subjective quality dimensions"
    echo "    comfy-health status            Full dashboard with scores"
    echo "    comfy-health show <file>       Dig into issues for a file or detector"
    echo "    comfy-health next              Next priority fix"
    echo ""
    echo "  Claude Code slash commands:"
    echo "    /pre-pr                        Local quality gate before pushing"
    echo "    /pre-pr --quick                Stage 1 only (~30s)"
    echo "    /pre-pr --full                 Full check with build + bundle size"
    echo "    /comfy-deslop                  ComfyUI-tuned scan (full repo)"
    echo "    /comfy-deslop src/             Focused folder scan"
    echo "    /behavioral-health             Test health audit"
fi
