#!/usr/bin/env bash
# ck-init.sh — Initialize the common-knowledge store
# Usage: bash ck-init.sh [CK_HOME_OVERRIDE]
# Called by: the common-knowledge skill during Phase 1 (init)

set -euo pipefail

# ─── Resolve CK_HOME ───────────────────────────────────────────────────────────
if [[ -n "${1:-}" ]]; then
  CK_HOME="$1"
elif [[ -n "${CK_HOME:-}" ]]; then
  : # already set from environment
else
  CK_HOME="$HOME/common-knowledge"
fi

echo "📚 Initializing common-knowledge store at: $CK_HOME"
echo ""

# ─── Create directory tree ─────────────────────────────────────────────────────
mkdir -p "$CK_HOME/_global"

# ─── .gitignore ────────────────────────────────────────────────────────────────
cat > "$CK_HOME/.gitignore" << 'EOF'
.DS_Store
Thumbs.db
*.tmp
*.swp
*.bak
.env
.env.local
EOF

# ─── _global stubs ─────────────────────────────────────────────────────────────
cat > "$CK_HOME/_global/agent-config.md" << 'EOF'
# AI Agent Configuration

Notes on AI agent setup, model preferences, and environment config.

## Models in Use

| Agent | Model | Use Case |
|-------|-------|---------|
|       |       |         |

## API Keys (locations, not values)

| Service | Key Location |
|---------|-------------|
|         |             |

## Common Environment Variables

```bash
export CK_HOME="$HOME/common-knowledge"
```

## Agent Notes

<!-- Add notes about agent configuration, MCP servers, skill paths, etc. -->
EOF

cat > "$CK_HOME/_global/tech-decisions.md" << 'EOF'
# Global Technology Decisions

Architecture and technology decisions that span multiple projects.

| Date | Decision | Projects Affected | Rationale |
|------|----------|------------------|-----------|
|      |          |                  |           |
EOF

cat > "$CK_HOME/_global/integrations.md" << 'EOF'
# Cross-Project Integrations

Global map of all known project connections.
This file is updated automatically by `/ck link`.

<!-- Entries appended below by the common-knowledge skill -->
EOF

# ─── Root README (index, auto-generated) ───────────────────────────────────────
TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M UTC" 2>/dev/null || echo "unknown")
cat > "$CK_HOME/README.md" << EOF
# Common Knowledge Store

> Updated: $TIMESTAMP
> Projects: 0

This is a Git-backed local knowledge store managed by the \`common-knowledge\` skill.
Every directory is a project. Every save is a git commit.

## Projects

No projects yet. Run \`/ck save <project-slug>\` to add the first project.

## Global Knowledge

- [Agent Config](./_global/agent-config.md)
- [Tech Decisions](./_global/tech-decisions.md)
- [Integrations](./_global/integrations.md)

---
*Managed by the [common-knowledge](https://github.com/shihabshahrier/common-knowledge) skill.*
EOF

# ─── Git init ──────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "⚠️  git not found — store created but not version-controlled."
  echo "   Install git and re-run this script to enable history tracking."
  exit 0
fi

if [[ ! -d "$CK_HOME/.git" ]]; then
  git -C "$CK_HOME" init -q
  git -C "$CK_HOME" checkout -qb main 2>/dev/null || git -C "$CK_HOME" branch -M main 2>/dev/null || true
  echo "✅ Git initialized (branch: main)"
else
  echo "ℹ️  Git already initialized, skipping git init."
fi

git -C "$CK_HOME" add -A
git -C "$CK_HOME" diff --cached --quiet && echo "ℹ️  Nothing new to commit." || \
  git -C "$CK_HOME" commit -qm "chore: initialize common-knowledge store"

echo ""
echo "✅ common-knowledge store ready at: $CK_HOME"
echo ""
echo "Next steps:"
echo "  /ck save <project>    — save current project knowledge"
echo "  /ck status            — list all tracked projects"
echo "  /ck load <project>    — load a project's knowledge into context"
