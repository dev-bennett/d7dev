# Enterprise Reporting Comparison — 2026-05-05

@../CLAUDE.md

## Status

Complete (2026-05-06). All 5 variances investigated, mechanisms identified, looker-only diff lists generated. Ryan owns PQL follow-up using the CSVs. Engineering follow-ups (variance 3 + variance 5 fixes) tracked in `etl/tasks/2026-05-06-enterprise-reporting-fixes/`.

## Purpose

Reconcile 5 Looker-vs-HubSpot variances flagged by Ryan Severns (RevOps) on 2026-05-05; meeting with Ryan + Dave Kart 2026-05-06.

## Scope

Same timeframe both sides per Ryan's framing:
- Variances 1–4 (PQL/MQL): YTD-2026 (Jan 1 – today)
- Variance 5 (Apr deals): April 2026 only

## Files

- `initial_request.md` — Ryan's Slack message + dashboard LookML + HubSpot filter blocks (source of truth for the request)
- `console.sql` — labeled q01–q14 queries reproducing both sides + gap decomposition
- `q##.csv` — query exports (one per labeled query)
- `findings.md` — meeting brief

## Conventions

- Each Looker reproduction (q01–q05) MUST match Ryan's quoted number to float precision.
- Each HubSpot reproduction (q06–q10) MUST match Ryan's quoted number within ±2% (Stitch lag tolerance).
- Outside those gates: SQL is wrong, not the variance. Diagnose, don't iterate blindly.
- Verbatim element names in `findings.md` (LookML measure paths, HubSpot property names, list IDs).
