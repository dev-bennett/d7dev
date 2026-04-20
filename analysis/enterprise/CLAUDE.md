# Enterprise

@../CLAUDE.md

Analyses covering the enterprise lead funnel: MQL (form submissions), SAL (sales-accepted), SQL (sales-qualified), PQL (product-qualified via Clay enrichment), DTC upsells, and deal progression. Central mart: `soundstripe_prod.core.dim_enterprise_leads`.

## Conventions

- Each analysis lives under a topic subdirectory (e.g., `enterprise/pql/`, `enterprise/mql/`, `enterprise/deals/`), with dated task folders under `tasks/` within each topic.
- Enterprise lead scoring is produced by `enterprise_lead_scoring_model.py` (XGBoost, dbt Python model) and synced back to HubSpot as `snowflake__lead_score` via Polytomic.
- Score field disambiguation matters: HubSpot contacts carry multiple scoring signals (`hubspotscore`, `lead_score_2_0`, `hs_predictivecontactscore_v2`, `customer_health_score`, `new_member_health_score`, `ryan___lead_score_value`, `snowflake__lead_score`). Always name the specific field.
- Stakeholder-facing outputs go through the §10 Writing Scrub before delivery.
