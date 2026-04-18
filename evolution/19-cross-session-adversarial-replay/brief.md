# Project 19: Cross-session adversarial replay

## Overview
Findings are challenged only at authoring time. Weeks later, new memory, dependency changes, or directive revisions may invalidate a finding that was correct at authoring. Without replay, a finding stays "correct by default" until a stakeholder questions it.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.6

## End goal
A scheduled replay pass runs the current adversarial apparatus (project 14 critic + current rule set + current memory) over the corpus of prior findings. When the current apparatus would flip a prior finding, a correction artifact is generated at `analysis/_corrections/<date>-<finding-slug>.md` and surfaced for stakeholder review. Replay is bounded by a scheduled compute budget.

## Phased approach

### Phase 1 — Findings corpus indexer
**Complexity:** Medium
**Exit criteria:** An index of all analytical findings (path, date, bound queries, §-blocks) exists and is refreshed on new findings.
**Steps:**
- Scanner for `analysis/**/findings.md`
- Metadata extraction
- Persist index

### Phase 2 — Replay runner
**Complexity:** High
**Exit criteria:** Runner replays a finding through the current critic; emits flip-candidate marker if critique diverges materially.
**Steps:**
- Runner wiring (on-demand and scheduled)
- Critique-divergence detection
- Budget-bounded scheduler

### Phase 3 — Stakeholder-notification workflow
**Complexity:** Medium
**Exit criteria:** Corrections surface to user via /evolve; pattern for re-communicating to original stakeholder documented.
**Steps:**
- Correction artifact template
- /evolve integration
- Stakeholder-ledger update (project 18)

## Dependencies
- Project 14 (semantic directive governance) for the critic apparatus
- Project 16 (claim provenance) for finding metadata
- Project 18 (stakeholder ledger) for re-communication tracking

## Risks
- Replay storms generate many flips after a rule change → rate-limit and batch
- Re-communication fatigue for stakeholders → only flip-events above severity threshold surface externally
