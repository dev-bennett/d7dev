# Project 03: Runtime substrate audit

## Overview
The framework document treats host-runtime capabilities (hook events, permissions model, CLAUDE.md auto-loading, additional-context injection, session-transcript persistence, native task tools, skills, plugins, MCP integrations) as implicit background infrastructure. The user's multi-week experience shows the opposite: these user-level Claude objects have been structurally critical to traction and are the least-documented part of the system. The framework doc has been revised to add §1.4 recognizing the substrate, but a catalog of every substrate resource, its scope, its lifecycle, and its canonical usage pattern does not yet exist.

This project produces that catalog and the interaction-pattern guidance derived from it.

## Linked framework section
`../../analytical-orchestration-framework.md` §1.4 (Runtime substrate)

## End goal
A single documented catalog covering every user-scope and project-scope Claude runtime resource. Each entry includes:

- Resource name and path
- Scope (user `~/.claude/` vs project `<repo>/.claude/`)
- Lifecycle semantics (when created, when updated, when deleted)
- Authoring mechanism (human, agent, runtime, plugin)
- Invocation mechanism (tool, command, skill, auto-loaded)
- Precedence rules when user-scope and project-scope overlap
- Canonical usage pattern (when to prefer this resource over alternatives)
- Known failure modes

Output: `knowledge/runbooks/runtime-substrate-catalog.md` (committed artifact) plus optional `evolution/03-runtime-substrate-audit/inventory/` holding any discovery scripts.

## Phased approach

### Phase 1 — Inventory
**Complexity:** Low-Medium
**Exit criteria:** Every resource in `~/.claude/` and `<repo>/.claude/` is listed with path, scope, apparent lifecycle.
**Resources to inventory:**
- Memory (user-scope, per-project keyed by project path)
- Session transcripts (user-scope)
- Projects registry (user-scope)
- Todos / native task state (user-scope)
- Settings files at user vs project scope with precedence
- Commands (project-scope)
- Agents (project-scope + user-scope if any)
- Hooks (project-scope + user-scope if any)
- Skills (user-scope via plugins + project-scope via plugin installation)
- MCP / plugin registry (user-scope)
- Rules (project-scope, auto-loaded)
- CLAUDE.md import chain (project-scope, auto-loaded)
- Keybindings (user-scope config)
- Status line config (user-scope config)
- Session log (user-scope transcripts directory)

### Phase 2 — Interaction mapping
**Complexity:** Medium
**Exit criteria:** For each resource, document how it interacts with other resources. Produce an adjacency diagram or table. Identify conflicts (e.g., user-level hook overriding project-level hook) and recommend precedence.
**Steps:**
- For each resource pair, identify interaction surfaces (shared state, overrides, sequencing)
- Document precedence rules (project overrides user, user-scope memory keyed by project, etc.)
- Identify known-problematic interactions (e.g., hook edits mid-session, settings.local.json overriding settings.json silently)

### Phase 3 — Canonical patterns + runbook
**Complexity:** Medium
**Exit criteria:** `knowledge/runbooks/runtime-substrate-catalog.md` committed. `/orient` references it. Framework doc §1.4 cross-links to it.
**Steps:**
- Write the runbook with all three preceding outputs
- Add cross-references from framework doc §1.4
- Link from `/orient` output as optional deep-dive material

## Dependencies
- None (purely observational)

## Risks
- Host-runtime behavior is under active development — cross-reference against the runtime's documentation release notes, and date-stamp the runbook
