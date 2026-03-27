---
name: Git Workflow
---

# Git Workflow Conventions

- Branch naming: `feature/<name>`, `fix/<name>`, `refactor/<name>`, `analysis/<topic>`, `lookml/<name>`, `etl/<name>`, `kb/<topic>`
- Commit messages: imperative mood, 50-char subject line, body explains "why" not "what"
- Always create new commits -- never amend unless explicitly asked
- Stage specific files by name -- never use `git add .` or `git add -A`
- Before committing: run `pytest` if test files exist for changed modules
- PR descriptions: Summary (bullet points) + Test Plan format
- Never force-push to main
- Keep commits atomic: one logical change per commit
- Analytical work: commit analysis outputs with the queries that produced them
- LookML changes: commit view + explore + tests together as atomic units
- Large context ingestions: use a dedicated `ingest/<repo-name>` branch
