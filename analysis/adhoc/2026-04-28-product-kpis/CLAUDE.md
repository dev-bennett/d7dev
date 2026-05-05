# Product KPIs 24-Month Trend Review — 2026-04-28

@../CLAUDE.md

First-principles exploratory review of all 14 tiles on Looker Dashboard 19 (Product KPIs) at monthly grain over the trailing 24 months (2024-05 → 2026-04). Stakeholder: Meredith Knott (Product). Analyst: Devon Bennett.

## Why this task exists

Several tiles likely show visibly declining trends in the trailing months. The leading hypothesis from prior work is that most per-session rate declines are mechanical consequences of the March 2026 domain consolidation (session denominator inflated by ~160K artifact Direct sessions over the Mar 5–25 window) plus a real mix shift toward lower-intent organic traffic post-cutover (per `analysis/data-health/2026-04-27-domain-consolidation-non-customer/findings_non_current_customer.md` — NC Organic subscriptions/day +19% even as session-CVR fell 23–26%).

The deliverable distinguishes **measurement artifact** vs **real mix-shift signal** vs **real product/business signal** at the per-KPI level so Meredith can read the dashboard correctly going forward.

## Scope

- **In scope:** 14 existing tiles on Dashboard 19 (the `product_kpis.lkml` export at the workspace root is the canonical tile list)
- **Cross-reference only:** Tiles 15–16 pending in `lookml/tasks/2026-04-25-product-kpis-ltv-cohort/`
- **Time grain:** Monthly, 24 months (2024-05 → 2026-04). Distinct from dashboard defaults (week / 12mo)
- **Lead with declines:** triage which KPIs visibly move in the trailing 3 months; deep-dive those, sweep the rest
- **Out of scope:** modifying the dashboard itself (recommendations only); Statsig experimentation deep-dive; root-causing the data-quality issues themselves (those are tracked in their own open project memories)

## Conventions

- All diagnostic queries → `console.sql` with q## block headers per `feedback_one_sql_file_per_query_set`
- Findings → `findings.md` (single doc with per-KPI verdict table + per-declining-KPI deep-dive sections + follow-up mini-analysis roadmap)
- Tabular outputs → `tables/` (one CSV per in-scope KPI + `kpi_summary.csv` wide format + `regime_windows.csv` for overlay shading). Charts are produced downstream by the analyst in their tool of choice from these tables — the in-house PNG generator was deleted as unsatisfactory.
- Table generation → `scripts/tables.py`
- Data-quality contract: every per-session KPI verdict cites the magnitude of artifact-session inflation in its source query, not the project memory entry

## Cross-references

- Dashboard export: `product_kpis.lkml` (this directory; LookML source of truth for tile definitions)
- Calibration: `knowledge/data-dictionary/calibration/core__fct_sessions.md`, `core__fct_sessions_attribution.md`, `core__dim_daily_kpis.md`, `core__fct_events.md`
- Prior NC-traffic findings: `analysis/data-health/2026-04-27-domain-consolidation-non-customer/findings_non_current_customer.md`
- Prior Meredith deliverable (tone/structure reference): `analysis/experimentation/2026-04-23-pricing-page-scroll-depth/`
- Pending LTV cohort tiles: `lookml/tasks/2026-04-25-product-kpis-ltv-cohort/`
- Open data-quality issues: `project_domain_consolidation`, `project_page_category_classifier_broken_open`, `project_mixpanel_autocapture_collapse_open`, `project_direct_traffic_spike_2026_04_17_open`, `project_statsig_model_late_arrival_open`, `project_wcpm_1to1_mapping_exclusion`
