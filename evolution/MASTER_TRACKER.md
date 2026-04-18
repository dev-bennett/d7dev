# Master Tracker — Framework Evolution

Reference framework: `../analytical-orchestration-framework.md`
Gap analysis: `GAP_ANALYSIS.md`
Roadmap artifacts: `roadmap/` (steps 1–6 of the roadmapping process)
Project index: `README.md`
Last updated: 2026-04-18

## Structure
Work is organized as **swimlane → epic → task-directory**.
- **Swimlanes** (roadmap/04): 7 dependency-ordered layers
- **Epics** (roadmap/04): 23 named bundles with scope + linked ideas + priority
- **Task directories** (`01-*` through `25-*`): phase-level plans within epics; some epics span multiple task directories; three epics still need new task directories (2.2, 3.3, 4.3)

## Status legend
- **not-started** — project defined, no work begun
- **in-progress** — at least one phase started
- **blocked** — waiting on dependency
- **complete** — all phases exited
- **abandoned** — project abandoned (with reason in tracker.md)

## Swimlane 0 — Substrate & bootstrap hygiene

### Epic 0.1 — Runtime substrate catalog — **P1**
- Ideas: I13, I15, I21, I53
- Tasks:
  - `03-runtime-substrate-audit/` — not-started

### Epic 0.2 — Zero-prompt & command-call integrity — **P1**
- Ideas: I22, I29
- Tasks:
  - `01-zero-prompt-contract-audit/` — not-started

### Epic 0.3 — Telemetry substrate (OpenTelemetry) — **P1**
- Ideas: I55 (user-introduced)
- Upstream: none
- Downstream beneficiaries: 1.2, 2.3, 5.2, 6.8, 6.9
- Tasks:
  - `25-telemetry-substrate/` — not-started

## Swimlane 1 — Enforcement foundation

### Epic 1.1 — Hook lifecycle & safety — **P1**
- Ideas: I27, I28
- Upstream: 0.1
- Tasks:
  - `06-hook-edit-guard/` — not-started

### Epic 1.2 — Unified session & event state substrate — **P1**
- Ideas: I23, I26, I30, I54
- Upstream: 0.3 (OTel stream), 1.1 (safe hook evolution)
- Tasks:
  - `02-unified-session-state-log/` — not-started

## Swimlane 2 — Governance machinery

### Epic 2.1 — Directive artifact linter — **P2**
- Ideas: I17, I18
- Upstream: 1.2
- Tasks:
  - `04-directive-linter/` — not-started

### Epic 2.2 — Directive enforcement at delivery — **P3**
- Ideas: I14, I48, I49, I50, I51, I52
- Upstream: 2.1
- Tasks:
  - _new task directory needed_ — not-created

### Epic 2.3 — Rule lifecycle & telemetry — **P2**
- Ideas: I19, I20, I08
- Upstream: 1.2
- Tasks:
  - `05-rule-efficacy-telemetry/` — not-started

## Swimlane 3 — Memory & transcript substrate

### Epic 3.1 — Memory decay & promotion — **P2**
- Ideas: I31, I32, I33, I34, I35
- Upstream: 1.2
- Tasks:
  - `08-top-n-stalest-memory-injection/` — not-started
  - `09-open-memory-auto-promotion/` — not-started

### Epic 3.2 — Memory-to-rule migration — **P3**
- Ideas: I36
- Upstream: 2.3, 3.3
- Tasks:
  - `10-memory-to-rule-migration/` — not-started

### Epic 3.3 — Session-transcript corpus access — **P3**
- Ideas: I37
- Upstream: 1.2
- Tasks:
  - _new task directory needed_ — not-created

## Swimlane 4 — Workspace & knowledge hygiene

### Epic 4.1 — Workspace contract & query hygiene — **P2**
- Ideas: I16, I38, I39, I40, I41, I42
- Upstream: 1.1
- Tasks:
  - `11-task-readme-frontmatter/` — not-started

### Epic 4.2 — Knowledge discovery gate + cross-reference integrity — **P2**
- Ideas: I43, I44
- Upstream: 1.1
- Tasks:
  - `12-discovery-gate-enforcement/` — not-started

### Epic 4.3 — Reference-layer manifest & staleness — **P3**
- Ideas: I45, I46
- Upstream: none
- Tasks:
  - _new task directory needed_ — not-created

## Swimlane 5 — Orchestration intelligence

### Epic 5.1 — Prior-investigation enforcement — **P2**
- Ideas: I47
- Upstream: 1.1
- Tasks:
  - `13-prior-investigation-enforcement/` — not-started

### Epic 5.2 — Cost-aware agent dispatch — **P2**
- Ideas: I24, I25
- Upstream: 0.1, 1.2
- Tasks:
  - `07-agent-cost-dispatch/` — not-started

### Epic 5.3 — Semantic directive critique — **P3**
- Ideas: I01
- Upstream: 2.1
- Tasks:
  - `14-semantic-directive-governance/` — not-started

### Epic 5.4 — Parallel hypothesis arbitration — **P3**
- Ideas: I02
- Upstream: 5.1, 5.2
- Tasks:
  - `15-parallel-hypothesis-arbitration/` — not-started

## Swimlane 6 — Corpus-level & self-evolution

### Epic 6.1 — Decay-aware knowledge substrate — **P3**
- Ideas: I04
- Upstream: 3.1, 4.1
- Tasks:
  - `17-knowledge-graph-substrate/` — not-started

### Epic 6.2 — Warehouse-state live context frame — **P3**
- Ideas: I09
- Upstream: 1.2
- Tasks:
  - `21-warehouse-state-context-frame/` — not-started

### Epic 6.3 — Claim-to-provenance rendering — **P3**
- Ideas: I03
- Upstream: 2.1, 4.1, 6.2
- Tasks:
  - `16-claim-provenance-rendering/` — not-started

### Epic 6.4 — Intervention lifecycle tracker — **P3**
- Ideas: I07
- Upstream: 2.1
- Tasks:
  - `20-intervention-lifecycle-tracker/` — not-started

### Epic 6.5 — Stakeholder epistemic model — **P3**
- Ideas: I05
- Upstream: 6.1
- Tasks:
  - `18-stakeholder-epistemic-model/` — not-started

### Epic 6.6 — Cross-session adversarial replay — **P3**
- Ideas: I06
- Upstream: 3.3, 5.3, 6.5
- Tasks:
  - `19-cross-session-adversarial-replay/` — not-started

### Epic 6.7 — Epistemic drift detection — **P3**
- Ideas: I10
- Upstream: 5.3, 6.1
- Tasks:
  - `22-epistemic-drift-detection/` — not-started

### Epic 6.8 — Meta-retrospective — **P3**
- Ideas: I11
- Upstream: 2.3, 3.3
- Tasks:
  - `23-meta-retrospective/` — not-started

### Epic 6.9 — Directive efficacy experiments — **P4**
- Ideas: I12
- Upstream: 1.2, 2.3, 6.8
- Tasks:
  - `24-directive-efficacy-experiments/` — not-started

## Rollup

**Counts by priority**
- P1: 5 epics (0.1, 0.2, 0.3, 1.1, 1.2)
- P2: 7 epics (2.1, 2.3, 3.1, 4.1, 4.2, 5.1, 5.2)
- P3: 10 epics (2.2, 3.2, 3.3, 4.3, 5.3, 5.4, 6.1–6.8)
- P4: 1 epic (6.9)
- Total: 23 epics

**Counts by status**
- not-started: 23 epics (25 task-directories not-started, 3 new task-directories needed for 2.2, 3.3, 4.3)
- in-progress: 0
- blocked: 0 (all dependencies satisfied at P1 level)
- complete: 0
- abandoned: 0

**Counts by swimlane**
- Swimlane 0: 3 epics (0.1, 0.2, 0.3)
- Swimlane 1: 2 epics
- Swimlane 2: 3 epics
- Swimlane 3: 3 epics
- Swimlane 4: 3 epics
- Swimlane 5: 4 epics
- Swimlane 6: 9 epics

## Critical path
`0.1 → 1.1 → 1.2 → 2.1 → 5.3 → 6.6` — six epics in series. Any slip on 0.1 propagates the chain. Epic 0.3 is parallel to 0.1 and feeds 1.2, 2.3, 5.2, 6.8, 6.9 but does not extend the critical path.

## Immediate pick
P1 epics have minimal mutual dependencies at the top of the tree. Parallel starts: **0.1 + 0.2 + 0.3** in one session; **1.1** in the session after 0.1; **1.2** after both 1.1 and 0.3.

## Gap-analysis coverage
Per `roadmap/06-roadmap-artifact.md` integration check: every non-MATCH item in `GAP_ANALYSIS.md` maps to exactly one epic (52 items), is emergent (2 items — epistemic discipline + memory discipline — covered across multiple epics), or is out-of-scope operational cleanup (1 item — lookml submodule half-registration, tracked in `project_commit_backlog.md`). Plus one user-introduced item (I55 OTel telemetry) owned by Epic 0.3, added post-audit.

## Update protocol
- Per-task `tracker.md` remains the source of truth for phase/status
- This master tracker is refreshed during `/evolve` sessions or at manual review points
- When an epic's status or dependency changes, update both the relevant task tracker AND this file
- Roadmap artifacts in `roadmap/` are refreshed when an epic's scope, priority, or swimlane assignment changes
