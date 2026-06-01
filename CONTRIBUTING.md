# Contributing to common-knowledge

Thanks for wanting to improve this skill!

## Ground Rules

- Edit only `skills/common-knowledge/SKILL.md` and `skills/common-knowledge/references/`.
- Run `bash install.sh` after every change to propagate to all agent paths.
- Test changes in at least one AI agent before submitting a PR.
- Keep `SKILL.md` under 5000 tokens. Move dense content to `references/`.

## Making Changes

```bash
# Clone
git clone https://github.com/shihabshahrier/common-knowledge
cd common-knowledge

# Edit the skill
vim skills/common-knowledge/SKILL.md

# Install and test
bash install.sh
# Then in your agent: /ck <command>

# Commit
git add -A
git commit -m "feat(skill): your change description"
git push origin main
```

## Commit Message Format

```
feat(skill): add new /ck export command
docs(skill): update store-layout reference
fix(skill): correct Windows path detection
chore(skill): update install paths for new agent
```

## Adding a New Section Template

1. Add the template to `skills/common-knowledge/references/section-templates.md`.
2. Reference it in `SKILL.md` Phase 3 instructions.
3. Update `skills/common-knowledge/references/store-layout.md` if a new file type is added.
4. Run `bash install.sh` and test.

## Reporting Issues

Open a GitHub issue with:
- Which AI agent you're using
- The command that failed
- What you expected vs what happened
