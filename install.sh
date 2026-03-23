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
echo "[1/3] Installing comfy-desloppify..."
if command -v pip3 &>/dev/null; then
    pip3 install -e "$SCRIPT_DIR/desloppify-fork" 2>/dev/null || {
        echo "  pip install failed, trying uvx..."
        pip3 install "$SCRIPT_DIR/desloppify-fork"
    }
else
    echo "  pip3 not found. Install manually: pip install -e $SCRIPT_DIR/desloppify-fork"
fi

# 2. Copy Claude Code agents/skills/commands into the target project
echo ""
echo "[2/3] Installing Claude Code agents and skills into $TARGET/.claude/..."

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
echo "[3/3] Installing /comfy-deslop global command..."
mkdir -p "$HOME/.claude/commands"
cp "$SCRIPT_DIR/claude/commands/comfy-deslop.md" "$HOME/.claude/commands/" && \
    echo "  /comfy-deslop installed globally" || true

echo ""
echo "Done! Available commands:"
echo "  desloppify scan          Full repo health scan"
echo "  /comfy-deslop            ComfyUI-tuned scan (full repo)"
echo "  /comfy-deslop src/       Focused folder scan"
echo "  /comfy-deslop --pr 123   PR review"
echo "  /comfy-deslop --staged   Pre-commit check"
echo "  /comfy-deslop HEAD~3     Recent commits scan"
echo "  /pre-pr                  Local quality gate before pushing"
echo "  /pre-pr --quick          Fast check (skip code review)"
echo "  /pre-pr --full           Full check with build + bundle size"
