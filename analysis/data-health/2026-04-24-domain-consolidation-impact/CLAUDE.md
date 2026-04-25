# Domain Consolidation Impact Analysis — 2026-04-24

@../CLAUDE.md

Impact analysis of the 2026-03-16 domain consolidation cutover (app.soundstripe.com merged under www.soundstripe.com / soundstripe.com via Fastly). Stakeholder: Meredith Knott (Asana ticket 1213715723297289, gid project Epics-Data, In Progress, due 2026-04-10, follow-up nudge 2026-04-21).

## PRD Success Criteria — verbatim quotes

From `analysis/data-health/2026-04-01-direct-traffic-spike/domain_consolidation_prd.pdf` page 3 (Success Criteria) and page 10 (Implementation Plan alignment, Updated Feb 10):

- "**No loss of SEO traffic after migration (±5%)**" — short-term success criterion, evaluable now
- "**20% overall increase in traffic from organic search (3-6 months post-launch)**" — long-term goal, NOT yet evaluable at 5.5 weeks
- "≥ 95% continuity in user/session tracking across tools"
- "No increase in login or checkout drop-off post-launch"
- "Zero P0 incidents related to auth, billing, or content access"

The Asana task body's "estimated 20% improvement" language maps to the LONG-TERM goal, not the short-term criterion. Read-out frames the +20% as a 3-6 month leading-indicator watermark, not a verdict.

## Scope (per user decision)

Traffic + acquisition. Specifically:
- Primary: weekly organic-search sessions (`last_channel_non_direct = 'Organic Search'` in fct_sessions)
- Primary: host-consolidated total sessions (pre = www + app combined; post = soundstripe.com)
- Secondary: branded/non-branded organic split, organic landing-path Herfindahl, bounce/duration with saturation check
- Acquisition: weekly organic-driven new subscriptions from `dim_daily_kpis.organic_search_subscriptions`
- Out of scope: revenue/MRR (subscription cohort lag too short for the post-window)

## Comparison frame

| Window | Dates | Treatment |
|---|---|---|
| Pre-period (long) | 2025-10-01 → 2026-03-04 | ~22 weeks for trend + seasonality |
| Pre-period (recency) | 2026-01-19 → 2026-03-04 | 6 weeks matched-recency baseline |
| Contamination zone 1 | 2026-03-05 → 2026-03-25 | Hard-exclude from headline; document signature |
| Stabilization buffer | 2026-03-26 → 2026-04-08 | Trend included; not in headline |
| Post-period (clean primary) | 2026-03-26 → 2026-04-13 | 3 weeks; primary post-window for headline delta |
| Contamination zone 2 | 2026-04-14 → 2026-04-17 | Apply two-mechanism filter; validate before retain |
| Post-period tail | 2026-04-18 → 2026-04-24 | Clean tail check |
| YoY anchor | 2025-03-26 → 2025-04-13 | Seasonal control |

## Conventions

- Diagnostic queries: `console.sql` (q1–q15 labels)
- Findings: `findings.md` (signal-detection template)
- Asana-pasteable read-out: `asana-ticket.md` (platform-safe)
- Charts (max 2): `charts/` (matplotlib, weekly time series with shaded contamination zones + YoY overlay; per-channel composition stack)
- CSVs: q14 summary roll-up, q9 04-17 substantiation, q11 acquisition

## Calibration prerequisites (DONE)

- `core.fct_sessions` — calibrated 2026-04-24 (`knowledge/data-dictionary/calibration/core__fct_sessions.md`)
- `core.dim_daily_kpis` — calibrated 2026-04-24 (`knowledge/data-dictionary/calibration/core__dim_daily_kpis.md`)
- `core.fct_sessions_attribution` — calibrated 2026-04-24 (`knowledge/data-dictionary/calibration/core__fct_sessions_attribution.md`)

## Cross-references

- Plan: `/Users/dev/.claude/plans/expressive-nibbling-rabin.md`
- Prior investigation: `analysis/data-health/2026-04-01-direct-traffic-spike/` (engineer-confirmed contamination root cause)
- Open OOZ: `analysis/data-health/2026-04-17-direct-traffic-spike/` (second spike, hypothesis pending engineering)
- Format precedent: `analysis/experimentation/2026-04-18-wcpm-test-audit/asana-ticket.md`
- Memory: `project_domain_consolidation`, `project_direct_traffic_spike_2026_04_17_open`, `project_page_category_classifier_broken_open`

## Status

- 2026-04-24 — calibration complete; query build in progress.
