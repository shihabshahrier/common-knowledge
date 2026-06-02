#!/usr/bin/env bash
# ck-status.sh — Build the store-level rollup so `status` and cross-project
# discovery cost ONE small read instead of scanning every project's meta.json.
#
# Produces:
#   _global/catalog.json   machine rollup (one entry per project)
#   README.md              human project index table
#   stdout                 a compact table the agent reads directly
#
# Usage:
#   ck-status.sh --home <CK_HOME>                 full rebuild (scan all projects)
#   ck-status.sh --home <CK_HOME> --project <s>   upsert one project (O(1), for save)
#   flags: --no-readme  --no-commit
#
# Token win: agent reads the printed table / catalog.json (~1–4k tok for 100
# projects) instead of reading 100 meta.json files (~25k tok). Nothing lost —
# the catalog lists every project; detail is pulled on demand via /ck load.

set -uo pipefail

CK_HOME="${CK_HOME:-$HOME/common-knowledge}"
ONLY=""; READSME=1; COMMIT=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home)       CK_HOME="$2"; shift 2 ;;
    --project)    ONLY="$2"; shift 2 ;;
    --no-readme)  READSME=0; shift ;;
    --no-commit)  COMMIT=0; shift ;;
    *) echo "❌ Unknown arg: $1" >&2; exit 1 ;;
  esac
done
[[ -d "$CK_HOME" ]] || { echo "❌ Store not found: $CK_HOME (run /ck init)" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 required" >&2; exit 1; }

CK_HOME="$CK_HOME" CK_ONLY="$ONLY" CK_READSME="$READSME" python3 <<'PY'
import json, os, datetime, glob

CK = os.environ["CK_HOME"]
ONLY = os.environ.get("CK_ONLY") or ""
catalog_path = os.path.join(CK, "_global", "catalog.json")

def load_json(p):
    try:
        with open(p) as f: return json.load(f)
    except Exception: return None

def scan_project(slug):
    d = os.path.join(CK, slug)
    meta = load_json(os.path.join(d, "meta.json")) or {}
    idx  = load_json(os.path.join(d, "index.json")) or {"entries": []}
    tags = sorted({t for e in idx.get("entries", []) for t in e.get("tags", [])})
    crit = sum(1 for e in idx.get("entries", []) if e.get("importance") == "critical")
    return {
        "slug": slug,
        "name": meta.get("name", slug),
        "type": meta.get("type", ""),
        "status": meta.get("status", ""),
        "stack": meta.get("tech_stack", []),
        "description": meta.get("description", ""),
        "updated": meta.get("last_updated", ""),
        "tags": tags,
        "entries": len(idx.get("entries", [])),
        "critical": crit,
    }

def all_slugs():
    out = []
    for p in sorted(glob.glob(os.path.join(CK, "*"))):
        b = os.path.basename(p)
        if os.path.isdir(p) and b not in ("_global", ".git"):
            out.append(b)
    return out

cat = load_json(catalog_path) or {"updated": "", "count": 0, "projects": []}

if ONLY:
    # Incremental upsert of a single project (O(1)) — used by save.
    others = [p for p in cat.get("projects", []) if p["slug"] != ONLY]
    if os.path.isdir(os.path.join(CK, ONLY)):
        others.append(scan_project(ONLY))
    projects = others
else:
    projects = [scan_project(s) for s in all_slugs()]

projects.sort(key=lambda p: p["slug"])
now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
cat = {"updated": now, "count": len(projects), "projects": projects}

os.makedirs(os.path.dirname(catalog_path), exist_ok=True)
with open(catalog_path, "w") as f:
    json.dump(cat, f, indent=2)

# README index
if os.environ.get("CK_READSME") == "1":
    today = now[:10]
    rows = "\n".join(
        f"| [{p['name']}](./{p['slug']}/) | {p['type']} | {p['status']} | "
        f"{(p['updated'] or '')[:10]} | {p['description']} |"
        for p in projects) or "| _none_ | | | | |"
    readme = f"""# Common Knowledge Store

> Updated: {today}
> Projects: {len(projects)}

Git-backed local knowledge store managed by the `common-knowledge` skill.
Every directory is a project. Every save is a git commit.

## Projects

| Project | Type | Status | Updated | Description |
|---------|------|--------|---------|-------------|
{rows}

## Global Knowledge
- [Catalog (machine rollup)](./_global/catalog.json)
- [Agent Config](./_global/agent-config.md)
- [Tech Decisions](./_global/tech-decisions.md)
- [Integrations](./_global/integrations.md)
- [Learnings](./_global/learnings.md)
"""
    with open(os.path.join(CK, "README.md"), "w") as f:
        f.write(readme)

# Compact table to stdout (this is what the agent reads — cheap + complete)
print(f"# Knowledge Store — {len(projects)} projects (updated {now[:16]}Z)")
print(f"{'SLUG':22} {'TYPE':10} {'STATUS':11} {'CRIT':4} STACK / DESCRIPTION")
for p in projects:
    stack = ",".join(p["stack"][:3])
    line = f"{p['slug']:22} {p['type'][:10]:10} {p['status'][:11]:11} {p['critical']:<4} {stack} — {p['description']}"
    print(line[:160])
PY

if [[ "$COMMIT" -eq 1 ]] && command -v git >/dev/null 2>&1 && [[ -d "$CK_HOME/.git" ]]; then
  git -C "$CK_HOME" add -A
  git -C "$CK_HOME" diff --cached --quiet || \
    git -C "$CK_HOME" commit -qm "chore: update catalog + project index"
fi
