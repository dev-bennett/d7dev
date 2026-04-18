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
