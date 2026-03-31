# Lifecycle Email Flow — MVP Proposal

**Prepared for:** Marketing
**Date:** 2026-03-24
**Data period:** Feb 2026 (segment sizes), Sep 2025–Feb 2026 (transition averages)
**Source:** `soundstripe_prod.core.fct_sessions`, `soundstripe_prod.core.subscription_periods`

---

## 1. Summary

This proposal defines a five-stage subscriber lifecycle framework and recommends an MVP set of email flows mapped to each stage. Segment definitions are derived from observed behavioral patterns in Snowflake session data. Each segment is sized with Feb 2026 subscriber counts. Enterprise subscribers are excluded from this framework (handled by Sales/AM). New subscribers are also out of scope — the existing onboarding flow covers that stage.

The core finding from the underlying engagement analysis — that 81% of the decline in subscriber download activity is attributable to fewer subscribers logging in, not to changes in behavior among those who do — shapes the flow design: the highest-volume intervention opportunity is in the lapsing and lapsed segments, where ~20,000 paying subscribers have not visited in 30+ days.

### Scope

This proposal covers two types of flows: **ramp-up** (triggered once when a subscriber enters a segment, e.g., re-engagement and win-back) and **evergreen** (recurring on a schedule for subscribers who remain in a segment, e.g., value reinforcement and download nudge). The distinction matters for implementation — ramp-up flows fire on segment transition, while evergreen flows run on a cadence for the duration of segment membership.

---

## 2. Lifecycle Segments

Each active subscriber (excluding enterprise) is classified on a rolling basis using two behavioral signals: session activity in the last 30 days and recency of last session.

| # | Segment | Definition | Feb 2026 Count | % of Base |
|---|---------|-----------|---------------|-----------|
| 1 | **Active Downloader** | Session in last 30 days + downloaded 1+ song or SFX | 10,670 | 31.3% |
| 2 | **Active Browser** | Session in last 30 days + zero downloads | 3,322 | 9.7% |
| 3 | **Early Lapse** | No session in last 30 days; last session 31–60 days ago | 7,670 | 22.5% |
| 4 | **Deep Lapse** | No session in last 30 days; last session 61–180 days ago | 3,274 | 9.6% |
| 5 | **Dormant** | No session in last 30 days; last session 180+ days ago or never | 9,064 | 26.6% |

**Total active subscribers (non-enterprise, all core plans): 34,000**

The classification is mutually exclusive and exhaustive — every active non-enterprise subscriber falls into exactly one of the five segments.

---

## 3. Segment Distribution by Plan Type

| Segment | Business | Pro Plus | Pro | Personal |
|---------|----------|----------|-----|----------|
| Active Downloader | 49.4% | 44.7% | 34.8% | 18.8% |
| Active Browser | 18.7% | 12.8% | 10.0% | 8.7% |
| Early Lapse | 18.7% | 19.7% | 23.1% | 22.7% |
| Deep Lapse | 8.4% | 7.3% | 9.1% | 11.5% |
| Dormant | 3.6% | 15.3% | 22.5% | 37.9% |
| **Active rate** | **68.1%** | **57.5%** | **44.8%** | **27.5%** |

Enterprise subscribers are excluded from this framework (handled by Sales/AM). Among the remaining plans, Business has the highest proportion of active subscribers. Personal (Creator) has the lowest — only 27.5% of Personal subscribers had a session in Feb 2026, and 37.9% are Dormant. Pro sits in the middle at 44.8% active.

These differences should inform plan-specific email content and cadence.

---

## 4. Proposed Email Flows

### 4.1 Active Downloader — Value Reinforcement

**Trigger:** Subscriber classified as Active Downloader for 2+ consecutive months
**Goal:** Retention, expanded usage, reduce transition to Early Lapse
**Cadence:** 1–2 emails/month

Supporting data: Each month, an average of 2,091 Active Downloaders transition to Early Lapse (across all core plans). Reinforcing the value of active subscribers' usage may reduce this outflow.

**Recommended content:**
- Monthly usage summary ("You downloaded X songs this month")
- New releases aligned with their download history
- Feature discovery (SFX library, custom playlists, licensing guides)

---

### 4.2 Active Browser — Download Nudge

**Trigger:** Subscriber classified as Active Browser (session but no downloads)
**Goal:** Convert browsing to downloading
**Cadence:** 1–2 emails/month

Supporting data: 3,322 subscribers log in each month but do not download. This is 24% of all visitors. Among visitors who do download, 73.7% downloaded at least one song — the gap between "showing up" and "getting value" is the target.

**Recommended content:**
- Curated content based on browsing behavior (search terms, genres viewed)
- "Songs you might have missed" based on session activity
- Direct download CTAs with preview

---

### 4.3 Early Lapse — Re-engagement Trigger

**Trigger:** No session in 30 days (subscriber transitions from active to Early Lapse)
**Window:** 31–60 days since last session
**Goal:** Recover before the subscriber disengages further
**Cadence:** 2–3 emails over the 30-day window

Supporting data: 7,670 subscribers are in Early Lapse at any given time. From the transition data, an average of 1,790 Early Lapse subscribers per month recover to Active Downloader or Active Browser — demonstrating that re-engagement is achievable in this window. However, 969/month progress to Deep Lapse.

**Recommended content:**
- "We miss you" + what's new since their last visit (new releases, features)
- Personalized content recommendation based on past downloads/searches
- Time-sensitive content (trending songs, seasonal collections)

---

### 4.4 Deep Lapse — Win-back Campaign

**Trigger:** Subscriber transitions from Early Lapse to Deep Lapse (61+ days since last session)
**Window:** 61–180 days since last session
**Goal:** Win back or identify churn risk for retention team
**Cadence:** 1–2 emails

Supporting data: 3,274 subscribers are in Deep Lapse. Recovery from this stage is lower — data from the lapse-and-return analysis shows that return probability decreases with gap length. 623 subscribers per month progress from Deep Lapse to Dormant.

**Recommended content:**
- "A lot has changed" — highlight major additions since their last visit
- Plan value reminder (cost per download, licensing coverage)
- Direct CTA to browse or re-engage

---

### 4.5 Dormant — Final Win-back or Sunset

**Trigger:** Subscriber classified as Dormant (180+ days or never visited)
**Window:** One-time or very low frequency
**Goal:** Final re-engagement attempt or sunset (stop emailing to preserve sender reputation)

Supporting data: 9,064 subscribers (26.6%) are Dormant. This is the largest single segment. Among these, 422 have never had a session at all. The Dormant segment is heavily weighted toward Personal plan subscribers (3,851 of the 9,064).

**Recommended content:**
- Final value proposition email
- "Is this still the right plan for you?" — opportunity to surface downgrade, pause, or plan change options
- If no engagement after final attempt, move to sunset (suppress from marketing emails)

---

## 5. Key Data Points for Sizing

These monthly averages (trailing 6 months) size the flows between segments:

| Transition | Avg/Month | Interpretation |
|-----------|----------|---------------|
| Active Downloader → Early Lapse | 2,234 | Largest decay flow |
| Active Browser → Early Lapse | 1,432 | |
| Early Lapse → Active Downloader | 1,790 | Recovery (re-engagement works) |
| Early Lapse → Active Browser | 1,444 | Partial recovery |
| Early Lapse → Deep Lapse | 969 | Decay continues |
| Deep Lapse → Dormant | 623 | Terminal decay |
| Active Downloader ↔ Active Browser | ~1,150/819 | Fluid boundary between active states |

The largest single monthly flow is Active Downloader → Early Lapse at 2,234/month. This is the primary leakage point and the strongest argument for the Re-engagement Trigger (§4.3).

---

## 6. Implementation Priority

Based on segment size and potential impact:

| Priority | Flow | Segment Size | Rationale |
|----------|------|-------------|-----------|
| 1 | Re-engagement Trigger | 7,670 | Largest recoverable segment; 42% return rate from Early Lapse |
| 2 | Download Nudge | 3,322 | Already visiting — lowest friction conversion |
| 3 | Win-back Campaign | 3,274 | Lower recovery rate but still meaningful volume |
| 4 | Value Reinforcement | 10,670 | Preventive; reduces inflow to Early Lapse |
| 5 | Dormant Sunset | 9,064 | Large segment but lowest recovery probability |

---

## 7. Methodology

**Segment classification:** Each non-enterprise subscriber is assigned to exactly one segment on a rolling 30-day window basis using the decision tree in the accompanying flow diagram. Classification order: (1) session in last 30 days + downloads → Active Downloader, (2) session in last 30 days + no downloads → Active Browser, (3) no session in last 30 days + last session 31–60 days ago → Early Lapse, (4) no session in last 30 days + last session 61–180 days ago → Deep Lapse, (5) no session in last 30 days + last session 180+ days ago or never → Dormant. Enterprise subscribers are excluded entirely — their engagement is managed by Sales/AM.

**Active subscriber definition:** Subscription period overlaps the calendar month (start_date ≤ last day of month AND (cancelled_at IS NULL OR cancelled_at ≥ first day of month)).

**Visitor definition:** Active subscriber with at least one session in the calendar month.

**Download definition:** Downloaded at least 1 song or sound effect (downloaded_songs_count + downloaded_sound_effects_count > 0).

**Transition data:** Computed by tracking each subscriber's segment classification month over month across Sep 2025–Feb 2026 (6 months), then averaging.

---

## 8. Accompanying Materials

| File | Description |
|------|-------------|
| `lifecycle_flow_all.png` | Aggregate flow diagram — all core plans |
| `lifecycle_flow_business.png` | Business plan flow diagram |
| `lifecycle_flow_creator.png` | Personal (Creator) plan flow diagram |
| `lifecycle_flow_pro.png` | Pro plan flow diagram |
| `lifecycle_flow_pro_plus.png` | Pro Plus plan flow diagram |
| `segment_sizing.sql` | Snowflake queries (S1: monthly sizes by plan, S2: transition matrix) |
| `discovery_queries.sql` | Exploratory queries used to determine segment boundaries |
| `s1.csv` / `s2.csv` | Raw query results |

**Note:** The enterprise flow diagram (`lifecycle_flow_enterprise.png`) has been removed — enterprise subscribers are excluded from this framework.
