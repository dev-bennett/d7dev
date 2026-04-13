# MQL Match Coverage Summary

Population: 254 distinct emails across weeks 02-23 through 03-30 (from Q2).

## Current State (deployed pipeline)

| Category | Emails | % |
|---|---|---|
| Tier 1/2 matched | 175 | 69% |
| Tier 3 only | 78 | 31% |
| Unmatched | 1 | <1% |

Tier 3 produces false positives (Q3 confirmed: every multi-distinct_id case is tier 3).

## Proposed Fixes

### Fix 1: Already deployed (current PR)

Expanded `enterprise_form_submissions` and `enterprise_form_view` in fct_sessions_build for `/brand-solutions`, `/agency-solutions`, and `CTA Form Submitted` on `/enterprise`. Added same patterns to dim_mql_mapping tier 1.

Recovers: MQLs whose form submission fires a Mixpanel event on those URLs with matching base_url within 120s. These are already tier-1 matched in the deployed pipeline.

### Fix 2: Pricing page — `Clicked Contact Sales` / `Enterprise Intent`

- Add to fct_sessions_build `enterprise_schedule_demo` aggregation
- Add to dim_mql_mapping `form_events_mixpanel` CTE
- Normalize `/library/pricing` → `/pricing` in base_url derivation

Recovers: ~50 tier-3-only emails. Q6b confirmed the event fires within seconds of HubSpot submission for these users.

### Fix 3: Widen tier 2 window from 120s to 300s

5 emails on `/music-licensing-for-enterprise` have page view events between 128s and 298s from the HubSpot submission. Users load the page, spend time filling out the form, HubSpot records the submission minutes later.

Recovers: 5 tier-3-only emails (brian.sostak, jhsaeger, patrick.r.morris, ryhendron4, sloaneodkinney).

### Fix 4: Broaden `CTA Form Submitted` URL filter

Currently: `CTA Form Submitted AND url ILIKE '%/enterprise%'`
Proposed: `CTA Form Submitted AND (url ILIKE '%/enterprise%' OR url ILIKE '%/api%')`

Recovers: 1 email (shetuwang@699pic.com — `CTA Form Submitted` / `Landing Page Hero` on `/api` at 2s).

## After All Fixes

| Category | Emails | % |
|---|---|---|
| Tier 1/2 matched | ~231 | 91% |
| Genuinely untrackable | ~22 | 9% |
| Tier 3 needed | 0 | 0% |

The 22 untrackable emails break down as:

- **10 meetings-only**: HubSpot form submitted on `meetings.hubspot.com`. Mixpanel does not track that domain. No Mixpanel event exists on any URL within 300s. These users reached the meetings link without going through a Mixpanel-instrumented enterprise page (direct link from sales rep, email, etc.).

- **12 enterprise page with zero Mixpanel signal**: HubSpot form submitted on `/music-licensing-for-enterprise` or `/enterprise`. Q8 confirmed: no Mixpanel event of any kind on that URL within 300s. The Mixpanel JS did not execute — ad blocker, browser privacy settings, or JS error.

## Why We Can't Get Closer

1. **Meetings MQLs (10)**: The submission happens on `meetings.hubspot.com`, a HubSpot-hosted domain. We do not control Mixpanel instrumentation on that domain. The existing `enterprise_schedule_demo` click captures users who click through from a Soundstripe enterprise page — but these users bypassed the Soundstripe site entirely. No pipeline change can create a Mixpanel event that didn't fire.

2. **Enterprise page with no JS execution (12)**: Q8 searched for ANY Mixpanel event (no event filter, no identity requirement) on the matching URL within ±300s and found nothing. Mixpanel requires JavaScript execution in the browser. If the user's browser blocks third-party scripts (ad blocker, privacy extension, corporate firewall), no Mixpanel event is generated. The HubSpot form uses server-side submission (independent of Mixpanel JS), so HubSpot records the lead while Mixpanel has no record of the visit.

Both gaps are structural: they exist at the instrumentation boundary, not the matching logic. No query-side or model-side change can recover data that was never collected.
