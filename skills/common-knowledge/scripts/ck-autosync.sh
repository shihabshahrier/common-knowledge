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

# Nothing staged or unstaged → done.
if git -C "$CK_HOME" diff --quiet && git -C "$CK_HOME" diff --cached --quiet \
   && [[ -z "$(git -C "$CK_HOME" ls-files --others --exclude-standard)" ]]; then
  exit 0
fi

STAMP=$(date -u "+%Y-%m-%dT%H:%MZ" 2>/dev/null || echo "unknown")
git -C "$CK_HOME" add -A
git -C "$CK_HOME" commit -qm "chore: auto-sync knowledge store $STAMP" || exit 0
echo "🔄 common-knowledge: auto-synced uncommitted changes ($STAMP)"
exit 0
