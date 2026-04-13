---
status: draft
domain: data-health
date: 2026-04-01
author: d7admin
---

# March Conversion Rate Correction: Domain Consolidation Impact

## Context

Between 03/05 and 03/25, pre-rendering cache clears and Google crawl resubmissions tied to the domain consolidation rollout generated ~200K+ automated sessions that were classified as Direct traffic. These sessions inflated the session denominator in all conversion rate calculations, making March site performance appear worse than reality. Engineering confirmed the root cause on 2026-04-01 (see `2026-04-01-direct-traffic-spike.md`). Data normalized on 03/26.

## Correction Methodology

Sessions matching the artifact signature were excluded to produce a corrected denominator:
- Chrome browser, Direct channel, bounced (1 pageview), session duration under 20 seconds
- Landing on `www.soundstripe.com` or `app.soundstripe.com`
- Only during the affected window (03/05-03/25)

This filter removes the most severe distortion but also catches some legitimate short-bounce sessions. The corrected rates below represent an **upper bound** — the true rate falls between the reported and corrected values. Pre-03/05 and post-03/25 data is unaffected.

## Weekly Summary

| Week | Reported Sessions | Corrected Sessions | Excluded | Reported Signup Rate | Corrected Signup Rate | Reported Sub CVR | Corrected Sub CVR |
|------|------------------:|-------------------:|---------:|--------------------:|---------------------:|----------------:|-----------------:|
| 03/01-03/04 | 65,452 | 65,452 | 0 | 2.83% | 2.83% | 0.12% | 0.12% |
| 03/05-03/11 | 128,645 | 74,561 | 54,021 | 2.39% | 4.08% | 0.08% | 0.13% |
| 03/12-03/18 | 202,885 | 89,099 | 113,786 | 1.42% | 3.09% | 0.07% | 0.14% |
| 03/19-03/25 | 159,661 | 80,414 | 79,247 | 2.16% | 3.90% | 0.09% | 0.17% |
| 03/26-03/31 | 109,206 | 109,206 | 0 | 3.01% | 3.01% | 0.13% | 0.13% |

## Interpretation

The reported data shows signup rates dropping to 1.4% in the week of 03/12-03/18 and subscription CVR dropping to 0.07%. These numbers are artificial — the denominator was inflated by automated traffic.

The corrected data shows March conversion rates were consistent with or slightly above the early-March baseline throughout the month. The post-03/26 data (unaffected by either the contamination or the correction filter) shows signup rates at 3.01% and sub CVR at 0.13%, which is consistent with the pre-consolidation baseline.

**For Q1 reporting:** conversion rate metrics for the 03/05-03/25 window should be treated as unreliable. The corrected rates provide directional guidance but are not precise. The clean periods (03/01-03/04 and 03/26-03/31) are the most trustworthy indicators of March site performance, and both show rates in the 2.8-3.0% signup rate / 0.12-0.13% sub CVR range.

## Related

- [Signal Detection: Direct Traffic Spike](2026-04-01-direct-traffic-spike.md) — root cause investigation
- Engineering validation: Luke Capizano, 2026-04-01 (pre-rendering cache clears + Google crawl resubmissions)
