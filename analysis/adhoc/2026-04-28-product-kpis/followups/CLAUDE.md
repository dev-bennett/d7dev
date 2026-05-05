# Follow-up Mini-Analyses — Product KPIs

@../CLAUDE.md

Six scoped sub-analyses (M1–M6) referenced in `../findings.md` "Follow-up mini-analysis roadmap." Each subdirectory holds its own CLAUDE.md, query file (if SQL was needed), result CSVs, and `findings.md` (the verdict that rolls back up to the parent dashboard review).

## Conventions

- One subdirectory per mini-analysis: `M<N>-<slug>/`
- Each subdirectory's `findings.md` opens with the triggering finding (cited from parent), the headline question, and the verdict — in that order
- Queries land in each subdirectory's `queries.sql` (file-first per `feedback_one_sql_file_per_query_set`)
- All findings explicitly state which parent tile(s) the conclusion refines

## Status

| ID | Mini-analysis | Status |
|---|---|---|
| M3 | Per-visitor variant of tiles 5/6/11 | complete |
| M4 | MQL 3-component decomposition | complete |
| M2 | Subscriber acquisition -74% channel decomposition | complete |
| M2.1 | Bot-strip variant of M2 (aggregate + per-channel; tests D1 hypothesis) | complete |
| M6 | Revenue/session shift-share | complete |
| M5 | Engagement metric recomputation on lagged-window basis | complete |
| M1 | Tile 12 expansion-rate root-cause | partial (data-side mechanisms tested; pricing PRD review pending stakeholder) |
