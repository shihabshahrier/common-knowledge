# common-knowledge skill

Maintain a Git-backed local knowledge store across all your projects and AI agents.

## Invocation

`/ck <command> [project]` or `/common-knowledge <command> [project]`

## Commands

- `init` — Create and initialize the store
- `save <project> [--auto]` — Save current context
- `load <project>` — Load project knowledge
- `map <project>` — Update codebase map
- `schema <project>` — Save schema/API spec
- `progress <project>` — Append progress log
- `link <a> <b>` — Record connection
- `learn "<text>" [project]` — Capture a gotcha/insight/idea
- `learnings [project]` — Recall saved learnings
- `ingest <file> [project]` — Extract a PDF/CSV/DOCX/PPTX/XLSX into the store
- `status` — List all projects
- `search <query>` — Full-text search
- `sync` — Git commit pending changes

## Rules

- Store: `$CK_HOME` (default `~/common-knowledge`)
- Every write = a git commit
- `progress.md` and `connections.md` are append-only
- `meta.json` must be valid JSON

Full spec: `skills/common-knowledge/SKILL.md`
