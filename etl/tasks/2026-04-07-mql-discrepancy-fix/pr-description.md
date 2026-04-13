# Expand enterprise form matching and add tiered MQL attribution

## Summary

- **fct_sessions_build**: Expand `enterprise_form_submissions` and `enterprise_form_view` to capture `Submitted Form` on `/brand-solutions` and `/agency-solutions` (empty context) and `CTA Form Submitted` on `/enterprise`
- **dim_mql_mapping**: Full rewrite with three-tier matching (VID+time+URL → time+URL → session proximity) recovering 100% of HubSpot MQLs to Mixpanel sessions. Adds `match_tier`, `match_reason`, `form_page_type` columns
- **dim_session_mqls** (new): Session-level bridge table — one row per `session_id`, joinable 1:1 to `fct_sessions`

## Context

HubSpot MQLs diverged from Mixpanel MQLs starting ~2026-02-23 (71% gap by 03-30). Root cause: Enterprise v2 form deployed to new marketing pages where Mixpanel fires with empty context instead of `Enterprise Contact Form`. See `analysis/data-health/2026-04-07-mql-discrepancy/findings.md`.

## Pre-merge

`fct_sessions_build` rows from 2026-02-23 forward deleted from `soundstripe_prod.TRANSFORMATIONS` (TRANSFORMER role) to shift incremental watermark for reprocessing.

## Test plan

- [ ] fct_sessions_build: `enterprise_form_submissions > 0` for sessions on `/brand-solutions` and `/agency-solutions`
- [ ] dim_mql_mapping: `match_tier` populated, weekly matched count ≈ HubSpot MQL count
- [ ] dim_session_mqls: `has_mql = 1` rows present, row count ≈ distinct session count in dim_mql_mapping
- [ ] Weekly QA query against `soundstripe_prod` after prod build completes
