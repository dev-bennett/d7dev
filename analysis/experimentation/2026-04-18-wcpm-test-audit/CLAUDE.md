# WCPM Pricing Test Audit — 2026-04-18

@../CLAUDE.md

Audit of Mixpanel vs. Statsig discrepancy on add-on purchases in the `wcpm_pricing_test` experiment. Inquiry from Meredith.

## Inputs
- `inquiry.md` — Meredith's request + links to Mixpanel report and Statsig console
- `Untitled Report_Insights_2026-03-13_to_2026-04-18.csv` — Mixpanel pulse export
- `wcpm_pricing_test-pulse_export-2026-04-18 (1).csv` — Statsig pulse export
- `console.sql` — diagnostic queries q0–q23a (findings.md maps findings to specific queries)
- Test setup doc provided 2026-04-20: Variants A/B/C price table (Control $24.99, Mid $17.99, Deep $15.99 monthly; yearly $19.99 / $14.99 / $12.99 per month)

## Status
- **Complete** (reconciliation) + **two OPEN structural findings** (2026-04-20 update)
- Reconciliation: Mixpanel 27 → Statsig 12 decomposes exactly into 4 (Mixpanel weekly-bucket backfill) + 1 (Statsig-model late-arrival drop, Finding 4) + 8 (never exposed) + 2 (exposed after purchase). See `findings.md` Finding 3.
- **Root cause identified for the 8 never-exposed purchasers (Finding 6, added 2026-04-20):** Statsig's Enforced 1:1 identifier mapping drops users whose identity spans multiple `statsig_stable_id` values. Domain consolidation (www+app → soundstripe.com via Fastly, March 2026) caused stable_id sprawl that trips this rule. q21 shows 2,709 logged-in user_ids (~13.5% of the 20,072 exposed) carry multi-arm exposures that Pulse filters out; 6 of the 8 never-exposed add-on purchasers match this pattern. Three of those paid non-control variant prices at checkout (8c0609f2 $17.99 Mid, 61f4b26d $17.99 Mid, 2fc757ce $15.99 Deep), confirming Chargebee's differential pricing applied the variant even when Statsig couldn't attribute the exposure.
- **2 of 8 never-exposed remain unexplained** (e4ba58b5, 2fc757ce): single stable_id, single arm in raw exposures, absent from `first_exposures`. Candidates: unit-quality filter, bot classification, exposure timestamp vs. pulse-snapshot cutoff.
- **Arm-level impact:** Pulse counts 12 today. If 1:1 didn't drop sprawl-affected users → 18. If the 2 unexplained and the 1 pipeline drop were also recovered → 21. The 2 `exposed_after_purchase` stay excluded (Statsig working as designed).
- Finding 4 (late-arrival drop in Statsig dbt model) still OPEN. Tracked in `project_statsig_model_late_arrival_open.md` memory.
- Finding 6 (1:1 identifier mapping exclusion) OPEN. Tracked in `project_wcpm_1to1_mapping_exclusion.md` memory. KB article at `knowledge/domains/experimentation/identifier-mapping-and-exclusions.md`.
- Slack-ready message to Meredith remains in `findings.md`. Original version was sent before Finding 6 was confirmed; see the "Updated synopsis (2026-04-20)" section of findings.md for the fuller stakeholder readout.
