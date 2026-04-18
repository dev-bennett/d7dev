# Project 21: Warehouse state context frame

## Overview
Warehouse state is currently queried on-demand during investigations. Incremental lag, schema drift events, model dependency health, freshness breaches, and pipeline run status become visible only when a query returns unexpectedly empty or a finding is already off. A session-start frame exposes these conditions before query authoring.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.9

## End goal
A background collector polls warehouse metadata (dbt run status, source freshness, Stitch replication lag, recent schema changes) and maintains a small state file. `UserPromptSubmit` injects a summary of current anomalies (lags > N hours, schema changes in last 24h, freshness breaches) into session context.

## Phased approach

### Phase 1 — Metadata collector
**Complexity:** Medium-High
**Exit criteria:** Polling script produces a state file with current warehouse anomalies.
**Steps:**
- Identify source metadata (dbt Cloud API, Snowflake information_schema, Stitch status API)
- Collector script with rate limits
- Schedule (cron or launchd)

### Phase 2 — Context injection
**Complexity:** Low-Medium
**Exit criteria:** prompt-context.sh includes a warehouse-anomaly section when the state file has non-empty anomalies.
**Steps:**
- Extend prompt-context.sh
- Size budget (truncate verbose state)
- Suppress when no anomalies

### Phase 3 — /preflight integration
**Complexity:** Medium
**Exit criteria:** /preflight for any investigatory task surfaces warehouse state relevant to the tables that task will touch.
**Steps:**
- Task-to-table inference from task directory
- Relevant-state filtering
- /preflight output section

## Dependencies
- None strictly; benefits from project 11 (task frontmatter for table linkage)

## Risks
- Metadata API rate limits → conservative polling, local cache
- State staleness (hourly cache for fast-changing metrics) → document freshness in the injected context
