---
table: <schema>.<table_name>
last_calibrated: <YYYY-MM-DD>
schema_hash: <SHA256 hex of sorted column-name list, joined by '|'. Compute via: SELECT SHA2(LISTAGG(column_name, '|') WITHIN GROUP (ORDER BY column_name), 256) FROM <db>.information_schema.columns WHERE table_schema = <schema> AND table_name = <table>
dbt_model: <relative path from dbt repo root, e.g. marts/core/fct_events.sql | none>
row_count: <integer from information_schema.tables>
bytes_gib: <float>
col_count: <integer>
---

# <schema>.<table_name> — Calibration

## Purpose (business meaning)

<One paragraph. Pulled from dbt schema.yml description, knowledge/domains/ summaries, and LookML view description if present. Business-level, not technical.>

## Lineage

- **dbt model:** `context/dbt/models/<path>` (or `none` for raw sources)
- **Upstream sources:** `<fqn1>`, `<fqn2>` — from `ref()` / `source()` calls in the model SQL
- **dbt tags:** `<tag1>`, `<tag2>`
- **Materialization:** `<view | table | incremental>` — if incremental: `unique_key=<col>`, `incremental_strategy=<strategy>`
- **Incremental watermark behavior:** <note any late-arrival gotchas, e.g., "filters event_ts > watermark; drops late-arriving rows">

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| <col_name> | <type> | <raw_source_col or derivation> | <description from schema.yml> | <e.g., "NULL pre-2026-03-17"> |

<If table has >20 columns, list only PK + 10 most-used. Add a line: "Full schema: run `column_existence.sql` or see `information_schema.columns`.">

<Critical: list columns that are DROPPED from upstream sources. Example for fct_events:
"Dropped from pc_stitch_db.mixpanel.export: USER_AGENT, IP, MP_LIB, SCREEN_*. If you need these, query the raw source, not fct_events.">

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| <target> | `<this.col = that.col>` | `<1:1 | 1:N | N:1 | N:M>` | <gotcha or standard pattern> |

## Grain & identity

- **Grain:** one row per <X>
- **Primary key:** `<col(s)>`
- **Distinct-user column:** `<user_id | distinct_id | stable_id>` — <why this one>

## Typical usage patterns

- **Date scoping:** typical window is <N> days; rows/day ≈ <K>. Scanning more than <M> days costs >$<X>
- **Common filters:** `<predicate pattern>`
- **Canonical queries:** <links to knowledge/query-patterns/ entries that reference this table>

## Known pitfalls

<Pulled from: memory (project_* entries naming this table), OPEN issues, prior analyses, feedback memories>

- <gotcha with link to memory or analysis>

## Cost profile (from query_history)

- **P50 elapsed for date-scoped aggregates:** <Xms>
- **P95 elapsed:** <Yms>
- **Bytes scanned (typical):** <Z> MB/GB
- **Avoid:** <query shapes known to be expensive or pathological>

## Prior analyses referencing this table

<Top 5–10 most recent / relevant>

- [analysis/<domain>/<slug>/](../../../analysis/<domain>/<slug>/) — <one-line what was done>

## LookML semantics (if applicable)

<If context/lookml/views contains views sourced from this table, note the canonical measures/dimensions used in reporting.>

- View: `<view_name>` — key measures: `<list>`, key dimensions: `<list>`
