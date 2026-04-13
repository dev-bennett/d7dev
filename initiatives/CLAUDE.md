# Initiatives

@../CLAUDE.md

Cross-workspace initiative tracking. Each initiative is a body of work that spans multiple d7dev workspaces (analysis/, etl/, lookml/, knowledge/) and needs a single place that ties the pieces together.

## Structure

```
initiatives/
  CLAUDE.md
  <slug>.md          -- one file per initiative, tracks all artifacts across workspaces
```

## When to Create an Initiative

Create an initiative file when work touches 2+ workspaces (e.g., ETL + LookML, or analysis + knowledge + ETL). Single-workspace tasks don't need an initiative -- the task README is sufficient.

## Initiative File Format

```markdown
# <Initiative Title>
- **Status:** active | paused | complete
- **Started:** YYYY-MM-DD
- **Owner:** <who drives this>
- **Phase:** <current phase description>

## Objective
<1-2 sentences: what this initiative achieves and why>

## Artifacts

### ETL
- `etl/tasks/YYYY-MM-DD-<slug>/` -- <status, what it contains>

### LookML
- `lookml/tasks/YYYY-MM-DD-<slug>/` -- <status, what it contains>

### Knowledge
- `knowledge/domains/<domain>/` -- <what was added>
- `knowledge/decisions/YYYY-MM-DD-<slug>.md` -- <decision captured>

### Analysis
- `analysis/<domain>/YYYY-MM-DD-<slug>/` -- <what was produced>

## Changelog
- YYYY-MM-DD: <what happened>
```

## Conventions

- One file per initiative, named by slug (e.g., `lifecycle-notifications.md`)
- Update the changelog entry at the end of each session that touches the initiative
- Link to specific task directories and knowledge articles, not entire workspaces
- When an initiative is complete, mark status and archive (don't delete)
