# ETL / Data Engineering Workspace

SQL transforms, pipeline designs, and data quality checks.

## Structure

- `etl/tasks/` -- task-based work directories (discovery, validation, context)
- `etl/sql/staging/` -- staging layer transform drafts (1:1 with sources)
- `etl/sql/intermediate/` -- intermediate transform drafts (business logic)
- `etl/sql/marts/` -- mart layer transform drafts (consumption-ready)
- `etl/pipelines/` -- pipeline designs and orchestration scripts
- `etl/quality/` -- reusable data quality check queries

## Task Organization

Each ETL initiative gets a task directory:

```
etl/tasks/YYYY-MM-DD-<slug>/
  README.md                -- task context, status, target models, PR link
  fct_events.sql           -- transform draft (named to match dbt model)
  <query_group>/           -- directory per query group (discovery, validation, etc.)
    <query_group>.sql      -- the SQL queries
    a.csv, b.csv, ...      -- exported results, named to match query labels
  validation/
    validation.sql
    a.csv, b.csv, ...
```

Everything lives in the task directory -- transform drafts, discovery queries,
validation queries, and exported results. Query groups get their own
subdirectory so the SQL and its exported results stay together. Name CSV
files to match the query labels in the SQL (Query A -> a.csv, etc.).

Transform draft files are named to match the dbt model they modify (e.g.,
`fct_events.sql`) so the promotion target is obvious.

### Task README format

```markdown
# <Task title>
- **Status:** draft | in-progress | promoted | complete
- **Date:** YYYY-MM-DD
- **PR:** <link when promoted>
- **Models touched:** <list of dbt models modified>
- **Source:** <what prompted this work>

## Context
<Why this work exists, what it enables>

## Files
- `schema_check.sql` -- <purpose>
- `validation.sql` -- <purpose>
- `etl/sql/marts/<model>.sql` -- <what changed>
```

### Before starting new ETL work

Check `etl/tasks/` for prior work on the same models or data sources.
If a prior task touched the same model, review its README and validation
queries before duplicating effort.

## Conventions

@../.claude/rules/sql-snowflake.md
@../.claude/rules/dbt-standards.md

## Workflow

1. Create task directory: `etl/tasks/YYYY-MM-DD-<slug>/`
2. Write discovery/schema check queries in the task directory
3. Reference context/dbt/ for existing model patterns
4. Write transform drafts in the task directory (dbt-compatible SQL, named to match target model)
5. Write validation queries in the task directory
6. Validate with `/etl audit`
7. Promote transforms to the dbt repo via PR
8. Update task README with PR link and status

## Relationship to dbt Repo

Transforms here are prototypes developed with full analytical context.
They follow dbt conventions so promotion is straightforward.
The dbt repo owns the production DAG; this workspace owns the analytical intent.
