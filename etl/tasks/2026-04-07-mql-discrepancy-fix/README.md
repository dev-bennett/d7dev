# MQL Discrepancy Pipeline Fix
- **Status:** complete (pending Devon verification 2026-05-08; will re-open if validation finds issues)
- **Date opened:** 2026-04-07
- **Date refreshed:** 2026-05-06
- **Date closed:** 2026-05-07
- **Base PR:** [SoundstripeEngineering/dbt-transformations#718](https://github.com/SoundstripeEngineering/dbt-transformations/pull/718) — merged 2026-04-22 (SHA `504f24d`)
- **Models touched (base scope, shipped):** fct_sessions_build, dim_mql_mapping, dim_session_mqls
- **Models touched (follow-up):** fct_sessions_build (`backfill_from` var), dim_mql_mapping (four coverage edits)
- **Source:** analysis/data-health/2026-04-07-mql-discrepancy/

## Open follow-up (2026-05-08, deferred to Monday 2026-05-11)

Dashboard tile alignment question on `mql_workflow_monitoring_dashboard.txt`: the "MQLs (Mixpanel) - Source" tile and the "MQL Forms (Hubspot) -> Workflow" tile's "Mixpanel Labeled MQL" series don't agree, and per the LookML they can't (the latter's `mql_flag` actually measures HubSpot's `became_mql`, not anything Mixpanel-side; plus grain + double-count issues). Three suggested actions (label rename, `dim_mql_mapping`-sourced source breakdown, or a Mixpanel-evidence boolean on contacts) documented in `dashboard-tile-alignment.md`. Pick one Monday.

## Closeout (2026-05-07)

Follow-up deployed and reverted-then-redeployed cleanly. Initial deployment of Change 1A (adding `Clicked Contact Sales` / `Enterprise Intent` to `enterprise_schedule_demo`) inflated the Looker `mqls_schedule_demo` measure 49× because that signal is high-volume AND the consuming Looker measure has no HubSpot anchoring. Reverted; signal correctly captured in `dim_mql_mapping.form_events_mixpanel` (Change 2B), where the join to HubSpot form submissions filters it down to real MQLs. Final state:

- `fct_sessions_build`: `backfill_from` var only (Change 1B); `enterprise_schedule_demo` at original definition.
- `dim_mql_mapping`: pricing/`/api` events in form_events_mixpanel, base_url normalization, tier-2 window 300s, expanded enterprise_url_patterns.
- `dim_session_mqls`: unchanged from #718, rebuilds from `dim_mql_mapping`.

## Context

HubSpot MQLs diverged from Mixpanel MQLs starting ~2026-02-23. Root cause: the `Enterprise v2 - Updated` HubSpot form was deployed to `/brand-solutions`, `/agency-solutions`, and `/enterprise` pages where Mixpanel fires `Submitted Form` with empty context (or `CTA Form Submitted`) instead of `Enterprise Contact Form`. Investigation also identified a pricing-page CTA path (`Clicked Contact Sales` / `Enterprise Intent` on `/library/pricing`) that fell through to tier 3 false positives, plus tier-2 timing-window misses on `/music-licensing-for-enterprise`.

## What's shipped (PR #718, 2026-04-22)

- **fct_sessions_build:** `enterprise_form_submissions` and `enterprise_form_view` expanded to capture `Submitted Form` on `/brand-solutions` + `/agency-solutions` and `CTA Form Submitted` on `/enterprise`.
- **dim_mql_mapping:** full v2 rewrite with three-tier matching (vid+time+url → time+url → session proximity). Adds `match_tier`, `match_reason`, `form_page_type`.
- **dim_session_mqls:** new session-level bridge table, joinable 1:1 to `fct_sessions` on `session_id`.
- **LinkedIn creative_id normalization** (incidental fix, also in #718).

Result: MQL coverage moved from ~69% tier 1/2 to a planned 91% post-follow-up. As of merge, the deployed pipeline still has ~31% in tier 3 (false-positive-prone) until the follow-up lands.

## What's pending (follow-up PR)

Coverage fixes documented in `qa/revision-plan.md` and `qa/coverage-summary.md`, deployment runbook in `implementation-guide.md`.

1. **fct_sessions_build:** add `backfill_from` var to incremental block
2. **dim_mql_mapping:** add pricing-page event + `/api` CTA event to `form_events_mixpanel` filter; normalize `/library/` out of base_url; widen tier 2 window 120s → 300s; add `/library/pricing` and `/api` to `enterprise_url_patterns`

> **Removed 2026-05-07:** an earlier proposed change (adding `Clicked Contact Sales` / `Enterprise Intent` to `fct_sessions_build.enterprise_schedule_demo`) was deployed and reverted. The signal is 49× higher volume than the existing one (1,997 events / 1,567 distinct_ids YTD-2026 vs. 36/32). Since `enterprise_schedule_demo` is the source for the Looker `mqls_schedule_demo` measure (which has no HubSpot anchoring), adding it inflated the Mixpanel-side MQL count past HubSpot and dominated the source-distribution chart. The signal IS captured in `dim_mql_mapping.form_events_mixpanel` (HubSpot-anchored — the only correct place for it).

## dbt Model Files (follow-up drafts in this directory)

- `dim_mql_mapping.sql` — full file with all four follow-up edits applied (drop-in replacement for the dbt-Cloud editor)
- `fct_sessions_build.sql` — full file with the `backfill_from` var edit only (Change 1A reverted 2026-05-07; drop-in replacement for the dbt-Cloud editor)
- `dim_session_mqls.sql` — unchanged from PR #718 (kept for reference)
- `fct_sessions_enriched.sql` — abandoned alternative architecture (header-annotated; not pursued)

## LookML Files (in `lookml/tasks/2026-04-07-mql-discrepancy-fix/`)

- `fct_sessions_view_changes.lkml` — changes to `fct_sessions.view.lkml` for joining `dim_session_mqls`. Status: was originally drafted alongside the base PR; verify against current LookML state before promoting.

## Architecture

```
fct_sessions_build (expanded event matching — base shipped + follow-up enterprise_schedule_demo)
  → fct_sessions (existing view)

dim_mql_mapping (tiered HubSpot-to-Mixpanel matching — v2 shipped + follow-up coverage fixes)
  → dim_session_mqls (session-level bridge — shipped)
```

`dim_session_mqls` joins 1:1 to `fct_sessions` on `session_id`. LookML joins the bridge into the existing `fct_sessions` explore.

## Deployment Workflow (follow-up)

dbt commands only update `soundstripe_dev`. Production updates via PR merge to `main`.

1. **Dev:** Apply the two follow-up file changes on `develop_dab` (in dbt Cloud web IDE), build + verify in `soundstripe_dev`
2. **Prod prep:** `DELETE FROM soundstripe_prod.TRANSFORMATIONS.fct_sessions_build WHERE session_started_at >= '2026-02-23'` (TRANSFORMER role) — only needed for the `enterprise_schedule_demo` reprocessing; `dim_mql_mapping` is full-refresh and `dim_session_mqls` rebuilds from it.
3. **PR:** Open follow-up PR `develop_dab` → `main` using `pr-description.md`
4. **Merge:** Once CI passes, merge — triggers production deployment
5. **QA:** Re-run `qa/q2-aligned-comparison.sql` and `qa/q4-tier3-exposure.sql` against `soundstripe_prod`. Expect tier-3-only exposure to drop from ~31% to ~9%.

See `implementation-guide.md` for the full step-by-step.
