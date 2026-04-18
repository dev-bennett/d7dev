# Step 1 — Scope & Stakeholders

## Initiative name
Framework Evolution — Next-generation implementation of the analytical orchestration framework

## Reference
`../../analytical-orchestration-framework.md`

## Problem statement
The current workspace is a first-generation implementation of the framework. GAP_ANALYSIS.md audited 67 recommendations and found 30 ABSENT, 13 GAP, 11 PARTIAL, 13 MATCH. Gaps are structural (no directive linter, no rule telemetry, no unified state log, no hook-edit guard) and behavioral (prior-investigation search, discovery-before-knowledge, zero-prompt contract). The framework doc also names 12 frontier evolution horizons (§10), none of which are implemented.

## In scope
- Close every GAP/PARTIAL/ABSENT item in GAP_ANALYSIS.md with a named epic that owns it
- Implement the 12 §10 horizons as a set of epics
- Restructure the flat 24-project list into swimlanes + epics with explicit dependencies
- Produce a roadmap artifact that the user can consume for sequencing decisions

## Out of scope
- Host-runtime modifications (hook event definitions, permission model, CLAUDE.md import semantics are substrate; we consume, not author)
- External-system integration work (ticketing, BI platform UI) beyond minimal pointer handoffs
- Production code in the warehouse-transformation or BI repositories — those stay promoted-from-workspace

## Stakeholders
- **Primary stakeholder:** the user (principal analyst). Consumer of every artifact produced by this initiative — briefs, trackers, roadmap documents, retrospectives, chat messages, and the framework doc itself. Decision-maker on scope, priority, and acceptance. Subject to the same stakeholder-communication discipline (§8 adversarial check, §10 sentence audit, §11 intervention classification) that external stakeholders receive.
- **Primary implementer:** the AI agent operating this workspace. Authors artifacts for the primary stakeholder to consume.
- **Downstream (indirect) stakeholders:** external consumers of analytical deliverables produced via the framework (marketing, engineering, finance, product, RevOps). Their experience improves as the framework matures; they do not vote on the framework-evolution initiative itself.

Framing correction (2026-04-18): earlier versions of this scope doc treated the user as "decision-maker / consumer" and reserved the word "stakeholder" for external consumers. That framing was wrong and is now corrected. The user is the first-class stakeholder for this initiative; every artifact produced here is a stakeholder-facing artifact.

## Success criteria
- Every gap in GAP_ANALYSIS.md is assigned to an epic (no orphans)
- Every epic has a priority (P1–P5) with rationale
- Dependency graph has no silent cycles and exposes the critical path
- A canonical `/orient` and `/evolve` run reflects the swimlane/epic structure when reporting status
- Every artifact produced for the primary stakeholder (briefs, trackers, retrospectives, chat responses, roadmap documents) passes the §10 Sentence Audit and the §8 Adversarial Check before delivery — this applies to workspace-internal artifacts, not only external-facing prose

## Known constraints
- `feedback_dont_edit_live_hooks.md`: hook edits apply at session boundaries
- Commit-hygiene recurrence (`project_commit_backlog.md`): landing changes incrementally is mandatory
- User-level substrate (§1.4 of framework doc) is not directly modifiable from this workspace

## Timeline posture
Quarter-scale rollout. Tier-1 (P1) epics expected to land within ~4 sessions each. Tier-3 (P3–P4) epics expected to span multiple months with external validation.
