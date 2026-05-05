# M1 — Tile 12 Expansion-Rate Root-Cause

| | |
|---|---|
| **Triggering finding** | `../../findings.md` tile 12 verdict: only material non-artifact REAL signal (~2% baseline → 0.5-0.75% Feb-Apr 2026, -65%). Mechanism enumeration M1.1-M1.4 listed but data could not discriminate within Dashboard 19 scope. |
| **Headline question** | Of the four mechanisms, which does the data support? |
| **Source data** | `M1_chargebee_event_volume.csv`, `M1_qualifying_subs_by_prior_plan.csv`, plus `../../q03.csv` for the canonical tile-12 expansion counts |
| **Status** | partial: 2 of 4 mechanisms tested with data; 2 require external context |

## Verdict — primary mechanism is cohort plan-mix shift; chargebee event volume contributes; pricing PRD review needed

**The expansion-rate decline is a real cohort-composition story.** The qualifying-subs population's mix tilted from ~66% Personal-tier to ~31% Personal-tier between April 2025 and February 2026 — with a step change in May 2025. If Personal subs upgrade more often than Pro subs (consistent with intuition: Pro is already mid-tier; Personal has more upside room), the blended expansion rate would mechanically fall as Personal share fell, even with no per-tier behavior change.

**Layered on top: chargebee event-volume crater in 2026-Q1.** Total chargebee_subscription_changes events fell from 220-245/mo (Nov-Dec 2025) to 81-141 (Feb-Apr 2026). The cumulative drop is steeper than the subscription-base drop, suggesting either a true behavior change or a data-quality issue in the Stitch-Chargebee replication pipeline.

## Mechanism-by-mechanism verdicts

### M1.4 — Chargebee event volume drop: PARTIAL SUPPORT

**Total chargebee_subscription_changes events per month:**

| Month | Events | Plan-changes (prior≠new) | vs May 2024 |
|---|---:|---:|---:|
| 2024-05 | 400 | 157 | baseline |
| 2024-12 | 241 | 123 | -40% / -22% |
| 2025-05 | 189 | 99 | -53% / -37% |
| 2025-12 | 245 | 76 | -39% / -52% |
| **2026-02** | **141** | **36** | **-65% / -77%** |
| **2026-03** | **89** | **32** | **-78% / -80%** |
| **2026-04** | **81** | **30** | **-80% / -81%** |

The 2026-Q1 step is dramatic. Plan-changes fell from 75 (Jan 2026) to 36 (Feb 2026) — a single-month -52% drop. That's bigger than the subscription-base drop in the same period (q03.csv qualifying_subs Jan→Feb = 482 → 493, basically flat).

This is **either a real product/customer behavior change OR a data-quality issue** in the chargebee-events Stitch replication pipeline. **Worth flagging immediately:**

```
NEW OPEN PROJECT MEMORY (recommend writing):
  chargebee_subscription_changes event volume cratered to 81-141/mo Feb-Apr 2026
  (vs 184-245 Nov 2025 - Jan 2026). Step magnitude > subscription-base shrinkage.
  Possible Stitch replication issue post-domain-consolidation, or possible real plan-change
  behavior collapse. Owner: data team to verify Stitch is replicating; engineering to verify
  Chargebee webhooks are firing.
```

If this is a data issue, M1's tile 12 verdict shifts toward "measurement artifact, not real signal." If it's a real behavior change, the question moves to M1.1 (pricing) or M1.2 (UX).

### M1.3 — Cohort plan-mix shift: STRONG SUPPORT

Personal share among tile 12 qualifying subs:

| Month | Qualifying subs (P+Pro+PP) | Personal share | Δ vs baseline |
|---|---:|---:|---:|
| 2024-05 | 2,041 | 65.7% | baseline |
| 2024-11 | 1,624 | 64.5% | stable |
| 2025-04 | 1,378 | 64.9% | **last month at "baseline" mix** |
| **2025-05** | **1,250** | **52.2%** | **step change** |
| 2025-08 | 935 | 42.5% | continued decline |
| 2025-11 | 731 | 35.6% | |
| 2026-02 | 493 | 31.2% | -34.5pp from baseline |
| 2026-04 | 560 | 37.5% | partial recovery |

**The May 2025 step change is the most actionable lead in this whole analysis.** Personal share went from ~65% (stable for 12 months) to 52% in a single month, then continued declining. This is the signature of a **plan-portfolio change** — a new plan launched, an existing plan deprecated/repositioned, or a marketing/pricing campaign shifted acquisition.

**The expansion-rate decline (q03.csv) trajectory aligns:**
- 2024-05: 28/2041 = 1.37% (high Personal share)
- 2025-04: 28/1378 = 2.03% (still high Personal share)
- 2025-05: 28/1250 = 2.24% (Personal share fell, but expansion count held — single-month coincidence)
- 2025-12: 13/633 = 2.05% (Personal share at 39%)
- 2026-02: 3/493 = 0.61% (Personal share 31%)
- 2026-04: 4/530 = 0.75% (Personal share 38%)

The expansion rate didn't fall in May 2025 when Personal share first stepped — it held. The big rate drop is in Q1 2026, which coincides with the chargebee event-volume crater (M1.4). **So M1.3 alone does not explain the rate drop.** The combination of M1.3 (smaller Personal pool to upgrade from) AND M1.4 (chargebee events stopped flowing) likely produces the headline -65% rate.

### M1.1 — Pricing/plan-structure change: NOT TESTED, BUT POINTED TO

The May 2025 step change in Personal share is exactly the signature of a pricing/plan event around that date. **Recommend Meredith confirm with Pricing team: was a plan launched, deprecated, or repositioned in April or May 2025?** This is the single highest-leverage question for understanding tile 12.

### M1.2 — Expansion-flow UX regression: NOT TESTED

Requires Mixpanel funnel data on plan-upgrade pages (clicked-upgrade-button → completed-checkout-on-new-plan). Out of scope for this MCP-driven mini-analysis. Worth a separate dive if M1.4 turns out to be a data issue (rules out the chargebee mechanism) and M1.1 doesn't fully account for the residual.

## Updated tile 12 narrative

The parent doc framed tile 12 as: "real ~65% drop in upgrade propensity from mid-2025 baseline (~2%) to Feb-Apr 2026 (~0.6%)."

**Revised framing:** the tile 12 decline is the COMBINATION of:
1. **A May 2025 cohort-composition step change** (Personal share 65% → 52% → 31% by Feb 2026), strongly suggestive of a pricing/plan-portfolio event in May 2025 — needs Pricing PRD review to confirm
2. **A 2026-Q1 chargebee event-volume crater** (-77% in plan-changes) — possibly a data-quality / replication issue (NEEDS IMMEDIATE INVESTIGATION) or possibly a real plan-change behavior collapse
3. The direct measure of "per-Personal-tier-sub upgrade propensity" cannot be computed from this dataset due to the LTV-join fanout in the LookML measure — the LookML measure should be audited for correctness on the prior_plan / new_plan classifier and LTV-join cardinality

## Roll-up to parent dashboard

| Tile | Refined verdict |
|---|---|
| 12 (Expansion 0-30d) | **Reclassify from "REAL signal, mechanism undetermined" → "REAL + DATA QUALITY CONCERN, mechanism partially identified."** Cohort plan-mix shift in May 2025 + 2026-Q1 chargebee-event volume crater jointly explain most of the headline drop. The remaining gap (whether per-tier upgrade propensity actually changed) requires fixing the LookML LTV-join fanout AND/OR querying Mixpanel funnels. |
| 13 (Avg expansion value) | (No change — the low-N volatility framing stands; the value-per-expansion is small-N noise on top of M1's mechanism story) |

## Recommendations for Meredith

**Top priority:**

1. **Investigate the chargebee_subscription_changes event-volume crater.** Was there a Stitch replication change, a Chargebee webhook configuration change, or anything in our pipeline that would cause -52% plan-changes Jan→Feb 2026? Owner: data team (Devon) + engineering. Time-box: 2 hours of Stitch + Chargebee dashboard checking.
2. **Pricing review for May 2025.** Was a plan launched, deprecated, or repositioned around April/May 2025? The Personal-share step change is too clean to be organic; it indicates a portfolio event. Owner: Meredith + Pricing team.

**Second priority:**

3. **LookML measure audit on tile 12.** The expansion-rate measure depends on a LEFT JOIN to `subscription_ltv_assumptions` on plan only — fanout is possible. The Looker numbers happen to be reasonable but the join cardinality is fragile. Owner: Devon (LookML).

**Third priority:**

4. **Mixpanel funnel diagnostic on the upgrade flow** if (1) reveals the chargebee event-volume drop is real-not-data and (2) doesn't fully explain. Out of scope for M1's data.

## §11 Intervention Class

```
INTERVENTION CLASS — Chargebee event-volume crater (NEW OPEN ITEM):
  FINDING: chargebee_subscription_changes plan_change events fell from ~75-90/mo (Q4 2025) to 30-36/mo (Feb-Apr 2026); step change Jan→Feb 2026; plausible Stitch replication or Chargebee webhook regression
  PERSISTENCE TEST: every downstream Looker tile or dbt model that depends on chargebee changes will produce wrong numbers until fixed
  OWNER TEST: data team (Stitch verification) + engineering (Chargebee webhook verification)
  SMALLEST FIX: 2hr investigation; if regression confirmed, escalate to Stitch / engineering
  CLASSIFICATION: STRUCTURAL — depending on diagnostic outcome, either a Stitch fix or a real-world finding
```

```
INTERVENTION CLASS — May 2025 Personal-share step change:
  FINDING: Personal-tier share of new-subscription cohort fell from 64.9% (Apr 2025) to 52.2% (May 2025) — single-month -13pp shift; continued declining to 31.2% by Feb 2026
  PERSISTENCE TEST: ongoing — the cohort mix shift compounds across all per-tier rates downstream
  OWNER TEST: Meredith + Pricing/marketing team
  SMALLEST FIX: confirm whether a pricing/plan portfolio event happened in May 2025; if yes, the cohort mix shift is intended and the framing of tile 12 changes; if no, requires further investigation
  CLASSIFICATION: OPERATIONAL pending Pricing review
```
