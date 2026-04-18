# Project 17: Knowledge graph substrate

## Overview
Memory and knowledge artifacts are flat markdown. Conflicts between two memories making contradictory claims about the same entity are detected only when both happen to be cited in the same session. Time-bound claims don't expire. Second-order queries ("what did I know about X as of date Y", "which initiatives affect metric M") require manual traversal.

## Linked framework section
`../../analytical-orchestration-framework.md` §10.4

## End goal
A typed knowledge graph maintained by a background indexer reading markdown artifacts:
- Entities: metric, table, stakeholder, initiative, memory, decision
- Relationships: derived-from, owned-by, affects, references
- Temporal validity per claim
- Conflict detection on contradictory relationships
- Query interface accessible to `/orient`, `/evolve`, and analyst on demand

Markdown remains the authoring surface. Graph is derived.

## Phased approach

### Phase 1 — Schema + indexer
**Complexity:** High
**Exit criteria:** Schema documented; indexer reads a seed set of memory/knowledge files; graph persisted (SQLite or JSON).
**Steps:**
- Entity type definitions
- Relationship type definitions with temporal validity semantics
- Indexer implementation
- Round-trip test (markdown → graph → query → expected answer)

### Phase 2 — Conflict detection
**Complexity:** High
**Exit criteria:** When two markdown artifacts produce contradictory triples, indexer flags the conflict.
**Steps:**
- Contradiction rules (e.g., "owned-by" uniqueness, "derived-from" acyclicity)
- Surface conflicts in /orient and /evolve
- Resolution workflow

### Phase 3 — Query interface + consumer integration
**Complexity:** Medium
**Exit criteria:** /orient, /evolve, /analyze can query the graph; common queries documented.
**Steps:**
- Query library
- Consumer integration
- Performance check on full corpus

## Dependencies
- Project 03 (runtime substrate audit) documents the memory scopes the indexer reads
- Project 11 (task README frontmatter) provides structured input for task-related entities

## Risks
- Graph drift from markdown → background indexer must run incrementally on file changes
- Schema churn → version the schema; migrations via script
