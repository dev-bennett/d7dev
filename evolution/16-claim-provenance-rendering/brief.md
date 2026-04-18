# Project 16: Claim provenance rendering

## Overview
Stakeholder-facing numbers currently carry provenance as prose footnotes. Tracing a delivered number back to the SQL line that produced it, the transformation DAG from source to final table, the ingestion-lag characteristics, and the incremental window requires manual effort. One-interaction provenance renders this chain at read time from workspace artifacts.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.3

## End goal
Every analytical finding's numeric value carries structured metadata (query id, source table, transformation lineage, freshness timestamp, lag risk tag). A rendering pipeline produces a stakeholder view where each number is interactive: one click exposes the chain. Chain is computed from workspace artifacts at render time.

## Phased approach

### Phase 1 — Query header metadata schema
**Complexity:** Medium
**Exit criteria:** Every query file in task workspaces has header metadata (query id, target tables, freshness dependency, incremental risk tag).
**Steps:**
- Define header schema (YAML-ish or comment block)
- Backfill existing queries
- Validator in `/review`

### Phase 2 — Finding-to-query binding
**Complexity:** Medium-High
**Exit criteria:** Findings.md can reference query-id; a binding verifier confirms every number in findings is bound to a query.
**Steps:**
- Define binding syntax
- Validator (directive linter extension)
- Migration of recent findings

### Phase 3 — Rendering pipeline
**Complexity:** High
**Exit criteria:** A render script produces HTML/markdown with click-through provenance from findings + bound queries + upstream DAG metadata.
**Steps:**
- Collect DAG metadata from transformation submodule
- Build renderer
- Stakeholder UI handoff pattern

## Dependencies
- Project 04 (directive linter) for binding verification
- Project 21 (warehouse-state context frame) for freshness/lag metadata

## Risks
- Binding granularity (per-number vs per-table vs per-section) → start coarse, refine later
- Rendering surface choice (static HTML vs live dashboard) → prefer static for versioning
