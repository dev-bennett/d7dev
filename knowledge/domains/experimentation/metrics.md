# Experimentation Metrics

Last updated: 2026-04-20
Author: d7admin (revised by Devon Bennett 2026-04-20)

## Pulse-undercount caveat (open, 2026-04-20)

Every metric below is read from Statsig Pulse, which applies Enforced 1:1 identifier mapping to the exposed population. Post-domain-consolidation stable_id sprawl currently causes ~13.5% of logged-in exposed user_ids to be dropped across `wcpm_pricing_test` (see `identifier-mapping-and-exclusions.md`). Until that finding is resolved, treat Pulse totals and per-arm counts as lower bounds, and treat arm-level comparisons as potentially biased if sprawl rates differ across arms. Stakeholder readouts for any Statsig-sourced metric should include this caveat explicitly.

## User-Level Experiment Metrics

| Metric | Definition | Source | Keyed On |
|--------|-----------|--------|----------|
| Exposure rate | Sessions with Statsig exposure event / total sessions | fct_events | statsig_stable_id |
| Signup conversion rate | Sessions with signup / exposed sessions | fct_sessions | statsig_stable_id |
| Subscription conversion rate | Sessions with created_subscription / exposed sessions | fct_sessions | statsig_stable_id |
| Transaction conversion rate | Sessions with any purchase / exposed sessions | fct_sessions | statsig_stable_id |
| Pricing CTA value | Expected click value by plan selection | statsig_clickstream_events_etl_output | statsig_stable_id |

## SEO Experiment Metrics (page-level)

| Metric | Definition | Source | Keyed On |
|--------|-----------|--------|----------|
| Organic sessions | Distinct sessions where channel = Organic Search | fct_sessions | landing_page_url |
| Organic visitors | Distinct visitors from organic search | fct_sessions | landing_page_url |
| Impressions | Search result impressions | Google Search Console | page_url |
| Avg position | Mean search result position | Google Search Console | page_url |
| CTR | Clicks / impressions from search | Google Search Console | page_url |
| Signup rate (guardrail) | Signups / organic sessions per URL | fct_sessions | landing_page_url |
| Bounce rate (guardrail) | Bounced sessions / sessions per URL | fct_sessions | landing_page_url |

## Statistical Standards

- Minimum detectable effect: define per experiment before launch
- Confidence level: 95% (Statsig default)
- Use Statsig's built-in CUPED variance reduction when available
- Minimum experiment duration: use Statsig power analysis calculator
- SEO experiments: minimum 2-7 days for re-indexing signals; wait for plateau before reading results
