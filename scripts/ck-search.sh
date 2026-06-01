#!/usr/bin/env bash
# ck-search.sh — Full-text search across the common-knowledge store
# Usage: bash ck-search.sh <query> [CK_HOME_OVERRIDE]
# Called by: the common-knowledge skill during Phase 6 (search)

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
FOUND=0
MATCH_COUNT=0
MAX_MATCHES=50

# Collect results, group by project
declare -A PROJECT_MATCHES

while IFS= read -r match; do
  FOUND=1
  MATCH_COUNT=$((MATCH_COUNT + 1))
  if [[ $MATCH_COUNT -gt $MAX_MATCHES ]]; then
    break
  fi

  # Extract project from path
  REL_PATH="${match#"$CK_HOME/"}"
  PROJECT=$(echo "$REL_PATH" | cut -d'/' -f1)

  if [[ -z "${PROJECT_MATCHES[$PROJECT]+x}" ]]; then
    PROJECT_MATCHES[$PROJECT]=""
  fi
  PROJECT_MATCHES[$PROJECT]+="  ${match}"$'\n'

done < <(grep -rn \
  --include="*.md" \
  --include="*.json" \
  --include="*.sql" \
  --include="*.yaml" \
  --include="*.yml" \
  -i "$QUERY" "$CK_HOME" \
  --exclude-dir=".git" \
  2>/dev/null || true)

# ─── Output grouped by project ─────────────────────────────────────────────────
if [[ $FOUND -eq 0 ]]; then
  echo "No results found for: \"$QUERY\""
  echo ""
  echo "Tip: Try a shorter or different keyword."
  exit 0
fi

for PROJECT in "${!PROJECT_MATCHES[@]}"; do
  if [[ "$PROJECT" == "_global" ]]; then
    echo "📁 _global (cross-project knowledge)"
  else
    echo "📁 $PROJECT"
    # Show description from meta.json if available
    META="$CK_HOME/$PROJECT/meta.json"
    if [[ -f "$META" ]]; then
      DESC=$(python3 -c "import json,sys; d=json.load(open('$META')); print(d.get('description',''))" 2>/dev/null || \
             grep -o '"description":"[^"]*"' "$META" 2>/dev/null | head -1 | sed 's/"description":"//;s/"//')
      [[ -n "$DESC" ]] && echo "   $DESC"
    fi
  fi
  echo "${PROJECT_MATCHES[$PROJECT]}"
done

if [[ $MATCH_COUNT -ge $MAX_MATCHES ]]; then
  echo "⚠️  Results capped at $MAX_MATCHES matches. Refine your query for more specific results."
fi

echo "─────────────────────────────"
echo "Total matches: $MATCH_COUNT"
