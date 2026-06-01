#!/usr/bin/env bash
# install.sh — Install the common-knowledge skill to all AI agent paths
# Usage: bash install.sh

set -e

SKILL="common-knowledge"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skills/$SKILL"

if [[ ! -d "$SKILL_SRC" ]]; then
  echo "❌ Skill source not found at: $SKILL_SRC"
  exit 1
fi

install_to() {
  local dest="${1}/${SKILL}"
  mkdir -p "$dest"
  cp -r "$SKILL_SRC/." "$dest/"
  echo "  ✅ $dest"
}

echo "📦 Installing '${SKILL}' skill to all agent paths..."
echo ""

# Claude Code (primary)
install_to "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

# Codex / Amp / Goose / Kiro
install_to "$HOME/.agents/skills"

# opencode (SST)
install_to "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"

# Gemini CLI / Antigravity (standard path)
install_to "$HOME/.gemini/antigravity/skills"

# Gemini CLI / Antigravity (user's custom config path)
install_to "$HOME/.gemini/config/skills"

# OpenClaw
install_to "$HOME/.openclaw/workspace/skills"

echo ""
echo "✅ Installation complete."
echo ""
echo "Usage in any AI agent:"
echo "  /ck init                    — create the knowledge store"
echo "  /ck save <project>          — save current project knowledge"
echo "  /ck load <project>          — load project knowledge into context"
echo "  /ck status                  — list all tracked projects"
echo "  /ck search <query>          — search across the store"
echo ""
echo "Reinstall anytime: bash install.sh"
