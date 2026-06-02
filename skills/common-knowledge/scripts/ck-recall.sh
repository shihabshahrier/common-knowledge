#!/usr/bin/env bash
# ck-recall.sh — Warm-start context injector for the common-knowledge store.
# Intended as a Claude Code SessionStart hook: detects the current project from
# cwd, and if the store has knowledge for it, prints a compact context block
# (project meta + lessons + last progress + global lessons titles) to stdout,
# which the agent picks up as session context.
#
# Read-only. Silent (exit 0, no output) when there is nothing relevant, so it
# never pollutes unrelated sessions.
#
# Usage: ck-recall.sh        (reads cwd; CK_HOME from env or default)

set -uo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
[[ -d "$CK_HOME" ]] || exit 0

# ─── Detect project slug from cwd (mirrors SKILL.md Phase 2) ────────────────────
RAW=$(git remote get-url origin 2>/dev/null | sed 's|.*/||; s/\.git$//')
[[ -z "$RAW" ]] && RAW=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
SLUG=$(printf '%s' "$RAW" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[ _./]\{1,\}/-/g; s/[^a-z0-9-]//g; s/-\{2,\}/-/g; s/^-//; s/-$//')

[[ -z "$SLUG" ]] && exit 0
PDIR="$CK_HOME/$SLUG"
[[ -d "$PDIR" ]] || exit 0   # no knowledge for this project → stay quiet

# ─── Emit a compact warm-start block ────────────────────────────────────────────
echo "📚 common-knowledge — recalled context for project: $SLUG"
echo "   (store: $CK_HOME)"
echo ""

# Brief is the curated warm core — load it first and in full if present.
if [[ -f "$PDIR/brief.md" ]]; then
  echo "### Brief"
  cat "$PDIR/brief.md"
  echo ""
fi

if [[ -f "$PDIR/meta.json" ]]; then
  DESC=$(sed -n 's/.*"description" *: *"\([^"]*\)".*/\1/p' "$PDIR/meta.json" | head -1)
  STATUS=$(sed -n 's/.*"status" *: *"\([^"]*\)".*/\1/p' "$PDIR/meta.json" | head -1)
  LP=$(sed -n 's/.*"local_path" *: *"\([^"]*\)".*/\1/p' "$PDIR/meta.json" | head -1)
  echo "### Project"
  [[ -n "$DESC" ]]   && echo "- $DESC"
  [[ -n "$STATUS" ]] && echo "- Status: $STATUS"
  [[ -n "$LP" ]]     && echo "- Local: $LP"
  echo ""
fi

if [[ -f "$PDIR/learnings.md" ]]; then
  echo "### Lessons for $SLUG (recall before deciding)"
  tail -n 60 "$PDIR/learnings.md"
  echo ""
fi

if [[ -f "$CK_HOME/_global/learnings.md" ]]; then
  TITLES=$(grep '^## ' "$CK_HOME/_global/learnings.md" 2>/dev/null | sed 's/^## /- /' | head -20)
  if [[ -n "$TITLES" ]]; then
    echo "### Global lessons (run /ck learnings for detail)"
    echo "$TITLES"
    echo ""
  fi
fi

if [[ -f "$PDIR/progress.md" ]]; then
  echo "### Recent progress"
  tail -n 20 "$PDIR/progress.md"
fi

exit 0
