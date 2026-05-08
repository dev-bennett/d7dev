---
name: Analysis Methodology
paths: ["analysis/**"]
---

# Analytical Rigor Standards

See context/informational/agent_directives_v3.md for full directive details.

## Three-Pass Workflow (§7)

All analytical work follows three sequential passes. Do not interleave them.

1. **BUILD:** Write SQL, produce charts, assemble reports. Output only. No commentary, no interpretation.
2. **VERIFY:** Produce all verification artifacts -- Type Audits (§1), Contract Checklists (§2), Identity Checks (§5), Enumeration Checklists (§6), spot-check one row manually.
3. **INTERPRET:** Write analytical commentary with Null Hypothesis Blocks (§4), Verification Questions (§3), Adversarial Questions (§8), Intervention Classification (§11).

Pass 2 cannot be skipped. Pass 3 cannot begin until Pass 2 is complete.

Direct Snowflake execution (`mcp__claude_ai_Snowflake__sql_exec_tool`, or `/sql`) is appropriate during PASS 1 BUILD iteration and PASS 2 VERIFY spot-checks. It is not a substitute for file-first capture of deliverable queries — any query whose result is cited must live in a `.sql` file. See `.claude/rules/snowflake-mcp.md`.

## Claim Verification (§3)

For each interpretive claim: (1) state the claim, (2) formulate a verification question that could disprove it, (3) answer that question independently without looking at the original claim, (4) compare, (5) revise if they conflict.

**Absence Rule:** "No rows exist for X" is an observation. "X never happened" is a causal claim. Data absence has multiple explanations -- state what the data shows and flag that the cause is undetermined.

## Null Hypothesis Check (§4)

When interpreting cohort shifts, seasonal patterns, engagement decay, or correlated metrics:

```
NULL CHECK:
  OBSERVATION: [what the data shows]
  NULL HYPOTHESIS: [what this looks like if nothing unusual is happening]
  VERDICT: [null explains it / null does NOT explain it -- with numbers]
  INTERPRETATION: [framing consistent with verdict]
```

If null explains it, do not frame the pattern as alarming or notable.

## Algebraic Identity Detection (§5)

When 3+ related rate metrics are computed from the same data, check for A = B x C or weighted-average decompositions. Surface shift-share decompositions proactively.

## Definition-Use Case Alignment (§12)

When defining segments/cohorts that drive actions, verify temporal mechanic alignment:

```
ALIGNMENT CHECK -- [category]:
  INTERVENTION: [what action will this category trigger?]
  TEMPORAL MECHANIC OF INTERVENTION: [event-driven / state-driven / hybrid]
  TEMPORAL MECHANIC OF DEFINITION: [snapshot / event-based / rolling window]
  MATCH: [YES/NO]
  SIZING SANITY: [expected magnitude vs. query output]
```

Do not proceed to query authoring for any category that fails alignment.

## Investigatory Analysis (Signal Detection, Data Quality, Anomaly Investigation)

Investigatory work follows a modified sequence: context gathering precedes query authoring.

0. **PRIOR INVESTIGATION SEARCH (mandatory first step):** Before writing anything, search `analysis/**` for prior investigations on the same observable. Use Glob (`*<topic-slug>*`, e.g. `*direct-traffic-spike*`, `*mql-discrepancy*`) and Grep the metric/channel/pipeline name. If one is found, read the findings doc end-to-end. Its confirmed root cause is the leading hypothesis for the current observation — test whether it explains the new data before composing new hypotheses. Failing this step is the single highest-leverage mistake in this class of work.
1. **CONTEXT:** Gather all available domain context BEFORE writing diagnostic SQL.
   - If the user states a suspected cause, investigate that cause first
   - Seek PRDs, deployment timelines, architecture docs, changelogs for the relevant system
   - Read the dbt model lineage (source → staging → marts) for any tables you'll query. For Mixpanel work specifically: `pc_stitch_db.mixpanel.export` is the SOURCE; `fct_events` is a transformation that drops columns (UA, IP, mp_lib, screen dims, initial_referrer). If event-level fingerprinting is needed, query the raw source.
   - Identify the fields available in the model before writing queries that reference them
2. **BUILD:** Write diagnostic queries directly to the working file (visitors.sql or equivalent). Do not show queries in chat for the user to copy.
3. **ITERATE:** After each query round, check the filesystem for result files before composing analysis. The user may export results faster than you respond.
4. **VERIFY/INTERPRET:** Same as the standard three-pass workflow -- verification artifacts, null hypothesis checks, claim verification.

Hypothesis discipline: let the data constrain hypotheses, but also let available context constrain them. If a known infrastructure change coincides with a data anomaly, the infrastructure change is the leading hypothesis until evidence contradicts it.

## Substantiation Frame: Distribution-at-Rollup + Concentration

For claims about an observable's character (scraping, bot traffic, attribution artifact, behavior shift), the primary substantiating artifact is a single query with three elements:

1. **Per-population comparison** across the suspect cohort and ≥2 control cohorts (e.g., spike-window direct, baseline direct, spike-window referred)
2. **Distribution at a stakeholder-visible rollup** — not raw URL/event grain, but the rollup a dashboard consumer would see (URL → section, event → category, user → cohort)
3. **Concentration metric** inside each (section, population) cell — top-N share of events, unique values count, or Herfindahl. Flat concentration + many unique values = enumeration/coverage. Concentrated on popular values = preference/organic.

This frame separates coverage hypotheses from preference hypotheses from misattribution hypotheses in one query. Draft it EARLY — don't detour through raw samples or single-dimensional attribute aggregates first.

**Diagnostic saturation check:** before presenting a metric as signal, verify it's not saturated at baseline. If bounce rate is 88% at baseline and 97% in the spike window, the spike is not a bounce-rate story — the population is already bot-heavy. Character-level discriminators require non-saturated baselines.

**Correction filter validation:** When building a filter to exclude contaminated data, validate against control periods before presenting results. If the corrected metric in the affected window is systematically higher or lower than both the pre-contamination and post-fix control periods, the filter is miscalibrated. Use all available prior query results to inform the filter — do not ignore dimensions (e.g., landing host, geo) that the data already exposed as relevant.

## Default trend-window selection for period-over-period reviews

For "year in review" / "trend review" / period-over-period decomposition analyses (NOT discrete event impact analyses — that's the next section), the default comparison anchor is **YoY full 12-month windows.** Cherry-picked single-month or single-quarter endpoints are not defensible without explicit justification.

**Rule:** when comparing period 1 to period 2 to compute Δs, decompositions, or YoY ratios, the default is two adjacent 12-month buckets (e.g., May 2024 - Apr 2025 vs May 2025 - Apr 2026). Two single calendar months are NOT a valid headline anchor — they're peak-vs-trough cherry-picking with no statistical defense.

**Why this matters:** single-month endpoints amplify monthly noise; the "Δ" depends on which month you happened to pick. Single months are vulnerable to one-off events (campaigns, holidays, artifact spikes) that 12-month aggregates dilute. Stakeholders interpret "month X vs month Y" as the trend; it isn't — it's two snapshots that may or may not represent the trend.

**When to deviate:**
- If a discrete event partitions the window cleanly (cutover, deploy), use DID against DoW-aligned prior-year anchors per the next section.
- If the stakeholder explicitly requested a different window (rolling 90-day, fiscal quarter, since-launch), state the request and proceed.
- If the YoY window straddles a known artifact period (e.g., 2 months of 12 are contaminated), state the dilution effect; the bucket is usually still defensible because 10 of 12 months are clean.

**Decomposition framings — provide both aggregate and per-segment by default.** When asked for a decomposition (channel, plan, geo, etc.), the natural reader question is both "what's the headline" and "what's driving it per segment." A per-segment decomposition that sums to the total is NOT the same as treating the total as one rate × volume pair — they hide the mix-shift effect in different places (per-segment hides it in the volume term; aggregate hides it in the rate term). Default to producing both, distinct, with the same Δ-total but different attribution narratives. Do not wait for the stakeholder to ask "where's the aggregate version" — that's the second-tier ask after "give me the channel breakdown" and predictable.

**Mislabeling discipline:** if your headline window is May 2024 → Feb 2026 (21 months) do NOT call it a "24-month decline." Label the actual span.

## Pre/post event impact analyses: DoW-aligned DID + metric discipline

For analyses of the form "did event X (cutover, launch, deploy) at date D change metric Y over a short post-window," the headline construct is **difference-in-differences against DoW-aligned prior-year anchors** — not raw within-period pre/post and not raw same-period YoY. See `feedback_did_for_pre_post_event_analyses.md` for full how-to.

Key requirements:
- DoW-align the prior-year windows (start on the same weekday as the current-year window). 19-day windows are sensitive to weekday/weekend mix; misalignment by even one day biases the YoY ratio. Verify Easter and other DoW-sensitive holidays sit at similar positions.
- For SEO-incrementality questions, **sessions** is the right metric. Visitors are polluted by post-cutover identity fragmentation (documented at the `statsig_stable_id` level by the WCPM audit; equivalent applies to Mixpanel `distinct_id`). Logged-in users are gated by login propensity and represent returning customers, not the SEO target population. See `feedback_apply_memory_at_metric_validity.md`.
- Disclose the attribution column choice. `last_channel_non_direct` carries attribution forward across visits. Raw `channel` gives a cleaner SEO-incrementality read but breaks comparability with marketing dashboards. State which was used and why.
- When the focal channel's DID swings opposite to a concurrent channel's DID at the same cutover (e.g., Organic +X, Direct −Y), some of the focal gain may be reclassification. Bound real incrementality: floor = focal_DID − |concurrent_decline|; ceiling = focal_DID. Present as a range.
- Commit to ONE headline metric across the whole deliverable. Don't flip metrics under pushback — present a defensible range with the caveat inline. See `feedback_commit_to_one_metric.md`.

## Attribution discipline: timing alignment + mechanism enumeration

Before attributing a pre-vs-post window difference to any specific date, event, or mechanism, run both checks below. Failing either reduces the claim to "this analysis does not attribute the delta."

**Timing alignment test.** Pre-vs-post window-level deltas hide the within-window timeline. If you attribute a delta to a specific date (e.g., a deploy, a config change), the weekly (or daily) series of the metric must show a discontinuity on/near that date. Draw the weekly series BEFORE committing to attribution. If the metric rose pre-deploy, plateaued, or stepped on a different date, the window-level attribution is unsupported. See `feedback_enumerate_mechanisms_before_attribution.md`.

**Mechanism enumeration.** Before writing "X caused Y" / "Y is an X story" / "Y is explained by X", enumerate at least one alternative mechanism that would produce the same observed data. Explain how the data discriminates between them. If it does not, rewrite the claim as "the data is consistent with {X, alternative}; this analysis does not distinguish among them" and state what evidence would discriminate. Integrative / window-level decompositions do NOT substitute for weekly timing alignment — "aggregate X explains aggregate Y over the window" is not the same as "X drove Y at the timeline that matters." See `feedback_enumerate_mechanisms_before_attribution.md`.

**Stakeholder benchmark cross-check.** If a stakeholder-provided document reports a prior value for a metric you are recomputing, explicitly compare your computed value to theirs in the Verify pass. Treat >2x gaps as failed sanity checks — likely a methodology bug, not a "definitional difference." Re-audit the query (particularly step-rate nesting per sql-snowflake.md) before publishing. See `feedback_cross_check_stakeholder_benchmarks.md`.

**BUILD-time application of the cross-check.** The cross-check fires at BUILD pass too, not only Verify. Whenever a query returns a row count or total that is computable against a known reference (a stakeholder doc's reported count, a baseline xlsx, a prior-snapshot file in the task folder), compare the two before iterating further or building charts/CSVs on top. A >2x ratio between your output and the reference is a STOP-and-diagnose signal at BUILD time — the most likely root cause is wrong scope, wrong filter, or wrong date interpretation, not a "growth story" or a "labeling difference." Three failure modes share this pattern:

1. **Scope/filter mismatch.** Your query includes rows the reference excluded (e.g., content-partner songs, archived rows, all-states vs released-only).
2. **Date interpretation.** A filename or doc-title date you parsed implies a different baseline date than the stakeholder intended (e.g., "0922" → September 2022 vs September 22, 2025).
3. **Population definition.** The reference's denominator was a stricter cohort (logged-in only, paying only, Soundstripe-original only) than your default.

If a downstream observation (e.g., "the vocal-class mapping doesn't fit") is also unexplained, do not rationalize the downstream observation independently — it is a *symptom* of the upstream scope failure. Unwind to the load-bearing assumption first.

## Reconciliation Audit: every number must trace to a real reporting source

TRIGGER: You are about to deliver a chart, decomposition, sensitivity table, or comparison artifact whose numbers are framed as informing stakeholders about what the dashboard / canonical report shows.

The §1 Type Audit checks SQL internal consistency (denominators match declared rate, JOINs preserve the right population). It does NOT check whether the rate I'm computing is the one a stakeholder would see if they pulled the dashboard. **An analyst-constructed metric can pass Type Audit while diverging from the canonical reporting source.** Three failure modes from this class — all observed in `analysis/adhoc/2026-04-28-product-kpis/`:

1. **Synthesized denominator.** Built `chart_06_dl_30_60d_raw_vs_lagged.csv` with a "raw" series using `subscribers_in_cohort` as the denominator. The Looker tile uses `subs_60_plus`. The "raw" series existed nowhere on the dashboard — but was labeled as if it did, alongside a "lagged-clean" series at the real denominator. The implied "+10pp fix from lagging" was theater on a baseline that didn't exist.

2. **Synthesized model layer.** M6 revenue model applied \$6,000 × Enterprise sub count as the Enterprise LTV contribution. Looker's `total_revenue` measure does NOT do this — Enterprise gets \$0 in the LTV term (LEFT JOIN to `subscription_ltv_assumptions` returns NULL because no Enterprise row exists), and \$6k appears separately as `mqls × 0.05 × 6000`. The +18% rev/session and -6% net headlines computed from M6's model don't reconcile to any Looker tile.

3. **Synthesized rate variant.** chart_03 labeled an M3-derived per-visitor signup rate as "all_visitor_signup_rate" alongside the engaged-visitor CVR. The Looker tile 5 (`sign_ups_per_session`) uses a per-session denominator, not per-visitor. The label implied dashboard tile, the construction was an analyst-derived alternative.

For any analytical artifact that purports to inform stakeholders about what the dashboard shows, run this block:

```
RECONCILIATION AUDIT — [artifact name]:
  For every numerator: cite the LookML measure / dbt column that produces this value
    [series 1 numerator]: [LookML measure path or "analyst-derived: <reason>"]
    ...
  For every denominator: cite the LookML measure / dbt column
    [series 1 denominator]: [LookML measure path or "analyst-derived: <reason>"]
    ...
  Stakeholder-pull check: if a stakeholder opens the dashboard right now, do my numbers match within float precision? [YES / NO + which differ + why]
  Synthetic-baseline check: any series in this artifact that doesn't exist as a real measure? [YES → must be relabeled `analyst_derived_*` and not shown side-by-side with real measures as peers / NO]
  RESULT: [PASS / FAIL]
```

GATE: any FAIL, do not deliver. Either match the canonical source or relabel the synthetic component as `analyst_derived_<name>` with a paragraph explaining why the analyst-derived view differs from the dashboard view. Never both, never side-by-side as if peer comparisons.

RULE: a series labeled "raw" or "before" or "as-shipped" or any framing that implies the dashboard's view must use the LookML measure formula exactly. Synthesized variants are the analyst's view, not the dashboard's view, and must be labeled as such.

See `feedback_chart_series_must_be_apples_to_apples.md` for the longer-form discussion of why the failure mode is sandbagging (manufactured before/after) rather than just "different denominators" (labeling problem).

## Core Standards

- Every analysis must state: question, methodology, data sources, limitations
- Quantify uncertainty -- ranges, confidence intervals, sample sizes
- Distinguish correlation from causation explicitly
- Document assumptions and their sensitivity
- Reproducibility: include the SQL/query that produced each finding
- Timestamp all analyses; note data freshness
- Flag analyses as draft/reviewed/final
- Metric definitions must reference the canonical data dictionary
- When a finding contradicts prior knowledge, investigate before reporting
- Output format: use templates from analysis/_templates/
