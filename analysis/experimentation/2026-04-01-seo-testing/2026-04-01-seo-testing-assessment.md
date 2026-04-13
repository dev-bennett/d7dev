---
status: draft
domain: experimentation
date: 2026-04-01
author: d7admin
---

# Technical Assessment: SEO A/B Testing via Statsig

## Objective

Enable marketing to run SEO experiments (starting with header copy variants on marketing pages) and measure organic search impact using Statsig's page-level testing methodology.

## How Statsig SEO Testing Works

Standard A/B tests randomize by user. SEO tests randomize by **page URL** — each URL is deterministically hashed into a variant bucket, so both crawlers and human visitors always see the same variant for a given URL. This is necessary because Googlebot must see a consistent page to index and rank it.

| Property | User-Level (current) | Page-Level (SEO, needed) |
|----------|---------------------|-------------------------|
| Randomization unit | `statsig_stable_id` | Canonical page URL |
| Assignment | JS SDK at page load | Template renderer or CDN edge |
| What crawlers see | Default (no experiment) | The assigned variant |
| Primary metrics | Conversion, engagement | Organic impressions, position, CTR, sessions |
| Metric key | `statsig_stable_id` | `page_url` |

Key requirement from Statsig: register `page_url` as a Custom Unit ID in Project Settings. The canonical URL is stripped of protocol and query params before hashing so assignment is stable.

Statsig recommends this for sites with 10K+ indexable URLs. Expect 2-7 days for initial re-indexing signals after launch; wait for the re-indexing plateau before reading results.

## Current Soundstripe Instrumentation

| Component | Status | Notes |
|-----------|--------|-------|
| Statsig account + proxy | Active | `ab.soundstripe.com` via Fastly |
| Statsig JS SDK on marketing pages | Exists | In HubSpot repo `<head>` scripts — verify active post-domain-consolidation |
| User-level experiment tracking | Active | `statsig_stable_id` in fct_events → `_external_statsig` clickstream model |
| `page_url` Custom Unit ID | Not configured | Needs registration in Statsig console |
| Variant serving at CDN/template layer | Not implemented | Fastly VCL or HubSpot template changes needed |
| Organic session metrics keyed on `page_url` | Not built | Needs new dbt model in `_external_statsig` schema |
| Google Search Console → Statsig | Not connected | Needed for impression/position/CTR metrics |

## Three Workstreams

### 1. Statsig Console Setup

**Owner:** Analytics
**Effort:** < 1 hour
**Dependencies:** None

- Register `page_url` as a Custom Unit ID in Statsig Project Settings → Custom Unit IDs
- Pre-register metrics in Statsig's metric catalog: organic sessions, organic visitors, signup rate, bounce rate — all keyed on `page_url`
- Create the SEO experiment: define URL targeting rules and header copy variants

### 2. Variant Serving

**Owner:** Engineering (Luke Capizano / domain consolidation team)
**Effort:** 1-3 days
**Dependencies:** Statsig console setup (workstream 1)

The variant must be served server-side or at the CDN edge so that Googlebot sees it on first render. Client-side JS swaps risk the crawler seeing the default content.

**Recommended: Fastly VCL edge**
- Fastly already fronts all `www.soundstripe.com` traffic (domain consolidation architecture)
- VCL hashes the canonical URL to determine variant bucket
- Injects variant-specific header copy into the HTML response before proxying to HubSpot
- Crawlers see the variant natively — no JS rendering dependency
- This is the "CDN edge function" approach referenced in Statsig's docs

**Fallback: HubSpot HubL template**
- HubSpot's server-side template language (HubL) can implement conditional rendering
- Would need a mechanism to pass the Statsig variant assignment to the template (e.g., via a custom module that hashes the URL and selects the variant)
- Avoids Fastly VCL complexity but adds HubSpot-side logic

**Verification before launch:**
- Confirm Statsig JS SDK is active on www.soundstripe.com post-domain-consolidation
- Confirm crawlers receive the variant in the raw HTML response (test with `curl` or Google's URL Inspection tool)

### 3. Metric Pipeline

**Owner:** Analytics / Data
**Effort:** 0.5-1 day
**Dependencies:** Statsig console setup (workstream 1)

**New dbt model** in `models/marts/_external_statsig/` materializing to the `_external_statsig` schema (where Statsig reads from Snowflake):

```sql
-- statsig_seo_experiment_metrics.sql
-- Daily organic session metrics by landing page URL for Statsig SEO experiments
SELECT landing_page_url AS page_url
    ,session_started_at::date AS metric_date
    ,COUNT(DISTINCT session_id) AS organic_sessions
    ,COUNT(DISTINCT distinct_id) AS organic_visitors
    ,SUM(CASE WHEN signed_up > 0 THEN 1 ELSE 0 END) AS signups
    ,SUM(CASE WHEN created_subscription > 0 THEN 1 ELSE 0 END) AS subscriptions
    ,SUM(bounced_sessions) AS bounced_sessions
    ,COUNT(DISTINCT session_id) AS total_sessions_denominator
FROM {{ ref("fct_sessions") }}
WHERE last_channel_non_direct = 'Organic Search'
GROUP BY 1, 2
```

This gives Statsig the primary metric (organic sessions per URL per day) and guardrail metrics (signup rate, bounce rate) from the same model.

**Google Search Console integration** is also needed for impression-level metrics (impressions, avg position, CTR). Options:
- Check if Statsig has a native GSC connector
- If not, build a separate pipeline: GSC API → Snowflake → `_external_statsig` schema

### SEO-Specific Guardrails

Per Statsig's methodology, monitor before making decisions:

| Guardrail | Source | What to watch |
|-----------|--------|---------------|
| Indexation delta | Search Console | Sharp drops = template bugs (noindex, broken canonicals) |
| Cannibalization | Search Console | Multiple URLs ranking for same query = diluted CTR |
| HTTP response mix | Fastly logs | Misconfigured redirects (410s, redirect chains) |
| Core Web Vitals | Search Console / Lighthouse | LCP & CLS regressions hurt rankings |
| Crawl budget | Fastly logs | Slow/bloated pages decrease crawl rate |

## Implementation Sequence

| Step | Owner | Effort | Dependency |
|------|-------|--------|------------|
| 1. Register `page_url` Custom Unit ID | Analytics | 10 min | None |
| 2. Verify Statsig JS SDK on www post-consolidation | Engineering | 30 min | None |
| 3. Decide variant serving approach (Fastly vs HubSpot) | Engineering + Analytics | Decision | Steps 1-2 |
| 4. Implement variant serving | Engineering | 1-3 days | Step 3 |
| 5. Build `statsig_seo_experiment_metrics` dbt model | Analytics | 0.5 day | Step 1 |
| 6. Connect GSC to Statsig (or build pipeline) | Analytics | 0.5-1 day | Step 1 |
| 7. Create experiment + define variants in Statsig | Analytics + Marketing | 1 hour | Steps 4-6 |
| 8. Launch, monitor guardrails, wait for re-indexing | All | 2-7+ days | Step 7 |

## Open Questions for Engineering

1. Can Fastly VCL modify the HTML response body (swap header text) at the edge before proxying to HubSpot? Or can it only set headers/redirect?
2. Is the Statsig JS SDK confirmed active on www.soundstripe.com pages post-domain-consolidation? The hubspot repo had it in `<head>` but Phase 3 (Tool Reconfiguration) of the domain consolidation was listed as in-progress.
3. Does Soundstripe have Google Search Console API access configured? This is needed for impression/position metrics.

## Related

- [Experimentation domain overview](../../../knowledge/domains/experimentation/overview.md)
- [Experimentation metrics](../../../knowledge/domains/experimentation/metrics.md)
- [Statsig SEO testing docs](https://docs.statsig.com/experiments/types/seo-testing)
- Domain consolidation PRD: `analysis/data-health/2026-04-01-direct-traffic-spike/domain_consolidation_prd.pdf`
