# Step 5 — Prioritize

Priority bands: **P1** immediate / **P2** next / **P3** frontier / **P4** future / **P5** backlog.

Priority is assigned per epic, not per task-directory. Rationale is documented for every P1 and P2 epic.

## P1 — Immediate (unblocks everything downstream)

| Epic | Name | Rationale |
|------|------|-----------|
| 0.1  | Runtime substrate catalog | User explicitly named this as a structural gap. Unblocks every downstream swimlane by clarifying where resources live and what capabilities are assumed. |
| 0.2  | Zero-prompt & command-call integrity | Active friction observed in the current session's /orient run. Any new command or hook added without this epic done will repeat the prompt-storm. |
| 0.3  | Telemetry substrate (OpenTelemetry) | Verification foundation. Without structured telemetry, every downstream claim about system behavior depends on reading transcripts and trusting the narrative. User explicitly rejects work accepted on promise. OTel enablement is low-effort; the leverage is that Epic 1.2 (event log), Epic 2.3 (rule telemetry), Epic 5.2 (dispatch cost), Epic 6.8 (meta-retro), Epic 6.9 (directive experiments) consume this substrate directly rather than rolling their own instrumentation. |
| 1.1  | Hook lifecycle & safety | Blocker for safely evolving any hook-based enforcement (epics 1.2, 4.1, 4.2, 5.1). Without this, every hook migration carries mid-session-disable risk. |
| 1.2  | Unified session & event state substrate | Consumer of 0.3 telemetry stream; upstream of dispatch logging (5.2), transcript processes (3.3), meta-retrospective (6.8). Earliest enabler of corpus-level intelligence once 0.3 is in place. |

## P2 — Next (compliance with framework §1–§9)

| Epic | Name | Rationale |
|------|------|-----------|
| 2.1  | Directive artifact linter | Gates projects 5.3, 6.3, 6.6. Every downstream semantic check depends on parsable §-blocks. |
| 2.3  | Rule lifecycle & telemetry | Pruning discipline; converts memory-to-rule flow into a measurable path. Also the pattern that all other telemetry-enabled projects inherit. |
| 3.1  | Memory decay & promotion | Low-to-medium cost; addresses recurring session-start friction (stale memory cited as fresh). Ships independently. |
| 4.1  | Workspace contract & query hygiene | `/orient` and `/status` become structured rather than string-parsed. Unblocks task-level telemetry in downstream epics. |
| 4.2  | Knowledge discovery gate | Prevents a known failure class (knowledge from samples). Low complexity once hook-lifecycle (1.1) is in place. |
| 5.1  | Prior-investigation enforcement | Prevents the most expensive single class of workflow failure observed in recent sessions (fishing-expedition investigation). Hook-enforces a pattern already required behaviorally. |
| 5.2  | Cost-aware agent dispatch | Cheap annotation pass + dispatcher heuristic; addresses the duplicated-search anti-pattern. |

## P3 — Frontier (§10 evolution horizons)

| Epic | Name |
|------|------|
| 2.2  | Directive enforcement at delivery |
| 3.2  | Memory-to-rule migration |
| 3.3  | Session-transcript corpus access |
| 4.3  | Reference-layer manifest & staleness |
| 5.3  | Semantic directive critique |
| 5.4  | Parallel hypothesis arbitration |
| 6.1  | Decay-aware knowledge substrate |
| 6.2  | Warehouse-state live context frame |
| 6.3  | Claim-to-provenance rendering |
| 6.4  | Intervention lifecycle tracker |
| 6.5  | Stakeholder epistemic model |
| 6.6  | Cross-session adversarial replay |
| 6.7  | Epistemic drift detection |
| 6.8  | Meta-retrospective |

## P4 — Future (requires P3 maturity)

| Epic | Name |
|------|------|
| 6.9  | Directive efficacy experiments |

## P5 — Backlog
*(none currently — all gaps assigned at P1–P4)*

## Priority tally
- P1: 5 epics (0.1, 0.2, 0.3, 1.1, 1.2)
- P2: 7 epics
- P3: 14 epics (includes 2.2 promoted-from-P2 on reshuffle; others unchanged)
- P4: 1 epic (6.9)
- Total: 27 (one added for 0.3 telemetry)

(Note: Some P3 items were promoted-from-P2 or absorbed into P1 epics via §1.4 additions in the framework revision. Some former tier-2 projects split across multiple P-levels because epics now group ideas differently than the flat list did.)
