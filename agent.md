# common-knowledge — Agent Guide

> **Last updated:** 2026-06-02
> **Status:** v1.0.1 — Hardened (scripts bundled, drift removed)
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
├── install.sh                  │   └── integrations.md
└── agent.md  ← THIS FILE       └── {project-slug}/
                                    ├── meta.json
                                    ├── codebase-map.md
                                    ├── progress.md
                                    ├── decisions.md
                                    ├── connections.md
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
│           └── ck-search.sh   ← Bash: cross-store grep (Phase 6)
├── install.sh                 ← Install to all agent paths
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

### v1.1 — Planned
- [ ] `/ck sync --remote` — push to Context-Heavy graph via bulk import API
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
| 2026-06-02 | `connections.md` mirrors Context-Heavy edge model | Future: each connection → a graph edge. Migration becomes trivial. |
| 2026-06-02 | `meta.json` machine-readable per project | Agents parse JSON faster than prose. Status, type, paths available without reading Markdown. |
| 2026-06-02 | Append-only for `progress.md` and `connections.md` | History must never be lost. These files are logs, not documents. |

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
