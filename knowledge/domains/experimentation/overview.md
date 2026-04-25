# Experimentation Domain Overview

Last updated: 2026-04-20
Author: d7admin (revised by Devon Bennett 2026-04-20)

## Purpose

Controlled experimentation across the Soundstripe platform — A/B testing, multivariate testing, and SEO experiments. Measures causal impact of product, marketing, and content changes.

## Platform Architecture

**Statsig** is the experimentation platform.

| Component | Location | Purpose |
|-----------|----------|---------|
| Statsig proxy | `ab.soundstripe.com` → Fastly → Statsig | Client-side SDK communication |
| JS SDK | Loaded in HubSpot `<head>` (hubspot repo) and app | Assignment + exposure tracking |
| `statsig_stable_id` | Mixpanel event property | User-level experiment identifier |
| fct_events | `soundstripe_prod.core.fct_events` (line 69) | Stable ID flows into warehouse |
| Clickstream model | `_external_statsig.statsig_clickstream_events_etl_output` | Enriched events for Statsig consumption |

## Experiment Types

### User-Level (standard A/B tests)
- Randomization unit: user (via `statsig_stable_id`)
- Assignment: Statsig SDK at page load
- Metrics: conversion, engagement, revenue — keyed on stable_id
- Current state: **fully operational**

### Page-Level (SEO experiments)
- Randomization unit: page URL (deterministic hash of canonical URL)
- Assignment: template renderer or CDN edge function
- Metrics: organic impressions, position, sessions — keyed on `page_url`
- Current state: **not yet implemented** — requires `page_url` Custom Unit ID, variant serving layer, and organic metric pipeline

## Data Sources

- `soundstripe_prod.core.fct_events` — all Mixpanel events with `statsig_stable_id`
- `soundstripe_prod.core.fct_sessions` — session-level aggregations with conversion flags
- `soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output` — Statsig-facing enriched events
- Google Search Console — organic impressions, clicks, position (not yet integrated with Statsig)

## Known systemic issues

Two open structural findings affect every user-level experiment read through our current stack. Both were surfaced during the `wcpm_pricing_test` audit (2026-04-18 → 2026-04-20) and are repo-wide, not WCPM-specific.

| Finding | Effect | Doc |
|---|---|---|
| Statsig Enforced 1:1 identifier mapping + post-consolidation stable_id sprawl | ~13.5% of logged-in exposed user_ids dropped from Pulse; experiment power proportionately reduced | [`identifier-mapping-and-exclusions.md`](identifier-mapping-and-exclusions.md) |
| `statsig_clickstream_events_etl_output` incremental predicate | Late-arriving fct_events rows silently skipped; directionally undercounts any downstream metric | memory: `project_statsig_model_late_arrival_open.md`; `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` Finding 4 |

Both should be flagged to stakeholders consuming Statsig Pulse results until resolved.

## Related

- dbt models: `context/dbt/models/marts/_external_statsig/`
- dbt config: `dbt_project.yml` lines 29-31 (`_external_statsig` schema)
- Domain consolidation PRD: Statsig reconfiguration documented in Phase 3
- `identifier-mapping-and-exclusions.md` — 1:1 mapping mechanism, detection queries, and mitigation options
