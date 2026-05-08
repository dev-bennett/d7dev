# MQL Discrepancy Fix — Implementation Guide (Follow-up)

**Status:** Base scope shipped in [#718](https://github.com/SoundstripeEngineering/dbt-transformations/pull/718) merged 2026-04-22 (SHA `504f24d`). This is the follow-up runbook for the coverage fixes verified still missing from `origin/main` HEAD on 2026-05-06.

> **2026-05-07 update — Change 1A reverted.** A first deployment attempt showed Change 1A (adding `Clicked Contact Sales` / `Enterprise Intent` to `enterprise_schedule_demo`) inflating the Looker `mqls_schedule_demo` measure by ~49× — that event is 1,997 events / 1,567 distinct_ids YTD-2026 vs. 36/32 for the original signal. The signal correctly belongs in `dim_mql_mapping.form_events_mixpanel` (HubSpot-anchored — Change 2B) but NOT in `fct_sessions_build` (feeds a Looker measure with no HubSpot anchoring). Change 1A is removed; the only remaining fct_sessions_build edit is Change 1B (`backfill_from` var).

**Branch:** `develop_dab` → `main`

**Files to edit on `develop_dab`:**
- `models/marts/marketing/dim_mql_mapping.sql` — four edits (events, base_url, tier-2 window, url patterns)
- `models/transformations/mixpanel/fct_sessions_build.sql` — one edit (backfill_from var)

**No edits needed:**
- `models/marts/marketing/dim_session_mqls.sql` — already in production from #718, picks up `dim_mql_mapping` changes automatically on rebuild.

---

## Change 1 — `fct_sessions_build.sql`

The full post-fix file is checked in at `etl/tasks/2026-04-07-mql-discrepancy-fix/fct_sessions_build.sql` — drop-in replacement for the dbt-Cloud editor.

If editing inline instead, the two edits are:

### 1A. ~~Replace the `enterprise_schedule_demo` aggregation~~ — **REMOVED 2026-05-07**

**Do not apply.** The original revision plan proposed adding `Clicked Contact Sales` / `Enterprise Intent` to this aggregation. A 2026-05-07 deployment surfaced that this signal is 49× higher volume than the existing one (1,997 events / 1,567 distinct_ids YTD-2026 vs. 36/32). Since `enterprise_schedule_demo` is the source for the Looker `mqls_schedule_demo` measure (`fct_sessions.view.lkml:493`), and that measure has no HubSpot anchoring, adding the high-volume signal here inflates Mixpanel-side MQL counts past HubSpot and dominates the source-distribution chart.

The signal is correctly captured in `dim_mql_mapping.form_events_mixpanel` (Change 2B), where it's HubSpot-anchored and only fires when matched to a real form submission. Leave `enterprise_schedule_demo` at its original definition.

### 1B. Add `backfill_from` var to the incremental block (~lines 17-20)

Pattern matches `models/marts/core/fct_events.sql` (line 112-118): branch the entire WHERE clause. **Do not** try to coalesce a literal into the aggregate subquery — `select <literal> from {{ this }}` returns N rows (one per existing row) and dbt errors with "Single-row subquery returns more than one row."

**Before:**
```sql
    {% if is_incremental() %}
        where 
            event_ts::date >= (select dateadd('days', -2, coalesce(max(session_started_at), '1900-01-01')::date) from {{ this }} )
    {% endif %}
```

**After:**
```sql
    {% if is_incremental() %}
        {% if var('backfill_from', none) is not none %}
            where
                event_ts::date >= '{{ var("backfill_from") }}'::date
        {% else %}
            where
                event_ts::date >= (select dateadd('days', -2, coalesce(max(session_started_at), '1900-01-01')::date) from {{ this }} )
        {% endif %}
    {% endif %}
```

---

## Change 2 — `dim_mql_mapping.sql`

The full post-fix file is checked in at `etl/tasks/2026-04-07-mql-discrepancy-fix/dim_mql_mapping.sql` — drop-in replacement for the dbt-Cloud editor.

If editing inline instead, the four edits are:

### 2A. Extend `enterprise_url_patterns` (top of file, ~line 44)

**Before:**
```sql
{% set enterprise_url_patterns = [
    '%/music-licensing-for-enterprise%',
    '%/brand-solutions%',
    '%/agency-solutions%',
    '%/enterprise%'
] %}
```

**After:**
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

### 2B. Add events to `form_events_mixpanel` filter (~end of CTE, after line 122)

Add inside the existing `where ... and ( ... )` block:

```sql
                -- FOLLOW-UP: Contact Sales click on pricing page (enterprise intent)
                or (a.event = 'Clicked Contact Sales' and a.context = 'Enterprise Intent')
                -- FOLLOW-UP: CTA Form Submitted on /api page
                or (a.event = 'CTA Form Submitted' and a.url ilike '%/api%')
```

### 2C. Normalize `/library/` in `base_url` derivation (~line 99 in `form_events_mixpanel` CTE)

**Before:**
```sql
            ,split_part(split_part(a.url, '?', 1), '//', 2) as base_url
```

**After:**
```sql
            ,replace(split_part(split_part(a.url, '?', 1), '//', 2), 'soundstripe.com/library/', 'soundstripe.com/') as base_url
```

### 2D. Widen tier 2 window 120s → 300s (~line 200 in `tier2_page_activity` CTE)

**Before:**
```sql
                on abs(datediff('seconds', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 120
```

**After:**
```sql
                on abs(datediff('seconds', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
```

---

## Deployment Steps

dbt commands only update `soundstripe_dev`. Production updates via PR merge to `main`.

### 1. Apply changes 1 and 2 in dbt Cloud on `develop_dab`

Use the workspace drafts as the source of truth — both are full post-fix files, drop-in replacements for the dbt-Cloud editor:
- `etl/tasks/2026-04-07-mql-discrepancy-fix/fct_sessions_build.sql`
- `etl/tasks/2026-04-07-mql-discrepancy-fix/dim_mql_mapping.sql`

### 2. Build in dev to verify

```
dbt run --select fct_sessions_build --vars '{"backfill_from": "2026-02-23"}'
dbt run --select dim_mql_mapping dim_session_mqls --full-refresh
```

Spot-check in `soundstripe_dev`:
- `enterprise_schedule_demo > 0` for sessions on `/library/pricing` with `Clicked Contact Sales` events
- `dim_mql_mapping`: `match_tier` distribution shifts toward tier 1 for previously tier-3-only `enterprise_landing` cases
- `dim_session_mqls`: `bridged_distinct_ids` ≈ `bridged_emails`

### 3. Commit on `develop_dab`

Use `etl/tasks/2026-04-07-mql-discrepancy-fix/commit-message.txt` for the message.

### 4. Delete affected rows from prod (TRANSFORMER role)

```sql
USE ROLE TRANSFORMER;

DELETE FROM soundstripe_prod.TRANSFORMATIONS.fct_sessions_build
WHERE session_started_at >= '2026-02-23';
```

This shifts the incremental watermark so the prod build reprocesses with the new `enterprise_schedule_demo` definition. `dim_mql_mapping` is `materialized='table'` so no prep needed; `dim_session_mqls` rebuilds from it automatically.

### 5. Open PR `develop_dab` → `main`

Use `etl/tasks/2026-04-07-mql-discrepancy-fix/pr-description.md` as the body. CI runs automatic build/run + downstream — wait for CI to pass.

### 6. Merge

Triggers production deployment. `fct_sessions_build` reprocesses from 2026-02-23 forward; `dim_mql_mapping` and `dim_session_mqls` rebuild full-refresh.

### 7. QA against `soundstripe_prod`

Re-run after prod build completes:
- `qa/q2-aligned-comparison.sql` — expect `bridged_emails` ≈ `hs_all_forms`, `bridged_distinct_ids` ≈ `bridged_emails`
- `qa/q4-tier3-exposure.sql` — expect tier-3-only exposure to drop from ~31% to ~9%

**Expected end state:**
- Tier 1/2 covers ~91% of MQLs
- Tier 3 covers 0% (untrackable population is no longer reached by tier 3 because `enterprise_url_patterns` matches but no events exist for those users)
- ~9% genuinely untrackable: meetings-only direct links + ad-blocked sessions

See `qa/coverage-summary.md` for the full breakdown.
