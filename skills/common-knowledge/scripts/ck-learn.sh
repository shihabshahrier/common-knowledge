#!/usr/bin/env bash
# ck-learn.sh — Append a learning (gotcha, pattern, pitfall, insight, idea) to the store
# Usage:
#   ck-learn.sh --home <CK_HOME> [--project <slug>] [--type <t>] [--tags <csv>] \
#               [--title <title>] --body <text>
# If --project is omitted the learning is global (_global/learnings.md).
# The agent composes title/body prose; this script persists + commits deterministically.
# Called by: the common-knowledge skill during Phase 3F (learn)
# Compatible with bash 3.2+.

set -euo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
PROJECT=""
TYPE="insight"
TAGS=""
TITLE=""
BODY=""

# ─── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)    CK_HOME="$2"; shift 2 ;;
    --project) PROJECT="$2"; shift 2 ;;
    --type)    TYPE="$2"; shift 2 ;;
    --tags)    TAGS="$2"; shift 2 ;;
    --title)   TITLE="$2"; shift 2 ;;
    --body)    BODY="$2"; shift 2 ;;
    *)         echo "❌ Unknown arg: $1"; exit 1 ;;
  esac
done

if [[ -z "$BODY" ]]; then
  echo "Usage: ck-learn.sh --home <CK_HOME> [--project <slug>] [--type <t>] [--tags <csv>] [--title <title>] --body <text>"
  exit 1
fi

# ─── Validate type against the allowed vocabulary ───────────────────────────────
case "$TYPE" in
  gotcha|pattern|pitfall|insight|idea) : ;;
  *) echo "⚠️  Unknown type '$TYPE' — defaulting to 'insight'."; TYPE="insight" ;;
esac

if [[ ! -d "$CK_HOME" ]]; then
  echo "❌ Knowledge store not found at: $CK_HOME"
  echo "   Run /ck init to create it."
  exit 1
fi

# ─── Resolve target file + scope label ──────────────────────────────────────────
if [[ -n "$PROJECT" ]]; then
  TARGET_DIR="$CK_HOME/$PROJECT"
  TARGET="$TARGET_DIR/learnings.md"
  SCOPE_LABEL="$PROJECT"
  PROJECT_FIELD="$PROJECT"
  COMMIT_SCOPE="$PROJECT"
  mkdir -p "$TARGET_DIR"
else
  TARGET_DIR="$CK_HOME/_global"
  TARGET="$TARGET_DIR/learnings.md"
  SCOPE_LABEL="Global"
  PROJECT_FIELD="—"
  COMMIT_SCOPE="global"
  mkdir -p "$TARGET_DIR"
fi

DATE=$(date -u "+%Y-%m-%d" 2>/dev/null || echo "unknown")
[[ -z "$TITLE" ]] && TITLE=$(echo "$BODY" | head -1 | cut -c1-60)
[[ -z "$TAGS" ]] && TAGS="—"

# ─── Create header if file is new (never overwrite — append-only) ───────────────
if [[ ! -f "$TARGET" ]]; then
  cat > "$TARGET" << EOF
# Learnings — $SCOPE_LABEL

Append-only log of gotchas, fixes, patterns, and insights captured for future
decision-making. Newest entries at the bottom. Recall with \`/ck learnings\`.

---
EOF
fi

# ─── Append the entry ───────────────────────────────────────────────────────────
cat >> "$TARGET" << EOF

## $DATE — $TITLE

> **Type:** $TYPE  |  **Tags:** $TAGS  |  **Project:** $PROJECT_FIELD

$BODY

---
EOF

echo "🧠 Learning saved to: ${TARGET#"$CK_HOME/"}"
echo "   $DATE — $TITLE  [$TYPE]"

# ─── Commit ──────────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "⚠️  git not found — learning saved but not committed."
  exit 0
fi

git -C "$CK_HOME" add -A
git -C "$CK_HOME" diff --cached --quiet && echo "ℹ️  Nothing new to commit." || \
  git -C "$CK_HOME" commit -qm "feat($COMMIT_SCOPE): capture learning — $TITLE [learning]"
