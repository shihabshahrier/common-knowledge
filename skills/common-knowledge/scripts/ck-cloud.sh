#!/usr/bin/env bash
# ck-cloud.sh — Bridge between the local common-knowledge store and a
# Context-Heavy cloud brain (https://github.com/shihabshahrier/Context-Heavy).
#
# The store stays local-first and git-backed; the cloud brain is an optional
# second home where pushed knowledge becomes searchable (hybrid FTS+vector),
# graph-linked, and shareable across agents and machines. Push is idempotent
# on the server (re-push never duplicates), pull is read-only (it prints
# context, it never writes store files — no echo loops).
#
# Subcommands:
#   connect --url <url> --key <cg_live_...> [--agent <name>]
#           [--auto-pull] [--auto-push]        configure the bridge
#   push [<project>] [--all] [--changed] [--dry-run]   store → cloud
#   pull [<project>] [--agent <name>]                  cloud → context (read-only)
#   status                                             show config + sync markers
#
# Config: $CK_HOME/.cloud (KEY=VALUE, gitignored, chmod 600). Env vars
# CH_API_URL / CH_API_KEY / CH_AGENT override the file. Sync markers live in
# $CK_HOME/.cloud-state.json (gitignored) — per-machine state, deliberately
# outside git so marker updates never create commits that re-trigger a push.
#
# Requires: curl + python3 (push/pull only; connect/status are pure bash).
# Compatible with bash 3.2+.

set -uo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
CONF="$CK_HOME/.cloud"
STATE="$CK_HOME/.cloud-state.json"

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

# ─── Config (file parsed with sed — never sourced/executed) ─────────────────────
cfg() { [[ -f "$CONF" ]] && sed -n "s/^$1=//p" "$CONF" | head -1 || true; }

load_config() {
  CH_API_URL="${CH_API_URL:-$(cfg CH_API_URL)}"
  CH_API_KEY="${CH_API_KEY:-$(cfg CH_API_KEY)}"
  CH_AGENT="${CH_AGENT:-$(cfg CH_AGENT)}"
  CH_AUTO_PULL="${CH_AUTO_PULL:-$(cfg CH_AUTO_PULL)}"
  CH_AUTO_PUSH="${CH_AUTO_PUSH:-$(cfg CH_AUTO_PUSH)}"
  CH_API_URL="${CH_API_URL%/}"
}

require_config() {
  load_config
  if [[ -z "${CH_API_URL:-}" || -z "${CH_API_KEY:-}" ]]; then
    echo "❌ Cloud bridge not configured."
    echo "   Run: /ck cloud connect --url <api-url> --key <cg_live_...>"
    echo "   (or set CH_API_URL + CH_API_KEY env vars)"
    exit 1
  fi
}

require_tools() {
  command -v curl &>/dev/null || { echo "❌ curl not found — required for cloud sync."; exit 1; }
  command -v python3 &>/dev/null || { echo "❌ python3 not found — required for cloud sync."; exit 1; }
}

# Keep bridge files out of the store's git history (idempotent).
ensure_gitignored() {
  local gi="$CK_HOME/.gitignore"
  [[ -d "$CK_HOME" ]] || return 0
  touch "$gi"
  grep -qx '\.cloud' "$gi" 2>/dev/null || echo '.cloud' >> "$gi"
  grep -qx '\.cloud-state\.json' "$gi" 2>/dev/null || echo '.cloud-state.json' >> "$gi"
}

# ─── connect ─────────────────────────────────────────────────────────────────────
cmd_connect() {
  local url="" key="" agent="" auto_pull="false" auto_push="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url)       url="$2"; shift 2 ;;
      --key)       key="$2"; shift 2 ;;
      --agent)     agent="$2"; shift 2 ;;
      --auto-pull) auto_pull="true"; shift ;;
      --auto-push) auto_push="true"; shift ;;
      *)           echo "❌ Unknown arg: $1"; usage ;;
    esac
  done
  [[ -z "$url" || -z "$key" ]] && { echo "❌ --url and --key are required."; usage; }
  [[ -d "$CK_HOME" ]] || { echo "❌ Store not found at $CK_HOME — run /ck init first."; exit 1; }

  cat > "$CONF" << EOF
CH_API_URL=${url%/}
CH_API_KEY=$key
CH_AGENT=$agent
CH_AUTO_PULL=$auto_pull
CH_AUTO_PUSH=$auto_push
EOF
  chmod 600 "$CONF"
  ensure_gitignored

  echo "☁️  Cloud bridge configured."
  echo "   URL:        ${url%/}"
  echo "   Key:        ${key:0:12}… (stored in $CONF, gitignored, chmod 600)"
  [[ -n "$agent" ]] && echo "   Agent:      $agent"
  echo "   Auto-pull:  $auto_pull   (SessionStart hook adds cloud warm-start)"
  echo "   Auto-push:  $auto_push   (SessionEnd hook pushes changed projects)"
  echo "   Try it:     /ck push <project> --dry-run"
}

# ─── status ──────────────────────────────────────────────────────────────────────
cmd_status() {
  load_config
  echo "☁️  Cloud bridge status"
  if [[ -z "${CH_API_URL:-}" || -z "${CH_API_KEY:-}" ]]; then
    echo "   Not configured. Run: /ck cloud connect --url <url> --key <cg_live_...>"
    return 0
  fi
  echo "   URL:        $CH_API_URL"
  echo "   Key:        ${CH_API_KEY:0:12}…"
  echo "   Agent:      ${CH_AGENT:-—}"
  echo "   Auto-pull:  ${CH_AUTO_PULL:-false}"
  echo "   Auto-push:  ${CH_AUTO_PUSH:-false}"
  if [[ -f "$STATE" ]] && command -v python3 &>/dev/null; then
    echo "   Last pushes:"
    python3 - "$STATE" << 'PY'
import json, sys
try:
    state = json.load(open(sys.argv[1]))
except Exception:
    state = {}
if not state:
    print("     (none yet)")
for slug, m in sorted(state.items()):
    print(f"     {slug}: {m.get('last_pushed_at', '?')}  commit {m.get('last_commit', '?')[:8]}")
PY
  else
    echo "   Last pushes: (none yet)"
  fi
}

# ─── push helpers ────────────────────────────────────────────────────────────────

# build_payload <slug> — emit the CKSyncInput JSON for one project on stdout.
# Parses meta.json, section files, learnings.md (incl. _global) and
# connections.md into the contract shape POST /v1/sync/ck expects.
build_payload() {
  CK_HOME="$CK_HOME" PROJECT="$1" python3 << 'PY'
import json, os, re, sys

home = os.environ["CK_HOME"]
slug = os.environ["PROJECT"]
pdir = os.path.join(home, slug)

def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None

# meta.json → passthrough properties on the Project node.
meta = {}
raw = read(os.path.join(pdir, "meta.json"))
if raw:
    try:
        meta = json.loads(raw)
    except ValueError:
        print(f"⚠️  {slug}/meta.json is not valid JSON — pushing without meta", file=sys.stderr)

# Section files → Document nodes. learnings/connections are structured
# separately; README.md and index.json are derived artifacts — skipped.
section_files = [
    ("brief", "brief.md"),
    ("codebase-map", "codebase-map.md"),
    ("decisions", "decisions.md"),
    ("progress", "progress.md"),
    ("schema-db", "schema/db.md"),
    ("api-endpoints", "api/endpoints.md"),
    ("frontend-components", "frontend/components.md"),
    ("infra-overview", "infra/overview.md"),
    ("workers-overview", "workers/overview.md"),
]
sections = []
for name, rel in section_files:
    content = read(os.path.join(pdir, rel))
    if content and content.strip():
        sections.append({"name": name, "content": content})

# learnings.md entries (format written by ck-learn.sh):
#   ## <date> — <title>
#   > **Type:** t  |  **Tags:** csv  |  **Project:** p
#   <body…>
#   ---
def parse_learnings(text, is_global):
    out = []
    if not text:
        return out
    for block in re.split(r"^## ", text, flags=re.M)[1:]:
        lines = block.splitlines()
        header = lines[0].strip()
        title = header.split(" — ", 1)[1] if " — " in header else header
        body = "\n".join(lines[1:])
        m = re.search(r"\*\*Type:\*\*\s*([a-zA-Z-]+)", body)
        ltype = m.group(1).lower() if m else "insight"
        m = re.search(r"\*\*Tags:\*\*\s*([^|\n]*)", body)
        tags = []
        if m:
            tags = [t.strip() for t in m.group(1).split(",")
                    if t.strip() and t.strip() != "—"]
        # Strip the meta blockquote and trailing rule, keep the prose.
        prose = re.sub(r"^>.*$", "", body, flags=re.M)
        prose = re.sub(r"^---\s*$", "", prose, flags=re.M).strip()
        def field(*labels):
            for lab in labels:
                m = re.search(
                    r"\*\*" + re.escape(lab) + r":?\*\*:?\s*(.*?)(?=\n\s*\*\*|\Z)",
                    prose, flags=re.S)
                if m and m.group(1).strip():
                    return m.group(1).strip()
            return ""
        ctx = field("Context")
        res = field("Resolution/Insight", "Resolution", "Insight")
        why = field("Why it matters", "Why")
        if not (ctx or res or why):
            ctx = prose  # unstructured body — keep everything as context
        entry = {"title": title, "learning_type": ltype, "context": ctx,
                 "resolution": res, "why_it_matters": why, "tags": tags}
        if is_global:
            entry["global"] = True
        out.append(entry)
    return out

learnings = parse_learnings(read(os.path.join(pdir, "learnings.md")), False)
# Global lessons ride along on every push; the server dedups by title slug,
# so re-sending is a cheap no-op (counted as learnings_skipped).
learnings += parse_learnings(read(os.path.join(home, "_global", "learnings.md")), True)

# connections.md entries (format written by Phase 3E link):
#   ## <project-b> [<type>]
#   - **Type:** rel
#   - **Notes:** …
connections = []
conn_raw = read(os.path.join(pdir, "connections.md"))
if conn_raw:
    for block in re.split(r"^## ", conn_raw, flags=re.M)[1:]:
        lines = block.splitlines()
        header = lines[0].strip()
        m = re.match(r"^(.*?)\s*\[([^\]]+)\]\s*$", header)
        to_project, rel = (m.group(1), m.group(2)) if m else (header, "")
        body = "\n".join(lines[1:])
        tm = re.search(r"\*\*Type:\*\*\s*([a-zA-Z_-]+)", body)
        if tm:
            rel = tm.group(1)
        nm = re.search(r"\*\*Notes:\*\*\s*(.*)", body)
        notes = nm.group(1).strip() if nm else ""
        if to_project.strip():
            connections.append({"to_project": to_project.strip(),
                                "relationship": rel.strip(), "notes": notes})

payload = {"project": slug, "meta": meta, "sections": sections,
           "learnings": learnings, "connections": connections}
json.dump(payload, sys.stdout)
PY
}

# mark_pushed <slug> <commit> — record the sync marker in .cloud-state.json.
mark_pushed() {
  STATE="$STATE" SLUG="$1" COMMIT="$2" URL="$CH_API_URL" python3 << 'PY'
import datetime, json, os
path = os.environ["STATE"]
try:
    state = json.load(open(path))
except Exception:
    state = {}
state[os.environ["SLUG"]] = {
    "last_commit": os.environ["COMMIT"],
    "last_pushed_at": datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ"),
    "url": os.environ["URL"],
}
with open(path, "w") as f:
    json.dump(state, f, indent=2, sort_keys=True)
PY
}

# project_commit <slug> — latest store commit touching this project (or "").
project_commit() {
  git -C "$CK_HOME" log -1 --format=%H -- "$1/" "_global/learnings.md" 2>/dev/null || true
}

# changed_since_push <slug> <commit> — 0 (true) when the project needs a push.
changed_since_push() {
  local slug="$1" head="$2" last=""
  [[ -f "$STATE" ]] && last=$(STATE="$STATE" SLUG="$slug" python3 -c '
import json, os
try:
    print(json.load(open(os.environ["STATE"])).get(os.environ["SLUG"], {}).get("last_commit", ""))
except Exception:
    print("")')
  [[ -z "$last" || "$head" != "$last" ]] && return 0
  # Same commit — still push if the working tree has uncommitted edits there.
  ! git -C "$CK_HOME" diff --quiet -- "$slug/" "_global/learnings.md" 2>/dev/null && return 0
  [[ -n "$(git -C "$CK_HOME" ls-files --others --exclude-standard -- "$slug/" 2>/dev/null)" ]] && return 0
  return 1
}

# push_project <slug> <dry_run> — build, POST, report, mark.
push_project() {
  local slug="$1" dry="$2"
  [[ -d "$CK_HOME/$slug" ]] || { echo "❌ No project '$slug' in $CK_HOME"; return 1; }

  local payload
  payload=$(build_payload "$slug") || { echo "❌ $slug: payload build failed"; return 1; }

  if [[ "$dry" == "true" ]]; then
    PAYLOAD="$payload" python3 << 'PY'
import json, os
p = json.loads(os.environ["PAYLOAD"])
print(f"   {p['project']}: {len(p['sections'])} sections, "
      f"{len(p['learnings'])} learnings, {len(p['connections'])} connections "
      f"({len(os.environ['PAYLOAD'])} bytes) — dry run, nothing sent")
PY
    return 0
  fi

  local resp http body
  resp=$(printf '%s' "$payload" | curl -sS --max-time 60 \
    -X POST "$CH_API_URL/v1/sync/ck" \
    -H "Authorization: Bearer $CH_API_KEY" \
    -H "Content-Type: application/json" \
    --data-binary @- -w '\n%{http_code}' 2>&1) || { echo "❌ $slug: ${resp:-curl failed}"; return 1; }
  http=$(printf '%s' "$resp" | tail -1)
  body=$(printf '%s' "$resp" | sed '$d')

  if [[ "$http" != "200" ]]; then
    echo "❌ $slug: push failed (HTTP $http)"
    echo "   ${body:0:300}"
    return 1
  fi

  BODY="$body" SLUG="$slug" python3 << 'PY'
import json, os
r = json.loads(os.environ["BODY"])
print(f"☁️  {os.environ['SLUG']} → pushed: "
      f"{r.get('sections_created',0)}+{r.get('sections_updated',0)} sections (new+updated), "
      f"{r.get('learnings_created',0)} learnings (+{r.get('learnings_skipped',0)} already known), "
      f"{r.get('connections',0)} connections")
PY
  mark_pushed "$slug" "$(project_commit "$slug")"
}

# ─── push ────────────────────────────────────────────────────────────────────────
cmd_push() {
  require_config
  require_tools
  ensure_gitignored
  local project="" all="false" changed="false" dry="false"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)     all="true"; shift ;;
      --changed) changed="true"; shift ;;
      --dry-run) dry="true"; shift ;;
      -*)        echo "❌ Unknown arg: $1"; usage ;;
      *)         project="$1"; shift ;;
    esac
  done

  local slugs=()
  if [[ "$all" == "true" || -z "$project" ]]; then
    # Every directory with a meta.json is a project; _global rides along.
    local d
    for d in "$CK_HOME"/*/; do
      d="${d%/}"
      [[ "$(basename "$d")" == "_global" ]] && continue
      [[ -f "$d/meta.json" ]] && slugs+=("$(basename "$d")")
    done
    [[ ${#slugs[@]} -eq 0 ]] && { echo "ℹ️  No projects in $CK_HOME yet."; return 0; }
  else
    slugs=("$project")
  fi

  local slug pushed=0 skipped=0 failed=0
  for slug in "${slugs[@]}"; do
    if [[ "$changed" == "true" ]] && ! changed_since_push "$slug" "$(project_commit "$slug")"; then
      skipped=$((skipped + 1))
      continue
    fi
    if push_project "$slug" "$dry"; then pushed=$((pushed + 1)); else failed=$((failed + 1)); fi
  done
  # Quiet when nothing happened (the hook contract: skip-only runs are silent).
  [[ "$pushed" -gt 0 || "$failed" -gt 0 ]] && [[ ${#slugs[@]} -gt 1 || "$skipped" -gt 0 ]] && \
    echo "   Done: $pushed pushed, $skipped unchanged, $failed failed."
  [[ "$failed" -gt 0 ]] && return 1
  return 0
}

# ─── pull ────────────────────────────────────────────────────────────────────────
cmd_pull() {
  require_config
  require_tools
  local project="" agent="${CH_AGENT:-}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      -*)      echo "❌ Unknown arg: $1"; usage ;;
      *)       project="$1"; shift ;;
    esac
  done

  local q="" warm lessons
  [[ -n "$project" ]] && q="project=$project"
  [[ -n "$agent" ]] && q="${q:+$q&}agent=$agent"
  # CK_CLOUD_MAX_TIME lets the SessionStart hook cap latency (default 20s).
  local mt="${CK_CLOUD_MAX_TIME:-20}"
  warm=$(curl -sS --max-time "$mt" "$CH_API_URL/v1/context/warm-start${q:+?$q}" \
    -H "Authorization: Bearer $CH_API_KEY") || { echo "❌ pull failed: cloud unreachable"; return 1; }
  lessons=$(curl -sS --max-time "$mt" \
    "$CH_API_URL/v1/learnings?limit=10${project:+&project=$project}" \
    -H "Authorization: Bearer $CH_API_KEY") || lessons=""

  WARM="$warm" LESSONS="$lessons" PROJECT="$project" URL="$CH_API_URL" python3 << 'PY'
import json, os, sys

def load(name):
    raw = os.environ.get(name, "")
    try:
        return json.loads(raw) if raw else {}
    except ValueError:
        return {}

warm, lessons = load("WARM"), load("LESSONS")
if warm.get("error") or warm.get("code"):
    print(f"❌ pull failed: {warm.get('message') or warm.get('error')}")
    sys.exit(1)

proj = os.environ.get("PROJECT") or "(workspace)"
print(f"☁️  Context-Heavy — cloud brain context for: {proj}")
print(f"   (source: {os.environ['URL']})\n")

persona = warm.get("persona") or {}
if persona.get("behavior"):
    print("### Persona (adopt this behavior)")
    print(persona["behavior"].strip() + "\n")

p = warm.get("project")
if p:
    line = f"- {p.get('name', '?')}"
    if p.get("description"):
        line += f" — {p['description']}"
    print("### Project\n" + line + "\n")

pinned = warm.get("pinned") or []
if pinned:
    print("### Pinned (always-relevant)")
    for n in pinned:
        d = f" — {n['description']}" if n.get("description") else ""
        print(f"- [{n.get('type','?')}] {n.get('name','?')}{d}")
    print()

hits = (lessons.get("data") or [])
if hits:
    print("### Lessons from the cloud brain (other agents/machines included)")
    for h in hits:
        body = (h.get("body") or "").strip()
        if len(body) > 400:
            body = body[:400] + "…"
        print(f"- [{h.get('learning_type','?')}] {h.get('name','?')}")
        if body:
            print("  " + body.replace("\n", "\n  "))
    print()

if not (persona.get("behavior") or p or pinned or hits):
    print("(cloud brain has nothing for this scope yet — push first: /ck push)")
PY
}

# ─── route ───────────────────────────────────────────────────────────────────────
[[ $# -lt 1 ]] && usage
sub="$1"; shift
case "$sub" in
  connect) cmd_connect "$@" ;;
  push)    cmd_push "$@" ;;
  pull)    cmd_pull "$@" ;;
  status)  cmd_status "$@" ;;
  *)       echo "❌ Unknown subcommand: $sub"; usage ;;
esac
