---
name: LookML Standards
paths: ["**/*.lkml", "lookml/**"]
---

# LookML Development Conventions

- One view per file, filename matches view name
- Views derived from a single table: name matches table name
- Derived tables: prefix with `dt_`
- Explores: define in dedicated explore files, not in model files
- Dimensions before measures in view files
- Group related fields with `group_label`
- Always set `type` explicitly on dimensions (don't rely on defaults)
- Use `sql_table_name` in views, not `derived_table`, when wrapping a simple table
- Descriptions required on all explores and measures
- Use `drill_fields` on measures for exploration paths
- Dashboard LookML: prefer LookML dashboards over user-defined for version control
- Naming: snake_case for all LookML identifiers
- Test every explore with at least one data test
- Comments: explain business logic, not syntax
