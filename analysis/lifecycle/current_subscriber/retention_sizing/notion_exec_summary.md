# Lifecycle Email Flow — Executive Summary

## The Problem

58% of active (paying) subscribers have not logged in within the last 30 days. The subscriber engagement analysis established that 81% of the decline in download activity is driven by fewer subscribers showing up — not by changes in behavior among those who do. There is no systematic email program targeting these lapsed subscribers.

> **Scope note:** This version is a **ramp-up design** — a one-time segmentation snapshot used to populate initial email flows. A future evergreen version will handle state-change triggers, deduplication, and continuous enrollment as subscribers move between segments.

## The Proposal

Classify every active subscriber into one of five lifecycle segments each month based on behavioral signals, and attach a targeted email flow to each:

> *Insert lifecycle_flow.png here*

| Segment | Avg Monthly Size | Email Flow | Priority |
|---------|-----------------|------------|----------|
| **Early Lapse** (31–60d inactive) | 9,974 (27%) | Re-engagement trigger | 1 |
| **Active Browser** (session in last 30 days, no downloads) | 3,732 (10%) | Download nudge | 2 |
| **Deep Lapse** (61–180d inactive) | 2,469 (7%) | Win-back campaign | 3 |
| **Active Downloader** (session in last 30 days + downloads) | 12,401 (34%) | Value reinforcement | 4 |
| **Dormant** (180d+ or never) | 8,177 (22%) | Final win-back or sunset | 5 |

## Retention Model

An adjustable Excel model (`retention_model.xlsx`) traces each flow through:

**Email funnel** (delivery → open → click) → **Re-engaged subscribers** → **Retained from churn** → **Revenue saved**

The model includes a "reminder churn" parameter for Deep Lapse and Dormant segments: a configurable estimate of the fraction of email openers who cancel after being reminded they have a subscription.

### What the Model Does

The model is a **scenario tool, not a forecast.** It provides a framework for evaluating each email flow's potential retention impact under a set of assumptions. All funnel parameters (delivery rate, open rate, click rate, retention rate, reminder churn rate) are adjustable inputs that need to be calibrated to Soundstripe's actual email performance data and refined as flows are deployed and measured.

Default parameter values are included as starting points for discussion. They are not empirically calibrated and should not be treated as predictions.

### Key Structural Observations

- **Early Lapse is the largest addressable segment** at ~10,000 subscribers/month, with ~32% recovering to an active state organically each month. This segment has no reminder churn risk, making it the most straightforward starting point.
- **Dormant and Deep Lapse segments require the most careful parameterization.** The reminder churn rate — which determines whether re-engaging these subscribers is net positive or negative — varies significantly by plan type. The model breaks this out by plan type so each can be evaluated independently.
- **Active Downloader and Active Browser flows** operate as retention reinforcement and conversion nudges respectively. Neither carries reminder churn risk.

### How to Use the Model

1. Open `retention_model.xlsx` — the model is a single sheet
2. Adjustable parameters are in blue cells at the top
3. Adjust parameters based on Marketing's email benchmarks or hypotheses
4. Review the net impact summary by plan type and by segment below the inputs

## Data Basis

- Total subscriber base: ~36K (excl. enterprise)
- Segment sizes: 6-month trailing averages (Sep 2025–Feb 2026)
- Source: `soundstripe_prod.core.fct_sessions` + `subscription_periods`
- Transition rates: 6-month average monthly flows between segments
- ARPU: current active subscriber revenue by plan
- Implied remaining months: derived from 6-month average monthly churn rate (1 / churn rate, capped at 60 months) — a directional estimate, not a survival analysis

## Next Steps

1. Review model parameters and calibrate to Soundstripe's email performance benchmarks
2. Evaluate Dormant/Deep Lapse strategy by plan type — the risk/reward profile differs substantially across plans
3. Prioritize Early Lapse re-engagement flow for MVP build
4. Instrument flows in HubSpot and measure against model projections to refine parameters
5. Design evergreen version with state-change handling and deduplication
