# Evergreen Lifecycle Email Flow — Proposal

**Prepared for:** Marketing
**Date:** 2026-03-25
**Prerequisite:** Initial ramp-up flows deployed and measuring (see `../retention_sizing/`)
**Data period:** Sep 2025–Feb 2026 (6-month trailing averages, rolling 30-day windows)

---

## 1. Summary

The initial ramp-up deploys one email series per segment as a static enrollment. The evergreen version replaces this with a continuous, state-aware system: subscribers enter and exit flows based on real-time segment transitions, with deduplication and suppression logic preventing redundant or unprofessional contact.

The transition data shows ~10,500 segment transitions each month across the four core plans. Without evergreen logic, these transitions create three problems:

1. **Stale flows**: A subscriber who re-engages mid-way through an Early Lapse series continues receiving "we miss you" emails despite being active again.
2. **Redundant enrollment**: A subscriber who completes an Early Lapse flow, re-engages briefly, then lapses again receives the same series a second time.
3. **Concurrent flows**: A subscriber transitioning from Active Browser → Early Lapse could theoretically be enrolled in both flows simultaneously.

---

## 2. Design Principles

1. **One active flow per contact at all times.** A subscriber is never enrolled in two lifecycle flows simultaneously.
2. **State changes override flow position.** If a subscriber's segment changes, they exit their current flow and are evaluated for enrollment in the new segment's flow.
3. **Cooldown prevents fatigue.** After completing or exiting a flow, a subscriber cannot re-enter the same flow for a minimum cooldown period.
4. **Priority hierarchy resolves conflicts.** When a subscriber is eligible for multiple flows, the highest-priority flow wins.
5. **Sunset is terminal (until re-engagement).** A subscriber who completes the Dormant sunset flow is suppressed from all lifecycle emails until they take an active session.

---

## 3. Flow Priority Hierarchy

When a subscriber's state changes and they are eligible for enrollment, flows are evaluated in priority order:

| Priority | Flow | Trigger | Rationale |
|----------|------|---------|-----------|
| 1 | Early Lapse Re-engagement | Transition to Early Lapse | Largest recoverable segment; time-sensitive window |
| 2 | Deep Lapse Win-back | Transition to Deep Lapse | Escalation from Early Lapse; lower but meaningful recovery |
| 3 | Dormant Sunset | Transition to Dormant | Final attempt before suppression |
| 4 | Active Browser Download Nudge | Classified as Active Browser for 2+ consecutive evaluations | Stable browsers — not transient |
| 5 | Active Downloader Value Reinforcement | Classified as Active Downloader for 2+ consecutive evaluations | Preventive; lowest urgency |

**Rule:** A higher-priority flow always preempts. If a subscriber is in the Value Reinforcement flow and transitions to Early Lapse, they exit Value Reinforcement and enter Re-engagement immediately.

---

## 4. Enrollment Triggers and Exit Conditions

### 4.1 Early Lapse Re-engagement

| | |
|---|---|
| **Enroll when** | Subscriber transitions to Early Lapse (no session in 30 days, last session 31-60 days ago) |
| **Exit (goal met)** | Subscriber has a session (returns to Active Downloader or Active Browser) |
| **Exit (escalation)** | Subscriber transitions to Deep Lapse (61+ days since last session) |
| **Series length** | 3 emails over 21 days |
| **Cooldown** | 60 days after exit before re-enrollment in this flow |

Monthly enrollment volume: ~3,400 subscribers transition into Early Lapse each month (from Active Downloader + Active Browser + new entrants).

Monthly early exit (goal met): ~3,300 Early Lapse subscribers recover to an active state each month.

**Implication:** Many subscribers will exit this flow early (within 1-2 emails) because they re-engage. The series should front-load the most impactful email.

### 4.2 Deep Lapse Win-back

| | |
|---|---|
| **Enroll when** | Subscriber transitions to Deep Lapse |
| **Exit (goal met)** | Subscriber has a session |
| **Exit (escalation)** | Subscriber transitions to Dormant (180+ days) |
| **Series length** | 2 emails over 30 days |
| **Cooldown** | 90 days after exit before re-enrollment |

Monthly enrollment volume: ~1,220 subscribers transition into Deep Lapse each month (primarily from Early Lapse, with small contributions from Active Downloader and Active Browser).

### 4.3 Dormant Sunset

| | |
|---|---|
| **Enroll when** | Subscriber transitions to Dormant |
| **Exit (goal met)** | Subscriber has a session |
| **Exit (terminal)** | Series completes → subscriber added to lifecycle suppression list |
| **Series length** | 2 emails over 14 days |
| **Cooldown** | No re-enrollment. Suppressed until active session occurs, then cooldown resets. |

Monthly enrollment volume: ~660 subscribers transition into Dormant each month.

### 4.4 Active Browser Download Nudge

| | |
|---|---|
| **Enroll when** | Subscriber classified as Active Browser for 2 consecutive evaluations (stability filter) |
| **Exit (goal met)** | Subscriber downloads 1+ song/SFX (transitions to Active Downloader) |
| **Exit (lapsed)** | Subscriber transitions to Early Lapse or beyond |
| **Series length** | 2 emails over 14 days |
| **Cooldown** | 30 days after exit before re-enrollment |

The 2-evaluation stability filter prevents enrolling subscribers who are briefly between downloads. Without it, a subscriber who downloads on Day 1 and Day 35 would be classified as Active Browser on the Day-30 evaluation and incorrectly enrolled.

### 4.5 Active Downloader Value Reinforcement

| | |
|---|---|
| **Enroll when** | Subscriber classified as Active Downloader for 2 consecutive evaluations |
| **Exit (lapsed)** | Subscriber transitions out of Active Downloader |
| **Series length** | 1 email (monthly cadence, not a series) |
| **Cooldown** | 30 days (natural cadence) |

This is a recurring monthly touchpoint, not a multi-email series. It sends once per month while the subscriber remains an Active Downloader.

---

## 5. Deduplication Rules

1. **Check before enrollment:** Before enrolling a subscriber in any flow, verify they are not currently active in another flow. If they are:
   - If the new flow has higher priority → exit current flow, enroll in new flow
   - If the new flow has equal or lower priority → do not enroll; remain in current flow

2. **Suppression list check:** Before any enrollment, verify the subscriber is not on the lifecycle suppression list (post-Dormant sunset). If suppressed, do not enroll unless they have had an active session since suppression.

3. **Cooldown check:** Before enrollment, verify the subscriber's last exit from this specific flow was more than the cooldown period ago.

4. **Evaluation order:** Process state changes in priority order (Early Lapse first, then Deep Lapse, etc.) to ensure the highest-priority flow always wins.

---

## 6. State Transition Volumes (Monthly Averages)

These drive the evergreen model's enrollment volume estimates. From the s2 transition matrix, aggregated across 4 core plans:

### Inflows (enrollment triggers)

| Transition | Avg/Month | Flow Triggered |
|-----------|----------|----------------|
| Active Downloader → Early Lapse | 2,134 | Re-engagement |
| Active Browser → Early Lapse | 1,264 | Re-engagement |
| Early Lapse → Deep Lapse (+ small AD/AB → DL) | 1,217 | Win-back |
| Deep Lapse → Dormant | 661 | Sunset |
| Stable Active Browser (2+ months) | ~500 est. | Download Nudge |
| Stable Active Downloader (2+ months) | ~2,600 est. | Value Reinforcement |

### Outflows (exit triggers — goal met)

| Transition | Avg/Month | Flow Exited |
|-----------|----------|-------------|
| Early Lapse → Active Downloader | 1,982 | Re-engagement (goal) |
| Early Lapse → Active Browser | 1,304 | Re-engagement (goal) |
| Deep Lapse → (any active state) | ~200 est. | Win-back (goal) |
| Active Browser → Active Downloader | 880 | Download Nudge (goal) |

### Self-retention (stay in segment)

| Segment | Stay Rate/Month | Implication |
|---------|----------------|-------------|
| Active Downloader → Active Downloader | 2,599 (45%) | Less than half stay; reinforcement may reduce outflow |
| Early Lapse → Early Lapse | 2,232 (33%) | Two-thirds exit each month; series must act fast |
| Deep Lapse → Deep Lapse | 1,202 (65%) | Majority remain; 2-email series has time |
| Dormant → Dormant | 1,566 (~100%) | No observed recoveries in transition data; sunset is appropriate |

---

## 7. Retention Model Differences from Ramp-Up

The ramp-up model uses static segment sizes as the denominator. The evergreen model uses **monthly transition volumes** as the enrollment denominator, because in the evergreen system, a subscriber is enrolled when they *enter* a segment, not because they *are in* a segment at a point in time.

Key model changes:

| Dimension | Ramp-Up | Evergreen |
|-----------|---------|-----------|
| Denominator | Segment size (point-in-time) | Monthly inflow into segment (transition volume) |
| Reach | All subscribers in segment | Only new entrants + re-entrants past cooldown |
| Early exit | Not modeled | Subscribers who re-engage exit early (reduced email volume) |
| Deduplication | Not modeled | Subscribers in a higher-priority flow are excluded |
| Series completion | Assumed 100% | Adjusted by early exit rate |

The accompanying `build_model.py` generates a workbook modeling these dynamics. To compare the evergreen and ramp-up revenue estimates, open both workbooks side by side — the ramp-up model shows the upper bound (all subscribers in segment reached), while the evergreen model shows the realistic steady-state (only new entrants, adjusted for cooldown and early exits).

---

## 8. Implementation Requirements

### HubSpot Workflow Design

Each flow requires:
1. **Enrollment trigger:** Contact property change (lifecycle_segment = X) OR custom event
2. **Goal criteria:** Contact property change indicating re-engagement or escalation
3. **Suppression list:** Static list of contacts who completed Dormant sunset
4. **Cooldown tracking:** Custom date property per flow (e.g., `last_exit_early_lapse`) checked at enrollment

### Data Pipeline Requirements

The segment classification must run on a recurring schedule (recommended: daily) and write the result to a contact property in HubSpot. This requires:

1. A scheduled Snowflake query evaluating each subscriber's segment using the rolling 30-day window logic
2. A sync mechanism pushing the `lifecycle_segment` property to HubSpot contacts
3. Change detection: only push when a subscriber's segment changes (to trigger enrollment workflows)

### Contact Properties Needed

| Property | Type | Purpose |
|----------|------|---------|
| `lifecycle_segment` | Enumeration | Current segment classification |
| `lifecycle_segment_previous` | Enumeration | Prior segment (for transition detection) |
| `lifecycle_segment_changed_at` | DateTime | When the last segment change occurred |
| `lifecycle_flow_active` | String | Name of currently active lifecycle flow (or empty) |
| `lifecycle_suppressed` | Boolean | Whether contact is on lifecycle suppression list |
| `last_exit_{flow_name}` | DateTime | Per-flow cooldown tracking (5 properties) |

---

## 9. Implementation Sequence

| Phase | Deliverable | Depends On |
|-------|-------------|------------|
| 1 | Daily segment classification query + HubSpot sync | Ramp-up flows deployed and measuring |
| 2 | HubSpot contact properties created | Phase 1 |
| 3 | Early Lapse Re-engagement workflow (highest priority, highest volume) | Phase 2 |
| 4 | Deep Lapse Win-back workflow | Phase 3 |
| 5 | Dormant Sunset workflow + suppression list | Phase 4 |
| 6 | Active Browser Download Nudge workflow | Phase 3 |
| 7 | Active Downloader Value Reinforcement workflow | Phase 3 |
| 8 | Monitoring dashboard: enrollment volumes, early exit rates, cooldown hits, suppression list size | Phase 3 |

---

## 10. Monitoring and Calibration

Once deployed, track these metrics to calibrate the model:

1. **Enrollment volume per flow per month** — compare to transition data estimates
2. **Early exit rate** — % of enrolled subscribers who exit before series completion (goal met)
3. **Cooldown hit rate** — % of potential enrollments blocked by cooldown
4. **Deduplication hit rate** — % of potential enrollments blocked by active concurrent flow
5. **Suppression list growth** — monthly additions to lifecycle suppression
6. **Re-engagement from suppression** — subscribers who return after sunset and re-enter the system

These metrics replace the ramp-up model's assumptions with observed data and should feed back into parameter updates.
