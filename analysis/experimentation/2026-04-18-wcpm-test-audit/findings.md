# WCPM Pricing Test — Mixpanel vs. Statsig Reconciliation

Status: draft — **reconciliation fully closed via q13/q14; pipeline-drop root cause confirmed via q17/q18 as a STRUCTURAL issue.** Findings 1 and 2 retracted earlier in the session; see "Retractions" at bottom.
Author: Devon / Claude
Date: 2026-04-18
Queries: `console.sql` q0–q18 (q6 empty; q10 superseded by q12 → q13; q15/q16 obsolete after the Mixpanel-backfill explanation)
Source exports: `q0.csv`–`q18d.csv`, plus Meredith's `Untitled Report_Insights_*.csv` (Mixpanel) and `wcpm_pricing_test-pulse_export-*.csv` (Statsig)

## Headline

The WCPM Pricing Test is instrumented correctly. Mixpanel's 27 and Statsig's 12 are both right, and the 15-unit gap decomposes exactly.

**27 → 12 decomposition:**

- **−4:** Pre-experiment purchases (03-09 through 03-12) included in Meredith's week-of-03-09 weekly bucket despite her 03-13 filter start. Mixpanel's UI backfills the full week when bucketing is weekly — a Mixpanel UX quirk, not a data issue.
- **−1:** One Mixpanel add-on event is dropped between raw Mixpanel and fct_events.
- **−8:** Eight add-on purchasers never appear in `first_exposures_wcpm_pricing_test` — their paths to WCPM purchase don't hit the experiment's exposure trigger.
- **−2:** Two add-on purchasers were first exposed AFTER their purchase (3 and 7 days later, both purchased 2026-03-13). Statsig correctly excludes them from arm attribution.
- **= 12:** Statsig pulse total. Control 2 + Mid Reduction 8 + Deep Reduction 2. q13 reproduces the per-arm existing/new splits exactly (1/1 · 3/5 · 0/2).

The WCPM-test *setup* (assignment, attribution, metric definitions) is working correctly — Meredith's reporting question is answered. One structural issue surfaced in the course of the audit that is not blocking her decision but should be flagged to the team: the `statsig_clickstream_events_etl_output` dbt model's incremental predicate silently drops late-arriving fct_events rows, and the single −1 in this reconciliation is one concrete instance of that pattern. Details in Finding 4.

## Observed numbers

| Source | Metric | Value | Query |
|---|---|---|---|
| Raw Mixpanel, 03-13 → 04-18 | `Purchased Add-on` events (all add-ons) | 96 | q2 |
| Raw Mixpanel, 03-13 → 04-18 | Distinct add-on purchasers (all add-ons) | 23 | q2 |
| Raw Mixpanel, 03-13 → 04-18 | Distinct purchasers with `current_addons ILIKE '%warner%'` | 23 | q2 |
| Raw Mixpanel, 03-13 → 04-18 | Distinct purchasers with `current_plan_id IN (wcpm-monthly, wcpm-yearly)` | 0 | q2 |
| Raw Mixpanel, 03-13 → 04-18 | `statsig_stable_id` event-level fill rate | 98.96% | q2 |
| Raw Mixpanel, distinct add-ons in window | `warner-chappell-production-music-monthly-usd` | 12 users | q3 |
| Raw Mixpanel, distinct add-ons in window | `warner-chappell-production-music-yearly-usd` | 11 users | q3 |
| Raw Mixpanel, distinct add-ons in window | Any other add-on product | 0 | q3 |
| Statsig dbt model (unscoped to exposure) | Total add-on purchase rows | 22 | q4 |
| Statsig dbt model (unscoped to exposure) | Rows flagged `add_on_purchase_existing_sub=1` | 8 | q4 |
| Statsig dbt model (unscoped to exposure) | Rows flagged `add_on_purchase_new_sub=1` | 14 | q4 |
| Statsig pulse CSV (exposed units only) | Combined add-on purchases across arms | 12 | export |
| Statsig pulse CSV (exposed units only) | "Existing Subscriber" (swapped) | 4 | export |
| Statsig pulse CSV (exposed units only) | "New Subscriber" (swapped) | 8 | export |
| Pipeline drop check | Mixpanel events absent from fct_events (expected fct-side dedup) | 73 / 96 events (20 / 23 users have ≥1 drop) | q7 |
| Pipeline drop check | Distinct users absent from Statsig model for their add-on row | 1 | q17 |
| Pipeline drop check | fct_events row for the dropped add-on event | present (PK `a7a9fe2a-…`, event_ts 2026-03-22 19:53:39) | q18b |
| Pipeline drop check | Same PK in the Statsig model | absent (not found anywhere in 3,051 rows for this user) | q18c |
| Pipeline drop check | Statsig model current max(event_ts) | 2026-04-18 01:01:31 (210M rows) | q18d |
| Fan-out check | Add-on events multiplied by `subscription_periods` join | 0 (empty) | q6 |

## Finding 1 — [RETRACTED — see Retractions]

## Finding 2 — [RETRACTED — see Retractions]

## Finding 3 — Reconciliation (fully closed)

| Step | Count | Evidence |
|---|---|---|
| Meredith's Mixpanel report (weekly bucket) | 27 | Filter header: Mar 13 2026 12:00AM → Apr 18 2026 5:05PM |
| − Pre-experiment backfill (Mixpanel weekly-bucket UX quirk) | −4 | Her week-of-03-09 shows 8 uniques; 4 of those are events from 03-09 through 03-12 that Mixpanel pulls into the week-of-03-09 bucket even though her filter starts 03-13. My q1 constrained to `event_created >= 2026-03-13` returned 4 in that bucket; all later weekly buckets match Meredith's numbers exactly. |
| = In-window Mixpanel WCPM add-on purchasers | 23 | q2: distinct_users_wcpm_addon_filter |
| − Lost at fct_events → Statsig model | −1 | Per q17/q18: distinct_id `$device:1939e3fa043955-…` (stable_id `888dc645-…`, plan `pro-monthly-usd`, sub 236241 active, event 2026-03-22 19:53:40). 5 raw Mixpanel events → 1 survives into fct_events (PK `a7a9fe2a-…`, normal dedup) → 0 in the Statsig model. **Root cause confirmed** (q18c): the user has 3,051 other events in the Statsig model spanning 2024-12-06 through 2026-03-26, but PK `a7a9fe2a` is absent. The model's incremental predicate (`event_ts::date >= max(event_ts)::date from this`) silently skips late-arriving fct_events rows whose event_ts predates the current watermark. In this case the raw event fired 2026-03-22 19:53:40 but arrived in Stitch 2026-03-23 ~15:19 — after the model had likely advanced its watermark past 03-22. Subsequent runs exclude the row because `03-22 >= 03-23+` is false. |
| = Rows in the Statsig dbt model | 22 | q4 total |
| − Never exposed to `wcpm_pricing_test` | −8 | q14 bucket `never_exposed` (no matching row in `first_exposures_wcpm_pricing_test`) |
| − Exposed AFTER purchase | −2 | q14 bucket `exposed_after_purchase`; `af007bc8-…` (→ Deep, 7.1d gap) and `a9894073-…` (→ Mid, 3.0d gap) |
| = Statsig pulse total | 12 | Control 2 + Mid Reduction 8 + Deep Reduction 2 |

Arithmetic check: 27 − 4 − 1 − 8 − 2 = 12 ✓

Per-arm exact match (q13 vs. pulse CSV):

| Arm | Existing (q13) | New (q13) | Total (q13) | Pulse CSV |
|---|---|---|---|---|
| Control | 1 | 1 | 2 | 2 ✓ |
| Mid Reduction | 3 | 5 | 8 | 8 ✓ |
| Deep Reduction | 0 | 2 | 2 | 2 ✓ |
| not_exposed | 4 | 6 | 10 | — (residual) |

q13 vs. q12 differs only by adding `AND fe.first_exposure <= sa.event_ts` to the exposures join — confirming Statsig's attribution rule is "unit must be exposed before the event counts." Without that rule, 2 exposed-after-purchase users inflate the Mid Reduction and Deep Reduction "existing" counts by 1 each; with it, the reconciliation matches exactly.

### Awareness items about the test setup (not bugs)

- **8 purchasers never hit the exposure trigger.** Q3a said "no exposure rules selected other than not-a-bot." In practice the trigger fires on some client-side surface (page or component); users who complete a WCPM add-on purchase via a path that doesn't render that surface never get assigned to an arm. Worth a separate conversation about where the trigger is wired and whether that coverage matches the intent of the test.
- **2 purchasers exposed after they bought.** Both purchased on the experiment's start day (2026-03-13) and were first exposed 3 and 7 days later. Not a bug — this is Statsig working correctly — but the pattern suggests the exposure is not on the WCPM checkout path itself.

The third item (late-arrival drop in the Statsig dbt model) was also surfaced during the audit and is written up as its own structural finding in Finding 4 below rather than as an "awareness item," because it's a real code issue with repo-wide implications, not a test-setup observation.

### Intervention class

`INTERVENTION CLASS — population-scope difference`
- **FINDING:** Mixpanel counts all purchasers; Statsig counts only exposed purchasers. Comparing them directly as if they measure the same thing is a category error.
- **PERSISTENCE TEST:** If not documented, this question will recur for every subsequent test.
- **OWNER TEST:** Analyst + stakeholders.
- **SMALLEST FIX:** Add a note to whatever Statsig-onboarding / experimentation-domain doc exists stating: "Pulse metrics are scoped to exposed units. For a like-for-like comparison with Mixpanel, either filter Mixpanel to the exposed cohort via `statsig_stable_id`, or accept the scope difference and treat the two numbers as complementary, not duplicate."
- **CLASSIFICATION:** INFORMATIONAL.

## Finding 4 — Late-arrival drop in the Statsig dbt model (STRUCTURAL)

The 22 vs. 23 split between raw Mixpanel and the Statsig dbt model is explained by one specific event, and the mechanism is a repo-wide issue in `statsig_clickstream_events_etl_output`, not a fct_events problem.

**Evidence chain (q17 → q18):**

1. Raw Mixpanel has 5 `Purchased Add-on` events for distinct_id `$device:1939e3fa043955-…` at `2026-03-22 19:53:40`, with 5 distinct `__sdc_primary_key` values (client fired 5 duplicates). Stitch received all 5 between `2026-03-23 15:19:19` and `16:35:00` UTC.
2. fct_events dedups to **1 surviving row** (PK `a7a9fe2a-2c96-4101-a041-bd6d40fdc329`, event_ts `2026-03-22 19:53:39`). This is expected fct-side behavior.
3. The Statsig model has **0 rows** with that PK, for this user or otherwise (q18c, grep).
4. The same user has **3,051 other events in the Statsig model**, spanning `2024-12-06` through `2026-03-26`. The model's current watermark is `2026-04-18 01:01:31` (q18d). The watermark clearly advanced past 03-22 — so the row isn't "waiting to be picked up," it's orphaned.

**Mechanism:**

The dbt model (`context/dbt/models/marts/_external_statsig/statsig_clickstream_events_etl_output.sql`, lines 132–134) uses this incremental predicate:

```
{% if is_incremental() %}
    and event_ts::date >= (select coalesce(max(event_ts), '1900-01-01')::date from {{ this }})
{% endif %}
```

The predicate filters the *source* (fct_events), not the target, by comparing each candidate row's `event_ts::date` against the model's current max(event_ts). Any fct_events row that arrives AFTER the model's max has advanced past its `event_ts::date` is permanently skipped — the predicate `03-22 >= 03-23+` is false on every future run.

In the WCPM case: the raw event fired 2026-03-22 19:53:40, arrived in Stitch on 2026-03-23 ~15:19, and at some point landed in fct_events. By the time the Statsig model next ran against fct_events, its watermark was already past 03-22. The `a7a9fe2a` row was never eligible for inclusion again.

**Scope of impact:**

This is not specific to WCPM, add-ons, or Meredith's experiment. *Any* late-arriving fct_events row whose `event_ts` predates the Statsig model's current watermark is silently dropped. Stitch-side replication lag + daily dbt ordering makes this a recurring condition. The model has 210M rows; the true count of orphaned rows is unknown, and the undercount is directionally systematic (older events are more likely to be skipped than newer ones).

### Intervention class

`INTERVENTION CLASS — late-arrival predicate`
- **FINDING:** The Statsig dbt model's incremental predicate filters the source table by `event_ts::date >= max(event_ts)::date from this`, which excludes any late-arriving fct_events row whose event_ts predates the model's current max. One concrete case is documented (q17/q18); the pattern applies to every row passing through this model.
- **PERSISTENCE TEST:** Left in place, the model will continue to undercount silently — especially for any backfill, replication lag, or Stitch late-landing event. Downstream Statsig experiments reading any of the model's columns will have systematic undercounts for the affected rows.
- **OWNER TEST:** Analytics engineer / whoever owns `statsig_clickstream_events_etl_output.sql`.
- **SMALLEST FIX:** Widen the incremental predicate's lookback window. Example pattern (matches what other models in the repo use):
    ```
    and event_ts::date >= dateadd(day, -N, (select coalesce(max(event_ts), '1900-01-01')::date from {{ this }}))
    ```
    `N` should be at least the maximum expected Stitch replication lag (a few days is typical; a week is safer). Requires a one-time `--full-refresh` or a scoped backfill with `backfill_from` to recover already-orphaned rows.
- **CLASSIFICATION:** STRUCTURAL.

## Finding 5 — Fan-out check

q6 returned empty. The `subscription_periods` join without a period-selection predicate does not multiply add-on rows in practice during this window. This rules out over-counting from fan-out.

### Intervention class

INFORMATIONAL.

## Adversarial check (§8)

- **Q1 — Skeptical reader's first challenge?** "How do we know the numbers really reconcile and aren't just coincidentally close?" Addressed: q13 hits the pulse CSV's per-arm Existing/New/Total splits exactly (Control 1/1/2, Mid 3/5/8, Deep 0/2/2), and q14 shows the specific users in each bucket — including the two `exposed_after_purchase` users whose exposure timestamps literally postdate their add-on events.
- **Q2 — What assumption, if wrong, would flip a conclusion?** That `first_exposures_wcpm_pricing_test.unit_id` is the right join key to `statsig_clickstream_events_etl_output.statsig_stable_id`. Both are UUID-shaped and the arm totals in q11c match the pulse CSV exactly (6,115 / 5,972 / 6,137) under that join — if the join were wrong the arm sizes wouldn't reconcile.
- **Q3 — Next obvious question?** "Why do 8 add-on purchasers never see the experiment?" Answered partially: the exposure trigger fires on some client-side surface that isn't on every path leading to WCPM add-on purchase. The remedy is a conversation with whoever wired the test (not a data bug). Flagged as awareness item.
- **Q4 — Intervention mismatches?** Finding 4 (late-arrival drop) is framed as STRUCTURAL and carries a concrete fix direction. Other findings are INFORMATIONAL. No framing mismatches.

## Message to Meredith (Slack-ready)

*WCPM Pricing Test — 27 vs 12*

Both numbers reconcile. They count different populations:
- Mixpanel 27 = everyone who purchased the WCPM add-on in the window
- Statsig 12 = users who were assigned to a test arm before they purchased

The 15-unit gap:

- *4* — purchases 03-09 through 03-12. Your date filter starts 03-13, but when the report renders in weekly buckets Mixpanel pulls the full week of 03-09 into the first row.
- *1* — a purchase that didn't land in the Statsig source data. Pipeline issue on my side; I've identified the user and event and will ship a fix.
- *8* — users who purchased WCPM and were never assigned to the test. Their paths to purchase didn't hit the experiment's exposure trigger.
- *2* — users assigned to the test after they had already purchased. Statsig attributes events to an arm only when the user was exposed before the event.

Per-arm within the 12:
- Control: 2 (1 existing subscriber, 1 new subscriber)
- Mid Reduction: 8 (3 existing, 5 new)
- Deep Reduction: 2 (0 existing, 2 new)

## Retractions

**Retracted 2026-04-18 after author pushback.**

- **Original Finding 1 (label inversion):** I claimed `add_on_purchase_existing_sub` / `_new_sub` were semantically inverted based on (a) the condition `abs(diff(event_ts, subs.created_at)) < 1 hour` firing when a chargebee subscription is freshly created and (b) my lay reading of "existing subscriber" as "user subscribed before the event." `subscription_periods.start_date` is indeed `chargebee_subscriptions_normalize.created_at` (line 70 of that model), so my mechanical read of the condition is right. But a chargebee subscription can be freshly created in cases that are not "new user in the lay sense" — e.g., an existing user changing plans, or an add-on bundled with a just-created subscription that belongs to a pre-existing account. I treated a semantic interpretation as a code bug without confirming the intended definition with the model's author. Retracted.
- **Original Finding 2 (Mixpanel filter misuse):** I claimed Meredith's report was filtering on `current_plan_id` and therefore returning 0. Meredith's filter values (the two WCPM plan slugs) appear in the `current_addons` column per q0b, and q2 confirmed `current_addons ILIKE '%warner%'` returns 23 distinct users — matching her 27 after subtracting 4 pre-experiment purchases. I invented the `current_plan_id` framing; nothing in Q1b said which column she was filtering on. Retracted.
- **Consequence:** The retracted claims do not survive. A *separate* STRUCTURAL finding (Finding 4 — late-arrival drop in the Statsig dbt model's incremental predicate) was substantiated later in the session via q17/q18 and stands on its own evidence; it is unrelated to the retracted claims.
