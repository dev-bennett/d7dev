# Project 24: Directive efficacy experiments

## Overview
Directive sections are authored once and treated as fixed. Whether a stricter §4 (Null Hypothesis Check) catches more false-alarm deliverables, or whether a looser variant saves authoring time at no cost, is unmeasured. The directive is a hypothesis; it is not currently tested as one.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.12

## End goal
A variant framework attaches to directive sections: each section has a canonical variant plus zero or more experimental variants. Sessions are assigned to a variant. Outcome measures (false-positive deliverables, authoring time, rework rate) are pre-registered and measured across variants. Experiments run on quarter-scale cycles with documented outcome-measure commitments.

## Phased approach

### Phase 1 — Variant framework
**Complexity:** Medium
**Exit criteria:** A directive section can be authored in 2+ variants, each tagged with an experiment id; only one variant is active per session.
**Steps:**
- Variant file structure
- Session-level variant selection
- Variant tagging in session event log

### Phase 2 — Assignment logic
**Complexity:** Medium
**Exit criteria:** Sessions are assigned to variants randomly (or stratified) at session start.
**Steps:**
- Assignment policy (random, block, user-pinned)
- Record assignment in session metadata
- Expose variant to agent in session context

### Phase 3 — Outcome-measurement harness
**Complexity:** High
**Exit criteria:** Outcome measures are collected per session; quarterly rollup compares variants with statistical rigor.
**Steps:**
- Pre-register outcome measures per experiment
- Data collection (from session event log, retrospective corpus, user feedback)
- Quarterly statistical analysis

## Dependencies
- Project 02 (session event log)
- Project 05 (rule telemetry — similar measurement infrastructure)
- Project 23 (meta-retrospective — outcome signal source)

## Risks
- Directive churn → long cycles (quarter scale), pre-registered measures
- Hawthorne effect on experimental variants → blind the session-level assignment where possible
- Statistical under-power with small session count → plan experiments with tractable effect sizes
