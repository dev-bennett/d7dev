# MQL Discrepancy — LookML Changes

@../CLAUDE.md

LookML artifacts for the MQL discrepancy fix. Updates fct_sessions.view.lkml to
point at fct_sessions_enriched and adds reconciled MQL dimensions/measures.

## References

- Analysis: `analysis/data-health/2026-04-07-mql-discrepancy/findings.md`
- dbt drafts: `etl/tasks/2026-04-07-mql-discrepancy-fix/`
- Existing LookML: `context/lookml/views/Mixpanel/fct_sessions.view.lkml`
- Existing explore: `context/lookml/models/General.model.lkml` line 197
