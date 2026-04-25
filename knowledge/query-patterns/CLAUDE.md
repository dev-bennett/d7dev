@../CLAUDE.md

# Query Patterns

Canonical, reusable SQL patterns proven across ≥2 analyses. Referenced from `.claude/commands/sql.md` and `.claude/rules/snowflake-mcp.md` as the first place to check before drafting a new query.

## Purpose

Stop re-deriving the same queries (schema snapshots, bridge joins, step-rate templates, cohort pulls) from scratch. If a pattern has appeared in two analyses, it lives here with the prior analyses linked.

## Promotion rule — "twice = promote"

Do not pre-populate this directory with speculative patterns. Promote only when:
1. The query pattern has been used in ≥2 distinct analyses
2. The pattern is stable (table names, join keys, filter logic unlikely to churn)
3. It is worth citing — it encodes a non-obvious correctness requirement (e.g., step-rate nesting, session ↔ event bridge via `dim_session_mapping`)

First use: leave in the task directory. Second use: promote here and link the prior analyses in the header.

## File conventions

Each `.sql` file starts with a header comment block:

```sql
-- PURPOSE:       [one-line purpose]
-- TABLES:        [comma-separated]
-- PARAMETERS:    [named placeholders, e.g. :start_date, :table]
-- PRIOR USES:    [analysis/<domain>/<slug>/... — at least 2]
-- RATE BLOCK:    [§1 RATE/NUMERATOR/DENOMINATOR if rate query; else "n/a"]
-- LAST UPDATED:  [YYYY-MM-DD]
```

SQL body follows. Use explicit parameter placeholders (`:start_date`) rather than hardcoded values — this is a template, not a canned query.

## Index

See `_index.md` for the catalog keyed by topic/table.

## What does NOT belong here

- Analysis-specific queries (those live in the analysis task directory)
- One-off discovery queries (those are ephemeral MCP runs or task-dir `.sql` files)
- dbt models (those live in `context/dbt/` and the dbt repo)
- LookML derived tables (those live in `context/lookml/` and LookML repo)
