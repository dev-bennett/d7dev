# Project 13: Prior-investigation enforcement

## Overview
Starting an investigation on a previously-investigated observable without reading the prior investigation is the single most expensive class of workflow failure (captured in `feedback_prior_investigation_search.md`). Enforcement is currently behavioral — a forgotten or skipped search produces a fishing expedition that re-derives a conclusion already documented.

## Linked framework section
`../../analytical-orchestration-framework.md` §9

## End goal
For any write into an investigatory task directory (analysis/data-health, analysis/experimentation, etc.), a `prior_investigation_search.md` artifact must exist in the task directory before query authoring is permitted. The artifact documents: what slug/observable was searched, which directories were globbed, what was found, and the leading hypothesis derived from prior findings.

## Phased approach

### Phase 1 — Search-artifact spec
**Complexity:** Low
**Exit criteria:** Format of `prior_investigation_search.md` documented and templated in `analysis/_templates/`.
**Steps:**
- Define required fields (observable/slug, glob patterns, found paths, leading hypothesis, alternative hypotheses)
- Provide template
- Update `/preflight` to suggest generating the artifact

### Phase 2 — Hook enforcement
**Complexity:** Medium
**Exit criteria:** Write/Edit of a `.sql`, `.py`, or `findings.md` file in an investigatory directory is blocked if `prior_investigation_search.md` is absent from the task directory.
**Steps:**
- Write investigatory-gate.sh hook
- Scope to investigatory directories only
- Add to settings allowlist

### Phase 3 — /preflight integration
**Complexity:** Low-Medium
**Exit criteria:** /preflight runs the prior-investigation search as a required step, writes the artifact, logs to session event log.
**Steps:**
- Add step to /preflight
- Generate the artifact automatically when possible
- Leave agent to fill leading-hypothesis field

## Dependencies
- Project 06 (hook-edit guard) preferred first.
- Project 02 (event log) for search logging

## Risks
- Agents may fill out the artifact minimally to bypass the hook → artifact content quality check in project 14 (semantic governance)
