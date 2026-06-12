# Cloud Bridge Reference — Context-Heavy

How the local store syncs with a Context-Heavy cloud brain (currently in
development — the bridge works against any deployment of it, including
`http://localhost:8080` during development). Load this file only when
running Phase 9 (cloud) commands.

## Identity and workspaces

Context-Heavy is multi-tenant: a user registers (email/password), which
creates a **workspace**, then mints an API key (`POST /v1/keys`) scoped
`read`/`write`. That `cg_live_…` key **is** the bridge's identity — every
request sends it as `Authorization: Bearer`, the server resolves it to its
workspace, and all pushed/pulled knowledge lives inside that workspace only.
One key = one workspace = one brain. Different machines/agents using the same
key share the same brain; that is the catch-up mechanism.

The store stays **local-first**: everything works offline, git remains the
source of truth for your machine. The cloud brain is a second home where
pushed knowledge becomes hybrid-searchable (FTS + vector), graph-linked,
temporally versioned, and shared — so **any agent on any machine can catch up
with you, and you can catch up with them**.

---

## Configuration

| File | Purpose | Git status |
|------|---------|-----------|
| `$CK_HOME/.cloud` | `KEY=VALUE` config: URL, API key, agent name, autonomy flags | gitignored, `chmod 600` |
| `$CK_HOME/.cloud-state.json` | Per-project sync markers (`last_commit`, `last_pushed_at`) | gitignored |

```
CH_API_URL=https://api.example.com
CH_API_KEY=cg_live_xxxxxxxx
CH_AGENT=claude-code
CH_AUTO_PULL=true
CH_AUTO_PUSH=true
```

- Environment variables `CH_API_URL` / `CH_API_KEY` / `CH_AGENT` override the file.
- The API key is a Context-Heavy workspace key (`cg_live_…`) with **write**
  scope for push, **read** scope for pull. Sent as `Authorization: Bearer`.
- **Never commit the key.** `connect` writes it gitignored with `chmod 600`;
  `ck-init.sh` and `ensure_gitignored` keep both files ignored.
- Sync markers live **outside git** on purpose: they are per-machine state,
  and committing a marker update would itself change the project's last
  commit, re-triggering `--changed` pushes forever.

## Why pull never writes store files

`pull` prints cloud context to stdout (for the agent to read) and never
touches `$CK_HOME`. If pull wrote learnings into `learnings.md`, the next
push would send them back, the server would dedup, but local/cloud edits
could ping-pong. One-way write per direction keeps the loop open:
**files → cloud** on push, **cloud → context window** on pull.

---

## Payload mapping (push → `POST /v1/sync/ck`)

| Store file | Payload | Cloud result |
|------------|---------|--------------|
| `meta.json` | `meta` (passthrough) | properties on the **Project node** |
| `brief.md`, `codebase-map.md`, `decisions.md`, `progress.md`, `schema/db.md`, `api/endpoints.md`, `frontend/components.md`, `infra/overview.md`, `workers/overview.md` | `sections[]` (name + content) | **Document nodes** slugged `<project>-<section>`, `part_of` → Project, chunked + embedded |
| `<project>/learnings.md` | `learnings[]` (title, type, context, resolution, why, tags) | **Learning nodes**, `learned_in` → Project, deduped by title slug |
| `_global/learnings.md` | `learnings[]` with `global: true` | global Learning nodes (no project scope) |
| `connections.md` | `connections[]` (to_project, relationship, notes) | **edges** between Project nodes; missing targets stub-created |

Skipped: `README.md` + `index.json` (derived artifacts), raw `schema/db.sql`
and `api/openapi.yaml` (blobs — the `.md` twins carry the knowledge).

Idempotency: the server upserts by slug and only rewrites a section whose
body changed (each rewrite re-chunks + re-embeds). A re-push of an unchanged
project reports `0+0 sections, 0 learnings (+N already known)`.

Global learnings ride along on **every** push; the server's dedup makes the
repeat a cheap no-op. This guarantees globals reach the cloud even if the
user only ever pushes one project.

## Pull endpoints (read-only)

| Endpoint | Returns |
|----------|---------|
| `GET /v1/context/warm-start?project=<slug>&agent=<name>` | persona (behavior to adopt), project anchor, pinned nodes, recent lessons — exposure-filtered server-side per (project, agent) context profile |
| `GET /v1/learnings?project=<slug>&limit=10` | newest lessons with bodies (recall bumps their `use_count` on the server — the reuse signal) |

The `agent` parameter is the persona selector: the same workspace answers
differently to `claude-code` vs `cursor` vs a CI bot, per its context
profiles. Set a stable `CH_AGENT` in `connect` so the cloud brain knows who
is asking.

---

## Autonomy matrix

| Trigger | Manual command | Autonomous (opt-in) |
|---------|----------------|---------------------|
| Session start, catch up | `/ck pull <project>` | `ck-recall.sh` hook runs `pull` when `CH_AUTO_PULL=true` (6s cap, silent on failure, runs even when the local store has nothing — fresh-machine catch-up) |
| Session end, share | `/ck push <project>` | `ck-autosync.sh` hook runs `push --all --changed` when `CH_AUTO_PUSH=true` (after the local auto-commit; silent on failure) |
| Anytime | `push --all`, `push --dry-run`, `pull --agent <x>`, `cloud status` | — |

`--changed` skips a project when its latest store commit equals the recorded
marker **and** its working tree is clean. Everything else pushes; the server
side stays idempotent regardless, so a redundant push is safe, just slower.

## Failure behavior

- No config → manual commands explain how to connect; hooks stay silent.
- Cloud unreachable → manual commands print the curl error; hooks swallow it
  (a dead network must never break session start/end).
- Non-200 → first 300 bytes of the response body are shown.
- `meta.json` invalid JSON → warning to stderr, push continues without meta.
- `curl`/`python3` missing → clear error naming the missing tool.
