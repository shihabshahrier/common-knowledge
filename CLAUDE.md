# common-knowledge — Claude Code Rules

## What This Repo Is

This is the skill repo for `common-knowledge` — a Git-backed local knowledge store skill
for AI agents. It installs to all major agent paths via `bash install.sh`.

## Source of Truth

- **Edit only:** `skills/common-knowledge/SKILL.md` and `skills/common-knowledge/references/`
- **Generated (do not edit directly):** `.cursor/rules/`, `.windsurf/rules/`, `.clinerules/`, agents/
- After editing the skill, run `bash install.sh` to propagate to all agent paths.

## Key Constraints

- `SKILL.md` must stay under 5000 tokens.
- `name` field must match `^[a-z0-9]+(-[a-z0-9]+)*$` — currently: `common-knowledge`.
- `description` must be ≤1024 chars.
- All `{PLACEHOLDER}` variables must be substituted before writing any generated file.
- `progress.md` and `connections.md` in the knowledge store are **append-only** — never overwrite.
- `meta.json` must always be valid JSON.

## Architecture

The skill repo (here) is separate from the knowledge store (`~/common-knowledge/`).
- **This repo** = skill code (SKILL.md, scripts, install.sh)
- **`$CK_HOME`** = knowledge store data (project directories, git-tracked Markdown files)

## How to Make Changes

1. Edit `skills/common-knowledge/SKILL.md`
2. Edit references in `skills/common-knowledge/references/`
3. Run `bash install.sh`
4. Test with `/ck <command>` in any agent
5. Commit: `feat(skill): <description>` or `docs(skill): <description>`

## Testing

```bash
# After install, test init
# /ck init                        → creates ~/common-knowledge/
# /ck save test-project --auto    → auto-detect + save
# /ck status                      → list projects
# /ck search postgresql           → search across store
```
