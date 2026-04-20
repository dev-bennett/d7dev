# WCPM Pricing Test Audit — 2026-04-18

@../CLAUDE.md

Audit of Mixpanel vs. Statsig discrepancy on add-on purchases in the `wcpm_pricing_test` experiment. Inquiry from Meredith.

## Inputs
- `inquiry.md` — Meredith's request + links to Mixpanel report and Statsig console
- `Untitled Report_Insights_2026-03-13_to_2026-04-18.csv` — Mixpanel pulse export
- `wcpm_pricing_test-pulse_export-2026-04-18 (1).csv` — Statsig pulse export
- `console.sql` — working SQL file (empty at task start)

## Status
- **Complete** (2026-04-18). Reconciliation closed: Mixpanel 27 → Statsig 12 decomposes exactly into 4 (Mixpanel weekly-bucket backfill) + 1 (Statsig-model late-arrival drop) + 8 (never exposed) + 2 (exposed after purchase). See `findings.md`.
- One STRUCTURAL finding surfaced: `statsig_clickstream_events_etl_output` incremental predicate silently drops late-arriving fct_events rows. Tracked in `project_statsig_model_late_arrival_open.md` memory. Not blocking Meredith's question.
- Slack-ready message to Meredith is in `findings.md` under "Message to Meredith (Slack-ready)".
