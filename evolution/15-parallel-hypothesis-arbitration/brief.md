# Project 15: Parallel hypothesis arbitration

## Overview
A single leading hypothesis per investigation produces late-pivot costs when the leading hypothesis is wrong. Parallel arbitration forces hypothesis competition structurally — two sub-agents pursue divergent priors in parallel; an arbitrator reads both and either selects or prescribes the discriminator. Token cost is paid once in parallel rather than repeatedly in sequential user round-trips.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.2

## End goal
On any triggered investigation (hook or /preflight signal), /analyze dispatches:
- Sub-agent A with the prior-investigation-found root cause as its leading hypothesis
- Sub-agent B constructed to diverge (different mechanism or cohort)
Each produces the minimum discriminating query set. An arbitrator sub-agent reads both and outputs: selected hypothesis + evidence OR "neither discriminates; run query Q."

## Phased approach

### Phase 1 — Sub-agent role definitions
**Complexity:** Medium
**Exit criteria:** `hypothesis-advocate.md` and `hypothesis-arbitrator.md` agent definitions exist with prompts and tool palettes.
**Steps:**
- Design advocate prompt (given prior, produce discriminator queries only)
- Design arbitrator prompt (read both outputs, produce verdict)

### Phase 2 — Dispatcher integration
**Complexity:** Medium-High
**Exit criteria:** /analyze invokes the two-advocate + arbitrator triad when the investigation matches a trigger pattern.
**Steps:**
- Hook /analyze or add a preflight step
- Propagate prior-investigation results to advocates
- Surface arbitrator output as the leading hypothesis for downstream three-pass work

### Phase 3 — Measurement + tuning
**Complexity:** Medium
**Exit criteria:** Retrospective measures arbitrator accuracy and parallel-token cost vs. sequential baseline.
**Steps:**
- Track dispatch events in session log
- /evolve reports on arbitration outcomes
- Tune advocate divergence breadth

## Dependencies
- Project 07 (agent cost dispatch) — arbitration adds expensive parallel dispatch; cost awareness required.
- Project 13 (prior-investigation enforcement) — trigger requires prior-search artifact.

## Risks
- Spurious divergence (B advocate constructs a hypothesis with no support) → constrain B to evidence-grounded alternatives
- Cost explosion → arbitration used only for investigations flagged as high-leverage
