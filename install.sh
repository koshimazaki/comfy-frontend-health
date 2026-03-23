#!/usr/bin/env bash
set -euo pipefail

# comfy-frontend-health installer
# Installs the desloppify fork + copies Claude Code agents/skills into target project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"

echo "comfy-frontend-health installer"
echo "================================"

# 1. Install the desloppify fork
echo ""
echo "[1/5] Installing comfy-desloppify..."
if command -v pip3 &>/dev/null; then
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

mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.claude/commands"

# Agents
cp -r "$SCRIPT_DIR/claude/agents/"* "$TARGET/.claude/agents/" 2>/dev/null && \
    echo "  agents: $(ls "$SCRIPT_DIR/claude/agents/" | wc -l | tr -d ' ') copied" || true

# Skills (preserve directory structure)
for skill_dir in "$SCRIPT_DIR/claude/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$TARGET/.claude/skills/$skill_name"
    cp -r "$skill_dir"* "$TARGET/.claude/skills/$skill_name/" 2>/dev/null
done
echo "  skills: $(ls -d "$SCRIPT_DIR/claude/skills/"*/ 2>/dev/null | wc -l | tr -d ' ') copied"

# Commands
cp "$SCRIPT_DIR/claude/commands/"*.md "$TARGET/.claude/commands/" 2>/dev/null && \
    echo "  commands: $(ls "$SCRIPT_DIR/claude/commands/"*.md | wc -l | tr -d ' ') copied" || true

# Global command
echo ""
echo "[3/5] Installing /comfy-deslop global command..."
mkdir -p "$HOME/.claude/commands"
cp "$SCRIPT_DIR/claude/commands/comfy-deslop.md" "$HOME/.claude/commands/" && \
    echo "  /comfy-deslop installed globally" || true

# 4. Symlink comfy-health CLI wrapper
echo ""
echo "[4/5] Installing comfy-health CLI..."
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

# 5. Install shell completions
echo ""
echo "[5/5] Installing shell completions..."
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

echo ""
echo "Done! Available commands:"
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
