# Lifecycle Email Flow — Proposal & Retention Model

## Overview

This proposal defines a data-backed subscriber lifecycle email framework and models its retention impact. Subscribers are classified into five behavioral segments using rolling 30-day windows based on session activity and download behavior. Enterprise subscribers are excluded. Each segment maps to a targeted email flow designed to retain or re-engage subscribers.

The underlying engagement analysis established that 81% of the decline in subscriber download activity is attributable to fewer subscribers logging in — not to changes in behavior among those who do. The lifecycle email flows target this "showing-up problem" directly.

---

## Lifecycle Segments

Each active subscriber (excluding enterprise) is classified using rolling 30-day windows based on session activity and download behavior.

| Segment | Definition | Avg Monthly Size | % of Base |
|---------|-----------|-----------------|-----------|
| **Active Downloader** | Session in last 30 days + downloaded 1+ song/SFX | 12,401 | 33.6% |
| **Active Browser** | Session in last 30 days + no downloads | 3,732 | 10.1% |
| **Early Lapse** | No session in 30 days; last visit 31–60 days ago | 9,974 | 27.0% |
| **Deep Lapse** | No session in 30 days; last visit 61–180 days ago | 2,469 | 6.7% |
| **Dormant** | No session; last visit 180d+ or never | 8,177 | 22.2% |

**Total active subscriber base: ~36K avg/month** (excl. enterprise; 6-month trailing average, Sep 2025–Feb 2026)

5 segments are mutually exclusive and exhaustive. The classification follows a decision tree — see the flow diagram below.

---

## Flow Diagram

> *Insert lifecycle_flow.png here*

The diagram reads top-to-bottom. Each subscriber enters at the top and is classified through behavioral gates into exactly one segment. Each segment has an associated email touchpoint (dashed yellow boxes).

---

## Segment Distribution by Plan Type

| Segment | Business | Pro Plus | Pro | Personal |
|---------|----------|----------|-----|----------|
| Active Downloader | ~57% | ~47% | ~37% | ~22% |
| Active Browser | ~13% | ~12% | ~10% | ~9% |
| Early Lapse | ~20% | ~25% | ~31% | ~35% |
| Deep Lapse | ~3% | ~4% | ~5% | ~8% |
| Dormant | ~3% | ~12% | ~17% | ~26% |

Business has the highest active rate (~70%). Personal has the lowest — only ~31% of Personal subscribers had a session in the last 30 days, with 26% Dormant.

---

## Proposed Email Flows

### 1. Active Downloader — Value Reinforcement

**Goal:** Retention, reduce transition to Early Lapse

Each month, ~2,200 Active Downloaders transition to Early Lapse. Reinforcing value may reduce this outflow.

- Monthly usage summary
- New releases matching download history
- Feature discovery

### 2. Active Browser — Download Nudge

**Goal:** Convert browsing to downloading

3,700+ subscribers log in monthly but don't download — 24% of all visitors.

- Curated content based on browsing/search behavior
- Direct download CTAs with preview

### 3. Early Lapse — Re-engagement Trigger (31–60d)

**Goal:** Recover before further disengagement

~10,000 subscribers in this segment at any time. From transition data, ~3,200/month recover to an active state — re-engagement is achievable in this window.

- "What's new" since last visit
- Personalized content recommendation
- Seasonal/trending content

### 4. Deep Lapse — Win-back Campaign (61–180d)

**Goal:** Win back or flag for retention

~2,500 subscribers. Recovery rate is lower but volume is meaningful.

- Major additions since last visit
- Plan value reminder
- Direct CTA

### 5. Dormant — Final Win-back or Sunset (180d+)

**Goal:** Final re-engagement attempt or sunset

~8,200 subscribers (22% of base). This segment carries "reminder churn" risk — re-engagement emails may prompt cancellations from subscribers who forgot they were paying.

- Final value proposition
- Plan change/pause options
- Sunset if no engagement (preserve sender reputation)

---

## Retention Sizing Model

A single-sheet Excel workbook (`retention_model.xlsx`) models the revenue impact of these flows with adjustable parameters. Email funnel parameters are a single set across all plans.

### Model Structure

For each segment:

```
Segment Size × Delivery Rate × Open Rate × Click Rate = Re-engaged Subscribers
Re-engaged × Retention Rate = Subscribers Saved from Churning (Gross)
Opened × Reminder Churn Rate = Subscribers Lost (Deep Lapse/Dormant only)
Net Retained = Gross - Reminder Churn
Revenue Impact = Net Retained × ARPU × Remaining Months
```

### Default Assumptions

| Parameter | Active DL | Active Browse | Early Lapse | Deep Lapse | Dormant |
|-----------|-----------|---------------|-------------|------------|---------|
| Delivery | 95% | 95% | 95% | 93% | 90% |
| Open Rate | 25% | 28% | 22% | 15% | 10% |
| Click Rate | 8% | 12% | 8% | 5% | 3% |
| Retention Rate | 15% | 20% | 20% | 10% | 5% |
| Reminder Churn | 0% | 0% | 0% | 5% | 10% |

### Important: Model Parameters Are Not Calibrated

The default values above are starting points for discussion, not empirically calibrated predictions. In particular:

- **Retention Rate** (the fraction of clickers saved from churning) requires calibration against actual email performance data once flows are deployed. The defaults are directional estimates.
- **Reminder Churn Rate** for Deep Lapse and Dormant determines whether those flows are net positive or negative. This parameter varies significantly by plan type — a Business subscriber has a fundamentally different risk/reward profile than a Personal subscriber at \$12.62/month.
- **Implied Remaining Months** is derived from the 6-month average monthly churn rate (1 / churn rate, capped at 60 months). This is a directional heuristic, not a survival analysis. It does not account for billing cycle effects (annual subscribers can only churn at renewal), tenure-dependent churn rates, or the difference between voluntary and involuntary churn. It should be treated as an order-of-magnitude estimate for the purpose of comparing scenarios, not as a precise lifetime value projection.

All parameters are adjustable in the workbook. Marketing should model multiple scenarios by changing the blue input cells and evaluating the outputs by plan type.

---

## Implementation Priority

| Priority | Flow | Segment Size | Rationale |
|----------|------|-------------|-----------|
| 1 | Re-engagement Trigger | ~10,000 | Largest recoverable segment; ~32% monthly recovery rate |
| 2 | Download Nudge | ~3,700 | Already visiting — lowest friction conversion |
| 3 | Win-back Campaign | ~2,500 | Lower recovery but meaningful volume |
| 4 | Value Reinforcement | ~12,400 | Preventive; reduces inflow to Early Lapse |
| 5 | Dormant Sunset | ~8,200 | Largest segment; requires careful parameterization by plan type before deployment |

---

## Scope: Ramp-Up vs Evergreen

This deliverable covers the **initial ramp-up** version of the lifecycle email program.

**Initial Ramp-Up (this version):**
- Each segment gets one email flow series
- Subscribers classified and enrolled once per evaluation
- No mid-flow segment transition handling
- No deduplication logic between flows
- Goal: deploy flows, measure performance, calibrate funnel parameters

**Evergreen Version (future):**
- Must handle segment state changes mid-flow (e.g., Early Lapse subscriber re-engages → exit lapse flow)
- Deduplication: one active flow per contact at a time — no concurrent enrollment
- Re-entry rules: cooldown period before re-enrollment in a completed flow
- Suppression rules: handling contacts who completed the Dormant sunset flow and later re-engage
- Requires workflow design with enrollment triggers, goal criteria (exit conditions), and suppression lists

---

## Methodology

- **Segment sizes:** 6-month trailing averages (Sep 2025–Feb 2026) from `soundstripe_prod.core.fct_sessions` and `soundstripe_prod.core.subscription_periods`. Averages are used rather than single-month snapshots to reduce noise from seasonal variation and billing cycle effects.
- **Active subscriber:** Subscription period overlaps the calendar month (start_date ≤ last day of month AND (cancelled_at IS NULL OR cancelled_at ≥ first day of month)). Enterprise subscribers are excluded from the model.
- **New subscribers** (tenure < 30 days) are excluded from this program. They are handled separately outside lifecycle flows.
- **Segment classification** uses rolling 30-day windows: a subscriber is "active" if they had a session in the last 30 days, regardless of calendar month boundaries.
- **Visitor:** Active subscriber with at least one session in the last 30 days
- **Download:** Downloaded 1+ song or sound effect in the last 30 days (downloaded_songs_count + downloaded_sound_effects_count > 0)
- **Transition data:** Month-over-month segment reclassification, averaged over 6 months (Sep 2025–Feb 2026)
- **ARPU:** Average monthly revenue per subscriber by plan type (Business, Pro Plus, Pro, Personal), from `subscription_periods.monthly_revenue` (already normalized to monthly).
- **Implied remaining months:** Derived from the 6-month average monthly churn rate as 1 / churn_rate, capped at 60 months. This is a simplifying heuristic that assumes a constant churn rate and does not account for: (a) billing cycle constraints (annual subscribers can only churn at renewal), (b) tenure-dependent churn rates (long-tenured subscribers churn at different rates than new ones), or (c) the distinction between voluntary and involuntary churn. It provides a directional order-of-magnitude for comparing scenarios within the model, not a precise lifetime value projection. A proper conditional remaining tenure analysis (survival-based) would be needed to ground this input more rigorously.
