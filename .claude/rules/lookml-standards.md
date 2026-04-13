---
name: LookML Standards
paths: ["**/*.lkml", "lookml/**"]
---

# LookML Development Conventions

## File Organization

- One view per file, filename matches view name (snake_case)
- Views derived from a single table: name matches dbt model name
- Derived tables: prefix with `dt_`
- Dashboard files go in `lookml/dashboards/` (dev workspace) or `dashboards/` (LookML repo)
- New views go in the appropriate domain subdirectory under `views/` (General, Finance, Hubspot, Mixpanel, Music, Production, Subscriptions, etc.)
- Marketing notification views go in `views/General/` (matches existing marketing explore patterns in General.model.lkml)

## View Structure

Order within a view file:
1. `sql_table_name` declaration
2. Dimensions (primary key first, then alphabetical within group_labels)
3. Dimension groups (timestamps)
4. Measures
5. Sets (drill fields)

### Dimensions
- Always set `type` explicitly (string, number, yesno, etc.)
- Mark primary keys with `primary_key: yes`
- Use `group_label` to organize related fields (e.g., "User Info", "Subscription Info", "Engagement Metrics")
- Description required on dimensions that aren't self-evident from the name
- Use `hidden: yes` for internal/join-only fields

### Dimension Groups (Timestamps)
- Use `type: time` with explicit `timeframes` list
- Standard timeframes: `[raw, date, week, month, quarter, year]`
- Add `hour_of_day`, `day_of_week` only when analytically relevant

### Measures
- Description required on ALL measures
- Use `drill_fields` on count/sum measures for exploration paths
- Use `value_format_name` consistently: `decimal_0` for counts, `percent_2` for rates, `usd` for currency
- Filtered measures: use `filters` parameter, not sql WHERE clauses
- Rate measures: define as `type: number` with sql referencing other measures

## Table References

- Use `sql_table_name` in views, not `derived_table`, when wrapping a simple table
- Reference transformed tables in `soundstripe_prod` schemas (CORE, MARKETING, CONTENT, FINANCE, CARE, STAGING, TRANSFORMATIONS)
- Reference raw tables in `PC_STITCH_DB.SOUNDSTRIPE` only when no dbt model exists
- Use UPPERCASE for schema/table names in sql_table_name to match Snowflake convention
- Connection is always `soundstripe_prod` (defined at model level, not view level)

## Explores

- Current state: explores are defined in model files (General.model.lkml has 62 explores)
- New explores: add to the appropriate existing model file for now
- Marketing-related explores go in `General.model.lkml`
- Descriptions required on all explores
- Use `always_filter` for data governance on high-volume explores
- Document join relationships with comments explaining the business logic
- Use explicit `relationship:` on all joins (many_to_one, one_to_many, etc.)
- Use `sql_on` (not `foreign_key`) for join conditions

## Dashboards

- Prefer LookML dashboards over user-defined for version control
- Use `preferred_viewer: dashboards-next`
- Layout: `newspaper`
- Include dashboard filters for: date range (required), plus key dimensions
- Scorecard tiles for headline KPIs at the top
- Time-series tiles in the middle
- Detail/table tiles at the bottom
- Default date filter: 90 days unless domain-specific logic requires otherwise
- Reference existing `ad_content_performance.dashboard.lookml` as the structural template

## Naming Conventions

- snake_case for ALL LookML identifiers (views, dimensions, measures, explores)
- Prefix fact tables: `fct_`
- Prefix dimension tables: `dim_`
- Prefix derived tables: `dt_`
- View names match their underlying dbt model name where possible
- Measure names: verb + noun (e.g., `total_deliveries`, `read_rate`, `avg_hours_to_read`)

## Quality Standards

- Test every new explore with at least one data test
- Comments explain business logic, not syntax
- No hardcoded IDs or magic numbers without a comment explaining what they are
- Validate LookML syntax before committing (check for unmatched parens, missing commas)

## Workflow

1. Draft in `lookml/` workspace (d7dev repo)
2. Reference `context/lookml/` for existing patterns and naming
3. Reference `context/dbt/` for underlying data models and column names
4. Validate with `/lookml validate`
5. Promote to the LookML repo (SoundstripeEngineering/looker) via manual PR
