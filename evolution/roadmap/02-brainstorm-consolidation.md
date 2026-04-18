# Step 2 — Brainstorm Consolidation

This initiative did not run a live FigJam brainstorm. The brainstorm inputs were produced asynchronously via two artifacts:

1. `../../analytical-orchestration-framework.md` §10 — 12 frontier horizon items
2. `../GAP_ANALYSIS.md` — 67 audited recommendations (30 ABSENT + 13 GAP + 11 PARTIAL scored as candidate work items)

Plus one user-identified gap (runtime substrate recognition) that predates both.

The consolidated raw-idea list below is the input to Step 3 (Group & Define). Items are neither grouped nor prioritized here — that belongs downstream.

## Raw idea enumeration

### From framework §10 horizons
- I01 Semantic governance of directive artifacts (§10.1)
- I02 Parallel hypothesis arbitration (§10.2)
- I03 Claim-to-provenance binding at runtime (§10.3)
- I04 Decay-aware knowledge substrate (§10.4)
- I05 Stakeholder epistemic modeling (§10.5)
- I06 Cross-session adversarial replay (§10.6)
- I07 Intervention lifecycle as first-class artifact (§10.7)
- I08 Rule efficacy as measurable and evolutionary (§10.8)
- I09 Warehouse-state as live session context (§10.9)
- I10 Epistemic drift detection (§10.10)
- I11 Retrospective-of-retrospectives (§10.11)
- I12 Directive efficacy experiments (§10.12)

### From GAP_ANALYSIS §1
- I13 9-artifact-class enumeration in root CLAUDE.md
- I14 Core-invariant traceability enforced at tool-call surface
- I15 Runtime substrate recognition (user's hunch)

### From GAP_ANALYSIS §2 / §6.1
- I16 Scratch vs exploratory separation

### From GAP_ANALYSIS §3
- I17 Fenced §-block preambles
- I18 Directive-presence linter
- I19 Rule files carry `applies_to` / `implements` / `last_reviewed` frontmatter
- I20 Rule efficacy telemetry (fire/violation/irrelevance counters)

### From GAP_ANALYSIS §4
- I21 Commands-vs-skills disambiguation (framework doc + catalog)
- I22 Zero-prompt contract on canonical commands
- I23 `/evolve` auto-invocation threshold
- I24 Agent `expected_context_cost` field
- I25 Cost-aware sub-agent dispatch
- I26 Unified `.state/sessions/<id>.jsonl` event log
- I27 Hook-edit guard
- I28 Content-hash retry fingerprinting
- I29 Class-based bash whitelist
- I30 SessionEnd structured summary emission

### From GAP_ANALYSIS §5
- I31 `origin_session_id` consistency across memories
- I32 `violates:[§N]` frontmatter field on feedback memories
- I33 Top-N stalest memory injection
- I34 `_open.md` 14-day auto-promotion
- I35 `_open.md` 30-day forced resolution
- I36 Memory-to-rule migration proposal
- I37 Session-transcript corpus as accessible substrate

### From GAP_ANALYSIS §6
- I38 Task README strict frontmatter contract
- I39 `abandoned` as first-class task status
- I40 Per-query-set subdirectory enforcement (hook)
- I41 Query header schema (env, role, expected outputs)
- I42 Post-run output validation

### From GAP_ANALYSIS §7
- I43 Discovery gate on `knowledge/` writes
- I44 Cross-reference integrity check

### From GAP_ANALYSIS §8
- I45 MANIFEST.md schema standardization
- I46 30-day reference staleness flag

### From GAP_ANALYSIS §9
- I47 Prior-investigation search enforcement (hook)
- I48 Three-pass workflow enforcement
- I49 Writing-scrub operational coverage validation
- I50 §11 Intervention classification delivery gate
- I51 Substantiation-frame-first enforcement
- I54 `/preflight` consistent invocation at task-start (auto-trigger analog to `/evolve`)

### User-introduced (post-audit)
- I55 OpenTelemetry-based structured tracing substrate — enable `CLAUDE_CODE_ENABLE_TELEMETRY`, run a local OTLP collector, expose tool calls / session events / token usage / latencies as structured spans + metrics + logs; foundation for verification (as opposed to trust) of every downstream measurement

### From GAP_ANALYSIS §12
- I52 Communication norms structural enforcement beyond writing-scrub

### From GAP_ANALYSIS §13
- I53 Bootstrap-sequence canonical record (the current workspace was bootstrapped iteratively)

## Count
55 raw ideas total (54 gap-derived + 1 user-introduced post-audit).

## Coverage audit against GAP_ANALYSIS.md

Objective: every non-MATCH row in `../GAP_ANALYSIS.md` maps to exactly one I-item here, or is explicitly flagged as out of scope for discrete project planning.

Non-MATCH row count from GAP_ANALYSIS: 11 PARTIAL + 13 GAP + 30 ABSENT = 54 (with two overlaps — discovery/ appears in both §6 and §7; /evolve auto-invocation appears in both §4 and §9 — so 54 distinct).

Coverage by GAP_ANALYSIS section:

| GAP § | Row                                                         | Covered by |
| ----- | ----------------------------------------------------------- | ---------- |
| §1    | 9-artifact-class enumeration (PARTIAL)                      | I13        |
| §1    | Core-invariant traceability (GAP)                           | I14        |
| §1    | Runtime substrate recognition (ABSENT)                      | I15        |
| §2    | Scratch vs exploratory separation (GAP)                     | I16        |
| §3    | Fenced §-block preambles (ABSENT)                           | I17        |
| §3    | Directive-presence linter (ABSENT)                          | I18        |
| §3    | Rule frontmatter (ABSENT)                                   | I19        |
| §3    | Rule efficacy telemetry (ABSENT)                            | I20        |
| §4    | Commands-vs-skills disambiguation (GAP)                     | I21        |
| §4    | Zero-prompt contract (GAP)                                  | I22        |
| §4    | /evolve auto-invocation (ABSENT)                            | I23 (shared with §9) |
| §4    | Agent expected_context_cost (ABSENT)                        | I24        |
| §4    | Cost-aware dispatch (ABSENT)                                | I25        |
| §4    | Unified state log (GAP)                                     | I26        |
| §4    | Hook-edit guard (ABSENT)                                    | I27        |
| §4    | Content-hash retry fingerprinting (GAP)                     | I28        |
| §4    | Class-based bash whitelist (GAP)                            | I29        |
| §4    | SessionEnd structured summary (PARTIAL)                     | I30        |
| §5    | origin_session_id consistency (PARTIAL)                     | I31        |
| §5    | violates:[§N] frontmatter (ABSENT)                          | I32        |
| §5    | Top-N stalest injection (ABSENT)                            | I33        |
| §5    | _open.md 14d auto-promotion (ABSENT)                        | I34        |
| §5    | _open.md 30d forced resolution (ABSENT)                     | I35        |
| §5    | Memory-to-rule migration (ABSENT)                           | I36        |
| §5    | Session-transcript corpus as substrate (ABSENT)             | I37        |
| §6    | Task README frontmatter (ABSENT)                            | I38        |
| §6    | abandoned first-class status (ABSENT)                       | I39        |
| §6    | discovery/ sibling convention (ABSENT)                      | I43 (shared with §7) |
| §6    | Per-query-set subdir enforcement (PARTIAL)                  | I40        |
| §6    | Query header env/role/outputs (ABSENT)                      | I41        |
| §6    | Post-run output validation (ABSENT)                         | I42        |
| §7    | Discovery-gate enforcement (ABSENT)                         | I43        |
| §7    | Cross-reference integrity (ABSENT)                          | I44        |
| §8    | Submodules half-registered (PARTIAL)                        | **OUT OF SCOPE** — operational cleanup; tracked in `project_commit_backlog.md` memory, not a framework project |
| §8    | MANIFEST ingestion-date schema (PARTIAL)                    | I45        |
| §8    | 30-day staleness flag (ABSENT)                              | I46        |
| §9    | /preflight consistent invocation (PARTIAL)                  | I54        |
| §9    | Prior-investigation search enforcement (GAP)                | I47        |
| §9    | Three-pass workflow enforcement (GAP)                       | I48        |
| §9    | Writing scrub scope (PARTIAL)                               | I49        |
| §9    | Intervention-classification delivery gate (GAP)             | I50        |
| §9    | /evolve auto-trigger (GAP)                                  | I23        |
| §9    | Substantiation-frame enforcement (GAP)                      | I51        |
| §10.1 | Semantic governance                                          | I01        |
| §10.2 | Parallel hypothesis arbitration                              | I02        |
| §10.3 | Claim-to-provenance                                          | I03        |
| §10.4 | Decay-aware knowledge substrate                              | I04        |
| §10.5 | Stakeholder epistemic modeling                               | I05        |
| §10.6 | Cross-session adversarial replay                             | I06        |
| §10.7 | Intervention lifecycle                                       | I07        |
| §10.8 | Rule efficacy (ABSENT, overlaps §3.2)                        | I08        |
| §10.9 | Warehouse-state live context                                 | I09        |
| §10.10| Epistemic drift detection                                    | I10        |
| §10.11| Retrospective-of-retrospectives                              | I11        |
| §10.12| Directive efficacy experiments                               | I12        |
| §12   | Communication norms structural enforcement (PARTIAL)         | I52        |
| §12   | Epistemic discipline enforcement (PARTIAL)                   | **EMERGENT** — satisfied by collective of I14 (traceability), I17–I18 (linter), I01 (semantic critic), I47 (prior-investigation), I50 (delivery gate), I51 (substantiation) |
| §12   | Memory discipline mid-session update (PARTIAL)               | **EMERGENT** — satisfied by I33 (stale injection nudges review), I36 (memory-to-rule), project 09 (forced resolution) |
| §13   | Bootstrap sequence canonical record (PARTIAL)                | I53        |
| (new) | OpenTelemetry structured tracing substrate (user-introduced, P1) | I55    |

**Coverage status:** 54 non-MATCH rows → 52 assigned I-items + 2 marked EMERGENT + 1 marked OUT OF SCOPE = 55 total dispositions (one row double-assigned where §3.2 and §10.8 overlap on rule telemetry).

## Handoff to Step 3
All 55 I-items feed into `03-groupings.md` for thematic clustering. Out-of-scope and emergent items are acknowledged in groupings as notes, not as distinct groups.
