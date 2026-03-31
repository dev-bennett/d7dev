# Checkpoint — 2026-03-25

## Completed
- v1 proposal approved (2026-03-24)
- v1 segment sizing queries (s1.csv, s2.csv)
- v1 retention model (retention_model.xlsx, 4-sheet format)
- v1 flow diagrams (per-plan + aggregate)
- v1 Notion docs (notion_full.md, notion_exec_summary.md)
- Plan approved for v2 revisions
- v2: Segment sizing queries rewritten to rolling 30-day windows (segment_sizing.sql)
- v2: build_model.py rewritten — single-sheet compact model, 4 plans, 5 segments, single funnel param set
- v2: retention_model.xlsx regenerated (53 rows, 1 sheet)
- v2: build_diagram.py rewritten to match new_flow.png (enterprise gate, new sub exit, 5 terminal segments)
- v2: lifecycle_flow.png + .svg regenerated
- v2: build_flow_diagram.py updated for per-plan diagrams (4 plans + aggregate, no enterprise)
- v2: notion_full.md updated (enterprise/NEW removed, rolling windows, ramp-up vs evergreen)
- v2: notion_exec_summary.md updated
- v2: proposition.md updated
- v2: Verification pass — enumeration check, spot-check funnel math, grep for stale references
- v2: s1.csv and s2.csv updated with rolling-window query data from Snowflake
- v2: All outputs regenerated with fresh data (model, diagrams)
- Evergreen proposal created (evergreen/proposition.md)
- Evergreen model created (evergreen/build_model.py → evergreen_model.xlsx)
- Evergreen flow diagram created (evergreen/build_flow_diagram.py → evergreen_flow.png)

## In Progress
- None

## Open Items
- None

## Pending Decisions
- None

## Key Context
- Enterprise excluded from lifecycle email program (handled by Sales/AM)
- New Subscribers out of scope (existing onboarding flow)
- Segment classification uses rolling 30-day windows, not calendar months
- Email funnel parameters are a single set across all plans (not per-plan)
- Model is single-sheet with inputs and outputs visible together
- Deliverable distinguishes initial ramp-up vs future evergreen version
- s1.csv and s2.csv now contain rolling-window data
- Evergreen model uses transition volumes (s2) as enrollment denominators, not static segment sizes
