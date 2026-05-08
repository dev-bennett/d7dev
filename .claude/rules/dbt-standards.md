---
name: dbt Standards
paths: ["context/dbt/**", "etl/**"]
---

# dbt Best Practices

- Model naming: stg_ (staging), int_ (intermediate), fct_ (facts), dim_ (dimensions)
- One model per file, filename matches model name
- Use ref() and source() -- never hardcode table names
- Schema tests on every model: unique, not_null on primary keys minimum
- Document every model and column in schema.yml
- Sources defined in _sources.yml at the staging layer
- Incremental models: always define unique_key and strategy
- Use tags for logical grouping and selective runs
- Materializations: view for staging, table/incremental for marts
- Jinja: use macros for repeated SQL patterns; keep models readable
- Seeds: only for small lookup/mapping tables, not data loads
- Snapshots: use timestamp strategy when available, check strategy as fallback
- Follow the staging -> intermediate -> marts layering pattern
- Place intermediate models in transformations/<domain>/, mart models in existing marts/<domain>/
- New source tables: add to existing src_*.yml in alphabetical order, provide complete file replacement
- Schema tests must match join semantics: no relationships tests on LEFT JOIN FKs, no accepted_values without verifying the full value set
- Stitch sources: use `updated_at` as replication key for tables where rows get updated after insert (not `id`)
- dbt Cloud dev targets soundstripe_dev; production tables live in soundstripe_prod
- When manually rebuilding prod tables: USE ROLE TRANSFORMER, then GRANT SELECT to EMBEDDED_ANALYST after creation
- Before writing any dbt run/build command: read the target model's config block and incremental logic to confirm materialization strategy, unique_key, and available variables. Do not assume one model's config matches another's -- fct_events has backfill_from, fct_sessions_build does not.

## backfill_from canonical pattern

When adding `backfill_from` to a dbt incremental, **branch the entire WHERE clause** — never coalesce a literal into the aggregate subquery. The latter compiles to `select <literal> from {{ this }}`, which returns N rows and errors with `090150 (22000): Single-row subquery returns more than one row`.

Canonical pattern (from `models/marts/core/fct_events.sql`):

```sql
{% if is_incremental() %}
    {% if var('backfill_from', none) is not none %}
        and event_ts >= '{{ var("backfill_from") }}'::timestamp
    {% else %}
        and event_ts >= (select dateadd('days', -1, coalesce(max(event_ts), '1900-01-01')::date) from {{ this }} )
    {% endif %}
{% endif %}
```

Notes:
- Test with `var('backfill_from', none) is not none`, not `var('backfill_from', false)`.
- Cast the literal to match the LHS column type (`::date` if comparing `event_ts::date`; `::timestamp` if comparing `event_ts` directly).
- The backfill_from branch typically drops the `dateadd(-N days)` cushion — the user-specified date is the boundary.

## Validate event volume before expanding event-counting aggregations

When proposing a change to a `sum(case when event=X and context=Y ...)` field in `fct_sessions_build` or any model whose output feeds a Looker measure, two checks are mandatory before recommending the change:

1. **Event-volume sanity check.** Compare the new signal's event count and distinct_id count to the existing signal in the same window. A new signal >5× existing volume reshapes any downstream measure consuming the column.
2. **HubSpot/anchor check.** Look up the LookML measure consuming the column. If it's `COUNT(DISTINCT case when <col> > 0 then distinct_id)` with no JOIN to a HubSpot/CRM source, ANY new signal added inflates the user-facing MQL/conversion count without filtering by whether a real form/conversion happened.

If new volume is large AND there's no downstream anchoring, the signal belongs in `dim_mql_mapping.form_events_mixpanel` (or a similar HubSpot-anchored CTE) — NOT in `fct_sessions_build`. Validate even when preserving an old draft from a prior task — a month-old plan needs the same validation as a fresh one.

This rule was authored after a 2026-05-07 incident where preserving an un-validated 2026-04-07 draft inflated `mqls_schedule_demo` 49× (1,997 events for the new signal vs. 36 for the existing) and required a multi-hour DELETE + rebuild to revert.
