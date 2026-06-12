#!/usr/bin/env bash
# ck-autosync.sh — Commit any pending changes in the common-knowledge store.
# Intended as a Claude Code SessionEnd hook so knowledge written during a session
# is never left uncommitted. Deterministic, safe, quiet when there is nothing to do.
#
# Usage: ck-autosync.sh        (CK_HOME from env or default)

set -uo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
[[ -d "$CK_HOME/.git" ]] || exit 0
command -v git &>/dev/null || exit 0

# ─── Local leg: commit anything the session left uncommitted ────────────────────
if ! git -C "$CK_HOME" diff --quiet || ! git -C "$CK_HOME" diff --cached --quiet \
   || [[ -n "$(git -C "$CK_HOME" ls-files --others --exclude-standard)" ]]; then
  STAMP=$(date -u "+%Y-%m-%dT%H:%MZ" 2>/dev/null || echo "unknown")
  git -C "$CK_HOME" add -A
  if git -C "$CK_HOME" commit -qm "chore: auto-sync knowledge store $STAMP"; then
    echo "🔄 common-knowledge: auto-synced uncommitted changes ($STAMP)"
  fi
fi

# ─── Cloud leg (opt-in: CH_AUTO_PUSH=true in $CK_HOME/.cloud) ───────────────────
# Pushes only projects that changed since their last push, so other agents and
# machines can catch up. Runs even when the tree was already clean — an earlier
# session may have committed without reaching the cloud. Best-effort: a dead
# network never breaks session end.
CONF="$CK_HOME/.cloud"
if [[ -f "$CONF" && "$(sed -n 's/^CH_AUTO_PUSH=//p' "$CONF" | head -1)" == "true" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [[ -f "$SCRIPT_DIR/ck-cloud.sh" ]]; then
    bash "$SCRIPT_DIR/ck-cloud.sh" push --all --changed 2>/dev/null || true
  fi
fi
exit 0
