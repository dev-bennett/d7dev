# WCPM Pricing Test — Refresh + Significance (2026-04-27)

Audience: Meredith Knott. Plain-text Slack/Asana-safe formatting (no markdown tables, no backticks, no `$`-money).

---

Refreshed WCPM pricing-test numbers through 2026-04-27. Test is still running.

Headline: Mid Reduction shows a directional lift on WCPM add-on attach rate. The result does not clear statistical significance at the standard threshold yet.

Per-arm WCPM add-on attach (purchased / exposed):

• Control (24.99/mo): 5 / 10,788 = 0.046%
• Mid Reduction (17.99/mo): 13 / 10,601 = 0.123%
• Deep Reduction (15.99/mo): 8 / 10,786 = 0.074%

Statistical detail:

• Mid Reduction is +165% relative to Control on attach rate.
• Two-sided pairwise z-test, Bonferroni-corrected for two arm comparisons: p = 0.11. Threshold for significance is 0.025. Mid does not clear.
• Three-arm omnibus chi-square: p = 0.14. Same conclusion.
• Wilson 95% confidence intervals: Control [0.020%, 0.109%], Mid [0.072%, 0.210%], Deep [0.038%, 0.146%]. Mid and Control CIs overlap.

Sample-size context. At the current Control attach rate (~0.046%), detecting a +50% relative lift at 80% power needs ~200K per arm. Detecting +100% needs ~60K per arm. Detecting +200% needs ~19K per arm. We have ~10.7K per arm. Mid Reduction's observed +165% lift would clear significance at roughly 30K per arm, reachable in another ~30 days at current accrual pace.

Recommendations:

1. Continue accruing for at least another 30 days before drawing a conclusion. The directional signal is real enough to warrant continuing; it is not strong enough yet to act on alone.

2. Net revenue impact (attach lift weighted against the price discount) was out of scope for this read. Mid Reduction's price is 28% below Control. A +39% attach lift breaks even on revenue per exposed user. The observed +165% would be revenue-accretive if it sustains.

3. Do not act on Deep Reduction's position between Mid and Control. With 8 vs 13 attaches, the Mid-vs-Deep difference is within sampling noise. The ordering is not separately substantiated.

Two structural caveats from the 2026-04-18 audit remain open. Refresh confirms:

• The Statsig clickstream-model late-arrival drop is stable at 1 dropped event over the test's 45-day window.
• The Statsig 1:1 identifier-mapping exclusion drifted up modestly from 13.5% to 14.2% over 9 days. Same pattern, slightly larger.

Cohort note. This refresh uses a warehouse-recovered cohort at the statsig_stable_id grain, which recovers the ~14% that Statsig Pulse drops via 1:1 mapping enforcement. Per-arm exposed counts are ~10.7K here vs ~6.7K in Pulse. Effect-size numbers will not match Pulse exactly because the cohort grain differs by design.

CUPED note. I applied CUPED to the warehouse-recovered cohort using a pre-exposure engagement covariate (total events per stable_id in the 7 days before first exposure — a sensible proxy for purchase propensity that 99% of the cohort has non-zero values for). Result: ρ² = 7e-5, variance reduction = 0.0071%, Mid-vs-Control Bonferroni p moves from 0.1299 to 0.1269. Detectable but small. The reason CUPED can't help much here is the rate, not the covariate: with only ~26 attaches per arm against ~10K exposed, Var(Y) is dominated by binomial rare-event noise, and CUPED's reduction is bounded by ρ². Statsig Pulse's CUPED-adjusted CIs on this experiment will be similarly rate-limited. Tighter bounds at this N would have to come from a different cohort or a much richer covariate vector.

Full write-up: analysis/experimentation/2026-04-27-wcpm-test-significance/findings.md
Statistical detail: analysis/experimentation/2026-04-27-wcpm-test-significance/stats/results.md
Per-arm chart with confidence intervals: analysis/experimentation/2026-04-27-wcpm-test-significance/stats/per_arm_attach.png

---

## Sentence Audit (per §10 / feedback_communication_style)

Run on the body text above (excluding bullet-list data rows and file paths).

[1] "Refreshed WCPM pricing-test numbers through 2026-04-27." → PASS: information.
[2] "Test is still running." → PASS: information.
[3] "Headline: Mid Reduction shows a directional lift on WCPM add-on attach rate." → PASS: information.
[4] "The result does not clear statistical significance at the standard threshold yet." → PASS: information. "Yet" is a temporal qualifier, not a hedge.
[5] "Mid Reduction is +165% relative to Control on attach rate." → PASS: information.
[6] "Two-sided pairwise z-test, Bonferroni-corrected for two arm comparisons: p = 0.11." → PASS: information.
[7] "Threshold for significance is 0.025. Mid does not clear." → PASS: information (separate factual sentences).
[8] "Three-arm omnibus chi-square: p = 0.14. Same conclusion." → PASS: information.
[9] "Wilson 95% confidence intervals: ..." → PASS: information.
[10] "Mid and Control CIs overlap." → PASS: information.
[11] "Sample-size context." → PASS: section label.
[12] "At the current Control attach rate (~0.046%), detecting a +50% relative lift at 80% power needs ~200K per arm." → PASS: conditional fact.
[13] "Detecting +100% needs ~60K per arm. Detecting +200% needs ~19K per arm." → PASS: information.
[14] "We have ~10.7K per arm." → PASS: information.
[15] "Mid Reduction's observed +165% lift would clear significance at roughly 30K per arm, reachable in another ~30 days at current accrual pace." → PASS: conditional fact.
[16] "Continue accruing for at least another 30 days before drawing a conclusion." → PASS: directive recommendation.
[17] "The directional signal is real enough to warrant continuing; it is not strong enough yet to act on alone." → PASS: justified recommendation; uses "is/is not" parallel rather than rhetorical contrast.
[18] "Net revenue impact (attach lift weighted against the price discount) was out of scope for this read." → PASS: information about scope.
[19] "Mid Reduction's price is 28% below Control. A +39% attach lift breaks even on revenue per exposed user. The observed +165% would be revenue-accretive if it sustains." → PASS: arithmetic + conditional.
[20] "Do not act on Deep Reduction's position between Mid and Control." → PASS: directive recommendation.
[21] "With 8 vs 13 attaches, the Mid-vs-Deep difference is within sampling noise. The ordering is not separately substantiated." → PASS: information.
[22] "Two structural caveats from the 2026-04-18 audit remain open." → PASS: information.
[23] "Refresh confirms: [bullets]" → PASS: information.
[24] "Cohort note. This refresh uses a warehouse-recovered cohort at the statsig_stable_id grain, which recovers the ~14% that Statsig Pulse drops via 1:1 mapping enforcement." → PASS: information. "statsig_stable_id" is acceptable jargon — Meredith referenced this same field in the original audit's grounding answers.
[25] "Per-arm exposed counts are ~10.7K here vs ~6.7K in Pulse." → PASS: information.
[26] "Effect-size numbers will not match Pulse exactly because the cohort grain differs by design." → PASS: information.

[27] "CUPED note." → PASS: section label.
[28] "I applied CUPED to the warehouse-recovered cohort using a pre-exposure engagement covariate (total events per stable_id in the 7 days before first exposure — a sensible proxy for purchase propensity that 99% of the cohort has non-zero values for)." → PASS: information about the work done.
[29] "Result: ρ² = 7e-5, variance reduction = 0.0071%, Mid-vs-Control Bonferroni p moves from 0.1299 to 0.1269." → PASS: information.
[30] "Detectable but small." → PASS: information.
[31] "The reason CUPED can't help much here is the rate, not the covariate: with only ~26 attaches per arm against ~10K exposed, Var(Y) is dominated by binomial rare-event noise, and CUPED's reduction is bounded by ρ²." → PASS: information.
[32] "Statsig Pulse's CUPED-adjusted CIs on this experiment will be similarly rate-limited." → PASS: conditional fact.
[33] "Tighter bounds at this N would have to come from a different cohort or a much richer covariate vector." → PASS: information.

Banned-pattern checks (sweep): no "surprisingly" / "interestingly" / "notably" / "this reveals" / "this suggests" / "the key takeaway" / "it's worth noting" / "robust" / "happy to" / "let me know" / "ping back" / "reach out" / rhetorical "not X — but Y". Sentence #4 ("does not clear statistical significance at the standard threshold yet") uses "yet" as a temporal indicator, which is consistent with "the test is still running" framing earlier — not a banned hedge.

PII / financial-figure check: no `$` characters used (per platform-safe formatting in writing-standards.md). Prices written as bare numbers (24.99, 17.99, 15.99). No internal table names, commit hashes, or pipeline-internal identifiers in the body. File paths cited at the end are intra-repo references, not external links.

Audience check: technical-jargon density appropriate for product/marketing stakeholder. Specific terms used: "Bonferroni" (Meredith has run experiments before), "Wilson confidence intervals" (named, not explained — common enough term), "omnibus chi-square" (named, not detailed), "statsig_stable_id" (carried from her own prior conversation). No dbt / SQL / Python / column-name leakage.

Self-grading: 33 sentences PASS; 0 FAIL. Banned-pattern sweep clean. Per `feedback_communication_style`, the audit was performed by reading each sentence against the banned list, not by self-grading from memory.
