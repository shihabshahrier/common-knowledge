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
| `/ck status` | List all tracked projects |
| `/ck search <query>` | Full-text search across the store |
| `/ck sync` | Git commit all pending changes |

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
```

## Platform Support

| OS | Default Store Path | Override |
|----|-------------------|---------|
| macOS | `~/common-knowledge` | `export CK_HOME=/custom/path` |
| Linux | `~/common-knowledge` | `export CK_HOME=/custom/path` |
| Windows | `%USERPROFILE%\common-knowledge` | Set `CK_HOME` env var |

## Requirements

- **git** — for version control (optional but strongly recommended)
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
