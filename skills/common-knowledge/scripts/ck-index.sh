#!/usr/bin/env bash
# ck-index.sh — Upsert an entry into a project's index.json manifest.
# The manifest is the cheap, complete, machine-readable map of a project's
# knowledge: one entry per fact/file with summary + tags + importance + updated,
# so an agent can triage what to load WITHOUT reading every body. Importance
# drives no-miss loading (critical entries load first).
#
# Usage:
#   ck-index.sh --home <CK_HOME> --project <slug> --id <id> --file <relpath> \
#               --summary <text> [--tags <csv>] [--importance critical|normal] \
#               [--no-commit]
#
# Upsert semantics: an existing entry with the same id is replaced; `updated`
# is always set to now. JSON stays valid (jq). Commits by default.
# Called by: the skill during save / learn / ingest / map / schema.

set -euo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
PROJECT=""; ID=""; FILE=""; SUMMARY=""; TAGS=""; IMPORTANCE="normal"; COMMIT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)       CK_HOME="$2"; shift 2 ;;
    --project)    PROJECT="$2"; shift 2 ;;
    --id)         ID="$2"; shift 2 ;;
    --file)       FILE="$2"; shift 2 ;;
    --summary)    SUMMARY="$2"; shift 2 ;;
    --tags)       TAGS="$2"; shift 2 ;;
    --importance) IMPORTANCE="$2"; shift 2 ;;
    --no-commit)  COMMIT=0; shift ;;
    *) echo "❌ Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$PROJECT" || -z "$ID" || -z "$SUMMARY" ]]; then
  echo "Usage: ck-index.sh --home <CK_HOME> --project <slug> --id <id> --file <relpath> --summary <text> [--tags <csv>] [--importance critical|normal] [--no-commit]" >&2
  exit 1
fi
case "$IMPORTANCE" in critical|normal) : ;; *) IMPORTANCE="normal" ;; esac
[[ -d "$CK_HOME" ]] || { echo "❌ Store not found: $CK_HOME (run /ck init)" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "❌ jq required for index.json" >&2; exit 1; }

PDIR="$CK_HOME/$PROJECT"; mkdir -p "$PDIR"
IDX="$PDIR/index.json"
[[ -f "$IDX" ]] || echo '{"project":"'"$PROJECT"'","entries":[]}' > "$IDX"

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# csv tags → json array
TAGS_JSON="$(printf '%s' "$TAGS" | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s .)"

tmp="$(mktemp)"
jq \
  --arg id "$ID" --arg file "$FILE" --arg sum "$SUMMARY" \
  --arg imp "$IMPORTANCE" --arg upd "$NOW" --argjson tags "$TAGS_JSON" '
  .entries = ([ .entries[]? | select(.id != $id) ]
    + [ { id:$id, file:$file, summary:$sum, tags:$tags, importance:$imp, updated:$upd } ])
' "$IDX" > "$tmp" && mv "$tmp" "$IDX"

echo "🗂  index: $PROJECT/$ID [$IMPORTANCE] → ${FILE:-—}"

if [[ "$COMMIT" -eq 1 ]] && command -v git >/dev/null 2>&1 && [[ -d "$CK_HOME/.git" ]]; then
  git -C "$CK_HOME" add -A
  git -C "$CK_HOME" diff --cached --quiet || \
    git -C "$CK_HOME" commit -qm "chore($PROJECT): index $ID [index]"
fi
