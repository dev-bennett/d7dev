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
