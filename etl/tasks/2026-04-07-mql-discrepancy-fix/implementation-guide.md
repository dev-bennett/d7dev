# MQL Discrepancy Fix — Implementation Guide

## Completed

- fct_sessions_build: brand-solutions/agency-solutions/CTA Form Submitted event expansion — applied, full refresh running
- dim_mql_mapping: tiered matching rewrite — applied
- dim_session_mqls: new session bridge table — created
- QA round 1 (Q1–Q8): identified tier 3 false positives, pricing page gap, timing window gap, /api CTA gap

## Remaining Changes

Four changes to apply in dbt Cloud on `develop_dab` before opening the PR.

---

### Change 1: fct_sessions_build — pricing page enterprise intent + backfill var

**File:** `models/transformations/mixpanel/fct_sessions_build.sql`

**A. Replace line 74** (the `enterprise_schedule_demo` aggregation):

Current:
```sql
        ,sum(case when event = 'Clicked Element' and context = 'Enterprise Contact Form' then 1 else 0 end) as enterprise_schedule_demo
```

Replace with:
```sql
        ,sum(case when (event = 'Clicked Element' and context = 'Enterprise Contact Form')
                      or (event = 'Clicked Contact Sales' and context = 'Enterprise Intent')
                 then 1 else 0 end) as enterprise_schedule_demo
```

**B. Add `backfill_from` var to incremental logic** (line 17–20):

Current:
```sql
    {% if is_incremental() %}
        where 
            event_ts::date >= (select dateadd('days', -2, coalesce(max(session_started_at), '1900-01-01')::date) from {{ this }} )
    {% endif %}
```

Replace with:
```sql
    {% if is_incremental() %}
        where
            event_ts::date >= (select dateadd('days', -2,
                coalesce(
                    {% if var('backfill_from', false) %}
                        '{{ var("backfill_from") }}'::date
                    {% else %}
                        max(session_started_at)
                    {% endif %}
                    , '1900-01-01')::date
                ) from {{ this }} )
    {% endif %}
```

---

### Change 2: dim_mql_mapping — pricing event, URL normalization, wider tier 2, /api CTA

**File:** `models/marts/marketing/dim_mql_mapping.sql`

**A. Add events to `form_events_mixpanel` CTE** (after line 122):

Add these two lines to the event filter:
```sql
                -- New: Contact Sales click on pricing page (enterprise intent)
                or (a.event = 'Clicked Contact Sales' and a.context = 'Enterprise Intent')
                -- New: CTA Form Submitted on API page
                or (a.event = 'CTA Form Submitted' and a.url ilike '%/api%')
```

**B. Normalize `/library/` in base_url derivation** in `form_events_mixpanel` CTE (line 99):

Current:
```sql
            ,split_part(split_part(a.url, '?', 1), '//', 2) as base_url
```

Replace with:
```sql
            ,replace(split_part(split_part(a.url, '?', 1), '//', 2), 'soundstripe.com/library/', 'soundstripe.com/') as base_url
```

**C. Widen tier 2 time window from 120s to 300s** in `tier2_page_activity` CTE:

Current (line 200):
```sql
                on abs(datediff('seconds', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 120
```

Replace with:
```sql
                on abs(datediff('seconds', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
```

---

### Change 3: Update dim_mql_mapping enterprise_url_patterns

Add `/api` and `/library/pricing` to the Jinja variable at the top of the file (line 44–49) so tier 3 also covers these pages:

```sql
{% set enterprise_url_patterns = [
    '%/music-licensing-for-enterprise%',
    '%/brand-solutions%',
    '%/agency-solutions%',
    '%/enterprise%',
    '%/library/pricing%',
    '%/api%'
] %}
```

---

## Deployment Steps

**dbt commands only update `soundstripe_dev`. Production updates via PR merge to `main`.**

### 1. Apply changes 1–3 in dbt Cloud on `develop_dab`

### 2. Build in dev to verify
```
dbt run --select fct_sessions_build --vars '{"backfill_from": "2026-02-23"}'
dbt run --select dim_mql_mapping dim_session_mqls --full-refresh
```
Spot-check in `soundstripe_dev`:
- `enterprise_schedule_demo > 0` for sessions on `/library/pricing` with `Clicked Contact Sales`
- dim_mql_mapping: tier-3-only count should drop significantly vs current prod
- dim_session_mqls: `bridged_distinct_ids` should be closer to `bridged_emails`

### 3. Commit all changes on `develop_dab`

### 4. Delete affected rows from prod (TRANSFORMER role)
```sql
USE ROLE TRANSFORMER;

DELETE FROM soundstripe_prod.TRANSFORMATIONS.fct_sessions_build
WHERE session_started_at >= '2026-02-23';
```

No action needed for dim_mql_mapping (full refresh) or dim_session_mqls (rebuild).

### 5. Open PR from `develop_dab` → `main`
- Use `etl/tasks/2026-04-07-mql-discrepancy-fix/pr-description.md` (update to reflect all fixes)
- CI runs automatic build/run + downstream
- Wait for CI to pass

### 6. Merge PR
Triggers production deployment. `fct_sessions_build` reprocesses from new `max(session_started_at)` forward.

### 7. QA against `soundstripe_prod` (only after prod build completes)
Re-run `qa/q2-aligned-comparison.sql` and `qa/q4-tier3-exposure.sql`.

**Expected results:**
- `bridged_emails` ≈ `hs_all_forms` (aligned, no overcounting)
- `bridged_distinct_ids` ≈ `bridged_emails` (tier 3 false positives eliminated)
- Tier-3-only exposure drops to ~9% (untrackable: meetings direct links + ad-blocked sessions)
- Tier 1/2 covers ~91% of MQLs

See `qa/coverage-summary.md` for full breakdown.
