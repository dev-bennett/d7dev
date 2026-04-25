# WCPM Pricing Test — Mixpanel vs. Statsig Reconciliation Audit

Format: ready-to-paste into Asana. Platform-safe (no bare dollar signs, no backticks, no angle brackets).

---

## Title

Audit: WCPM Pricing Test — Mixpanel vs. Statsig add-on purchase reconciliation

---

## Description

Stakeholder request (Meredith, 2026-04-18): review the Statsig WCPM Pricing Test because Mixpanel and Statsig are showing different numbers for add-ons purchased, and confirm whether the test is set up and reporting correctly.

Numbers at inquiry time:
- Mixpanel report (Uniques of Purchased Add-on, 2026-03-13 to 2026-04-18, filtered to warner-chappell monthly or yearly add-on items): 27
- Statsig Pulse (wcpm_pricing_test, same window, summed across three arms): 12 (Control 2, Mid Reduction 8, Deep Reduction 2)

Sources:
- Mixpanel: mixpanel.com/s/b30sb
- Statsig console: console.statsig.com/5BaYGGuAWgthoz9gc1kXt3/6HtIxq5IfdlXn6veyFmMn3

Scope: quantify every component of the gap; confirm whether the test setup, variant delivery, and reporting are functioning correctly; identify any root causes blocking Pulse from reflecting the true in-arm purchase population.

Out of scope: evaluating the experiment's directional result (effect sizes are premature given the gap).

---

## Update 1 — Work and analysis plan

Posted before diagnostic work began.

Approach follows the project's three-pass analytical workflow (build, verify, interpret) with a prior-investigation search and grounding-questions pass up front.

1. Prior investigation search. Glob and grep analysis and knowledge workspaces for any prior audits of Mixpanel-vs-Statsig reconciliation, WCPM add-on accounting, or Statsig exposure gaps. Leading hypothesis if a prior finding exists: use its confirmed root cause as the first thing to test.
2. Grounding questions. Pin down exactly what Mixpanel is counting (event name, filter column, filter values, whether any exposure filter is applied) and what Statsig's Pulse is counting (metric type, attribution rule, exposure window). Record answers in grounding-questions.md before writing SQL. Gap between the two counts is expected because Statsig Pulse is exposure-scoped and Mixpanel is not; job is to quantify each component.
3. BUILD pass — diagnostic queries (console.sql):
   - q1 and q2: reproduce Mixpanel's 27 from raw pc_stitch_db.mixpanel.export.
   - q3: add-on composition (confirm WCPM is the only add-on in the window).
   - q4: reproduce Statsig's 12 from the soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output dbt model.
   - q7: pipeline survival — for each Mixpanel event, bucket by where it stops (raw Mixpanel, fct_events, Statsig dbt model).
   - q8 through q11: locate the experiment-specific exposures tables, confirm arm sizes match Pulse export exactly.
   - q12 and q13: join Statsig's 22 model rows to first_exposures under Statsig's attribution rule (unit exposed before event) to reproduce the per-arm 12.
   - q14: row-level bucketing (never exposed, exposed after purchase, exposed before purchase).
4. VERIFY pass — Type Audits for every rate, Contract Checklists against Pulse export as reference, Enumeration Checklists for per-arm numbers.
5. INTERPRET pass — Null Hypothesis blocks for each apparent anomaly, Verification Questions on each interpretive claim, Adversarial Questions.
6. For any gap component that survives reconciliation, produce an Intervention Classification (informational, operational, or structural).

Target deliverable: a reconciliation that explains the 15-unit gap exactly (no residuals), plus Intervention Classifications on any material findings. Slack-ready stakeholder summary at the end.

Estimated effort: 1 day for reconciliation, plus additional time for any structural findings that require investigation beyond the stakeholder's immediate question.

---

## Update 2 — Summary of findings

Posted 2026-04-20 after the second-pass audit with pricing validation and 1:1 identifier-mapping analysis.

Status: audit complete. Reconciliation fully closes. Two OPEN structural findings have been surfaced for follow-up; they are not blocking Meredith's reporting question but they do affect every Statsig experiment we run until resolved.

### Reconciliation

Mixpanel 27 minus Statsig Pulse 12 equals 15. The 15-unit gap decomposes exactly:
- 4 purchases dated 2026-03-09 through 2026-03-12. Mixpanel's weekly-bucket UI pulls the full week of 03-09 into the first row of the report even when the date filter starts 03-13. Not in scope for the experiment; not a data issue.
- 1 purchase lost between fct_events and the Statsig dbt model due to a late-arriving event (Finding 1 below).
- 8 purchasers not assigned to any arm in Statsig's Pulse attribution. Six of the eight are explained by the 1:1 identifier mapping finding (Finding 2 below); two remain unexplained.
- 2 purchasers exposed to the experiment only AFTER they already purchased. Statsig's attribution rule correctly excludes these from arm counts.

Arithmetic check: 27 minus 4 minus 1 minus 8 minus 2 equals 12.

Per-arm match (Pulse CSV vs. our reproduction q13):
- Control: 2 (1 existing, 1 new). Match.
- Mid Reduction: 8 (3 existing, 5 new). Match.
- Deep Reduction: 2 (0 existing, 2 new). Match.

### Variant delivery is working correctly

The test setup document provided 2026-04-20 lists the intended arm-specific monthly prices as USD 24.99 (Control), USD 17.99 (Mid Reduction), USD 15.99 (Deep Reduction), configured via Chargebee Product Catalog 2.0 differential pricing gated on Statsig assignment.

Pulling unit_amount from dim_subscription_add_on_invoices for every in-window WCPM add-on purchaser (q20) confirmed:
- All twelve Pulse-counted purchasers paid the arm-specific price matching their assignment.
- Three of the eight never-exposed purchasers paid a non-control arm price at checkout (8c0609f2 USD 17.99 = Mid, 61f4b26d USD 17.99 = Mid, 2fc757ce USD 15.99 = Deep). These users were assigned to and served the reduced variant by Chargebee even though Statsig does not attribute the exposure to them in Pulse.

The instrumentation and variant-delivery integration are functioning as designed. The gap is entirely in Statsig's post-ingestion attribution filtering.

### Finding 1 — Statsig dbt model late-arrival drop (OPEN, STRUCTURAL)

The model soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output uses an incremental predicate that filters the source table (fct_events) by event_ts greater than or equal to the model's current max event_ts. Any fct_events row that arrives after the watermark has advanced past its event_ts::date is permanently skipped.

One concrete instance in this audit: user 1939e3fa... fired a Purchased Add-on at 2026-03-22 19:53:40 that arrived in Stitch on 2026-03-23 15:19 UTC, after the Statsig model's watermark had advanced past 03-22. The row survives in fct_events but is absent from the Statsig model entirely.

Scope: not specific to WCPM, add-ons, or this experiment. Every metric that depends on this model is directionally undercounted whenever Stitch replication lag or any pipeline delay causes an event to arrive after the model's watermark has passed.

Smallest fix: widen the incremental predicate's lookback window (typical pattern: dateadd(day, minus N, max(event_ts)) for N covering expected replication lag). Requires a full-refresh or scoped backfill to recover already-orphaned rows.

### Finding 2 — Statsig Enforced 1:1 identifier mapping exclusion (OPEN, STRUCTURAL)

Statsig's default identifier-mapping mode, Enforced 1:1, disqualifies any user_id that maps to multiple statsig_stable_ids. When that condition is present, Statsig drops all of that user's exposures from Pulse even if they all agree on a single arm.

Post-domain-consolidation (www plus app to soundstripe.com via Fastly, March 2026) has caused widespread stable_id sprawl — a single logged-in user now commonly carries two or more stable_ids across surfaces, visits, and browsers. That identity churn trips the 1:1 filter at scale.

Scale in wcpm_pricing_test (q21):
- 20,072 logged-in user_ids exposed to the test.
- 17,363 exposed to exactly one arm.
- 2,216 exposed to two arms.
- 493 exposed to three arms.
- Total multi-arm user_ids: 2,709 (approximately 13.5 percent of logged-in exposed users).
- 3,601 user_ids carry two or more distinct stable_ids in our own fct_events data; maximum observed is 106 stable_ids for a single user_id.

Per-suspect audit (q22 and q22a): six of the eight never-exposed add-on purchasers match the 1:1 pattern directly — their identity either spans multiple arms or multiple stable_ids (any ambiguity disqualifies under this mode). Two remain unexplained (e4ba58b5 and 2fc757ce): both have a clean single-stable_id deep-reduction exposure in the raw exposures table but are absent from first_exposures_wcpm_pricing_test, which is not a 1:1 symptom. Likely candidates for those two: unit-quality filter, bot classification, or exposure timestamp after the Pulse snapshot cutoff. Statsig's per-user console diagnostics should name the reason.

### Arm-level impact of the findings

Current Pulse count is 12. If the 1:1 exclusions were recovered the count would be 18 (Control 3, Mid 11, Deep 4). If the two unexplained residuals and the one pipeline late-arrival drop were also recovered the count would be 21 (Control 3, Mid 11, Deep 7). The two exposed-after-purchase cases remain excluded regardless — that is Statsig's attribution rule working as designed.

### Recommendations

1. Near-term, for this test: Meredith can treat the per-arm Pulse numbers as directional lower bounds. The price-validation evidence in q20 confirms the variants were served correctly, so effect-size estimation from Statsig Pulse is usable for ranking arms but will understate statistical power.

2. Escalations (two parallel tracks, both owned outside the analyst role):
   - Analytics to evaluate alternative Statsig identifier-mapping modes (Most Recent, user_id-primary, etc.) and ask Statsig to re-run Pulse under each; select the mode that maximizes retained units without introducing a compensating bias. Adopt account-wide if the comparison supports it.
   - Product engineering to stabilize statsig_stable_id continuity across the consolidated domain — cookie scope at .soundstripe.com, SameSite and Secure attributes, Statsig SDK init order relative to user-identification calls, post-Fastly-cutover localStorage vs. cookie reconciliation.

3. Data engineering to widen the Statsig clickstream model's incremental predicate lookback window and backfill the orphaned rows.

4. Every stakeholder readout sourced from Statsig Pulse carries the approximately 13.5 percent Pulse undercount caveat until Finding 2 is resolved.

### Artifacts

- analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md (full write-up, six findings, evidence tables)
- analysis/experimentation/2026-04-18-wcpm-test-audit/console.sql (q0 through q23a diagnostic queries)
- analysis/experimentation/2026-04-18-wcpm-test-audit/q20.csv (price validation per purchaser)
- analysis/experimentation/2026-04-18-wcpm-test-audit/q21.csv, q22.csv, q22a.csv, q23.csv, q23a.csv (1:1 mapping evidence)
- knowledge/domains/experimentation/identifier-mapping-and-exclusions.md (canonical KB article)

### Task status

Complete. Closing this ticket. The two structural findings will be tracked independently: data engineering work for Finding 1, analytics plus product engineering for Finding 2.
