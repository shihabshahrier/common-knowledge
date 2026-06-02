# Git Conventions Reference

Commit message format and git workflow for the `$CK_HOME` knowledge store.
Load this file only when you need to construct a git commit message.

---

## Table of Contents

- [Commit Format](#commit-format)
- [Type Reference](#type-reference)
- [Scope Rules](#scope-rules)
- [Examples by Command](#examples-by-command)
- [Branch Strategy](#branch-strategy)
- [Error Recovery](#error-recovery)

---

## Commit Format

```
<type>(<scope>): <description> [<tag>]
```

- **type** — what kind of change (see Type Reference)
- **scope** — project slug, `global`, or omitted for store-level changes
- **description** — imperative, present tense, ≤60 chars, no period at end
- **tag** — optional section tag in brackets: `[schema]`, `[api]`, `[infra]`, `[progress]`, `[map]`

Subject line max: **72 characters total.**

### Multi-line commit (when saving multiple sections at once)

```
feat(project-slug): save session context [schema, api]

- Updated DB schema with new users table
- Added /v1/auth endpoints to API docs
- Recorded decision: JWT over session cookies
```

---

## Type Reference

| Type | When to use |
|------|------------|
| `feat` | New knowledge added (new project, new schema, new endpoint doc) |
| `docs` | Updating documentation (codebase map, README, decisions) |
| `chore` | Maintenance (sync, progress log, index update, meta.json update) |
| `fix` | Correcting incorrect knowledge (wrong schema, outdated endpoint) |
| `refactor` | Restructuring knowledge files without changing content |

> **Note:** Link commits use `feat` (e.g. `feat: link a <-> b [type]`). Init commit uses `chore` (`chore: initialize common-knowledge store`).

---

## Scope Rules

| Scope | When to use |
|-------|-------------|
| `<project-slug>` | Changes scoped to one project directory |
| `global` | Changes to `_global/` directory |
| *(omitted)* | Store-level changes (init, status/README update, sync) |

### Examples

```
feat(context-heavy): add DB schema [schema]
docs(letx): update codebase map [map]
chore(context-heavy): log progress 2026-06-02 [progress]
feat: link context-heavy <-> letx [integrates_with]
chore: update project index
chore: initialize common-knowledge store
fix(my-app): correct API base URL in endpoints.md [api]
chore: sync knowledge store 2026-06-02T03:15Z
```

---

## Examples by Command

| `/ck` command | Commit message |
|--------------|----------------|
| `init` | `chore: initialize common-knowledge store` |
| `save <project>` | `feat(<project>): save session context [<section>]` |
| `map <project>` | `docs(<project>): update codebase map [map]` |
| `schema <project>` | `docs(<project>): update db schema [schema]` |
| `schema <project>` (API) | `docs(<project>): update api endpoints [api]` |
| `progress <project>` | `chore(<project>): log progress YYYY-MM-DD [progress]` |
| `link <a> <b>` | `feat: link <a> <-> <b> [<rel-type>]` |
| `learn` (global) | `feat(global): capture learning — <title> [learning]` |
| `learn <project>` | `feat(<project>): capture learning — <title> [learning]` |
| `ingest <file>` | `feat(<project>): ingest <filename> [ingest]` |
| `brief <project>` | `docs(<project>): refresh brief [brief]` |
| index upsert | `chore(<project>): index <id> [index]` |
| `status` | `chore: update catalog + project index` |
| `sync` | `chore: sync knowledge store YYYY-MM-DDTHH:MMZ` |

---

## Branch Strategy

The store uses a single `main` branch. No feature branches needed.

- Every `/ck` write commits directly to `main`.
- Use `git log --oneline` to review history.
- Use `git diff HEAD~1` to see what changed in the last save.
- Use `git show <hash>` to see a specific save's content.

---

## Error Recovery

| Error | Recovery |
|-------|---------|
| `nothing to commit` | Not an error — report "Store is clean" and continue. |
| `git: command not found` | Write files, skip all git commands. Warn user once. |
| `fatal: not a git repository` | Run `git -C "$CK_HOME" init && git -C "$CK_HOME" branch -M main` then retry. |
| Merge conflict (manual edit + agent write) | Run `git -C "$CK_HOME" diff` to show conflicts. User resolves manually. |
| Permission denied on `$CK_HOME` | Check `ls -la $(dirname "$CK_HOME")`. Suggest `chmod 755` or different path. |

---

## Input/Output Examples

**Input:** User runs `/ck save context-heavy --section schema`

**Output commit:**
```
feat(context-heavy): save DB schema [schema]

Added tables: nodes, edges, workspaces, users, api_keys
Added indexes: idx_nodes_fts, idx_nodes_workspace_id
Recorded: pgvector extension for semantic search
```

**Input:** User runs `/ck sync` with 3 dirty files

**Output commit:**
```
chore: sync knowledge store 2026-06-02T03:15Z
```

**Git log after a typical session:**
```
a3f12c4 chore: sync knowledge store 2026-06-02T04:00Z
8b2de1f feat: link context-heavy <-> letx [calls_api]
3c9a021 docs(letx): update codebase map [map]
f7d8b30 feat(context-heavy): save DB schema [schema]
1a4e562 chore: initialize common-knowledge store
```
