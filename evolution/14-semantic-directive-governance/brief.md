# Project 14: Semantic directive governance

## Overview
The directive linter (project 04) verifies §-block presence and structural completeness. It does not verify that the §1 RATE block's NUMERATOR field actually describes what the associated SQL computes, or that the §4 Null Hypothesis verdict follows from the verification numbers. A second-pass critic LLM reads the artifact and its §-blocks and produces an adversarial critique.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.1

## End goal
For any committed analytical output with §-blocks, a scheduled or hook-triggered critic pass reads the artifact + its §-blocks, produces a structured critique (coherence issues, misalignments, unsupported claims), and commits the critique alongside the deliverable. The critic is calibrated against a known-good historical corpus to keep false-positive rate below a session-friction threshold.

## Phased approach

### Phase 1 — Critic prompt + hook wiring
**Complexity:** Medium-High
**Exit criteria:** A critic skill/agent exists; given an artifact + §-blocks, produces structured critique; hook wires it on `PostToolUse` Write/Edit for analytical files.
**Steps:**
- Design critic prompt with structured output schema
- Decide sync (blocking on write) vs async (scheduled review)
- Wire hook or scheduler

### Phase 2 — Calibration corpus
**Complexity:** High
**Exit criteria:** A hand-curated known-good corpus exists; critic false-positive rate on this corpus is measured and tuned.
**Steps:**
- Select 10–20 historical artifacts judged high-quality
- Run critic; identify false-positive patterns
- Iterate critic prompt

### Phase 3 — False-positive threshold tuning
**Complexity:** Medium
**Exit criteria:** Critic false-positive rate ≤ threshold (e.g., 15% on calibration corpus); deployment live.
**Steps:**
- Measure on production artifacts
- Adjust threshold or prompt
- Document calibration in knowledge/runbooks/

## Dependencies
- Project 04 (directive linter) for §-block parsing

## Risks
- Over-firing critic generates noise and is ignored → strict calibration gate before live deployment
- Under-firing critic provides no signal → measured by adversarial seeding (known-bad artifacts)
