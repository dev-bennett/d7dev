# LookML Development Workspace

Working area for LookML development. Files here are drafts/proposals
to be promoted to the LookML repo after validation.

## Structure

- `lookml/models/` -- .model.lkml files
- `lookml/views/` -- .view.lkml files
- `lookml/explores/` -- .explore.lkml files (explore refinements)
- `lookml/dashboards/` -- .dashboard.lkml files
- `lookml/tests/` -- data test files

## Conventions

@../.claude/rules/lookml-standards.md

## Workflow

1. Reference context/lookml/ for existing project patterns
2. Reference context/dbt/ for underlying data models
3. Develop in this workspace
4. Validate with `/lookml validate`
5. When ready, manually promote to the LookML repo

## Relationship to LookML Repo

Files here are NOT the production LookML. They are proposals/drafts
developed with full analytical context from this command center.
Promotion to the LookML repo is a manual step with its own review process.
