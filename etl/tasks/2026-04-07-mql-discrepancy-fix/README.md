# MQL Discrepancy Pipeline Fix
- **Status:** draft
- **Date:** 2026-04-07
- **PR:** pending
- **Models touched:** fct_sessions_build, dim_mql_mapping, dim_session_mqls (new)
- **Source:** analysis/data-health/2026-04-07-mql-discrepancy/

## Context

HubSpot MQLs diverged from Mixpanel MQLs starting ~2026-02-23. Root cause: the `Enterprise v2 - Updated` HubSpot form was deployed to `/brand-solutions` and `/agency-solutions` pages where it fires `Submitted Form` with empty context instead of `Enterprise Contact Form`. Also, `CTA Form Submitted` on `/enterprise` is uncaptured. Investigation proved 100% of HubSpot MQLs can be matched to a Mixpanel session via tiered matching.

## dbt Model Files
- `fct_sessions_build.sql` — expanded enterprise form event matching (lines 67-74)
- `dim_mql_mapping.sql` — tiered HubSpot-to-Mixpanel matching (full rewrite)
- `dim_session_mqls.sql` — session-level MQL bridge table (NEW, aggregates dim_mql_mapping to 1 row per session)
## LookML Files (in lookml/tasks/2026-04-07-mql-discrepancy-fix/)
- `fct_sessions_view_changes.lkml` — changes to fct_sessions.view.lkml: new sql_table_name, reconciled MQL dimensions/measures, hide old measures

## Architecture

```
fct_sessions_build (expanded event matching)
  → fct_sessions (existing view)

dim_mql_mapping (tiered HubSpot-to-Mixpanel matching)
  → dim_session_mqls (session-level bridge)
```

`dim_session_mqls` is joinable 1:1 to `fct_sessions` on `session_id`. LookML joins the bridge table into the existing fct_sessions explore.

## Deployment Workflow

dbt commands only update `soundstripe_dev`. Production updates via PR merge to `main`.

1. **Dev:** Apply all model changes on `develop_dab`, build + verify in `soundstripe_dev`
2. **Prod prep:** DELETE FROM `soundstripe_prod.TRANSFORMATIONS.fct_sessions_build` WHERE session_started_at >= '2026-02-23' (TRANSFORMER role) — shifts incremental watermark back for reprocessing
3. **PR:** Open PR `develop_dab` → `main` — CI runs automatic build/run + downstream
4. **Merge:** Once CI passes, merge — triggers production deployment
5. **QA:** Validate MQL counts in `soundstripe_prod` against HubSpot baseline (only after prod build completes)
6. **LookML:** Join dim_session_mqls into fct_sessions explore, add reconciled MQL measures, hide old measures

See `implementation-guide.md` for full step-by-step.
