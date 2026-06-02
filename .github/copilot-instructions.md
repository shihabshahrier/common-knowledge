# common-knowledge skill — GitHub Copilot Instructions

This repo contains the `common-knowledge` AI agent skill.

## What This Skill Does

Maintains a Git-backed local knowledge store at `~/common-knowledge/` (configurable via `$CK_HOME`).
Every project gets a directory with: codebase map, progress log, DB schema, API docs,
infrastructure overview, and cross-project connections. Every write is a git commit.

## Invocation

`/ck <command> [project-slug]`

Commands: `init`, `save`, `load`, `map`, `schema`, `progress`, `link`, `learn`, `learnings`, `ingest`, `brief`, `status`, `search`, `sync`

## Key Rules When Working on This Repo

1. Edit only `skills/common-knowledge/SKILL.md` and `skills/common-knowledge/references/`.
2. Run `bash install.sh` after any changes to propagate to all agent paths.
3. `SKILL.md` must stay under 5000 tokens.
4. All `{PLACEHOLDER}` variables must be substituted in any generated file.
5. `progress.md` and `connections.md` in the store are append-only.
6. `meta.json` must always be valid JSON.

## Architecture

- `skills/common-knowledge/SKILL.md` — source of truth for all skill behavior
- `skills/common-knowledge/references/` — lazy-loaded domain knowledge
- `scripts/` — bash helpers (ck-init.sh, ck-search.sh)
- `install.sh` — installs to all AI agent paths
