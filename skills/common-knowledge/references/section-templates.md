# Section Templates Reference

Markdown templates for every file in a project's knowledge directory.
Load this file at the start of Phase 3 before writing any content files.
Replace all `{PLACEHOLDER}` values before writing.

---

## Table of Contents

- [README.md (project)](#readmemd-project)
- [codebase-map.md](#codebase-mapmd)
- [progress.md](#progressmd)
- [decisions.md](#decisionsmd)
- [connections.md](#connectionsmd)
- [schema/db.md](#schemadbmd)
- [api/endpoints.md](#apiendpointsmd)
- [frontend/components.md](#frontendcomponentsmd)
- [infra/overview.md](#infraoverviewmd)
- [workers/overview.md](#workersoverviewmd)
- [_global/integrations.md](#_globalintegrationsmd)
- [_global/tech-decisions.md](#_globaltech-decisionsmd)
- [_global/agent-config.md](#_globalagent-configmd)
- [Store README.md (root index)](#store-readmemd-root-index)

---

## README.md (project)

```markdown
# {Project Name}

> **Type:** {type} | **Status:** {status}
> **Repo:** {origin_repo}
> **Local:** {local_path}
> **Stack:** {tech_stack joined with ", "}
> **Updated:** {last_updated}

{description}

## Quick Links

- [Codebase Map](./codebase-map.md)
- [Progress Log](./progress.md)
- [Decisions](./decisions.md)
- [DB Schema](./schema/db.md)
- [API Endpoints](./api/endpoints.md)
- [Connections](./connections.md)
```

---

## codebase-map.md

````markdown
# Codebase Map — {Project Name}

> Last updated: {YYYY-MM-DD}
> Agent: {which AI agent wrote this}

## Architecture Overview

{One paragraph describing the overall system architecture and design philosophy.}

## System Diagram

```
{ASCII diagram of the architecture — services, databases, external integrations}
```

## Directory Structure

```
{project-root}/
├── {dir}/          # {purpose}
├── {dir}/          # {purpose}
└── {file}          # {purpose}
```

## Entry Points

| Entry | File | Description |
|-------|------|-------------|
| {API server} | {path/to/main.go} | {what it starts} |
| {frontend} | {src/main.tsx} | {what it renders} |

## Key Files

| File | Purpose |
|------|---------|
| {path} | {what it does} |
| {path} | {what it does} |

## Tech Stack

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| {Backend} | {Go + Gin} | {1.25} | {why chosen} |
| {Database} | {PostgreSQL} | {16} | {key features used} |

## Module Boundaries

{Description of how the codebase is organized into modules/packages/layers.}
````

---

## progress.md

Append a new entry for each session. Never overwrite existing entries.

```markdown
# Progress Log — {Project Name}

---

## {YYYY-MM-DD} — {Session Title}

> **Agent:** {which AI agent was used}
> **Duration:** {approx duration}
> **Status:** {active | blocked | complete}

### Completed This Session
- {what was built or fixed}
- {what was decided}

### In Progress
- {what's currently being worked on}

### Blocked / Issues
- {what is blocking progress}

### Next Steps
- {what should happen in the next session}

---
```

---

## decisions.md

```markdown
# Decision Log — {Project Name}

Architecture decision records (ADRs) for this project.

| Date | Decision | Rationale |
|------|----------|-----------|
| {YYYY-MM-DD} | {what was decided} | {why this choice was made} |
| {YYYY-MM-DD} | {what was decided} | {why this choice was made} |
```

---

## connections.md

Append a new section for each connection. Never overwrite existing entries.
Format is edge-compatible with the Context-Heavy graph model.

```markdown
# Connections — {Project Name}

Cross-project links and integration points.

---

## {other-project-name} [{relationship-type}]

- **From:** {this-project}
- **To:** {other-project}
- **Type:** {depends_on | integrates_with | calls_api | shares_db | owned_by | uses_lib | related_to}
- **Direction:** {unidirectional | bidirectional}
- **Local path:** {local path of other project}
- **Repo:** {origin_repo of other project}
- **Notes:** {describe the integration — what API, what DB, what data flows}
- **Recorded:** {YYYY-MM-DD}

---
```

---

## learnings.md

Append a new entry for each learning. Never overwrite existing entries.
Lives at `{project}/learnings.md` (project-specific) or `_global/learnings.md` (reusable, default).
Written by `/ck learn`, recalled by `/ck learnings`.

```markdown
# Learnings — {Global | Project Name}

Append-only log of gotchas, fixes, patterns, and insights captured for future
decision-making. Newest entries at the bottom. Recall with `/ck learnings`.

---

## {YYYY-MM-DD} — {short title}

> **Type:** {gotcha | pattern | pitfall | insight | idea}  |  **Tags:** {comma,separated,keywords}  |  **Project:** {slug or —}

**Context:** {where you got stuck / the situation / what prompted this}
**Resolution/Insight:** {what fixed it / the creative idea / the pattern}
**Why it matters:** {how this should inform a future decision}

---
```

### Type vocabulary

| Type | Use for |
|------|---------|
| `gotcha` | A non-obvious trap you hit and resolved (env, config, API quirk) |
| `pattern` | A reusable approach worth repeating |
| `pitfall` | Something to avoid — a path that wasted time |
| `insight` | A realization that changes how you decide (default) |
| `idea` | A creative idea to revisit later |

---

## schema/db.md

````markdown
# Database Schema — {Project Name}

> Last updated: {YYYY-MM-DD}
> Database: {type and version, e.g. PostgreSQL 16}
> Extensions: {e.g. pgvector, pg_trgm, uuid-ossp}

## Tables

### {table_name}

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| {id} | {uuid} | {PRIMARY KEY NOT NULL DEFAULT gen_random_uuid()} | {row identifier} |
| {name} | {text} | {NOT NULL} | {display name} |
| {created_at} | {timestamptz} | {NOT NULL DEFAULT now()} | {creation time} |

**Indexes:**
```sql
CREATE INDEX {index_name} ON {table_name} ({column});
```

**Foreign Keys:**
- `{column}` → `{other_table}({column})`

---

### {table_name_2}

...

## Migrations

| Migration | File | Description |
|-----------|------|-------------|
| {001} | {001_init.sql} | {what it creates} |

## Key Queries

```sql
-- {Description of what this query does}
SELECT ... FROM ... WHERE ...;
```
````

---

## api/endpoints.md

````markdown
# API Endpoints — {Project Name}

> Last updated: {YYYY-MM-DD}
> Base URL: {e.g. http://localhost:3000 / https://api.example.com}
> Auth: {e.g. Bearer token in Authorization header}
> Version: {e.g. /v1/}

## Authentication

{Describe how to authenticate. What header? What format? How to get a token?}

```bash
# Example authenticated request
curl -H "Authorization: Bearer {token}" {BASE_URL}/v1/resource
```

## Endpoints

### {Resource Name}

#### {METHOD} {/v1/path}

**Description:** {what this endpoint does}
**Auth required:** {yes | no}
**Scopes:** {read | write | admin}

**Request:**
```json
{
  "field": "value"
}
```

**Response 200:**
```json
{
  "data": {},
  "meta": {}
}
```

**Errors:**
| Status | Meaning |
|--------|---------|
| 400 | {validation error description} |
| 401 | {auth error description} |
| 404 | {not found description} |

---
````

---

## frontend/components.md

````markdown
# Frontend Architecture — {Project Name}

> Last updated: {YYYY-MM-DD}
> Framework: {e.g. React 19 + Vite}
> Styling: {e.g. Tailwind CSS 4}
> State: {e.g. React Query + Context API}

## Routing

| Route | Component | Description |
|-------|-----------|-------------|
| {/} | {LandingPage} | {what it shows} |
| {/dashboard} | {DashboardPage} | {what it shows} |

## Key Components

| Component | File | Purpose |
|-----------|------|---------|
| {ComponentName} | {src/components/} | {what it does} |

## State Management

{Describe how state is managed — context, query library, local state patterns.}

## API Integration

{Describe how the frontend calls the backend — axios, fetch, SDK, etc.}

## Build & Deploy

```bash
npm install
npm run dev       # local dev
npm run build     # production bundle
```
````

---

## infra/overview.md

````markdown
# Infrastructure Overview — {Project Name}

> Last updated: {YYYY-MM-DD}
> Cloud: {e.g. AWS / GCP / Fly.io / Vercel}
> IaC: {e.g. Terraform / Pulumi / manual}

## Architecture

```
{ASCII diagram of cloud architecture}
```

## Services

| Service | Provider | Config | Monthly Cost |
|---------|---------|--------|--------------|
| {API} | {ECS Fargate} | {0.25 vCPU, 512MB} | {~$15} |
| {Database} | {RDS PostgreSQL} | {t4g.micro} | {~$15} |

## Environment Variables

| Variable | Required | Description |
|----------|---------|-------------|
| {DATABASE_URL} | ✅ | {connection string} |
| {JWT_SECRET} | ✅ | {signing key} |

## Deploy Process

```bash
# {Step-by-step deploy commands}
```

## CI/CD

{Describe CI/CD pipeline — GitHub Actions, branches, what triggers deploy.}
````

---

## workers/overview.md

```markdown
# Workers & Background Jobs — {Project Name}

> Last updated: {YYYY-MM-DD}

## Jobs

| Job | Trigger | Description | Timeout |
|-----|---------|-------------|---------|
| {job-name} | {cron: */5 * * * *} | {what it does} | {5 min} |

## Queue System

{Describe the queue — Redis, SQS, BullMQ, etc. How jobs are enqueued and consumed.}

## Failure Handling

{Describe retry logic, dead letter queues, alerting on failure.}
```

---

## _global/integrations.md

Append a new entry for each cross-project link. Never overwrite.

```markdown
# Cross-Project Integrations

Global map of all known project connections.

---

## {project-a} → {project-b} [{relationship-type}] — {YYYY-MM-DD}

- **From:** {project-a} ({local_path or repo})
- **To:** {project-b} ({local_path or repo})
- **Type:** {relationship-type}
- **Notes:** {brief description of the integration}

---
```

---

## _global/tech-decisions.md

```markdown
# Global Technology Decisions

Architecture and technology decisions that span multiple projects.

| Date | Decision | Projects Affected | Rationale |
|------|----------|------------------|-----------|
| {YYYY-MM-DD} | {decision} | {project-a, project-b} | {why} |
```

---

## _global/agent-config.md

````markdown
# AI Agent Configuration

Notes on AI agent setup, model preferences, and environment config.

## Models in Use

| Agent | Model | Use Case |
|-------|-------|---------|
| {Antigravity} | {Gemini 2.5 Pro} | {general coding} |
| {opencode} | {Claude Sonnet 4.6} | {heavy refactoring} |

## API Keys (locations, not values)

| Service | Key Location |
|---------|-------------|
| {OpenRouter} | {~/.zshrc: OPENROUTER_API_KEY} |

## Common Environment Variables

```bash
# Add to ~/.zshrc or ~/.bashrc
export CK_HOME="$HOME/common-knowledge"
```

## Agent Notes

{Any notes about how to configure specific agents, MCP servers, skill locations, etc.}
````

---

## Store README.md (root index)

Auto-generated by `/ck status`. Do not hand-edit — it will be overwritten.

```markdown
# Common Knowledge Store

> Updated: {YYYY-MM-DD HH:MM UTC}
> Projects: {count}

This is a Git-backed local knowledge store managed by the `common-knowledge` skill.
Every directory is a project. Every save is a git commit.

## Projects

| Project | Type | Status | Updated | Description |
|---------|------|--------|---------|-------------|
| [{name}](./{slug}/) | {type} | {status} | {last_updated} | {description} |

## Global Knowledge

- [Agent Config](./_global/agent-config.md)
- [Tech Decisions](./_global/tech-decisions.md)
- [Integrations](./_global/integrations.md)

---
*Managed by the [common-knowledge](https://github.com/shihabshahrier/common-knowledge) skill.*
```
