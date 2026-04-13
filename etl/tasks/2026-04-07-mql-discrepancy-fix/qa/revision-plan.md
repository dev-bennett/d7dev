# Revision Plan: Pricing Page Enterprise Intent

## Problem

Pricing page MQLs fire `Clicked Contact Sales` / `Enterprise Intent` on `www.soundstripe.com/library/pricing`. Neither fct_sessions_build nor dim_mql_mapping capture this event. These MQLs fall to tier 3 (false-positive-prone) or go unmatched.

## Root Cause (from Q6b)

- Mixpanel event: `Clicked Contact Sales` with context `Enterprise Intent` on `www.soundstripe.com/library/pricing`
- HubSpot records the form URL as `www.soundstripe.com/pricing` (no `/library/` prefix)
- Pipeline has no filter for this event name/context
- base_url join fails even if it did: `www.soundstripe.com/library/pricing` != `www.soundstripe.com/pricing`

## Changes Required

### 1. fct_sessions_build — line 74

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

Adding to `enterprise_schedule_demo` rather than a new column because both are enterprise intent click signals where the actual form submission happens off-page. Downstream metrics already use `enterprise_schedule_demo > 0`.

### 2. dim_mql_mapping — form_events_mixpanel CTE (line 112-123)

Add to the event filter:
```sql
-- New: Contact Sales click on pricing page (enterprise intent)
or (a.event = 'Clicked Contact Sales' and a.context = 'Enterprise Intent')
```

### 3. dim_mql_mapping — base_url normalization

The tier 1 join condition `h.base_url = m.base_url` fails for pricing because HubSpot records `/pricing` and Mixpanel records `/library/pricing`.

In `form_events_mixpanel` CTE, change the base_url derivation to normalize `/library/` out:
```sql
,replace(split_part(split_part(a.url, '?', 1), '//', 2), 'soundstripe.com/library/', 'soundstripe.com/') as base_url
```

This makes the Mixpanel side produce `www.soundstripe.com/pricing` to match HubSpot.

Check whether `/library/` prefix appears in other enterprise URLs before applying broadly. If it's pricing-only, scope the replace to avoid unintended side effects on other URL matches.

### 4. fct_sessions_build — add backfill_from var

While we're touching this model, add the `backfill_from` var to the incremental logic so future changes don't require full rebuilds:
```sql
{% if is_incremental() %}
    where event_ts::date >= (
        select dateadd('days', -2,
            coalesce(
                {% if var('backfill_from', false) %}
                    '{{ var("backfill_from") }}'::date
                {% else %}
                    max(session_started_at)
                {% endif %}
                , '1900-01-01')::date
        ) from {{ this }}
    )
{% endif %}
```

## Deployment

This can either be folded into the current PR (if not yet merged) or a follow-up.

- fct_sessions_build: requires backfill from 2026-02-23 (DELETE + incremental rebuild, or full refresh, or backfill_from var if added first)
- dim_mql_mapping: full refresh table, just rebuild
- dim_session_mqls: depends on dim_mql_mapping, rebuild after

## Unresolved

- Meetings MQLs with no Mixpanel signal: genuinely untrackable via direct link. Awaiting sales input on weekly volume estimate.
- Tier 3: once pricing fix is in, re-run Q4 to measure remaining tier-3-only exposure. If it drops to meetings-only, tier 3 may be removable or constrainable.
