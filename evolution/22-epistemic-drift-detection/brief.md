# Project 22: Epistemic drift detection

## Overview
An agent may describe the same observable as "steady" → "elevated" → "concerning" across sessions while the underlying metric is unchanged. This is language drift, not data drift. Without detection, the agent compounds a framing trajectory that is not supported by the numbers.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.10

## End goal
A comparator agent reads sequential findings on the same subject (identified via knowledge-graph subject linkage, project 17) and flags tone-shift that exceeds metric-shift. When drift is detected, the current finding must explicitly state whether the change is in the data or in the language.

## Phased approach

### Phase 1 — Subject clustering
**Complexity:** Medium-High
**Exit criteria:** A process groups findings by subject (same metric, same channel, same observable).
**Steps:**
- Subject extraction from finding metadata
- Clustering over corpus
- Validation on hand-labeled subjects

### Phase 2 — Comparator agent
**Complexity:** High
**Exit criteria:** Comparator reads 2+ sequential findings on a subject; measures tone-shift (valence, intensity) vs metric-shift (numeric delta); flags exceedance.
**Steps:**
- Comparator prompt with structured output
- Calibration on known drift cases
- False-positive tuning

### Phase 3 — Alert pattern
**Complexity:** Medium
**Exit criteria:** When drift is flagged for a new finding, authoring is blocked until the finding explicitly states whether the change is in data or language.
**Steps:**
- Hook integration on findings writes
- Override / acknowledgement workflow
- Logging to session event log

## Dependencies
- Project 17 (knowledge graph) for subject linkage
- Project 14 (semantic directive governance) — related critic capability

## Risks
- Language-vs-data distinction is subjective → require comparator output to cite specific phrases + metric deltas
