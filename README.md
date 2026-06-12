# common-knowledge: Git-Backed AI Agent Memory

> A local, version-controlled knowledge base and persistent memory storage for AI agents, developers, and codebases.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-Open%20Standard-blue)](https://github.com/agent-skills)

## What It Does

`common-knowledge` is an open-source AI agent skill that creates and maintains a **structured, Git-versioned local knowledge base** at `~/common-knowledge/`. It solves the "amnesia" problem for autonomous agents by providing **persistent long-term memory** across sessions. 

Instead of relying on complex vector databases (Vectorless RAG), every AI agent session, architecture decision, API contract, and codebase map gets saved as plain Markdown and JSON in one centralized, offline-first location. It is readable by any agent (Claude Code, opencode, Cursor), any tool, and any human.

```
~/common-knowledge/
├── context-heavy/          ← per-project directory
│   ├── meta.json           ← machine-readable metadata
│   ├── codebase-map.md     ← architecture + entry points
│   ├── progress.md         ← session log (append-only)
│   ├── schema/db.md        ← database schema
│   ├── api/endpoints.md    ← API documentation
│   ├── connections.md      ← cross-project links
│   └── learnings.md        ← project-specific lessons (append-only)
├── letx/
│   └── ...
└── _global/
    ├── integrations.md     ← how all projects connect
    ├── tech-decisions.md   ← cross-project decisions
    └── learnings.md        ← reusable gotchas, patterns, insights
```

Every write is a **git commit** with a descriptive message. Full history, diffs, rollback.

## Install

```bash
git clone https://github.com/shihabshahrier/common-knowledge
cd common-knowledge
bash install.sh
```

Installs to all major AI agent paths automatically:
- `~/.claude/skills/` (Claude Code)
- `~/.agents/skills/` (Codex, Amp, Goose, Kiro)
- `~/.config/opencode/skills/` (opencode)
- `~/.gemini/antigravity/skills/` (Gemini CLI)
- `~/.gemini/config/skills/` (Antigravity IDE)
- `~/.openclaw/workspace/skills/` (OpenClaw)

## Usage

| Command | Description |
|---------|-------------|
| `/ck init` | Create and initialize the knowledge store |
| `/ck save <project>` | Save current session context |
| `/ck save <project> --auto` | Auto-detect project from cwd |
| `/ck load <project>` | Load all knowledge into context |
| `/ck map <project>` | Generate/update codebase map |
| `/ck schema <project>` | Save DB schema or API spec |
| `/ck progress <project>` | Append to progress log |
| `/ck link <a> <b>` | Record cross-project connection |
| `/ck learn "<text>" [project]` | Capture a gotcha/pattern/pitfall/insight/idea |
| `/ck learnings [project]` | Recall saved learnings into context |
| `/ck ingest <file> [project]` | Extract a PDF/CSV/DOCX/PPTX/XLSX and distill it into the store |
| `/ck brief <project>` | Regenerate the always-loaded warm core (`brief.md`) |
| `/ck status` | List all tracked projects |
| `/ck search <query>` | Full-text search across the store |
| `/ck sync` | Git commit all pending changes |
| `/ck cloud connect --url <u> --key <k>` | Configure the optional Context-Heavy cloud bridge |
| `/ck push [project\|--all] [--changed] [--dry-run]` | Push knowledge to the cloud brain (idempotent) |
| `/ck pull [project]` | Pull cloud context (persona + lessons) into the session — read-only |
| `/ck cloud status` | Show bridge config + last-push markers |

## Ingest documents

`/ck ingest <file>` pulls knowledge out of documents — **PDF, CSV, DOCX, PPTX, XLSX**, and any text format — and distills it into the store. Extraction is dependency-light: `pdftotext`/`textutil`/`pandoc` when present, otherwise a built-in zip+XML reader (no `openpyxl`/`python-pptx` needed) for Office files; CSV becomes a Markdown table.

The raw file is **never** committed — the agent summarizes the extracted text into `codebase-map.md` / `decisions.md` / `learnings.md` and records a source pointer (path + sha256) in `meta.json`.

## Scales to 100s of projects

Retrieval stays token-cheap as the store grows:
- **`/ck status`** reads one rollup (`_global/catalog.json`) + prints a compact table — ~2k tokens at 100 projects, not ~8k from opening every `meta.json`.
- **`/ck search`** caps results **per project** (never silently drops a project) and offers **`--manifest`** mode for ~1k-token cross-repo discovery, then `/ck load` only the relevant ones.
- **`/ck load`** is always single-project, two-stage (brief → manifest → critical-first), so per-load cost is flat regardless of store size.

Benchmarked at 100 projects (5 MB store): search 88 ms, status 59 ms, recall 53 ms.

## Autonomy (optional)

By default the store is trigger-driven — you (or the agent) invoke `/ck`. Opt into passive autonomy with deterministic Claude Code hooks:

```bash
bash install.sh --hooks   # backs up ~/.claude/settings.json first, idempotent
```

- **SessionStart → warm start:** auto-detects the project from your cwd and injects its saved lessons, recent progress, and metadata into context — the agent begins each session already knowing past gotchas and decisions.
- **SessionEnd → auto-sync:** commits any uncommitted store changes so nothing is lost.

Capture stays agent-driven (hooks can't compose a lesson) — the agent runs `/ck learn` / `/ck save` when something is worth remembering.

## Cloud bridge (optional) — Context-Heavy

The store is local-first and stays that way: everything above works offline with zero accounts. Optionally, it can also sync with **Context-Heavy** — a cloud brain (currently in development) that makes pushed knowledge hybrid-searchable (full-text + vector), graph-linked, temporally versioned, and shared across agents and machines.

```bash
# point the bridge at any Context-Heavy deployment — including localhost
/ck cloud connect --url http://localhost:8080 --key cg_live_... --agent claude-code

/ck push my-project --dry-run    # see what would be sent
/ck push my-project              # sections + learnings + connections → cloud graph
/ck pull my-project              # persona + pinned nodes + lessons → into context
```

- **Identity = API key.** A `cg_live_…` key belongs to one Context-Heavy workspace; everything you push and pull is scoped to that workspace. The key lives in `$CK_HOME/.cloud` (gitignored, `chmod 600`) — never in the repo.
- **Push is idempotent** — re-pushing an unchanged project is a no-op on the server.
- **Pull is read-only** — it prints context for the agent; it never writes store files.
- **Autonomy, opt-in:** `connect --auto-pull --auto-push` makes the SessionStart hook catch the agent up from the cloud (even on a fresh machine with an empty store) and the SessionEnd hook push changed projects — so any agent can catch up with you, and you with them. Both legs are best-effort: no network, no noise.

Without a `.cloud` config the bridge is completely inert — nothing changes for local-only users.

## How It Works

```
Phase 0 → Parse command & resolve $CK_HOME
Phase 1 → Init store (git init + directory structure)
Phase 2 → Auto-detect project from cwd (--auto flag)
Phase 3 → Save / Map / Schema / Progress / Link
Phase 4 → Load project knowledge into context
Phase 5 → Status (list projects, regenerate index)
Phase 6 → Search (grep across all files)
Phase 7 → Sync (git commit pending changes)
Phase 8 → Report (always: files changed + commit hash)
Phase 9 → Cloud bridge (connect / push / pull — optional)
```

## Platform Support

| OS | Default Store Path | Override |
|----|-------------------|---------|
| macOS | `~/common-knowledge` | `export CK_HOME=/custom/path` |
| Linux | `~/common-knowledge` | `export CK_HOME=/custom/path` |
| Windows | `%USERPROFILE%\common-knowledge` | Set `CK_HOME` env var |

## Requirements

- **git** — for version control (optional but strongly recommended)
- **curl + python3** — only for the optional cloud bridge (`/ck push`/`pull`)
- Any AI agent supporting the [Agent Skills open standard](https://github.com/agent-skills)

## Agent Support

| Agent | Supported | Path |
|-------|-----------|------|
| Claude Code | ✅ | `~/.claude/skills/` |
| Antigravity IDE | ✅ | `~/.gemini/config/skills/` |
| opencode | ✅ | `~/.config/opencode/skills/` |
| Codex | ✅ | `~/.agents/skills/` |
| Cursor | ✅ | `.cursor/rules/` (project) |
| Windsurf | ✅ | `.windsurf/rules/` |
| Cline | ✅ | `.clinerules/` |
| GitHub Copilot | ✅ | `.github/copilot-instructions.md` |
| Amp, Goose, Kiro | ✅ | `~/.agents/skills/` |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

---

*Part of the [Context-Heavy](https://github.com/shihabshahrier/Context-Heavy) ecosystem.
The local-first, offline complement to the hosted knowledge graph.*

---

📖 **Project page:** https://shihub.online/projects/common-knowledge
