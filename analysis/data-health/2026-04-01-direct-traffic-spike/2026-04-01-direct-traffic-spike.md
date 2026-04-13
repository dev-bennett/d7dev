---
status: reviewed
domain: data-health
date: 2026-04-01
author: d7admin
severity: medium
---

# Signal Detection: Direct Traffic Spike Following Domain Consolidation

## Signal

Intermittent spikes in Direct channel sessions between 03/05 and 03/25, peaking at 75K sessions on 03/18 (vs ~7-8K baseline). Spikes are concentrated in Chrome, landing on www.soundstripe.com, with 98%+ bounce rates, ~15s avg duration, and near-1:1 session:visitor ratio. Non-Direct channels stable throughout.

## Detection Method

Ad hoc review of traffic source reporting.

## Investigation

### Confirmed Hypothesis: Fastly shield POP IP leakage into Mixpanel geo resolution

When www.soundstripe.com DNS moved to Fastly as part of domain consolidation, the Fastly proxy layer (shield POPs in Frankfurt/DE, Amsterdam/NL, Montreal/CA) appears to have replaced client IPs before Mixpanel resolved visitor geo. Evidence:

- **Geo shift:** DE sessions on www went from 27 (pre-consolidation) to 33,969 during peak spike -- a 1,258x increase. NL: 30 to 17,962 (599x). CA: 30 to 1,285 (43x). These are Fastly shield POP locations, not real user geos.
- **Timeline alignment:** Spike dates map to rollout phases in the domain consolidation PRD: 03/05 (initial DNS changes), 03/16-03/19 (consolidation go-live and 301 redirect activation), 03/24-03/25 (subsequent rollout adjustment).
- **Landing host shift:** app.soundstripe.com was the dominant Direct host pre-03/16 (4,400-6,400/day). By 03/19 it drops to 21 sessions as 301 redirects to www.soundstripe.com/library/* take effect.
- **Fix evidence:** Shield geo % drops from 85% on 03/25 to 2.4% on 03/26, suggesting a configuration fix was deployed (likely Phase 3 tool reconfiguration from the PRD).

### Secondary effect: Redirect chain session duplication

The 301 redirect from app.soundstripe.com to www.soundstripe.com/library/* likely created intermediate Mixpanel sessions on the origin host before the user reached the destination. On 03/17, app.soundstripe.com shows 43,181 sessions with 97.8% shield geo and 1.1s avg duration -- these are redirect artifacts, not real browsing sessions.

## Root Cause

Confirmed by engineering (Luke Capizano, 2026-04-01): the spikes are caused by a combination of two factors during the domain consolidation rollout:

1. **Pre-rendering service cache clears.** During the rollout window, the team was adjusting sitemaps and bot traffic handling. Each adjustment cleared the pre-rendered cache, triggering the pre-rendering service to re-scan every page in the sitemap. The ~15s avg session duration matches pre-render execution time. These pre-render requests originated from Fastly infrastructure (explaining the DE/NL/CA geo concentration at shield POP locations) and fired Mixpanel tracking on each page load.

2. **Google sitemap resubmissions and crawl cache clears.** New sitemaps were submitted to Google around the spike dates, and the crawled cache was cleared with Google as well. This triggered aggressive re-crawling that compounded with the pre-render traffic.

Both sources produced Chrome-identified, single-pageview, bounced sessions with no referrer -- classifying as Direct in the channel attribution waterfall. The geo concentration in DE/NL/CA reflects the infrastructure origin of these requests (Fastly shield POPs), not real user locations.

## Impact Assessment

- **Affected date range:** 03/05-03/25 (most severe: 03/16-03/25)
- **Excess Direct sessions:** ~160K+ over baseline for the period
- **Geo data:** Unreliable for Direct sessions during the affected window -- real user IPs were not captured
- **Post-03/26:** Data appears clean (shield geo back to baseline 2-6%)

## Recommended Actions

- **Retroactive correction:** Exclude or flag sessions matching the consolidation artifact signature (Chrome + Direct + www.soundstripe.com + bounced + shield POP geos) from trend analysis for the affected window
- **Documentation:** Note the affected date range in reporting context for Q1 close
- **Validation:** Confirm with engineering that the fix deployed ~03/25-03/26 addressed the X-Forwarded-For / Mixpanel IP resolution issue

## False Positive Assessment

Low probability this is noise. The timing, geo pattern, and behavioral signature are fully consistent with the domain consolidation rollout timeline and Fastly's shield POP architecture.
