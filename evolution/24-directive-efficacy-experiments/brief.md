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

## Telemetry substrate consumption (from Epic 0.3)
**Stream read.** `logs.jsonl` for variant-tagged session events (assignment record + outcome events); `metrics.jsonl` for token-cost and latency outcome measures; `spans.jsonl` for workflow-time outcome measures.

**Schema-agnostic keying.** Each session records its active variant in `attributes["directive.variant"]` at SessionStart (workspace-authored — added by the assignment hook or `prompt-context.sh` shim). All cross-stream joins use `resource["session.id"]`. The variant tag and session.id are the only keys required for rollup; everything else is filterable metadata.

**Outcome measures — defined as queries.** Rather than persist bespoke outcome-measurement state, each pre-registered outcome is defined as a `jq` pipeline over the collector output (referenced from `../../knowledge/runbooks/telemetry-queries.md`). Example candidates:
- *False-positive deliverable rate:* count of retrospective-logged false positives per variant per session, joined via session.id to variant tag
- *Authoring time:* session-duration spans filtered by active-task attribute
- *Rework rate:* count of retry-guard warn/block events per session per variant

**Quarterly rollup.** Group outcome-query results by `attributes["directive.variant"]`, apply statistical test pre-registered per outcome. Variant-sample-size floor gates the rollup — underpowered comparisons hold, not report.

**Host-version sensitivity.** Variant tags survive host upgrades (workspace-authored). Outcome measures that rely on host-emitted metrics (token cost, latency) are re-validated on upgrade per the framework §1.4 host-version pinning rule.
