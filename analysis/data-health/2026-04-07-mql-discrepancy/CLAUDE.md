# MQL Discrepancy Investigation

@../CLAUDE.md

## Purpose

Investigate divergence between HubSpot MQL volume (increasing) and Mixpanel-derived MQL volume via `fct_sessions` (decreasing). Divergence began ~6 completed ISO weeks ago (~week of 2026-02-24).

## Hypothesis

A tracking change on enterprise forms (possibly related to March 2026 domain consolidation and/or new form implementations) introduced events that don't match the current filtering logic in `fct_sessions_build.sql` (lines 67-74).

## Pipeline Under Investigation

```
pc_stitch_db.mixpanel.export (raw)
  -> fct_events (incremental, -1 day lookback)
    -> fct_sessions_build (incremental, -2 day lookback)
      -> fct_sessions_build_step2 (session consolidation)
        -> fct_sessions (view, final aggregation)
```

## Query Sets

- `initial_exploration/` -- Starting context queries (Looker-derived)
- `q1-divergence/` -- Weekly HubSpot vs Mixpanel MQL side-by-side
- `q2-raw-event-audit/` -- Raw Mixpanel event taxonomy over time
- `q3-pipeline-dropoff/` -- Event volume at each pipeline stage
- `q4-match-rate/` -- HubSpot-to-Mixpanel match rate over time
- `q5-url-patterns/` -- URL pattern analysis (domain consolidation impact)

## Table References

- `pc_stitch_db.mixpanel.export` -- Raw Mixpanel events (Stitch)
- `soundstripe_prod.core.fct_events` -- Cleaned/deduplicated events
- `soundstripe_prod.core.fct_sessions` -- Session-level aggregation with MQL flags
- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions (dbt view)
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts with `became_mql`

## MQL Columns in fct_sessions_build

- `enterprise_form_submissions`: `event = 'Submitted Form' AND lower(context) = 'enterprise contact form'`
- `enterprise_landing_form_submissions`: `event = 'MKT Submitted Enterprise Contact Form' AND url ILIKE '%enterprise%'`
- `enterprise_schedule_demo`: `event = 'Clicked Element' AND context = 'Enterprise Contact Form'`
