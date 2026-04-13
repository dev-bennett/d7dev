---
domain: experimentation
date: 2026-04-01
last-updated: 2026-04-01 12:45
---

# Checkpoint -- SEO Testing Initiative

## Completed
- Experimentation domain scaffolded (analysis, knowledge, etl quality)
- Technical assessment written and published to Notion
- Knowledge base entries: domain overview + metrics definitions
- Open questions answered by engineering (AJ Robertson, 2026-04-01)
- Asana ticket created on Otternaut's board for team refinement: app.asana.com/1/411777761188590/project/1211348933341599/task/1213907806132166

## Open Questions — Status

1. **Can Fastly VCL modify HTML response body?** Yes (AJ, 2026-04-01). Luke asked why this is necessary (2a) — rationale shared: SEO tests require crawlers to see the variant in raw HTML on first render; client-side JS swaps risk Googlebot not seeing the variant. Whether Fastly body mod is actually needed depends on whether HubSpot HubL templates can implement variant logic server-side instead. To be discussed in refinement.
2. **Is Statsig JS SDK active on www post-consolidation?** HubSpot: yes. React SPA (/library): yes, loads via npm. **Rails: not yet** — planned during Project Overtake (Luke, 2026-04-01). This means Rails-served pages cannot participate in Statsig experiments until Overtake completes.
3. **Google Search Console API access?** Can be configured (AJ, 2026-04-01).

## Next Steps
- Discuss in Otternaut team refinement session
- #ext-dbs team to weigh in on viability and technical setup
- Clarify variant serving approach: Fastly VCL body mod vs HubSpot HubL server-side vs JS SDK (with crawl rendering tradeoff)
- Register `page_url` Custom Unit ID in Statsig console
- Build `statsig_seo_experiment_metrics` dbt model
- Connect Google Search Console data pipeline

## Pending Decisions
- Variant serving approach (Fastly VCL vs HubSpot HubL vs JS SDK with crawl delay tradeoff)
- Which pages are in scope given Rails doesn't have Statsig SDK yet (HubSpot marketing pages + React SPA only until Overtake)
- GSC integration method
- Timeline from Otternaut team refinement

## Key Context
- Marketing's first experiment: header copy variants on marketing pages
- Statsig SEO testing randomizes at page URL level, not user level
- Existing Statsig integration is user-level only (`statsig_stable_id`)
- AJ Robertson is the engineering point of contact; Taylor Armstrong (marketing) is CC'd
- Asana ticket is the tracking artifact going forward
