# Evolution — Framework Implementation Tracking

@../CLAUDE.md

## Purpose
Track material evolution of the analytical orchestration framework described in `../analytical-orchestration-framework.md`. Work is organized as swimlane → epic → task-directory per the 7-step roadmapping process outputs in `roadmap/`.

## Stakeholder framing
The primary stakeholder for every artifact in this directory is the workspace operator (the user). All briefs, trackers, roadmap artifacts, retrospectives, and chat responses produced in the course of this initiative are stakeholder-facing and subject to the full framework discipline — §8 Adversarial Check, §10 Sentence Audit, §11 Intervention Classification where applicable. "Stakeholder-facing" is not synonymous with "external"; the workspace operator is a first-class stakeholder for workspace-internal artifacts. See framework doc §1.5.

## Directory conventions
- `roadmap/` — outputs of the 7-step roadmapping process (scope, brainstorm, groupings, swimlanes+epics, priorities, roadmap artifact)
- `NN-slug/` — task-level plans. Each task belongs to exactly one epic per `roadmap/04-swimlanes-and-epics.md`.
- `MASTER_TRACKER.md` — rollup organized by swimlane → epic → task
- `GAP_ANALYSIS.md` — framework-doc → current-state audit (one-shot, refreshed during /evolve)
- `_templates/project-template/` — scaffolding for new task directories

## Authority hierarchy
1. `../analytical-orchestration-framework.md` — end-state definition
2. `GAP_ANALYSIS.md` — current-state diagnosis
3. `roadmap/04-swimlanes-and-epics.md` — authoritative epic definitions + task mapping
4. `roadmap/05-priorities.md` — priority assignments
5. Per-task `brief.md` — phase-level plan
6. Per-task `tracker.md` — source of truth for phase/status

## Update cadence
- Per-task `tracker.md`: updated when phase state changes
- `MASTER_TRACKER.md`: updated during `/evolve` sessions or at review points
- `GAP_ANALYSIS.md`: refreshed periodically (quarterly) to reflect closure of gaps
- Framework-doc amendments go to the framework doc first, then propagate to affected epics
- Epic scope changes go to `roadmap/04-swimlanes-and-epics.md` first, then propagate to affected tasks
