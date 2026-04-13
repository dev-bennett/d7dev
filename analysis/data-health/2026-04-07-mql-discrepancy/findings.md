# MQL Discrepancy: Findings & Remediation

## Summary

Mixpanel-derived MQL volume dropped from ~34-42/week to ~15-18/week starting the week of 2026-02-23, while HubSpot MQLs increased from ~32-40/week to ~50-56/week over the same period. The gap reached 71% by week of 03-30 (56 HubSpot vs 16 Mixpanel).

**100% of the gap is recoverable.** Every HubSpot MQL can be matched to a Mixpanel session through a combination of form event matching, page view matching, and session proximity matching.

## Root Cause

The `Enterprise v2 - Updated` HubSpot form was deployed to new marketing landing pages (`/brand-solutions`, `/agency-solutions`) in addition to its original location (`/music-licensing-for-enterprise`). The Mixpanel events fire correctly on all pages, but with different context values that the pipeline doesn't match.

### The Event Taxonomy

| Page | Mixpanel Event | Context | Pipeline Status |
|---|---|---|---|
| `/music-licensing-for-enterprise` | `Submitted Form` | `Enterprise Contact Form` | CAPTURED |
| `/brand-solutions` | `Submitted Form` | `""` (empty) | NOT CAPTURED |
| `/agency-solutions` | `Submitted Form` | `""` (empty) | NOT CAPTURED |
| `/enterprise` | `CTA Form Submitted` | `Landing Page Hero` / `Full Width CTA` | NOT CAPTURED |

The pipeline in `fct_sessions_build.sql` (line 67) only matches `lower(context) = 'enterprise contact form'`, so submissions from `/brand-solutions` and `/agency-solutions` are invisible.

### Evidence — Tiered Recovery (Q6 + Q7)

For 56 distinct HubSpot MQL contacts in week 03-30, matching to the raw Mixpanel export via three progressively broader strategies:

| Tier | Strategy | Window | Matched | % |
|---|---|---|---|---|
| 1 — Form event | `Submitted Form` or `CTA Form Submitted` on same URL | ±120s | 35 | 63% |
| 2 — Page view | Any Mixpanel event on the same enterprise URL | ±120s | 16 | 29% |
| 3 — Session proximity | Device visited an enterprise-related URL | ±30 min | 5 | 9% |
| **Total** | | | **56** | **100%** |

- **Tier 1** users have a direct form submission event in Mixpanel under an anonymous `$device:UUID` distinct_id, matchable by timestamp + URL (0-1 seconds apart). These include submissions on `/brand-solutions` (17), `/music-licensing-for-enterprise` (14), `/agency-solutions` (3), and `/enterprise` (2).
- **Tier 2** users have Mixpanel page views on the enterprise URL but the form submission event didn't fire (HubSpot form handling bypassed the Mixpanel callback). The page view gives us the anonymous session with UTM data.
- **Tier 3** users have a Mixpanel device that visited an enterprise-related page within ±30 min of the HubSpot submission. Wider window but the device was demonstrably on the relevant page.

Each tier provides the anonymous `distinct_id` → `session_id` → UTM/channel data from `fct_sessions`.

### Identity Resolution via dim_mql_mapping

The existing `dim_mql_mapping` model's two-tier matching already works for `/music-licensing-for-enterprise` events:
- **Primary (VID + time + URL)**: 9 matches — users with Soundstripe accounts whose identity chain resolves
- **Secondary (time + URL only)**: 10 additional matches — anonymous marketing-site sessions matched purely by timestamp + URL proximity

The secondary match fails for `/brand-solutions` and `/agency-solutions` because the `form_submissions_mixpanel` CTE filters events to only enterprise-context patterns. Expanding the event filter and adding page-view and session-proximity tiers closes the gap entirely.

### HubSpot MQL Growth

The HubSpot increase from ~32 to ~56 MQLs/week is real — driven by the `Enterprise v2 - Updated` form being placed on new marketing pages with paid search traffic (`brand-solutions` users arrive via Google PPC campaigns for "music for commercial use" and "audio licensing").

## Remediation

Three fixes, each building on the previous:

### Fix 1: Expand `fct_sessions_build` Event Matching

**Impact: increases fct_sessions MQL flags from ~16 to ~38 distinct_ids/week (tier 1 form events only)**

Current logic (line 67):
```sql
,sum(case when event = 'Submitted Form' and lower(context) = 'enterprise contact form'
    then 1 else 0 end) as enterprise_form_submissions
```

Proposed expansion — match by event + URL path rather than context alone:
```sql
,sum(case when (event = 'Submitted Form' and lower(context) = 'enterprise contact form')
              or (event = 'Submitted Form' and url ilike '%/brand-solutions%')
              or (event = 'Submitted Form' and url ilike '%/agency-solutions%')
              or (event = 'CTA Form Submitted' and url ilike '%/enterprise%')
         then 1 else 0 end) as enterprise_form_submissions
```

Apply to: `fct_sessions_build.sql`, `dim_mql_mapping.sql` (form_submissions_mixpanel CTE).

Backfill: `dbt run --select fct_sessions_build --vars '{"backfill_from": "2026-02-23"}'`

This fix captures tier 1 users only. The remaining 18 (tier 2 + tier 3) require the tiered matching in Fix 2.

### Fix 2: Rewrite `dim_mql_mapping` with Tiered Matching

**Impact: achieves 100% HubSpot-to-Mixpanel-session attribution (~56 distinct_ids/week)**

The current `dim_mql_mapping` uses a two-pass match (VID+time+URL, then time+URL at <10s). The rewrite adds three tiers:

| Tier | Strategy | Window | Coverage |
|---|---|---|---|
| 1 | Form event on same URL (VID or time+URL) | ±120s | 63% |
| 2 | Page view on same URL (form event didn't fire) | ±120s | 29% |
| 3 | Device on enterprise-related URL (session proximity) | ±30 min | 9% |

The rewritten model includes:
- Expanded event filter (same as Fix 1) in the tier 1 form event CTE
- Tier 2: matches on page views (`$mp_web_page_view`, `Viewed Page`, etc.) when no form event exists
- Tier 3: widens to ±30 min for devices that visited any enterprise-related URL
- `match_tier` and `match_reason` columns on every output row
- `form_page_type` classification by URL path (replaces host-based type)
- Jinja variable `enterprise_url_patterns` for maintainability as new pages are added

Draft: `etl/tasks/2026-04-07-mql-discrepancy-fix/dim_mql_mapping.sql`

Backfill: This model is materialized as a `table` with `full_refresh`, so a standard `dbt run --select dim_mql_mapping` rebuilds it completely.

### Fix 3: `fct_sessions_enriched` — Single Source of Truth

**Impact: one table in Snowflake with 100% reconciled MQLs for both ad-hoc analysis and Looker reporting**

**New dbt model: `dim_session_mqls`** (intermediate bridge)
- Aggregates `dim_mql_mapping` to one row per `session_id`
- Columns: `has_mql`, page-type flags, `mql_form_submissions`, `mql_distinct_contacts`, `best_match_tier`, timestamps

**New dbt model: `fct_sessions_enriched`** (view, single source of truth)
- LEFT JOINs `fct_sessions` to `dim_session_mqls` on `session_id`
- All original `fct_sessions` columns preserved
- `enterprise_form_submissions` overridden with HubSpot-sourced reconciled count
- Original Mixpanel-only count preserved as `enterprise_form_submissions_mixpanel` for audit
- New columns: `has_mql`, `has_enterprise_landing_mql`, `has_brand_solutions_mql`, `has_agency_solutions_mql`, `has_enterprise_page_mql`, `mql_match_tier`, `mql_distinct_contacts`, `first_mql_submission_ts`, `last_mql_submission_ts`

**Architecture:**
```
fct_sessions (existing)  ──┐
                           ├──▶  fct_sessions_enriched (single source of truth)
dim_mql_mapping (Fix 2)    │
  → dim_session_mqls ──────┘
```

**Snowflake:** `soundstripe_prod.CORE.FCT_SESSIONS_ENRICHED` — query directly for ad-hoc analysis with all session attributes + reconciled MQL data.

**LookML migration:**
- Change `sql_table_name` in `fct_sessions.view.lkml` from `FCT_SESSIONS` to `FCT_SESSIONS_ENRICHED`
- Add reconciled MQL dimensions and measures under `group_label: "MQL (Reconciled)"`
- `mqls_reconciled`: `COUNT(DISTINCT CASE WHEN has_mql THEN distinct_id END)` — source of truth
- Breakdown measures: `mqls_enterprise_landing`, `mqls_brand_solutions`, `mqls_agency_solutions`
- Hide or relabel old Mixpanel-only MQL measures
- No explore join changes — same table, same primary key

### Why All Three Fixes Are Needed

| Fix | What it captures | Surface |
|---|---|---|
| Fix 1 alone | ~38 MQLs/week (tier 1 form events) | fct_sessions flags — improves but partial |
| Fix 1 + Fix 2 | 56 MQLs/week (100%) | dim_mql_mapping only |
| Fix 1 + Fix 2 + Fix 3 | 56 MQLs/week (100%) | `fct_sessions_enriched` — single table for Snowflake + Looker |

### Downstream Model Considerations

These models consume `fct_sessions` MQL flags and benefit from Fix 1 automatically (no code changes needed):
- `dim_enterprise_leads` — uses `enterprise_form_submissions + enterprise_landing_form_submissions + enterprise_schedule_demo`
- `user_session_funnel` — same aggregation
- `dim_daily_kpis` — same aggregation

Fix 1 increases their MQL counts from ~16 to ~38/week. For the full 56, they would need to reference `fct_sessions_enriched` instead of `fct_sessions` — a separate follow-up task.

## Deployment Order

1. Deploy `fct_sessions_build` change + backfill from 2026-02-23
2. Deploy `dim_mql_mapping` rewrite (full refresh table)
3. Deploy `dim_session_mqls` (depends on dim_mql_mapping)
4. Deploy `fct_sessions_enriched` (view, depends on fct_sessions + dim_session_mqls)
5. Update LookML: change `sql_table_name` to `FCT_SESSIONS_ENRICHED`, add reconciled measures
6. Validate `mqls_reconciled` in Looker against HubSpot baseline
7. Swap dashboard elements from old `mqls` to `mqls_reconciled`
8. Hide old Mixpanel-only MQL measures

## Timeline

| Date | Event |
|---|---|
| ~2026-02-23 | `Enterprise v2 - Updated` form deployed to `/brand-solutions` and `/agency-solutions` |
| 2026-03-03 | Geoff deployed `lower()` fix and `$mp_web_page_view` URL matching |
| 2026-03-11 | Geoff updated `dim_mql_mapping` and `dim_enterprise_leads` |
| Mid-March | Domain consolidation (www+app → soundstripe.com via Fastly) went live |
| 2026-03-30 | Gap reached 71% (56 HubSpot vs 16 Mixpanel) |

## Data Sources

All queries and results in subdirectories:
- `q1-divergence/` — Weekly HubSpot vs Mixpanel side-by-side
- `q2-raw-event-audit/` — Raw Mixpanel event taxonomy, event pair comparison, host distribution
- `q3-uncaptured-events/` — URL inspection of empty-context and CTA Form Submitted events
- `q4-gap-reconciliation/` — HubSpot form name breakdown, fct_events → fct_sessions drop-off
- `q5-user-level-trace/` — User-level identity resolution and clickstream traces
- `q6-raw-event-reconciliation/` — Raw event matching by timestamp+URL, dim_mql_mapping audit
- `q7-close-the-gap/` — Tiered recovery funnel (100% match), email property check

## Model Drafts

**dbt models** (`etl/tasks/2026-04-07-mql-discrepancy-fix/`):
- `fct_sessions_build.sql` — expanded event matching (lines 67-74 replacement)
- `dim_mql_mapping.sql` — tiered HubSpot-to-Mixpanel matching (full rewrite)
- `dim_session_mqls.sql` — session-level MQL bridge (NEW)
- `fct_sessions_enriched.sql` — single source of truth view (NEW)

**LookML** (`lookml/tasks/2026-04-07-mql-discrepancy-fix/`):
- `fct_sessions_view_changes.lkml` — documented changes to fct_sessions.view.lkml (sql_table_name, new measures, hide old)
