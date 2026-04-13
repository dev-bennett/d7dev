# LookML Development Workspace

Working area for LookML development tasks. Files here are drafts/proposals
to be promoted to the LookML repo after validation in Looker's IDE.

## Structure

```
lookml/
  CLAUDE.md              -- this file
  reference/             -- refreshable mirror of the Looker repo structure (from context/lookml/)
  tasks/                 -- dated task directories for LookML development work
    YYYY-MM-DD-<slug>/
      CLAUDE.md          -- task context and status
      README.md          -- task scope, files, promotion status
      lkml/              -- LookML source files mirroring repo directory structure
        views/           -- .view.lkml files
        dashboards/      -- .dashboard.lookml files
        explores/        -- .explore.lkml files (or model snippets)
      promotion-guide.md -- step-by-step instructions for Looker IDE implementation
      commit-message.md  -- commit message for the Looker repo PR
      pr-description.md  -- PR description for the Looker repo PR
      *.pdf              -- dashboard screenshots for QA validation
```

## Reference Directory

`lookml/reference/` is a working copy of the Looker repo structure. Refresh from the submodule:

```bash
# Refresh reference from submodule
rm -rf lookml/reference && cp -r context/lookml/ lookml/reference/
```

Use this to check existing patterns, naming conventions, and explore structures
before writing new LookML. Never edit reference/ -- it's read-only.

## Task Workflow

1. Create task directory: `lookml/tasks/YYYY-MM-DD-<slug>/`
2. Reference `lookml/reference/` (or `context/lookml/`) for existing patterns
3. Reference `context/dbt/` for underlying data models and column names
4. Write LookML files in `tasks/<slug>/lkml/` mirroring the repo directory structure
5. Write promotion guide mapping each file to its repo target
6. Write commit message and PR description
7. User implements in Looker IDE from the promotion guide
8. User validates in Looker, commits, and merges PR
9. Update task README with PR link and status

## Conventions

@../.claude/rules/lookml-standards.md

## Relationship to Looker Repo

- Source repo: SoundstripeEngineering/looker (git submodule at context/lookml/)
- Files here are NOT production LookML -- they are proposals/drafts
- Promotion to the Looker repo is manual via Looker's IDE (not direct git push)
- Every task includes a promotion guide and PR documentation
