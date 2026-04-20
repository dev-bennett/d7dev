# Phase B — Pipeline-Shape Discovery

@../CLAUDE.md

Warehouse-level queries covering the enterprise lead-scoring pipeline:

```
  dim_hubspot_customer ─┐
  pql_pre_append ───────┤→ enterprise_lead_scoring_model (XGBoost retrains each dbt run)
  dtc_upsell_pre_append ┘       │
                                 ▼
                        hubspot_leads_with_scores (casts score, buckets probability)
                                 │
                                 ▼
                        polytomic_sync_hubspot_leads_with_scores (incremental, filters written rows)
                                 │
                                 ▼
                              Polytomic
                                 │
                                 ▼
                        HUBSPOT.HUBSPOT_CONTACTS.properties:snowflake__lead_score
```

## Tables queried

- `SOUNDSTRIPE_PROD.CORE.DIM_ENTERPRISE_LEADS` — consolidated MQL/PQL/DTC funnel
- `SOUNDSTRIPE_PROD.TRANSFORMATIONS.ENTERPRISE_LEAD_SCORING_MODEL` — raw XGBoost output
- `SOUNDSTRIPE_PROD._EXTERNAL_POLYTOMIC.HUBSPOT_LEADS_WITH_SCORES` — cast + probability bucket
- `SOUNDSTRIPE_PROD._EXTERNAL_POLYTOMIC.POLYTOMIC_SYNC_HUBSPOT_LEADS_WITH_SCORES` — sync-queued rows
- `SOUNDSTRIPE_PROD.MODEL_OUTPUT.ENTERPRISE_LEAD_SCORING` — final output joined with HubSpot state

## Key mechanism to validate

The Python model `enterprise_lead_scoring_model.py` calls `xgb.train()` every time dbt runs it, using the accumulated `leads_for_training` data. Model weights are not persisted — each dbt Cloud run retrains from scratch. This makes training-data composition drift a first-order candidate explanation for Ryan's Feb 2026 mean-score shift.

## Files

- `queries.sql` — B1 through B7
- `bN.csv` — one CSV per query
- `FINDINGS.md` — written after CSVs return, with Type Audits
