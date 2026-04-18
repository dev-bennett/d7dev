# Step 6 — Roadmap Artifact

Canonical outline + dependency graph for the framework-evolution initiative. This is the tracking document referenced by `../MASTER_TRACKER.md`.

## Swimlane × priority matrix

```
                          P1                    P2                     P3                       P4
Swimlane 0 Substrate    | 0.1, 0.2, 0.3       |                      |                         |
Swimlane 1 Enforcement  | 1.1, 1.2            |                      |                         |
Swimlane 2 Governance   |                     | 2.1, 2.3             | 2.2                     |
Swimlane 3 Memory       |                     | 3.1                  | 3.2, 3.3                |
Swimlane 4 Hygiene      |                     | 4.1, 4.2             | 4.3                     |
Swimlane 5 Intelligence |                     | 5.1, 5.2             | 5.3, 5.4                |
Swimlane 6 Corpus       |                     |                      | 6.1–6.8                 | 6.9
```

## Dependency graph

```
         ┌──────────────────┐
         │ 0.3 Telemetry    │────────────┐
         │   (OTel)         │            │
         └──────────────────┘            │
                                         │
                                ┌────────▼───────┐
                                │ 0.1 Substrate  │─────┐
                                │    catalog     │     │
                                └────────────────┘     │
                                                       ▼
┌────────────────┐                              ┌────────────────┐
│ 0.2 Zero-prompt│──────────────────────────────│ 1.1 Hook       │
└────────────────┘                              │ lifecycle      │
                                                └─────┬──────────┘
                                                      │
                                                      ▼
                                                ┌────────────────┐
                                                │ 1.2 Unified    │──┐
                                                │ event log      │  │  (consumes 0.3 stream)
                                                └─────┬──────────┘  │
                                                      │             │
                       ┌──────────────────────────────┼────────────┐│
                       ▼                              ▼            ││
              ┌────────────────┐              ┌───────────────┐    ││
              │ 2.1 Directive  │              │ 2.3 Rule      │    ││
              │ linter         │              │ telemetry     │    ││
              └───────┬────────┘              └───────┬───────┘    ││
                      │                               │            ││
           ┌──────────┴──────┐                        │            ││
           ▼                 ▼                        ▼            ││
     ┌──────────┐     ┌──────────┐             ┌──────────┐        ││
     │ 2.2 Del. │     │ 5.3 Crit.│             │ 3.2 Mem  │        ││
     │ gate     │     │          │             │ to rule  │◀───────┘│
     └──────────┘     └────┬─────┘             └─────┬────┘         │
                           │                         │              │
                           ▼                         ▼              │
            ┌────────────────────────────┐    ┌──────────────┐      │
            │ 6.6 Adversarial replay     │◀───│ 3.3 Corpus   │◀─────┘
            │ 6.7 Drift detection        │    │ access       │
            └────────────────────────────┘    └──┬───────────┘
                                                 │
                                                 ▼
                                            ┌──────────┐
                                            │ 6.8 Meta │
                                            │ retro    │
                                            └────┬─────┘
                                                 ▼
                                            ┌──────────────┐
                                            │ 6.9 Dir exp  │
                                            └──────────────┘

Independent chains:
  1.1 → 4.1 → 4.2 → 6.1 (knowledge graph) → 6.5 (stakeholder model), 6.7 (drift)
  1.1 → 5.1 (prior-inv) → 5.4 (arbitration)  [5.4 also depends on 5.2]
  0.1 → 5.2 (cost dispatch) [5.2 also consumes 0.3 telemetry for real token-cost measurement]
  1.2 → 6.2 (warehouse state) → 6.3 (claim provenance)
  2.1 → 6.4 (intervention tracker)
  3.1 ships independently
  4.3 ships independently

OTel consumers (direct):
  0.3 → 1.2 (event substrate), 2.3 (rule counters), 5.2 (token-cost measurement),
        6.8 (meta-retro corpus metrics), 6.9 (experiment outcome measurement)
```

## Critical path (longest chain of P1–P3 dependencies)

```
0.1 → 1.1 → 1.2 → 2.1 → 5.3 → 6.6 (Cross-session adversarial replay)
```

Six epics in series, spanning Substrate → Enforcement → Governance → Intelligence → Corpus. This is the longest dependency chain; any delay on 0.1 propagates to 6.6.

**Parallelization opportunities:**
- 0.1, 0.2, 0.3 all run in parallel at session start (all P1, no inter-dependency)
- After 1.1: 1.2, 4.1, 4.2, 5.1 can all progress in parallel
- After 1.2: 2.1 and 2.3 in parallel
- 6.1–6.9 largely parallel after their upstream dependencies resolve

## Epic-to-task-directory index

| Epic | Existing task-dir(s) | New task-dir needed? |
|------|----------------------|----------------------|
| 0.1  | `../03-runtime-substrate-audit/` | No |
| 0.2  | `../01-zero-prompt-contract-audit/` | No |
| 0.3  | `../25-telemetry-substrate/` | Yes (created alongside this update) |
| 1.1  | `../06-hook-edit-guard/` | No |
| 1.2  | `../02-unified-session-state-log/` | No |
| 2.1  | `../04-directive-linter/` | No |
| 2.2  | — | Yes (new: delivery-gate work) |
| 2.3  | `../05-rule-efficacy-telemetry/` | No |
| 3.1  | `../08-top-n-stalest-memory-injection/`, `../09-open-memory-auto-promotion/` | No |
| 3.2  | `../10-memory-to-rule-migration/` | No |
| 3.3  | — | Yes (new: corpus access substrate) |
| 4.1  | `../11-task-readme-frontmatter/` | No |
| 4.2  | `../12-discovery-gate-enforcement/` | No |
| 4.3  | — | Yes (new: reference manifest + staleness) |
| 5.1  | `../13-prior-investigation-enforcement/` | No |
| 5.2  | `../07-agent-cost-dispatch/` | No |
| 5.3  | `../14-semantic-directive-governance/` | No |
| 5.4  | `../15-parallel-hypothesis-arbitration/` | No |
| 6.1  | `../17-knowledge-graph-substrate/` | No |
| 6.2  | `../21-warehouse-state-context-frame/` | No |
| 6.3  | `../16-claim-provenance-rendering/` | No |
| 6.4  | `../20-intervention-lifecycle-tracker/` | No |
| 6.5  | `../18-stakeholder-epistemic-model/` | No |
| 6.6  | `../19-cross-session-adversarial-replay/` | No |
| 6.7  | `../22-epistemic-drift-detection/` | No |
| 6.8  | `../23-meta-retrospective/` | No |
| 6.9  | `../24-directive-efficacy-experiments/` | No |

**New task-directories needed:** 4 — Epic 0.3 (created this cycle), and Epics 2.2, 3.3, 4.3 (previously identified, still pending creation).

## Update protocol
- This artifact is refreshed when an epic changes priority, dependency, or swimlane assignment
- Per-task tracker.md files under `../NN-slug/` remain the source of truth for phase/status
- `../MASTER_TRACKER.md` rolls up task-level status under its parent epic per this index

## Gap-analysis integration check
Cross-referenced against `../GAP_ANALYSIS.md`:
- 54 non-MATCH items → 22 epics own 52 items; 2 items flagged emergent; 1 item flagged out-of-scope
- All 12 §10 horizons own dedicated epics (5.3, 5.4, 6.1–6.9) plus rule-efficacy cross-claim with Epic 2.3
- Previously uncovered items now owned: I14 core invariant (Epic 2.2), I37 transcript corpus (Epic 3.3), I45/I46 reference manifest (Epic 4.3), I48 three-pass enforcement (Epic 2.2), I49 writing scrub (Epic 2.2), I50 delivery gate (Epic 2.2), I51 substantiation frame (Epic 2.2), I52 communication norms (Epic 2.2), I54 /preflight auto-invocation (Epic 1.2)
