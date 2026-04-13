---
domain: data-health
date: 2026-04-01
last-updated: 2026-04-01 11:00
---

# Checkpoint -- Direct Traffic Spike Investigation

## Completed
- Scaffold: task folder, CLAUDE.md chain, signal detection report, visitors.sql
- Q1: Daily sessions by channel (baseline established)
- Q2: Browser distribution spike vs baseline (Chrome identified as driver)
- Q3: Daily Direct sessions by browser (Chrome spike confirmed)
- Q4: Landing page host + bounce rate (www.soundstripe.com identified, 98% bounce on spike days)
- Q5: Raw entry channel (wasted round-trip -- code already answered this)
- Q6: Country distribution (DE/NL/CA concentration identified -- Fastly shield POPs)
- Q7: Daily host + shield geo % correlation (rollout timeline mapped from data)
- Q8: Pre vs peak geo comparison (DE 27 -> 33,969 confirmed shield POP IP leakage)
- Signal detection report updated with confirmed hypothesis
- Stakeholder Slack message drafted and approved

## Root Cause (Validated by Engineering)
Pre-rendering service cache clears during domain consolidation rollout caused the pre-renderer to re-scan every page in the sitemap repeatedly from Fastly infrastructure (DE/NL/CA shield POPs). Combined with Google sitemap resubmissions and crawl cache clears triggering aggressive re-crawling. Both sources fired Mixpanel, creating Chrome/Direct/bounced sessions. Fix stabilized ~03/25-03/26. Confirmed by Luke Capizano 2026-04-01.

## Pending
- Stakeholder review of Q1 conversion correction summary

## Deliverables
- `2026-04-01-q1-conversion-correction.md` — corrected weekly conversion rates for March with methodology and interpretation

## Key Context
- Domain consolidation PRD: domain_consolidation_prd.pdf in this folder
- Affected window: 03/05-03/25 (most severe: 03/16-03/25)
- Post-03/26 data appears clean
- Excess Direct sessions during window: ~160K+
