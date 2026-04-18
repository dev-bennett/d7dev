# Project 11: Task README frontmatter

## Overview
Task directories under `etl/tasks/`, `lookml/tasks/`, and `analysis/<domain>/` carry READMEs with ad-hoc status sections (or none). `/orient` currently derives in-flight status by directory listing. Abandoned tasks are invisible unless manually noted. A strict frontmatter contract turns status into structured data.

## Linked framework section
`../../analytical-orchestration-framework.md` §6.2

## End goal
Every task README carries frontmatter with `status` (draft | in-progress | complete | abandoned), `owner`, `linked_initiatives[]`, `deliverable_paths[]`, and `abandonment_reason` (required iff status=abandoned). A pre-write hook validates the frontmatter. `/orient` and `/status` read structured data rather than parsing prose.

## Phased approach

### Phase 1 — Schema + migration
**Complexity:** Low-Medium
**Exit criteria:** Schema documented; all existing task READMEs migrated.
**Steps:**
- Define YAML frontmatter schema
- Backfill existing task READMEs (etl/tasks, lookml/tasks, analysis/data-health, etc.)
- Include an `/ingest` style one-shot migration command

### Phase 2 — Hook validation
**Complexity:** Low
**Exit criteria:** Pre-write hook rejects task READMEs missing required fields.
**Steps:**
- Extend session-gate.sh or add separate readme-frontmatter-guard.sh
- Zero-prompt-audit the new hook

### Phase 3 — Consumer integration
**Complexity:** Medium
**Exit criteria:** /orient and /status consume frontmatter; abandoned tasks explicitly surfaced.
**Steps:**
- Parser in /orient
- Parser in /status
- Add abandoned-task section to /orient output

## Dependencies
- Project 06 (hook-edit guard) — hook addition must respect mid-session immutability

## Risks
- Backfill introduces churn → stage by workspace type; commit per workspace
