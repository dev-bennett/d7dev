# Diagnose — Discovery queries

@../CLAUDE.md

Phase 1 (§7 investigatory workflow) event-schema and baseline-shape queries before writing the main console.sql funnel reconstruction.

## File

- `discovery.sql` — single file, labeled single-SELECT sections (D1–D5) per `feedback_one_sql_file_per_query_set`. Each section is highlight-and-run in Snowflake. Exports go to this directory as `d<N>.csv`.

## Scope

- D1: Distinct `event` values on `fct_events` where `page_category = 'pricing'` during the pre-change baseline (Jan 7 – Feb 6 2026). Settles which event names power "View Pricing" and "Selected Persona".
- D2: Scroll-depth instrumentation — probes `information_schema` for scroll-related columns on the raw Mixpanel source, then probes event names containing "scroll" across the baseline window. Necessary because `fct_events` filters out `$mp_page_leave`, `$mp_session_record`, `$mp_dead_click` (see `context/dbt/models/marts/core/fct_events.sql` line 90), where scroll data commonly lives.
- D3: `Clicked Pricing Product` property shape — confirms `plan_id` / `plan_name` cardinality for the plan-level funnel step.
- D4: Sign Up / Sign In event enumeration on the `signup` / `sign in` page categories.
- D5: Daily pricing-page visitor counts Jan 1 – Apr 23 — sizes baseline, locates contamination windows empirically.

## Schema references

- `soundstripe_prod.core.fct_events` — channel + page_category-enriched events (drops $mp_page_leave family)
- `pc_stitch_db.mixpanel.export` — raw Mixpanel source, used when fct_events' column filter drops needed properties
- `pc_stitch_db.information_schema.columns` — column discovery on raw source

## GATE

If D1 does not yield event names suitable for the "Clicked View Pricing" and "Selected Persona" funnel steps, AND D2 does not yield a scroll-depth property on a retained event, the 5-step funnel is not reconstructible end-to-end. Escalate to Meredith + product team with specifically what's missing before the main build. Do not fabricate event names or infer from similar-looking ones.
