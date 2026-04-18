# Project 20: Intervention lifecycle tracker

## Overview
STRUCTURAL findings currently carry only a prose classification tag. They end at authoring. No tracking answers "was the intervention adopted; was the criterion met." Unresolved structural issues accumulate silently. The open `_open.md` memory for Statsig late-arrival drop (Finding 4 from the WCPM audit) is an example — diagnosed but not closed.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.7

## End goal
Every STRUCTURAL finding emits a proposal artifact with: named owner, proposed fix, measurable success criterion, expected time-to-resolution, pointer to tracking surface (Linear/Jira/Asana ticket or internal _open.md). A background reader tracks adoption status and closes the intervention when the criterion is met. Quarterly rollup surfaces unresolved interventions as quantified organizational debt.

## Phased approach

### Phase 1 — Proposal schema
**Complexity:** Medium
**Exit criteria:** Format for intervention proposal artifact documented; template in `analysis/_templates/`.
**Steps:**
- Schema: finding_id, owner, fix_description, success_criterion, eta, tracking_pointer, status, opened, closed
- Integrate with §11 (Intervention Classification) output
- Backfill for existing OPEN memories

### Phase 2 — Tracking surface
**Complexity:** Medium-High
**Exit criteria:** Proposals are surfaced in `/status`; external ticket references check back for closure status (via MCP where available).
**Steps:**
- Surface-agnostic pointer format
- MCP integration where possible (ticketing systems)
- Fallback: manual status update

### Phase 3 — Quarterly rollup
**Complexity:** Medium
**Exit criteria:** A quarterly report lists unresolved interventions, time-in-flight, criterion status. Delivered as analytical output.
**Steps:**
- Rollup query
- Stakeholder report format
- Delivery automation

## Dependencies
- Project 04 (directive linter) for §11 block parsing
- Project 18 (stakeholder ledger) for delivery tracking

## Risks
- External-tracker drift → status may not reflect reality; reconcile on rollup
- Success-criterion quality dependent on authoring rigor → critic pass in project 14
