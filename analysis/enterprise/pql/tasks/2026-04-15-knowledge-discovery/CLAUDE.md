# 2026-04-15 Knowledge Discovery

@../CLAUDE.md

Two intertwined goals:

1. **Build contextual knowledge** about the HubSpot contacts object, the enterprise lead-scoring pipeline, and the Polytomic sync back to HubSpot. Prior state: the d7dev repo has rich tactical infrastructure but zero knowledge-base or memory coverage on these topics.
2. **Answer Ryan Severns' (Floodlight Growth, RevOps) 2026-04-15 question**: avg lead score for free sign-ups was steady at ~0.5 Aug-Jan 2025 and jumped to ~0.65 in Feb 2026+. Did scoring logic change?

## Approach

Execute in three query phases before solidifying knowledge artifacts (per `feedback_discovery_before_knowledge.md`):

- `contacts-shape/` — Phase A: full HubSpot contacts object shape, PROPERTIES inventory, score-field distributions, identity-key coverage
- `pipeline-shape/` — Phase B: dim_enterprise_leads + enterprise_lead_scoring + Polytomic sync health and lead-type mix over time
- `ryan-feb-score-shift/` — Phase C: stratified monthly means across all candidate score fields × cohort definitions + shift-share decomposition + per-source analysis + git-log audit of Feb 2026 dbt commits

After all three phases have results, Phase D (not in this task dir) writes `knowledge/domains/hubspot/`, `knowledge/domains/enterprise/`, `knowledge/data-dictionary/hubspot-scoring-fields.md`, and memory entries.

## Files in this directory

- `console.sql` — original exploratory query (`SELECT * FROM HUBSPOT.HUBSPOT_CONTACTS LIMIT 50`)
- `q1.csv` — 50-row sample from that query (2026-04-14 ingest window)
- `contacts-shape/` — Phase A query set
- `pipeline-shape/` — Phase B query set
- `ryan-feb-score-shift/` — Phase C query set

## Conventions

- Each query subdirectory has its own CLAUDE.md and `queries.sql`.
- CSV exports go into the same subdirectory, filenames `aN.csv` / `bN.csv` / `cN.csv` matching the query label.
- FINDINGS.md at the task root aggregates across phases; per-phase FINDINGS.md lives inside each subdirectory.
- All rate-producing queries carry a Rate Declaration (§1) header comment and get a Type Audit in the phase FINDINGS.
