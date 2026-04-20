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

## Telemetry substrate consumption (from Epic 0.3)
**Stream read.** `logs.jsonl` — specifically records with `attributes.source == "d7dev.hook"` (the filelog-bridged hook events; see `../25-telemetry-substrate/decisions/hook-bridge-pattern.md`). Counter aggregation runs on the collector output, not on `session-log.jsonl` directly, so rotation and scrubbing apply uniformly.

**Schema-agnostic keying.** Aggregate on `attributes["rule.id"]` (workspace-authored — added by the hook when its check implements a named rule) plus `attributes.outcome`. Do NOT aggregate on `attributes.hook` — moving a check between hooks would silently split the counter. `rule.id` is invariant to hook refactoring; `hook` name is not.

**Metric alternative.** If rule-fire counting migrates from log-record counting to native OTel counter metrics (e.g., a hook directly emits via a Python/Go sidecar), the metric name is workspace-authored-stable and the query pattern is unchanged — group by `attributes["rule.id"]`.

**Irrelevance detection.** Rules with zero fire events over a 30-day window are detected by absence in the `rule.id` aggregation. Query fires across the full log corpus (collector `data/` directory with all rotated backups) to avoid false-positive "irrelevance" from short retention windows.
