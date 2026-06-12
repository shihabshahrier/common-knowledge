---
name: common-knowledge
description: >
  Maintain a Git-backed local knowledge store across all your projects and AI agents.
  Invoke /ck <command> [project] or /common-knowledge to save, load, and search knowledge.
  Writes Markdown + JSON files; every save is a git commit with a descriptive message.
  Cross-platform (macOS, Linux, Windows). Works offline. Readable by any AI agent.
license: MIT
user-invocable: true
argument-hint: 'init | save <project> [--section <area>] [--auto] | load <project> | map <project> | schema <project> | progress <project> | link <a> <b> [--type <rel>] | learn <text> [project] [--type <t>] [--tags <csv>] | learnings [project] [--tag <t>] | ingest <file> [project] | brief <project> | status | search <query> | sync | cloud connect --url <u> --key <k> | push [project|--all] [--changed] [--dry-run] | pull [project] | cloud status'
when_to_use: >
  Use when user says: /ck, /common-knowledge, save to common knowledge, load project
  context, update knowledge store, what do I know about X, ck init, ck save, ck load,
  ck status, ck search, ck map, ck schema, ck progress, ck sync, ck link, ck learn,
  ck learnings, add this to my knowledge base, store this for later, remember this
  project, remember this lesson, save this learning, log a gotcha, note this pitfall,
  capture this insight, what have I learned about X, recall lessons, ck ingest,
  ingest this pdf, import this document, extract this csv/docx/pptx/xlsx, read
  this file into knowledge, summarize this document into the store, ck push,
  ck pull, ck cloud, push to cloud brain, pull from cloud brain, sync with
  context heavy, connect to context heavy, catch up from the cloud.
metadata:
  author: shihabshahrier
  category: knowledge-management
---

Maintain a Git-backed local knowledge store shared by every AI agent, codebase, and session.

## Commands

| Command | Description |
|---------|-------------|
| `init` | Create and initialize the knowledge store |
| `save <project> [--section <area>] [--auto]` | Save current session context to a project |
| `load <project> [--section <area>]` | Load all knowledge for a project into context |
| `map <project>` | Generate/update the codebase map |
| `schema <project>` | Save DB schema or API spec |
| `progress <project>` | Append a timestamped entry to the progress log |
| `link <project-a> <project-b> [--type <rel>]` | Record a cross-project connection |
| `learn <text> [project] [--type <t>] [--tags <csv>]` | Capture a gotcha/pattern/pitfall/insight/idea (global by default, or scoped to a project) |
| `learnings [project] [--tag <t>]` | Recall saved learnings into context |
| `ingest <file> [project]` | Extract a document (PDF/CSV/DOCX/PPTX/XLSX/…) and distill it into the store |
| `brief <project>` | Regenerate the curated, always-loaded warm core (`brief.md`) |
| `status` | List all tracked projects with status |
| `search <query>` | Full-text search across the entire store |
| `sync` | Git commit all pending uncommitted changes |
| `cloud connect --url <u> --key <k> [--agent <name>] [--auto-pull] [--auto-push]` | Configure the Context-Heavy cloud bridge |
| `push [<project>] [--all] [--changed] [--dry-run]` | Push project knowledge to the cloud brain (idempotent) |
| `pull [<project>] [--agent <name>]` | Pull cloud context (persona + pinned + lessons) into the session — read-only |
| `cloud status` | Show bridge config + last-push markers |

---

## Phase 0 — Parse & Route

1. Parse sub-command from the first argument (e.g. `save`, `load`, `init`).
2. Resolve `CK_HOME` in this priority order:
   - `$CK_HOME` environment variable (if set, use as-is)
   - macOS / Linux: `$HOME/common-knowledge`
   - Windows (PowerShell): `$env:USERPROFILE\common-knowledge`
   - Windows (CMD): `%USERPROFILE%\common-knowledge`
3. If `CK_HOME` directory does not exist AND command is not `init` → run Phase 1 first, then continue.
4. Route:
   - `init` → Phase 1
   - `save`, `map`, `schema`, `progress` (without project slug, or with `--auto`) → Phase 2, then Phase 3
   - `save`, `map`, `schema`, `progress` (with explicit project slug) → Phase 3
   - `link` → Phase 3E (both project slugs required; if missing, prompt)
   - `learn` → Phase 3F
   - `ingest` → Phase 3G
   - `brief` → Phase 3H
   - `learnings` → Phase 4L
   - `load` → Phase 4
   - `status` → Phase 5
   - `search` → Phase 6
   - `sync` → Phase 7
   - `cloud`, `push`, `pull` → Phase 9

---

## Phase 1 — Init

**Preferred:** run the bundled deterministic helper from the skill directory — it does every step below, is idempotent, and survives missing-git:

```bash
bash scripts/ck-init.sh "$CK_HOME"
```

If the script is not reachable, do the steps inline (this MUST match `scripts/ck-init.sh`):

Load `references/store-layout.md` for the full directory tree.

1. Create the `$CK_HOME/` directory and `$CK_HOME/_global/`.
2. Initialize git:
   ```bash
   git -C "$CK_HOME" init -q
   git -C "$CK_HOME" checkout -qb main 2>/dev/null || git -C "$CK_HOME" branch -M main
   ```
3. Create `$CK_HOME/.gitignore`:
   ```
   .DS_Store
   Thumbs.db
   *.tmp
   *.swp
   *.bak
   .env
   .env.local
   ```
4. Create `$CK_HOME/.gitattributes` (`* text=auto eol=lf` + `*.md *.json *.sql *.yaml` → `eol=lf`) for cross-platform line endings.
5. Create `$CK_HOME/README.md` with header + "No projects yet." (regenerated by `status`).
6. Create `$CK_HOME/_global/agent-config.md`, `tech-decisions.md`, `integrations.md` using the templates in `references/section-templates.md`. Only create if missing — never overwrite user edits.
7. Initial commit:
   ```bash
   git -C "$CK_HOME" add -A
   git -C "$CK_HOME" commit -qm "chore: initialize common-knowledge store"
   ```
8. Go to Phase 8 — Report.

---

## Phase 2 — Auto-Detect Project (--auto flag or project slug omitted)

When `--auto` is present OR user did not provide a project slug:

1. Try to get project name from git remote:
   ```bash
   git remote get-url origin 2>/dev/null | sed 's|.*/||' | sed 's/\.git$//'
   ```
2. Fallback: use the basename of the git root:
   ```bash
   basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
   ```
3. Sanitize the slug: lowercase, replace spaces/underscores/dots/slashes with hyphens, strip all other special characters.
   - Example: `Context-Heavy` → `context-heavy`, `my_app v2` → `my-app-v2`
4. If slug already exists in `$CK_HOME/`: inform user, ask to confirm or override.
5. Present detected slug. Proceed if user confirms. If user provides a different slug, use that.

---

## Phase 3 — Save / Map / Schema / Progress / Link / Learn / Ingest

Load `references/section-templates.md` before writing any files.

**Every write in this phase** (`save`, `map`, `schema`, `progress`, `link`) MUST set `meta.json.last_updated` to the current ISO 8601 UTC datetime before committing.

### Ensure meta.json exists

Load `references/store-layout.md` for the meta.json schema.

If `$CK_HOME/<project>/meta.json` does not exist, create it:
- Fill `name`, `slug`, `last_updated` from known info.
- Ask user for `type`, `origin_repo`, `local_path` if not evident from context.
- Set `status: "active"` and `tech_stack: []` as defaults.

### 3A — save (general context capture)

Collect from the current conversation:
- What was built, changed, or decided in this session
- Any schema, API, infra, or architectural info mentioned
- Blockers or next steps

Write to the appropriate files under `$CK_HOME/<project>/`:
- General decisions → `decisions.md`
- Build progress → `progress.md` (append with timestamp)
- Architecture info → `codebase-map.md`
- Use `--section` to target: `schema` (or `db`), `api`, `frontend`, `infra`, `workers`

Update `meta.json` field `last_updated` to current UTC time.

**Then maintain the retrieval layer on every save:**
- **`brief.md`** — refresh the warm core (Phase 3H); ≤1 screen, read first by `load`.
- **`index.json`** — upsert a manifest entry per notable thing written so `load` triages without reading bodies. Mark invariants/blockers/must-know gotchas `critical`, else `normal`:
  ```bash
  bash scripts/ck-index.sh --home "$CK_HOME" --project <slug> \
    --id <stable-id> --file <relpath> --summary "<one line>" \
    --tags "<csv>" --importance critical|normal --no-commit
  ```
- **catalog** — refresh this project's rollup entry (O(1)) so `status`/discovery stay current: `bash scripts/ck-status.sh --home "$CK_HOME" --project <slug> --no-commit`.

Commit (one commit for the batch):
```bash
git -C "$CK_HOME" add -A
git -C "$CK_HOME" commit -m "feat(<project>): save session context [<section>]"
```

### 3B — map

Generate `$CK_HOME/<project>/codebase-map.md`:
- If `local_path` in `meta.json`: note the actual directory structure (describe from context or cwd listing).
- Include: entry points, key files, architectural layers, tech stack, module boundaries.
- Commit: `"docs(<project>): update codebase map [map]"`

### 3C — schema

Determine subsection from content:
- Database schema → write `$CK_HOME/<project>/schema/db.md` + `schema/db.sql` (if SQL available)
- API spec → write `$CK_HOME/<project>/api/endpoints.md` + `api/openapi.yaml` (if spec available)
- Commit: `"docs(<project>): update db schema [schema]"` or `"docs(<project>): update api endpoints [api]"`

### 3D — progress

Append a new timestamped entry to `$CK_HOME/<project>/progress.md`.
- Use the session-completed items as the content.
- Commit: `"chore(<project>): log progress $(date -u +%Y-%m-%d) [progress]"`

### 3E — link

1. Ensure both project directories exist in `$CK_HOME/`.
2. Append to `$CK_HOME/<project-a>/connections.md`:
   ```markdown
   ## <project-b> [<type>]
   - **Direction:** <project-a> → <project-b>
   - **Type:** <rel> (e.g. depends_on, integrates_with, shares_db, calls_api)
   - **Notes:** <what the connection is>
   - **Recorded:** <date>
   ```
3. Mirror entry in `$CK_HOME/<project-b>/connections.md`.
4. Append summary to `$CK_HOME/_global/integrations.md`.
5. Update `meta.json.related_projects` for both projects: add the other project's slug if not already present.
6. Commit: `"feat: link <project-a> <-> <project-b> [<type>]"`

### 3F — learn (capture a reusable lesson)

A learning is a gotcha you got stuck on and resolved, a creative idea, a pattern, a pitfall to avoid, or an insight for future decision-making — knowledge that outlives a single session.

1. Compose the entry from the conversation:
   - **title** — one short line.
   - **type** — one of `gotcha | pattern | pitfall | insight | idea` (default `insight`).
   - **tags** — comma-separated keywords for later filtering (e.g. `postgres,pooling`).
   - **body** — structured prose: `**Context:**` (where stuck / the situation), `**Resolution/Insight:**` (what solved it / the idea), `**Why it matters:**` (future application).
2. Scope: **global by default** (`_global/learnings.md`) since most lessons are reusable. If the user names a project, or the lesson is clearly project-specific, scope it to `<project>/learnings.md`.
3. **Preferred:** persist deterministically with the bundled helper (it creates the header if new, appends, and commits):
   ```bash
   bash scripts/ck-learn.sh --home "$CK_HOME" [--project <slug>] \
     --type <type> --tags "<csv>" --title "<title>" --body "<body>"
   ```
   If the script is not reachable, append the entry inline to the target `learnings.md` (append-only — never overwrite) using the learnings template in `references/section-templates.md`, then commit.
4. Commit: `"feat(<project|global>): capture learning — <title> [learning]"`
5. For a **project-scoped** learning, add an index entry so it surfaces in `load` — `gotcha`/`pitfall` → `critical`, others → `normal`:
   ```bash
   bash scripts/ck-index.sh --home "$CK_HOME" --project <slug> \
     --id learn-<slugified-title> --file "learnings.md" \
     --summary "<title>" --tags "<csv>" --importance <critical|normal>
   ```

### 3G — ingest (pull knowledge from a document)

Distill a PDF/CSV/DOCX/PPTX/XLSX (or any text file) into the store. **Store the distilled knowledge, not the raw file** — keep blobs out of git.

1. Extract the document's text with the bundled helper:
   ```bash
   bash scripts/ck-ingest.sh "<file>"
   ```
   It prints the extracted text (capped by `CK_INGEST_MAX_LINES`, default 2000) plus a **source pointer** (path, sha256, bytes). For PDFs, if `pdftotext` is absent the script says so — read the PDF directly with your own file-reading tool instead.
2. **Distill** the extracted text — summarize into the project's existing files as fits the content:
   - facts/architecture → `codebase-map.md`; decisions → `decisions.md`; lessons → `learnings.md` (via 3F); status/log → `progress.md`.
   - Do not paste the raw extraction verbatim; capture what matters.
3. **Record the source** in `meta.json` under a `sources` array (create it if absent) — append `{ "path", "sha256", "ingested_at", "note" }`. This is a pointer only; never commit the original file into `$CK_HOME`.
4. Set `meta.json.last_updated`, then commit: `"feat(<project>): ingest <filename> [ingest]"`
5. Add an `index.json` entry for the distilled knowledge (`bash scripts/ck-index.sh … --id ingest-<name> --file <where-distilled> --summary "…"`), and refresh `brief.md` if the document changed the big picture.

### 3H — brief (regenerate the warm core)

`brief.md` is the single always-loaded digest. Regenerate it on save, or on demand via `/ck brief <project>`. Keep it ≤1 screen. Use the `brief.md` template in `references/section-templates.md`: what-it-is, stack, status, **Must-know (critical)**, top decisions, active/blockers, where-to-look pointers. Commit: `"docs(<project>): refresh brief [brief]"`.

---

## Phase 4 — Load

**Two-stage, no-miss retrieval — vital first, detail on demand:**

1. **Load `brief.md` first** (curated warm core: what it is, stack, status, must-know gotchas/invariants, blockers). Alone it gives the vital picture.
2. Read `meta.json` → name, type, status, local_path, origin_repo, tech_stack, sources.
3. Read `index.json` (manifest of id/summary/tags/importance) to triage **without** reading every body.
4. Load entry files by importance until context nears limit: **all `critical` first** (never drop these), then `normal`, then section files on request (`schema/db.md` for `--section schema|db`, `api/endpoints.md` for `--section api`, plus `frontend`/`infra`/`workers`).
5. Fallback (older project, no brief/index): read `README.md`, `codebase-map.md`, `progress.md` (last 60 lines), `decisions.md`, `connections.md`, `learnings.md`.
6. Output a structured summary; print local_path and repo.

---

## Phase 4L — Learnings (recall)

Surface saved lessons so they inform the current decision.

1. Determine scope:
   - `learnings` (no project) → read `$CK_HOME/_global/learnings.md`.
   - `learnings <project>` → read `$CK_HOME/<project>/learnings.md` **and** `_global/learnings.md`.
2. If `--tag <t>` is given, filter to entries whose `**Tags:**` line contains `<t>` (use search):
   ```bash
   bash scripts/ck-search.sh "<t>" "$CK_HOME"
   ```
3. Output: each learning as `date — title [type]` with its Context / Resolution / Why-it-matters. Newest first when summarizing.
4. Read-only — no commit.

---

## Phase 5 — Status

Run the rollup helper — it builds `_global/catalog.json` (machine rollup), regenerates the README index, prints a compact table, and commits:

```bash
bash scripts/ck-status.sh --home "$CK_HOME"
```

**Read its printed table** (one cheap read) — do **not** open every project's `meta.json`; at 100 projects that costs ~8k tokens vs ~2k for the table. Use `--project <slug>` for an O(1) incremental catalog update after a single save.

---

## Phase 6 — Search

Load `references/git-conventions.md` only if constructing a commit after search produces results that should be saved.

**Preferred:** run the bundled helper — it groups by project, caps **per project** (so no project is silently dropped at scale), and flags overflow:

```bash
bash scripts/ck-search.sh "$QUERY" --home "$CK_HOME" [--per-project N]
```

At many projects, search the cheap discovery layer first: `--manifest` greps only `catalog.json` + each `index.json`/`brief.md` to find *which* projects are relevant (~1k tokens), then `/ck load` those. This is the store-level twin of Phase 4's two-stage load.

If the script is not reachable, run inline (this MUST match `scripts/ck-search.sh`):

1. Run — `-F` is fixed-string (no regex injection), `.git` excluded, capped at 50:
   ```bash
   grep -rnF --include="*.md" --include="*.json" --include="*.sql" \
     --include="*.yaml" --include="*.yml" --exclude-dir=".git" \
     "$QUERY" "$CK_HOME" 2>/dev/null | head -50
   ```
2. Group results by project directory (parse path prefix). Root files → `(root)`.
3. Output: matched file + line number + the matched line.
4. If no bash available: read each file in `$CK_HOME` and search in-context manually.

---

## Phase 7 — Sync

1. Show pending changes:
   ```bash
   git -C "$CK_HOME" status --short
   ```
2. If no changes: report "Store is clean, nothing to commit." → Phase 8.
3. Stage and commit:
   ```bash
   git -C "$CK_HOME" add -A
   git -C "$CK_HOME" commit -m "chore: sync knowledge store $(date -u +%Y-%m-%dT%H:%MZ)"
   ```

---

## Phase 8 — Report

Always end every command with:

```
## Knowledge Store Update

  Store:    {CK_HOME}
  Command:  {command}
  Project:  {project-slug or "—"}
  Changed:  {list of files written or "none"}
  Commit:   {short-hash} — {commit message}
  Time:     {UTC timestamp}
```

If git is not available: omit commit line and warn "git not found — changes saved but not committed."

---

## Phase 9 — Cloud Bridge (Context-Heavy)

Load `references/cloud-bridge.md` for the config format, payload mapping, and autonomy matrix.

The store stays local-first; the bridge adds an optional cloud brain ([Context-Heavy](https://github.com/shihabshahrier/Context-Heavy)) where pushed knowledge becomes hybrid-searchable, graph-linked, and shared across agents and machines. All cloud commands run the deterministic helper:

- **`cloud connect`** — store URL + API key (gitignored, `chmod 600`) and autonomy flags:
  ```bash
  bash scripts/ck-cloud.sh connect --url "$CH_API_URL" --key "$CH_API_KEY" \
    [--agent <name>] [--auto-pull] [--auto-push]
  ```
- **`push`** — send a project (or `--all`) to `POST /v1/sync/ck`. Sections, learnings (project + global), and connections map to nodes and edges; the server is idempotent by slug, so re-push never duplicates. `--changed` skips projects already pushed at their current commit; `--dry-run` shows what would be sent:
  ```bash
  bash scripts/ck-cloud.sh push <project> [--all] [--changed] [--dry-run]
  ```
- **`pull`** — fetch the cloud warm-start (persona to adopt + pinned nodes + lessons, exposure-filtered per (project, agent) context profile) and recent learnings, and print them into the session. **Read-only: never writes store files.** After running it, actually adopt the persona behavior and weigh the lessons:
  ```bash
  bash scripts/ck-cloud.sh pull [<project>] [--agent <name>]
  ```
- **`cloud status`** — show config (key masked) + per-project last-push markers:
  ```bash
  bash scripts/ck-cloud.sh status
  ```

If the script is unreachable, do not improvise HTTP calls inline — report that the bridge helper is missing and where it should be.

---

## Autonomy (optional hooks)

The store is trigger-driven by default. Two **deterministic, opt-in** Claude Code hooks add passive autonomy (wire them with `bash install.sh --hooks`):

- **SessionStart → `scripts/ck-recall.sh`** — detects the project from cwd; if the store has knowledge for it, injects its lessons (`learnings.md`), `_global` lesson titles, meta, and recent progress so the session starts warm. Silent when no match. With `CH_AUTO_PULL=true` in the cloud config it also pulls the cloud warm-start (persona + lessons from other agents/machines) — even when the local store is empty for the project, so a fresh machine catches up automatically.
- **SessionEnd → `scripts/ck-autosync.sh`** — commits any uncommitted store changes so nothing written during the session is lost. Silent when clean. With `CH_AUTO_PUSH=true` it then pushes changed projects to the cloud brain so other agents can catch up with this session's knowledge.

Both cloud legs are best-effort: a dead network never blocks session start/end. Capture stays agent-driven: hooks cannot compose a learning. When a session resolves a gotcha, finds a pattern, or makes a notable decision, proactively run `/ck learn` or `/ck save` for it.

---

## Error Handling

| Situation | Action |
|-----------|--------|
| `CK_HOME` doesn't exist on non-init command | Run Phase 1 (init) silently, then continue |
| `meta.json` missing for a project | Create it interactively before writing other files |
| `git` not installed | Write files, skip all git commands, warn once |
| Project slug not found on `load` | List available projects, ask user to pick |
| Windows path with spaces | Wrap all paths in quotes in shell commands |
| `--auto` detects wrong project | Present detection, let user correct before proceeding |

---

## Token Efficiency Rules

- Load `references/store-layout.md` only in Phase 1 and Phase 3 (when meta.json is needed).
- Load `references/section-templates.md` only at the start of Phase 3.
- Load `references/git-conventions.md` only when constructing a non-standard commit message.
- Load `references/cloud-bridge.md` only in Phase 9 (cloud/push/pull).
- Never load all references at once — load lazily per phase.
- For `load`: read files sequentially; stop reading if context window nears limit (>100k tokens used).
- For `search`: cap at 50 matches total (`head -50`); refine the query if capped.

---

## Open-Weight Model Rules

- Substitute all variables (`$CK_HOME`, project slugs, dates) before writing any file content.
- `meta.json` must always be valid JSON — check before writing (no trailing commas, no comments).
- Git commands: always use `-C "$CK_HOME"` flag to avoid working directory confusion.
- Windows paths: replace forward slashes with backslashes; use `%USERPROFILE%` not `$HOME`.
- Slug sanitization: `^[a-z0-9]+(-[a-z0-9]+)*$` — enforce before creating any project directory.
- Never overwrite `progress.md`, `connections.md`, or `learnings.md` — always append.
- If git commit fails (nothing to commit), continue without error.
- All Markdown files: valid heading structure, no unclosed code fences, no broken tables.
