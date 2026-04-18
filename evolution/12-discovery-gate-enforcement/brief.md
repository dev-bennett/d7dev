# Project 12: Discovery gate enforcement

## Overview
Knowledge articles authored from samples, memory, or code reading alone produce durable claims on weak evidence. The `feedback_discovery_before_knowledge.md` memory captures the pattern. Enforcement is currently behavioral. A hook refusing knowledge writes without a discovery sibling makes the weak-evidence failure mode structurally impossible.

## Linked framework section
`../../analytical-orchestration-framework.md` §7

## End goal
A `PreToolUse` hook on Write/Edit intercepts any path matching `knowledge/**/*.md`. If the write path's directory does not contain a sibling `discovery/` directory with at least one `.sql` file and one `.csv` result, the hook refuses the write with a clear message. Discovery siblings are themselves committed artifacts.

## Phased approach

### Phase 1 — Hook implementation
**Complexity:** Low
**Exit criteria:** Write/Edit into `knowledge/` is blocked when no `discovery/` sibling exists.
**Steps:**
- Write `knowledge-discovery-gate.sh`
- Wire as `PreToolUse` Write|Edit
- Add to settings allowlist

### Phase 2 — Migration of existing articles
**Complexity:** Medium
**Exit criteria:** Every existing knowledge article has a discovery sibling (or a grandfathered exemption with explicit rationale).
**Steps:**
- Audit existing articles
- For each, identify or recreate the discovery query
- Commit discovery siblings

### Phase 3 — Cross-reference integrity
**Complexity:** Medium
**Exit criteria:** Pre-commit check validates that every data-dictionary field citation resolves to an actual entry.
**Steps:**
- Write cross-ref validator
- Wire into /test
- Document in guardrails

## Dependencies
- Project 06 (hook-edit guard)

## Risks
- Emergency knowledge writes (e.g., incident context) may need a temporary bypass → an override phrase similar to project 06, logged
