# Evolution Projects

Reference framework: `../analytical-orchestration-framework.md`
Gap analysis: `GAP_ANALYSIS.md`
Roadmap artifacts: `roadmap/` (7-step roadmapping process outputs — scope, brainstorm, groupings, swimlanes+epics, priorities, roadmap artifact)
Status dashboard: `MASTER_TRACKER.md`

## Structure
Work is organized as **swimlane → epic → task-directory**:
- **Swimlanes** — 7 dependency-ordered layers (0–6). Defined in `roadmap/04-swimlanes-and-epics.md`.
- **Epics** — 23 named bundles of related ideas. Each epic has a scope statement, included ideas (I01–I55 from brainstorm), priority (P1–P5), and mapped task directories.
- **Task directories** (`01-*` through `25-*`) — phase-level plans living within epics. Some epics span multiple task directories; three epics still need new task directories (2.2, 3.3, 4.3).

The flat `NN-slug` naming persists because these directories were created before the 7-step roadmap was iterated. The authoritative epic↔task-directory index lives in `roadmap/06-roadmap-artifact.md` and is rolled into `MASTER_TRACKER.md`.

## Tiers (legacy — use priorities going forward)
The original tier-1/tier-2/tier-3 labels still appear in task-directory briefs. The canonical priority system going forward is P1–P5 per `roadmap/05-priorities.md`.

## How to work with these projects
1. Consult `MASTER_TRACKER.md` to see the current epic/task status in swimlane order
2. Pick a P1 epic first, then P2, then P3 — respecting dependencies listed per epic
3. Read the task-directory `brief.md` for overview, end-goal, phased approach
4. Update the task-directory `tracker.md` when phase state changes
5. Run `/evolve` at session end to propagate status to `MASTER_TRACKER.md`

## Task directory index

| #  | Task directory                             | Epic | Priority |
| -- | ------------------------------------------ | ---- | -------- |
| 01 | zero-prompt-contract-audit                 | 0.2  | P1       |
| 02 | unified-session-state-log                  | 1.2  | P1       |
| 03 | runtime-substrate-audit                    | 0.1  | P1       |
| 04 | directive-linter                           | 2.1  | P2       |
| 05 | rule-efficacy-telemetry                    | 2.3  | P2       |
| 06 | hook-edit-guard                            | 1.1  | P1       |
| 07 | agent-cost-dispatch                        | 5.2  | P2       |
| 08 | top-n-stalest-memory-injection             | 3.1  | P2       |
| 09 | open-memory-auto-promotion                 | 3.1  | P2       |
| 10 | memory-to-rule-migration                   | 3.2  | P3       |
| 11 | task-readme-frontmatter                    | 4.1  | P2       |
| 12 | discovery-gate-enforcement                 | 4.2  | P2       |
| 13 | prior-investigation-enforcement            | 5.1  | P2       |
| 14 | semantic-directive-governance              | 5.3  | P3       |
| 15 | parallel-hypothesis-arbitration            | 5.4  | P3       |
| 16 | claim-provenance-rendering                 | 6.3  | P3       |
| 17 | knowledge-graph-substrate                  | 6.1  | P3       |
| 18 | stakeholder-epistemic-model                | 6.5  | P3       |
| 19 | cross-session-adversarial-replay           | 6.6  | P3       |
| 20 | intervention-lifecycle-tracker             | 6.4  | P3       |
| 21 | warehouse-state-context-frame              | 6.2  | P3       |
| 22 | epistemic-drift-detection                  | 6.7  | P3       |
| 23 | meta-retrospective                         | 6.8  | P3       |
| 24 | directive-efficacy-experiments             | 6.9  | P4       |
| 25 | telemetry-substrate                        | 0.3  | P1       |

## Epics without task directories yet
- Epic 2.2 (Directive enforcement at delivery, P3)
- Epic 3.3 (Session-transcript corpus access, P3)
- Epic 4.3 (Reference-layer manifest & staleness, P3)

Create these task directories when work on those epics begins.
