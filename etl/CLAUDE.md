# ETL / Data Engineering Workspace

SQL transforms, pipeline designs, and data quality checks.

## Structure

- `etl/sql/staging/` -- staging layer transforms (1:1 with sources)
- `etl/sql/intermediate/` -- intermediate transforms (business logic)
- `etl/sql/marts/` -- mart layer transforms (consumption-ready)
- `etl/pipelines/` -- pipeline designs and orchestration scripts
- `etl/quality/` -- data quality check queries

## Conventions

@../.claude/rules/sql-snowflake.md
@../.claude/rules/dbt-standards.md

## Workflow

1. Reference context/dbt/ for existing model patterns
2. Write transforms as dbt-compatible SQL (ref/source patterns)
3. Include quality checks for every new transform
4. Validate with `/etl audit`
5. When ready, promote transforms to the dbt repo

## Relationship to dbt Repo

Transforms here are prototypes developed with full analytical context.
They follow dbt conventions so promotion is straightforward.
The dbt repo owns the production DAG; this workspace owns the analytical intent.
