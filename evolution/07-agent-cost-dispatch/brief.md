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

## Telemetry substrate consumption (from Epic 0.3)
**Stream read.** `metrics.jsonl` — token-usage counter datapoints (host-emitted via native OTel). Secondary: `spans.jsonl` for per-tool latency and agent-invocation spans.

**Schema-agnostic keying.** Match on attribute presence, not exact metric name. Token-cost metrics appear under host-versioned names (e.g. `gen_ai.client.token.usage` at the time of pin — see `../25-telemetry-substrate/host-version-pin.md`); group by `resource["session.id"]` plus the presence of a `type` / `gen_ai.token.type` attribute to split input/output. When the host pin shifts the metric name, update the filter; all other query shape stays constant.

**Dispatch-decision consumption.** Dispatch decisions and their cost outcomes are logged by the orchestrator into the Epic 1.2 session event log (`.claude/state/sessions/<session-id>.jsonl`). This epic reads cost from that projection — the projection itself reads from `metrics.jsonl`. Keeps cost-read logic in one place (Epic 1.2) and dispatch-policy logic in another (Epic 5.2).

**Calibration query.** Sum `gen_ai.client.token.usage` grouped by agent name (derived from the span hierarchy or logged in the dispatch decision) over a rolling window. A `high` cost rating whose measured consumption is low-tier is a candidate for re-rating. A `low` rating whose measured consumption is top-tier is a calibration error to flag.
