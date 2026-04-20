# PQL (Product-Qualified Leads)

@../CLAUDE.md

Analyses of the product-qualified lead path: Clay-enriched HubSpot contacts scored by the enterprise XGBoost model, with scores written back to HubSpot as `snowflake__lead_score` via Polytomic. PQLs are the non-form-filled lane that feeds into `dim_enterprise_leads` alongside MQLs (form submissions) and DTC upsells.

## Pipeline

```
HUBSPOT.HUBSPOT_CONTACTS (raw)
  → staging.stg_contacts[_2]
  → marts.data_enrichment.pql_pre_append  (Clay-enriched filter)
  → transformations.python.enterprise_lead_scoring_model  (XGBoost)
  → marts.model_output.enterprise_lead_scoring
  → marts._external_polytomic.polytomic_sync_hubspot_leads_with_scores
  → Polytomic
  → HUBSPOT contact property: snowflake__lead_score
```

## Conventions

- Dated task folders under `tasks/YYYY-MM-DD-<slug>/`; each with its own CLAUDE.md.
- Each distinct query set gets its own subdirectory within the task folder, with its own CLAUDE.md and `queries.sql`.
- CSV exports land alongside the queries (`q1.csv`, `q2.csv`, etc.) with filename matching the query label.
- When the analysis depends on a specific score field, declare the field explicitly; don't let "lead score" go unqualified.
