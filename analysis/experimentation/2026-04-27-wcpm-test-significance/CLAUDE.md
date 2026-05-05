# WCPM Pricing Test — Significance Read-out (2026-04-27)

@../CLAUDE.md

Refresh of the 2026-04-18 audit (`../2026-04-18-wcpm-test-audit/`) extending the window from 2026-03-13 → 2026-04-18 to 2026-03-13 → 2026-04-27, plus a new statistical-significance deliverable on the WCPM add-on attach metric across the three pricing variants (Control / Mid Reduction / Deep Reduction).

## Decisions locked at scoping

- **Primary metric:** WCPM add-on attach (Existing-Subscriber + New-Subscriber combined). Matches what Statsig Pulse measures.
- **Cohort:** Warehouse-recovered only — raw `_external_statsig.exposures` with `stable_id`-level first-exposure dedup. Multi-arm `stable_id`s tie-broken by earliest exposure timestamp. Recovers users that Statsig Pulse drops via Enforced 1:1 mapping (per `project_wcpm_1to1_mapping_exclusion.md`); numbers will diverge from Pulse by design.
- **Statistical methodology:** Frequentist. Per-arm Wilson 95% CIs, pairwise two-proportion z-tests with Bonferroni correction (α=0.025), Newcombe rate-difference CIs, omnibus Fisher's exact (3×2). MDE / power analysis at current N. Sequential-testing peek caveat surfaced explicitly.

## Inputs (carried forward)

- Variant prices: Control $24.99, Mid $17.99, Deep $15.99 monthly; yearly $19.99 / $14.99 / $12.99 per month (test setup doc 2026-04-20)
- Statsig metrics: `WCPM Add Ons - Existing Subscriber` (sum of `ADD_ON_PURCHASE_EXISTING_SUB`), `WCPM Add Ons - New Subscriber` (sum of `ADD_ON_PURCHASE_NEW_SUB`); both `clickstream_events_etl` source, CUPED 7-day lookback
- Mixpanel filter: `Purchased Add-on` event with `properties` matching `warner-chappell-production-music-monthly-usd` or `warner-chappell-production-music-yearly-usd`
- Statsig sync: daily 0500 CDT
- Test still running as of 2026-04-27 (no stated end date)

## Open structural findings carried forward

These remain OPEN in repo memory and may bias the refreshed numbers:
- **Finding 4** — `_external_statsig.statsig_clickstream_events_etl_output` incremental predicate drops late-arriving rows (`project_statsig_model_late_arrival_open.md`). Symmetric across arms. Quantified in `q12`.
- **Finding 6** — Statsig Enforced 1:1 mapping drops ~13.5% of logged-in exposed user_ids (`project_wcpm_1to1_mapping_exclusion.md`). Sidestepped by warehouse-recovered cohort. Refreshed magnitude in `q13`.

## File layout

- `README.md` — status, scope, links
- `inquiry.md` — original Meredith ask + 2026-04-27 refresh ask
- `methodology.md` — §1 RATE blocks, §12 ALIGNMENT CHECK, statistical methodology, MDE/power assumptions, TYPE AUDIT entries
- `console.sql` — q01–q14 labeled SELECTs (one SELECT per label per `feedback_one_sql_file_per_query_set`)
- `q01.csv … qNN.csv` — exports from each labeled query
- `stats/` — Python statistical-test script, inputs, outputs, chart
- `findings.md` — full analyst write-up, structural caveats, intervention classification
- `stakeholder-readout.md` — Meredith-facing message (plain language, no internal jargon per `feedback_communication_style`)

## Reference files (do not modify)

- `../2026-04-18-wcpm-test-audit/console.sql` — source for reusable q1/q2/q4/q9d/q11c/q14/q21
- `../2026-04-18-wcpm-test-audit/findings.md` — original 6 findings + reconciliation chain
- `/knowledge/query-patterns/statsig_exposure_cohort.sql` — canonical cohort pattern
- `/knowledge/data-dictionary/calibration/_external_statsig__exposures.md` — pitfalls + canonical join
- `/knowledge/domains/experimentation/identifier-mapping-and-exclusions.md` — Finding-6 diagnostic + mitigation
