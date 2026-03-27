ETL / data engineering workflow for "$ARGUMENTS":

Supported actions (first word of $ARGUMENTS):
- "transform <name>" -- write/modify a SQL transform
- "quality <target>" -- create data quality checks for a table/model
- "pipeline <name>" -- design a pipeline definition
- "audit" -- review existing ETL assets against dbt snapshot

Workflow:
1. Check context/dbt/ for existing models and lineage
2. For transforms: create in etl/sql/<layer>/<name>.sql (layer = staging|intermediate|marts)
3. For quality checks: create in etl/quality/<name>.sql
4. For pipelines: create in etl/pipelines/<name>.md (design doc) or .py (script)
5. Document table dependencies and expected refresh cadence
6. Stage all created/modified files

Transforms should be written as dbt-compatible SQL (using ref() and source() patterns)
so they can be promoted to the dbt repo when ready.
