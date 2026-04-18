# Project 18: Stakeholder epistemic model

## Overview
Communication is currently role-indexed ("this is for a marketing stakeholder"). It is not stakeholder-indexed ("this is for Stakeholder A, who has seen findings X and Y, pushed back on Z, and flagged term T as unfamiliar"). Absent stakeholder state, the agent can re-deliver previously-rejected findings, use previously-flagged terms, or invent use cases the stakeholder never expressed.

**Scope clarification:** stakeholders include both external consumers (marketing, finance, engineering, product, RevOps) and the primary workspace operator (the user). The operator is the first-class stakeholder for every artifact produced in this workspace — briefs, trackers, retrospectives, chat messages. The operator ledger is the first ledger the system instantiates; it is seeded from existing feedback memories (notably `feedback_communication_style.md`, `feedback_listen_before_building.md`, `feedback_hold_correct_claims_under_pushback.md`, `feedback_stop_iterating_simplify.md`, `feedback_no_overclaim_from_code_reads.md`) which have been functioning as the operator's de facto ledger already.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.5

## End goal
`knowledge/stakeholders/<name>.md` maintains an append-only ledger per stakeholder: communications sent, with dates and content hashes; pushback received; flagged terms; accepted findings. A pre-delivery pass compares the draft against the ledger and surfaces coherence issues (re-delivery, term drift, fabricated use-case).

## Phased approach

### Phase 1 — Ledger schema + operator ledger
**Complexity:** Medium
**Exit criteria:** Per-stakeholder file format documented; operator (user) ledger is the first committed file, seeded from existing feedback memories; external stakeholder ledgers backfilled.
**Steps:**
- Schema: communications[], pushback[], flagged_terms[], accepted_findings[], rejected_framings[]
- Create operator ledger first — migrate relevant `feedback_*.md` content into structured pushback and flagged-term entries
- Identify existing external stakeholders from memory + recent retrospectives
- Backfill external ledgers

### Phase 2 — Delivery-time check
**Complexity:** Medium
**Exit criteria:** /analyze and /kb-update consult the ledger before delivery; conflicts surface as warnings.
**Steps:**
- Integrate into delivery step
- Warning output format
- Override workflow (acknowledge + proceed)

### Phase 3 — Automated ledger update
**Complexity:** Medium
**Exit criteria:** Delivered artifacts auto-append to ledger; pushback captured when user mentions a stakeholder by name.
**Steps:**
- Post-delivery hook to update ledger
- Pushback extraction from session transcripts
- Manual override for corrections

## Dependencies
- Project 17 (knowledge graph) — stakeholder ledger may be represented as graph entities

## Risks
- Privacy/ethics of maintaining per-person models → append-only, no inference from absence, only recorded exchanges
- Ledger drift from reality → quarterly user review of each active stakeholder ledger
