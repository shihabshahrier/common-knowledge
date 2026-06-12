#!/usr/bin/env bash
# install.sh — Install the common-knowledge skill to all AI agent paths
# Usage:
#   bash install.sh            install the skill to all agent paths
#   bash install.sh --hooks    also wire the autonomy hooks into Claude Code
#                              (~/.claude/settings.json: SessionStart recall +
#                               SessionEnd auto-sync). Backs up settings first.

set -e

SKILL="common-knowledge"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SRC="$SCRIPT_DIR/skills/$SKILL"
WITH_HOOKS=0
[[ "${1:-}" == "--hooks" ]] && WITH_HOOKS=1

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

install_hooks() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  local recall="$HOME/.claude/skills/$SKILL/scripts/ck-recall.sh"
  local autosync="$HOME/.claude/skills/$SKILL/scripts/ck-autosync.sh"
  local recall_cmd="bash \"$recall\""
  local autosync_cmd="bash \"$autosync\""

  echo ""
  echo "🪝 Wiring autonomy hooks into: $settings"

  if ! command -v jq &>/dev/null; then
    echo "  ⚠️  jq not found — cannot safely merge JSON."
    echo "     Add the contents of hooks/hooks.json to $settings manually."
    return 0
  fi

  mkdir -p "$(dirname "$settings")"
  [[ -f "$settings" ]] || echo '{}' > "$settings"

  local backup="${settings}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
  cp "$settings" "$backup"
  echo "  💾 Backup: $backup"

  # Append our hook entries only if an entry with the same command isn't present.
  local tmp; tmp="$(mktemp)"
  jq \
    --arg rc "$recall_cmd" \
    --arg ac "$autosync_cmd" '
    def has_cmd($evt; $cmd):
      [ .hooks[$evt][]?.hooks[]?.command ] | any(. == $cmd);
    .hooks //= {}
    | .hooks.SessionStart //= []
    | .hooks.SessionEnd //= []
    | (if has_cmd("SessionStart"; $rc) then .
       else .hooks.SessionStart += [ { "hooks": [ { "type":"command", "command":$rc } ] } ] end)
    | (if has_cmd("SessionEnd"; $ac) then .
       else .hooks.SessionEnd += [ { "hooks": [ { "type":"command", "command":$ac } ] } ] end)
  ' "$settings" > "$tmp" && mv "$tmp" "$settings"

  echo "  ✅ SessionStart → ck-recall.sh (warm-start context)"
  echo "  ✅ SessionEnd   → ck-autosync.sh (commit pending changes)"
  echo "     Restore anytime: cp \"$backup\" \"$settings\""
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

if [[ "$WITH_HOOKS" -eq 1 ]]; then
  install_hooks
fi

echo ""
echo "✅ Installation complete."
echo ""
echo "Usage in any AI agent:"
echo "  /ck init                    — create the knowledge store"
echo "  /ck save <project>          — save current project knowledge"
echo "  /ck load <project>          — load project knowledge into context"
echo "  /ck learn \"<text>\"          — capture a gotcha/insight/idea"
echo "  /ck status                  — list all tracked projects"
echo "  /ck search <query>          — search across the store"
echo "  /ck cloud connect …         — optional: bridge to a Context-Heavy cloud brain"
echo ""
if [[ "$WITH_HOOKS" -eq 0 ]]; then
  echo "Autonomy (optional): bash install.sh --hooks"
  echo "  → SessionStart auto-recalls project lessons; SessionEnd auto-commits."
  echo ""
fi
echo "Reinstall anytime: bash install.sh"
