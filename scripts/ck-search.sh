#!/usr/bin/env bash
# ck-search.sh — Full-text search across the common-knowledge store
# Usage: bash ck-search.sh <query> [CK_HOME_OVERRIDE]
# Called by: the common-knowledge skill during Phase 6 (search)
# Compatible with bash 3.2+ (no associative arrays)

set -euo pipefail

QUERY="${1:-}"
if [[ -z "$QUERY" ]]; then
  echo "Usage: ck-search.sh <query> [CK_HOME_OVERRIDE]"
  exit 1
fi

# ─── Resolve CK_HOME ──────────────────────────────────────────────────────────
if [[ -n "${2:-}" ]]; then
  CK_HOME="$2"
elif [[ -n "${CK_HOME:-}" ]]; then
  : # already set from environment
else
  CK_HOME="$HOME/common-knowledge"
fi

if [[ ! -d "$CK_HOME" ]]; then
  echo "❌ Knowledge store not found at: $CK_HOME"
  echo "   Run /ck init to create it."
  exit 1
fi

echo "🔍 Searching for: \"$QUERY\" in $CK_HOME"
echo ""

# ─── Search across all knowledge files ────────────────────────────────────────
# Uses -F for fixed-string (literal) matching — safe against regex injection.
# Results are sorted by path so project grouping is natural.
RESULTS=$(grep -rnF \
  --include="*.md" \
  --include="*.json" \
  --include="*.sql" \
  --include="*.yaml" \
  --include="*.yml" \
  "$QUERY" "$CK_HOME" \
  --exclude-dir=".git" \
  2>/dev/null | head -50 || true)

if [[ -z "$RESULTS" ]]; then
  echo "No results found for: \"$QUERY\""
  echo ""
  echo "Tip: Try a shorter or different keyword."
  exit 0
fi

# ─── Group output by project directory ─────────────────────────────────────────
CURRENT_PROJECT=""
MATCH_COUNT=0

while IFS= read -r line; do
  MATCH_COUNT=$((MATCH_COUNT + 1))

  # Extract project slug from path: $CK_HOME/<project>/...
  REL_PATH="${line#"$CK_HOME/"}"
  PROJECT="${REL_PATH%%/*}"

  # Print project header when project changes
  if [[ "$PROJECT" != "$CURRENT_PROJECT" ]]; then
    [[ -n "$CURRENT_PROJECT" ]] && echo ""
    CURRENT_PROJECT="$PROJECT"

    if [[ "$PROJECT" == "_global" ]]; then
      echo "📁 _global (cross-project knowledge)"
    else
      echo "📁 $PROJECT"
      # Show description from meta.json if available (pure bash, no python)
      META="$CK_HOME/$PROJECT/meta.json"
      if [[ -f "$META" ]]; then
        DESC=$(sed -n 's/.*"description" *: *"\([^"]*\)".*/\1/p' "$META" 2>/dev/null | head -1)
        [[ -n "$DESC" ]] && echo "   $DESC"
      fi
    fi
  fi

  echo "  $line"
done <<< "$RESULTS"

echo ""
echo "─────────────────────────────"
echo "Total matches: $MATCH_COUNT"

if [[ $MATCH_COUNT -ge 50 ]]; then
  echo "⚠️  Results capped at 50 matches. Refine your query for more specific results."
fi
