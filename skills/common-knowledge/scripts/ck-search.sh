#!/usr/bin/env bash
# ck-search.sh — Search across the common-knowledge store.
#
# Usage:
#   ck-search.sh <query> [CK_HOME]            full-text search (back-compatible)
#   ck-search.sh <query> --home <CK_HOME> [--per-project N] [--manifest]
#
# Flags:
#   --per-project N   max matches shown per project (default 5). Overflow is
#                     reported as "(+K more)" so a project is NEVER silently
#                     dropped — vital at 100+ repos where a common term would
#                     otherwise blow past a global cap and hide whole projects.
#   --manifest        search only the cheap discovery layer: _global/catalog.json
#                     + each project's index.json + brief.md. Token-light way to
#                     find WHICH projects are relevant; pull detail with /ck load.
#
# -F = fixed-string (no regex injection). .git excluded. Grouped by project.
# Compatible with bash 3.2+.

set -uo pipefail

QUERY=""; CK_HOME="${CK_HOME:-$HOME/common-knowledge}"; PER_PROJECT=5; MANIFEST=0
_seen_home=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)         CK_HOME="$2"; _seen_home=1; shift 2 ;;
    --per-project)  PER_PROJECT="$2"; shift 2 ;;
    --manifest)     MANIFEST=1; shift ;;
    -*)             echo "❌ Unknown flag: $1" >&2; exit 1 ;;
    *)
      if [[ -z "$QUERY" ]]; then QUERY="$1"
      elif [[ "$_seen_home" -eq 0 ]]; then CK_HOME="$1"   # back-compat positional
      fi
      shift ;;
  esac
done

if [[ -z "$QUERY" ]]; then
  echo "Usage: ck-search.sh <query> [CK_HOME] [--per-project N] [--manifest]" >&2
  exit 1
fi
if [[ ! -d "$CK_HOME" ]]; then
  echo "❌ Knowledge store not found at: $CK_HOME"
  echo "   Run /ck init to create it."
  exit 1
fi

MODE="full-text"; [[ "$MANIFEST" -eq 1 ]] && MODE="manifest"
echo "🔍 Searching ($MODE) for: \"$QUERY\" in $CK_HOME"
echo ""

# ─── Collect matches ────────────────────────────────────────────────────────────
if [[ "$MANIFEST" -eq 1 ]]; then
  # Discovery layer only: catalog + per-project index.json + brief.md.
  TARGETS=()
  [[ -f "$CK_HOME/_global/catalog.json" ]] && TARGETS+=("$CK_HOME/_global/catalog.json")
  while IFS= read -r f; do TARGETS+=("$f"); done < <(
    find "$CK_HOME" -path "$CK_HOME/.git" -prune -o \
      \( -name index.json -o -name brief.md \) -print 2>/dev/null | sort)
  if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "No manifest files yet. Run /ck status to build the catalog."; exit 0
  fi
  RESULTS=$(grep -rnF "$QUERY" "${TARGETS[@]}" 2>/dev/null | head -400 || true)
else
  RESULTS=$(grep -rnF \
    --include="*.md" --include="*.json" --include="*.sql" \
    --include="*.yaml" --include="*.yml" --exclude-dir=".git" \
    "$QUERY" "$CK_HOME" 2>/dev/null | head -400 || true)
fi

if [[ -z "$RESULTS" ]]; then
  echo "No results found for: \"$QUERY\""
  echo ""
  echo "Tip: try a shorter keyword, or --manifest for cross-project discovery."
  exit 0
fi

# ─── Group by project, cap per project (no project silently dropped) ────────────
CURRENT=""; TOTAL=0; SHOWN_IN_PROJ=0; OVERFLOW=0; PROJECTS=0

flush_overflow() {
  [[ "$OVERFLOW" -gt 0 ]] && echo "  … (+$OVERFLOW more in $CURRENT — refine query or /ck load $CURRENT)"
}

while IFS= read -r line; do
  TOTAL=$((TOTAL + 1))
  FILEPATH="${line%%:*}"
  REL="${FILEPATH#"$CK_HOME/"}"
  PROJECT="${REL%%/*}"
  if [[ "$PROJECT" == "$REL" ]] || [[ "$PROJECT" == *.md ]] || [[ "$PROJECT" == *.json ]]; then
    PROJECT="(root)"
  fi

  if [[ "$PROJECT" != "$CURRENT" ]]; then
    flush_overflow
    [[ -n "$CURRENT" ]] && echo ""
    CURRENT="$PROJECT"; SHOWN_IN_PROJ=0; OVERFLOW=0; PROJECTS=$((PROJECTS + 1))
    if [[ "$PROJECT" == "_global" ]]; then
      echo "📁 _global (cross-project knowledge)"
    elif [[ "$PROJECT" == "(root)" ]]; then
      echo "📁 / (store root)"
    else
      echo "📁 $PROJECT"
      META="$CK_HOME/$PROJECT/meta.json"
      if [[ -f "$META" ]]; then
        DESC=$(sed -n 's/.*"description" *: *"\([^"]*\)".*/\1/p' "$META" 2>/dev/null | head -1)
        [[ -n "$DESC" ]] && echo "   $DESC"
      fi
    fi
  fi

  if [[ "$SHOWN_IN_PROJ" -lt "$PER_PROJECT" ]]; then
    echo "  $line"
    SHOWN_IN_PROJ=$((SHOWN_IN_PROJ + 1))
  else
    OVERFLOW=$((OVERFLOW + 1))
  fi
done <<< "$RESULTS"
flush_overflow

echo ""
echo "─────────────────────────────"
echo "Matches: $TOTAL across $PROJECTS project(s) · showing ≤$PER_PROJECT per project"
if [[ "$TOTAL" -ge 400 ]]; then
  echo "⚠️  Raw matches capped at 400. Use --manifest or a narrower query."
fi
exit 0
