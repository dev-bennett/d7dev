# d7dev Platform Roadmap

**Date:** 2026-03-30
**Status:** Draft
**Context:** Complements the data function restructure proposal. This roadmap defines how d7dev bridges the capacity gap created by Geoff's departure and enables a single Principal Analyst to operate the full data function.

---

## Current State

The platform has three layers at different maturity levels:

**Operational:**
- CLI infrastructure — agents, commands, rules, methodology framework
- dbt integration — live submodule, development workflow established
- ETL task workflow — one completed task (reference track search) proving the pattern
- Knowledge base foundation — one domain, data dictionary started, one ADR

**Scaffolded:**
- LookML workspace (empty)
- ETL reusable SQL (staging, intermediate, marts directories empty)
- Data quality checks (empty)
- Python automation (empty)
- Test suite (empty)
- Operational runbooks (empty)

**Planned:**
- LookML submodule integration (Phase 3)
- CI/CD cross-repo validation (Phase 4)

---

## Roadmap

Organized by what it replaces — each phase targets a specific category of work that currently requires manual effort or that Geoff contributed to.

### Phase 1: Knowledge Capture (immediate)

**Gap addressed:** Geoff carries institutional knowledge about pipeline history, data quirks, past decisions, and stakeholder context that is not documented anywhere.

- Document all active data sources and their ingestion paths (Stitch configs)
- Expand data dictionary beyond fct_events to cover core mart models
- Write operational runbooks: pipeline failure response, backfill procedures, access provisioning, vendor escalation paths
- Capture known data quirks and edge cases as KB articles
- Document Polytomic sync configurations and downstream dependencies

**Outcome:** Eliminates single-point-of-knowledge risk. Any future contributor (or Devon after 6 months of not touching a pipeline) can find the answer without asking someone.

### Phase 2: Data Quality Automation

**Gap addressed:** Geoff manually monitors pipeline health and catches issues through experience. Without him, issues surface later — when a stakeholder sees bad data in a dashboard.

- Build reusable data quality checks in etl/quality/ (freshness, volume, schema drift, null rates on key columns)
- Implement the /monitor command with real checks against Snowflake
- Define alerting thresholds for core pipelines (Stitch -> Snowflake latency, row count anomalies, dbt run failures)
- Write validation queries for every mart model, not just new ones

**Outcome:** Proactive detection replaces reactive discovery. Pipeline issues are caught before they reach dashboards.

### Phase 3: LookML Development Workflow

**Gap addressed:** LookML changes currently happen directly in the Looker IDE with no version control, review, or testing. This is manageable with two people cross-checking; it's risky with one.

- Integrate LookML repo as git submodule (context/lookml/)
- Establish development workflow: draft in lookml/ workspace, validate, promote via PR
- Build LookML views and explores for domains starting with search/RTS
- Add data tests for every explore
- Connect Looker API for live state validation (Phase 3 of cross-repo roadmap)

**Outcome:** LookML changes follow the same governed workflow as dbt. Reduces risk of breaking dashboards.

### Phase 4: Analysis Automation

**Gap addressed:** Recurring analyses (monthly metrics, quarterly reviews, ad-hoc stakeholder requests) are manual end-to-end. Each one starts from scratch.

- Build domain-specific analysis templates beyond the current generic set
- Develop reusable query libraries per domain (search, engagement, revenue — whatever the active domains are)
- Implement the /analyze command with domain-aware query generation
- Create self-service dashboards in Looker that reduce ad-hoc request volume

**Outcome:** Recurring analytical work takes hours instead of days. Stakeholders can self-serve common questions.

### Phase 5: Pipeline Orchestration

**Gap addressed:** ETL pipeline management (Stitch configs, dbt runs, Polytomic syncs) is manual and scattered across vendor UIs.

- Build Python utilities in scripts/ for common pipeline operations
- Implement monitoring scripts that check pipeline state across Stitch, dbt Cloud, Snowflake, Polytomic
- Create the /etl audit command with real validation
- Document and automate backfill procedures

**Outcome:** Pipeline operations are scriptable and observable from one place instead of five vendor dashboards.

### Phase 6: CI/CD Integration (Phase 4 of cross-repo roadmap)

**Gap addressed:** Changes in d7dev, dbt, and LookML repos are validated independently. No cross-repo validation exists.

- Changes to ETL transforms in d7dev trigger validation against the dbt repo
- LookML changes validate against Snowflake schema
- Automated PR checks for both dbt and LookML promotions

**Outcome:** Cross-repo changes are validated before merge. Reduces production incidents from schema mismatches or broken references.

---

## How This Connects to the Restructure Proposal

Each phase directly addresses the "how does one person do this?" question:

| Phase | Replaces | Engineering alignment benefit |
| ----- | -------- | ----------------------------- |
| 1. Knowledge Capture | Geoff's institutional memory | Documentation standards shared with Luke's team |
| 2. Quality Automation | Geoff's manual monitoring | Shared alerting infrastructure with Engineering |
| 3. LookML Workflow | Two-person cross-checking | Code review and version control via Engineering practices |
| 4. Analysis Automation | Manual recurring analysis | Self-service reduces cross-departmental request load |
| 5. Pipeline Orchestration | Scattered vendor management | Shared tooling and observability with Engineering |
| 6. CI/CD Integration | Independent repo validation | Integrated with Engineering's CI/CD pipeline |

Phases 2, 3, 5, and 6 specifically benefit from — or require — closer collaboration with Engineering. This is work that is harder to do reporting to Finance and easier to do reporting to Luke.
