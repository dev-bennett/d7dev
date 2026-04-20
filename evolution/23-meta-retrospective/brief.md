# Project 23: Meta-retrospective

## Overview
`/evolve` produces session-scoped retrospectives. Patterns invisible at session scope — a friction that appears once every five sessions — only become obvious when the retrospective corpus is read as a whole. The framework itself evolves via these corpus-level observations.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.11

## End goal
A scheduled meta-retrospective reads `analysis/data-health/*-session-retrospective.md` plus the session-transcript corpus. It identifies patterns that recur across 3+ retrospectives, patterns that existing rules/hooks did not catch, and patterns that existing interventions did not resolve. Output: architectural proposals — new hook, new directive section, restructured command — rather than memories or rules.

## Phased approach

### Phase 1 — Corpus indexer
**Complexity:** Medium
**Exit criteria:** Indexer reads all retrospective files + transcripts; produces structured friction-point index.
**Steps:**
- Parse retrospective structure
- Extract friction points with classification
- Persist index

### Phase 2 — Meta-analysis prompt
**Complexity:** High
**Exit criteria:** Meta-retrospective agent reads index and produces corpus-level patterns + architectural proposals.
**Steps:**
- Prompt design
- Output schema (pattern, supporting evidence, proposal, proposal-target: hook|directive|command|other)
- Calibration on known pattern (e.g., commit backlog recurrence was a session-level symptom of a directive-level gap)

### Phase 3 — Proposal-triage workflow
**Complexity:** Medium
**Exit criteria:** Meta-retrospective proposals land in `evolution/` as candidate projects; promoted to real projects on acceptance.
**Steps:**
- Proposal-to-evolution-project pipeline
- Review workflow
- Cross-reference in MASTER_TRACKER.md

## Dependencies
- Project 02 (session event log) for transcript richness
- Project 05 (rule telemetry) for violation-count context

## Risks
- Confirmation bias in meta-analysis → adversarial pass from project 14 critic
- Proposal explosion → threshold on pattern recurrence (≥3 retrospectives)

## Telemetry substrate consumption (from Epic 0.3)
**Stream read.** Corpus-level reads across rotated collector output (`.claude/telemetry/data/*.jsonl` and rotated backups). `spans.jsonl` for tool-call frequency trends; `logs.jsonl` for hook-block rate over time; `metrics.jsonl` for latency percentile shifts and cost trends.

**Schema-agnostic keying.** Retrospective indexer joins prose retrospectives to quantitative signals via `resource["session.id"]`. For cross-session aggregates, key on `attributes.source`, `attributes.hook`, and `attributes["rule.id"]` (all workspace-stable per `../25-telemetry-substrate/host-version-pin.md`). Avoid keying on span or metric names directly.

**Threshold augmentation.** The `≥3 retrospectives` pattern-recurrence threshold is extended with: *"OR a single-session metric shift exceeding 2σ of the corpus baseline on a measured indicator (hook-block rate, P95 latency, token cost per turn)."* Quantitative shifts that never produced a retrospective still warrant meta-analysis because the absence of retrospective may itself be a signal.

**Retention implication.** Epic 6.8 benefits from long collector retention (to read longer baselines). The 14-day default from Epic 0.3 Phase 2 is insufficient for quarterly meta-retrospective; before this epic's Phase 2 work begins, either (a) lengthen retention on the specific streams this epic reads, or (b) persist a pre-aggregated rolled corpus to `knowledge/` that survives rotation. Decision record belongs in this epic's decisions/ directory when the time comes.
