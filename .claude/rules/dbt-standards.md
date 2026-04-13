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
