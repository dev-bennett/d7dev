# Project 07: Agent cost dispatch

## Overview
Sub-agent delegation currently happens on palette-fit alone. Duplicated search (primary context + sub-agent both searching the same corpus) is a documented anti-pattern but not structurally prevented. Cost awareness in the dispatch decision requires each agent to declare its context-cost profile and the orchestrator to consult it before dispatching.

## Linked framework section
`../../analytical-orchestration-framework.md` §4.2

## End goal
Every `.claude/agents/<name>.md` carries `expected_context_cost: low | medium | high` in frontmatter. The orchestrator's dispatch heuristic: if the task can be completed in primary context with equivalent quality AND primary context is below budget threshold, handle in primary. Otherwise delegate. Duplicated search is blocked by a post-dispatch check that refuses primary-context searches on the same corpus within a dispatch window.

## Phased approach

### Phase 1 — Annotate agents
**Complexity:** Low
**Exit criteria:** All 6 agent files carry `expected_context_cost`.
**Steps:**
- Assign ratings based on agent palette + typical task volume
- Commit

### Phase 2 — Dispatch heuristic
**Complexity:** Medium
**Exit criteria:** Orchestrator consults cost before dispatching. Dispatch decisions logged to session event log.
**Steps:**
- Define budget thresholds
- Document decision rule in `.claude/rules/guardrails.md`
- Agent behavior spec update

### Phase 3 — Duplicated-search guard + measurement
**Complexity:** Medium
**Exit criteria:** Post-dispatch, primary context refuses redundant searches for a dispatch window. Retrospective measures dispatch efficiency.
**Steps:**
- Track dispatched searches in event log
- Add refusal logic in agent behavior
- /evolve reports dispatch cost vs value

## Dependencies
- Project 02 (session event log) for decision logging

## Risks
- Cost ratings are subjective at annotation time → re-rate quarterly based on measured context usage
