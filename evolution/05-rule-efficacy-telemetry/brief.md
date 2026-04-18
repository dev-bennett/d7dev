# Project 05: Rule efficacy telemetry

## Overview
`.claude/rules/*.md` accumulates without pruning. No signal exists to identify rules that are redundant, never fire, or are routinely violated. A rule that fires weekly is a candidate for hook enforcement. A rule that hasn't fired in 30 days is a candidate for deprecation. Without telemetry, the rulebook grows monotonically.

## Linked framework section
`../../analytical-orchestration-framework.md` §3.2 + §10.8

## End goal
Every rule file carries machine-readable frontmatter (`applies_to`, `implements`, `last_reviewed`). Three counters accumulate per rule across sessions: **fires** (hook prevented a violation), **violations** (review caught what the rule missed), **irrelevance** (rule never triggered). A scheduled review produces proposals: deprecate rules with zero 30-day activity; strengthen rules violated weekly; consolidate rules whose violations co-occur.

## Phased approach

### Phase 1 — Frontmatter schema + migration
**Complexity:** Low-Medium
**Exit criteria:** Every existing rule file has `applies_to`, `implements`, `last_reviewed` frontmatter. No behavior change yet.
**Steps:**
- Define schema
- Migrate 10 existing rule files
- Add validator to ensure new rules carry frontmatter

### Phase 2 — Fire counter via hook
**Complexity:** Medium
**Exit criteria:** When a hook blocks a violation, it emits an event tagged with the rule ID. Counters roll up per rule.
**Steps:**
- Add rule-ID field to hook events (relies on project 02 unified log)
- Map each hook check to the rule it enforces
- Build counter aggregation reader

### Phase 3 — Review workflow + proposals
**Complexity:** Medium
**Exit criteria:** `/review rules` (or a scheduled skill) reads counters and proposes deprecations/strengthenings.
**Steps:**
- Thresholds: deprecate ≥30d no fires; strengthen ≥4 violations per week
- Proposal output format
- Integrate into `/evolve` retrospective

## Dependencies
- Project 02 (unified session state log) — counter aggregation is cheaper against the event log than per-marker files

## Risks
- Violation counting requires retrospective attribution (who noticed the violation, when) → may need `/review` to explicitly tag which rule a correction implicates
