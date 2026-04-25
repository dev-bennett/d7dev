@../CLAUDE.md

# Warehouse Calibration

Per-table **technical-truth** artifacts that ground MCP queries in the dbt submodule, LookML views, Snowflake schema, analysis history, and known pitfalls.

Sits **below** the business-definition layer in `knowledge/data-dictionary/`. The entries above (`fct-events-reference-track-search.md`, etc.) describe what a thing MEANS; files in here describe what it IS — lineage, columns, joins, incremental behavior, gotchas.

## When an artifact exists

- On first touch of any table via `mcp__claude_ai_Snowflake__sql_exec_tool`, the rule in `.claude/rules/snowflake-mcp.md` "Calibration before query" checks for a current artifact. Block-vs-warn depends on table size, fact/dim naming, raw-source schema, and intended query shape — not a fixed table list
- Current = `last_calibrated` within 30 days AND `schema_hash` matches live `information_schema`
- Produced by the `warehouse-calibrator` subagent via `/calibrate <table>`

## File naming

`<schema>__<table>.md` — double-underscore separator, lowercase. Examples:
- `core__fct_events.md`
- `core__fct_sessions.md`
- `_external_statsig__exposures.md`
- `pc_stitch_db__mixpanel__export.md` (database.schema.table → triple-underscore where three levels)

## File contents

Follow `_template.md` exactly. Frontmatter fields are consumed by tooling:
- `table` (fully-qualified)
- `last_calibrated` (YYYY-MM-DD)
- `schema_hash` (SHA256 of `LISTAGG(column_name, '|') WITHIN GROUP (ORDER BY column_name)` — Snowflake-native; `LISTAGG` requires a constant separator so `|` is used, not newline)
- `dbt_model` (relative path from dbt repo root, or `none` for raw)
- `row_count`, `bytes_gib`, `col_count` (from `information_schema.tables`)

## Index

`_index.md` lists all calibrated tables with last-calibrated date and short schema hash. Updated by `/calibrate` on every artifact write.

## Sweep reports

`_sweep_<YYYY-MM-DD>.md` — output of scheduled staleness sweeps. Not committed as artifacts; they're session logs.

## What does NOT belong here

- Business definitions (those go in the topic-specific entries above this directory)
- Analysis-specific findings (those live in `analysis/<domain>/<slug>/`)
- Query patterns (those live in `knowledge/query-patterns/`)
- Decision records (those live in `knowledge/decisions/`)
