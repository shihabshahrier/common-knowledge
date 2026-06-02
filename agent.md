# common-knowledge — Agent Guide

> **Last updated:** 2026-06-02
> **Status:** v1.5 — Scale layer (catalog rollup + capped/manifest search)
> **Repo:** https://github.com/shihabshahrier/common-knowledge
> **Author:** shihabshahrier

This file is the **living codebase map** for the `common-knowledge` skill repo.
Read this before modifying any skill files.

---

## 1. What Is This Repo?

`common-knowledge` is a **marketplace-ready AI agent skill** that creates and maintains a
**Git-backed local knowledge store** at `$CK_HOME` (default: `~/common-knowledge/`).

It acts as a **shared brain** across all your projects and AI agent sessions. Any agent that
supports the Agent Skills open standard can read from and write to the store.

### The Problem

AI agents start cold every session — they have no memory of:
- What other codebases exist and how they connect
- DB schemas, API contracts, and infra decisions from past sessions
- Progress made across multiple agent sessions
- Cross-project dependencies and integration points

### The Solution

A structured directory tree at `$CK_HOME` where every save is a git commit. Plain Markdown + JSON
files — any AI agent can read them, any human can read them, and they diff cleanly in git.

---

## 2. Two-Repo Architecture

```
this repo (skill code)          knowledge store (data, separate)
─────────────────────────       ─────────────────────────────────────
~/github/common-knowledge/      ~/common-knowledge/   (CK_HOME default)
├── skills/                     ├── .git/
│   └── common-knowledge/       ├── README.md          ← auto-index
│       ├── SKILL.md            ├── _global/
│       ├── references/         │   ├── agent-config.md
│       └── scripts/            │   ├── tech-decisions.md
├── install.sh                  │   ├── integrations.md
└── agent.md  ← THIS FILE       │   └── learnings.md
                                └── {project-slug}/
                                    ├── meta.json
                                    ├── codebase-map.md
                                    ├── progress.md
                                    ├── decisions.md
                                    ├── connections.md
                                    ├── learnings.md
                                    ├── schema/
                                    ├── api/
                                    ├── frontend/
                                    ├── infra/
                                    └── workers/
```

**Rule:** Never put knowledge store data in this repo. Never put skill code in `$CK_HOME`.

---

## 3. Repo Structure

```
common-knowledge/               ← This skill repo
├── agent.md                   ← THIS FILE — read first
├── skills/
│   └── common-knowledge/
│       ├── SKILL.md           ← SOURCE OF TRUTH for the skill
│       ├── references/
│       │   ├── store-layout.md      ← File tree + meta.json schema
│       │   ├── git-conventions.md   ← Commit message format
│       │   └── section-templates.md ← Markdown templates
│       └── scripts/           ← Bundled — ship with the skill via install.sh
│           ├── ck-init.sh     ← Bash: deterministic store init (Phase 1)
│           ├── ck-search.sh   ← Bash: cross-store grep (Phase 6)
│           ├── ck-learn.sh    ← Bash: append a learning (Phase 3F)
│           ├── ck-recall.sh   ← Bash: SessionStart warm-start injector
│           ├── ck-autosync.sh ← Bash: SessionEnd commit pending
│           ├── ck-ingest.sh   ← Bash: extract PDF/CSV/DOCX/PPTX/XLSX → stdout (Phase 3G)
│           ├── ck-index.sh    ← Bash: upsert index.json manifest entry (jq)
│           └── ck-status.sh   ← Bash: build _global/catalog.json + README + table (scale)
├── install.sh                 ← Install to all agent paths (--hooks wires autonomy)
├── hooks/
│   └── hooks.json             ← Claude Code hook snippet (SessionStart + SessionEnd)
├── agents/
│   └── openai.yaml            ← Codex display config
├── .claude-plugin/
│   └── plugin.json
├── .cursor/
│   └── rules/
│       └── common-knowledge.mdc
├── .windsurf/
│   └── rules/
│       └── common-knowledge.md
├── .clinerules/
│   └── common-knowledge.md
├── .codex/
│   └── config.toml
├── .github/
│   ├── copilot-instructions.md
│   └── FUNDING.yml
├── README.md
├── CLAUDE.md
├── AGENTS.md
├── GEMINI.md
├── CONTRIBUTING.md
├── LICENSE
└── .gitignore
```

---

## 4. Skill Commands

```bash
/ck init                           # Create and initialize the knowledge store
/ck save <project>                 # Save current session context
/ck save <project> --auto          # Auto-detect project from cwd
/ck save <project> --section api   # Save only API-related context
/ck load <project>                 # Load all project knowledge into context
/ck load <project> --section db    # Load only DB schema
/ck map <project>                  # Generate/update codebase map
/ck schema <project>               # Save DB schema or API spec
/ck progress <project>             # Append timestamped progress entry
/ck link <a> <b> [--type <rel>]    # Record cross-project connection
/ck learn "<text>" [project] [--type <t>] [--tags <csv>]  # Capture a gotcha/insight/idea
/ck learnings [project] [--tag <t>]                        # Recall saved learnings
/ck ingest <file> [project]                                # Extract+distill a document into the store
/ck brief <project>                                        # Regenerate the always-loaded warm core (brief.md)
/ck status                         # List all tracked projects
/ck search <query>                 # Full-text search across the store
/ck sync                           # Git commit all pending changes
```

---

## 5. Platform Support

| OS | Default `CK_HOME` | Override |
|----|-------------------|---------|
| macOS | `$HOME/common-knowledge` | `export CK_HOME=/custom/path` |
| Linux | `$HOME/common-knowledge` | `export CK_HOME=/custom/path` |
| Windows (PS) | `$env:USERPROFILE\common-knowledge` | `$env:CK_HOME = "C:\custom"` |
| Windows (CMD) | `%USERPROFILE%\common-knowledge` | `set CK_HOME=C:\custom` |

---

## 6. Implementation Status

### v1.0 — Initial Build ✅ 2026-06-02
- [x] `SKILL.md` — workflow type, Phases 0–8
- [x] `references/store-layout.md` — full file tree + meta.json schema
- [x] `references/git-conventions.md` — commit format + error recovery
- [x] `references/section-templates.md` — Markdown templates for all sections
- [x] `scripts/ck-init.sh` — bash init helper
- [x] `scripts/ck-search.sh` — bash search helper
- [x] `install.sh` — installs to 6 agent paths

### v1.0.1 — Hardening ✅ 2026-06-02
- [x] Moved `scripts/` into `skills/common-knowledge/scripts/` so they ship with `install.sh` (were orphaned at repo root, never installed).
- [x] `SKILL.md` Phase 1 / Phase 6 now call the bundled scripts; inline bash kept as fallback and aligned to match (no drift).
- [x] Hardened inline search: `-F` fixed-string, `--exclude-dir=.git`, `.yml`, 50-cap.
- [x] `last_updated` now bumped on every Phase 3 write (was save-only).
- [x] Fixed Phase 4 load coupling (`schema` section no longer pulls `api/endpoints.md`).
- [x] `agents/openai.yaml` — Codex config
- [x] `.claude-plugin/plugin.json`
- [x] `.cursor/rules/common-knowledge.mdc`
- [x] `.windsurf/rules/common-knowledge.md`
- [x] `.clinerules/common-knowledge.md`
- [x] `.codex/config.toml`
- [x] `.github/copilot-instructions.md`
- [x] `README.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTRIBUTING.md`, `LICENSE`

### v1.1 — Learnings ✅ 2026-06-02
- [x] `/ck learn "<text>" [project] [--type <t>] [--tags <csv>]` — capture a gotcha/pattern/pitfall/insight/idea.
- [x] `/ck learnings [project] [--tag <t>]` — recall lessons into context (Phase 4L).
- [x] `scripts/ck-learn.sh` — deterministic append + commit helper; global default, project-scopable.
- [x] `_global/learnings.md` (reusable) + `<project>/learnings.md` (project-specific), append-only.
- [x] `learnings.md` added to `load` read order; searchable via existing grep.
- [x] Templates + store-layout + git-conventions updated for learnings.

### v1.2 — Autonomy hooks ✅ 2026-06-02
- [x] `scripts/ck-recall.sh` — SessionStart hook: detect project from cwd, inject lessons + meta + recent progress (warm start). Read-only, silent on no-match.
- [x] `scripts/ck-autosync.sh` — SessionEnd hook: commit pending store changes. Silent when clean; no empty commits.
- [x] `hooks/hooks.json` — paste-ready Claude Code hook config.
- [x] `install.sh --hooks` — jq-merges hooks into `~/.claude/settings.json`, backs up first, idempotent (no dup on re-run). Scaffold-only by default — global settings untouched unless `--hooks` passed.
- [x] SKILL.md "Autonomy" section documents the passive recall+sync model and that capture stays agent-driven.

### v1.3 — Document ingestion ✅ 2026-06-02
- [x] `scripts/ck-ingest.sh <file>` — extract text/markdown to stdout for the agent to distill. Supports PDF (pdftotext), CSV (→md table), DOCX/RTF/ODT/HTML (textutil/pandoc), PPTX + XLSX + DOCX-fallback via dependency-free zip+XML (python3 stdlib — no openpyxl/python-pptx). Source pointer (path+sha256+bytes) printed.
- [x] `/ck ingest <file> [project]` — Phase 3G: extract → distill into codebase-map/decisions/learnings → record `meta.json.sources[]`. Raw file never committed.
- [x] `meta.json` gains optional `sources` array; store-layout + git-conventions updated.
- [x] Propagated to all rule files + README/agent.md.

### v1.4 — Retrieval layer ✅ 2026-06-02
- [x] `brief.md` per project — curated warm core, always loaded first by `load` and the recall hook. `/ck brief` regenerates (Phase 3H).
- [x] `index.json` per project — manifest (id/file/summary/tags/importance/updated). `scripts/ck-index.sh` upserts via jq (dedup by id, valid JSON).
- [x] **Importance tiers** — `load` reads brief → meta → index → all `critical` entries first → `normal` as budget allows. Vital info never dropped at context limit.
- [x] Wired into save (refresh brief + upsert index), learn (gotcha/pitfall→critical), ingest (index entry). `ck-recall.sh` loads `brief.md` first.
- [x] Two-stage retrieval: cheap-complete-manifest first, pull detail on demand.

### v1.5 — Scale layer ✅ 2026-06-02
- [x] `_global/catalog.json` — store rollup (1 entry/project: status, stack, tags, critical-count). The store-level twin of per-project `index.json`.
- [x] `scripts/ck-status.sh` — rebuilds catalog + README + prints compact table; `--project` does O(1) incremental upsert. Status now costs ~2k tokens at 100 projects vs ~8k reading every meta.json (measured 3.3×).
- [x] `ck-search.sh` reworked — **per-project cap** (default 5) so a common term never silently drops a project (overflow flagged); **`--manifest`** mode greps only catalog+index+brief for ~1k-token cross-repo discovery.
- [x] Wired: Phase 5 status → ck-status; Phase 6 search → capped + manifest two-stage; save → incremental catalog upsert.
- [x] Benchmarked at 100 projects: search 88ms, status 59ms, recall 53ms, 5MB store.

### v1.6 — Planned
- [ ] `/ck sync --remote` — push to Context-Heavy graph via bulk import API
- [ ] optional local semantic search (`ck-embed`) if grep proves insufficient
- [ ] `/ck export <project>` — export to JSON compatible with Context-Heavy bulk import
- [ ] `/ck diff <project>` — show git diff for a project's files
- [ ] `/ck archive <project>` — set status to archived + commit
- [ ] Shell completion script (`ck-completion.bash`, `ck-completion.zsh`)
- [ ] PowerShell init script for Windows (`ck-init.ps1`)

---

## 7. Key Design Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-06-02 | Store at `$HOME/common-knowledge` | Platform-standard. `CK_HOME` env var overrides for custom paths. |
| 2026-06-02 | Git for version control | Already installed on all dev machines. Full history, diffs, rollback. No extra infra. |
| 2026-06-02 | Markdown + JSON (no database) | Human-readable, agent-readable, diffs nicely. Works offline. Zero dependencies. |
| 2026-06-02 | Both `--auto` and explicit project detection | Explicit is default (precision). `--auto` for scripts and automation. |
| 2026-06-02 | Separate skill repo from knowledge store | Skill = code. Store = data. Clean separation. |
| 2026-06-02 | `_global/` for cross-project knowledge | Some knowledge spans projects. Need a dedicated home. |
| 2026-06-02 | Learnings default to `_global`, project-scopable | Lessons (gotchas/patterns/insights) are usually reusable across projects; default global, allow project scope. |
| 2026-06-02 | `ck-learn.sh` persists; agent composes prose | Same split as init/search — deterministic write + commit, LLM writes the content. Hook-friendly for auto-capture. |
| 2026-06-02 | Autonomy = recall + sync only; capture stays agent-driven | Hooks are deterministic shell — can't compose a learning. So auto-recall (read) + auto-sync (commit) are hooks; capture remains an LLM action via `/ck learn`. |
| 2026-06-02 | Hooks scaffold-only; `--hooks` to install | Editing global `~/.claude/settings.json` is the user's call. Default install never touches it; `--hooks` opts in with a backup. |
| 2026-06-02 | Ingest = extract→distill→pointer; no blobs | Raw PDFs/Office files bloat git and diff badly. Script extracts text; agent distills to markdown; only a path+sha256 pointer is stored. |
| 2026-06-02 | Office extraction via zip+XML, not openpyxl/python-pptx | Keep zero pip deps. pptx/xlsx/docx are zipped XML — python3 stdlib reads them. textutil/pandoc/pdftotext used when present. |
| 2026-06-02 | brief.md + index.json + importance tiers for retrieval | Read-till-limit loading dropped vital info. Two-stage: always-loaded curated brief + machine manifest for triage; load `critical` first so nothing vital is missed. Keeps git+markdown, no DB/vectors. |
| 2026-06-02 | catalog.json + capped/manifest search for scale | At 100 repos, status reading every meta.json = ~8k tokens, and a global search cap silently dropped projects. Catalog = store-level rollup (cheap status + discovery); per-project search cap = no project lost. Same two-stage pattern, lifted to store level. |
| 2026-06-02 | `connections.md` mirrors Context-Heavy edge model | Future: each connection → a graph edge. Migration becomes trivial. |
| 2026-06-02 | `meta.json` machine-readable per project | Agents parse JSON faster than prose. Status, type, paths available without reading Markdown. |
| 2026-06-02 | Append-only for `progress.md`, `connections.md`, `learnings.md` | History must never be lost. These files are logs, not documents. |

---

## 8. How to Contribute / Modify

1. Edit `skills/common-knowledge/SKILL.md` (and references) — this is the source of truth.
2. Run `bash install.sh` to propagate changes to all agent paths.
3. **Do NOT edit** agent-specific files (`.cursor/rules/`, `.windsurf/rules/`, etc.) directly —
   they're generated from the skill. Reflect changes there manually if needed.
4. Commit with: `feat(skill): <what changed>` or `docs(skill): <what changed>`.
5. Test the skill in at least one agent (Antigravity or Claude Code) before committing.

---

## 9. Install

```bash
# Clone the skill repo (if not already)
git clone https://github.com/shihabshahrier/common-knowledge
cd common-knowledge

# Install to all agent paths
bash install.sh

# Initialize the knowledge store (first time)
# Then in your AI agent:
# /ck init
```

---

## 10. Connection to Context-Heavy

This skill is the **local, offline-first complement** to [Context-Heavy](../Context-Heavy/),
which provides a hosted knowledge graph with semantic search, graph traversal, and MCP tools.

| Feature | common-knowledge (this skill) | Context-Heavy |
|---------|-------------------------------|---------------|
| Storage | Local filesystem + git | Cloud PostgreSQL |
| Format | Markdown + JSON | Typed graph (nodes + edges) |
| Access | Any AI agent, any tool | REST API + MCP (14 tools) |
| Online required | No | Yes |
| Search | grep / full-text | Full-text + semantic (pgvector) |
| Graph traversal | Manual (connections.md) | Recursive CTE + shortest path |
| Multi-user | No | Yes (workspaces) |

**Migration path:** `/ck sync --remote` (v1.1) will push `connections.md` entries as edges
and project directories as nodes into a Context-Heavy workspace via the bulk import API.
