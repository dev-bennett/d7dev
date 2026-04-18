# Framework Gap Analysis

Reference: `../analytical-orchestration-framework.md`
Date: 2026-04-18
Status tags: **MATCH** (implementation meets spec) / **PARTIAL** (spec partially met) / **GAP** (exists but substantially short of spec) / **ABSENT** (not implemented)

## §1 Foundational identity

| Recommendation                                     | Status  | Evidence                                                                                         |
| -------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------------ |
| Orchestration-brain identity articulation          | MATCH   | CLAUDE.md states "analytical command center"; agent directives reinforce                         |
| 9-artifact-class enumeration                       | PARTIAL | Classes exist but are not formally labeled or cataloged                                          |
| Core-invariant traceability (directive+query+verif)| GAP     | Traceability is by convention. Findings docs lack machine-checkable bindings to queries          |
| Runtime substrate recognition (§1.4 new)           | ABSENT  | Until this revision, host capabilities were treated as implicit                                  |

## §2 Topology

| Recommendation                          | Status  | Evidence                                                                                 |
| --------------------------------------- | ------- | ---------------------------------------------------------------------------------------- |
| Six layers present                      | MATCH   | Governance / Orchestration / Memory / Knowledge / Workspace / Reference all exist        |
| CLAUDE.md chain walkable from any leaf  | MATCH   | Enforced by session-gate.sh pre-hook; 100+ CLAUDE.md files across tree                   |
| Scratch vs exploratory separation       | GAP     | `analysis/adhoc/` conflates both; no dedicated `scratch/`                                |

## §3 Governance layer

| Recommendation                                        | Status  | Evidence                                                                              |
| ----------------------------------------------------- | ------- | ------------------------------------------------------------------------------------- |
| Directive doc with §1–§13                             | MATCH   | `context/informational/agent_directives_v3.md` has all 13 sections                    |
| Fenced §-block preambles (`<§N>...</§N>`)             | ABSENT  | §-blocks are authored as free-form code fences; no deterministic linter               |
| Directive-presence linter                             | ABSENT  | No linter exists                                                                      |
| Rule files with `applies_to`/`implements` frontmatter | ABSENT  | 10 rule files have no frontmatter                                                     |
| Rule efficacy telemetry (fires/violations/irrelevance)| ABSENT  | No counters; no scheduled proposals                                                   |
| CLAUDE.md chain enforcement hook                      | MATCH   | session-gate.sh PreToolUse on Write/Edit                                              |

## §4 Orchestration layer

| Recommendation                                       | Status  | Evidence                                                                               |
| ---------------------------------------------------- | ------- | -------------------------------------------------------------------------------------- |
| Commands vs skills disambiguation                    | GAP     | 16 project-scope commands exist; user-scope skills exist; no explicit model of both    |
| Zero-prompt contract on canonical commands           | GAP     | Violated during /orient this session — stat/grep/for bash patterns prompted            |
| `/evolve` auto-invocation threshold                  | ABSENT  | /evolve is opt-in only                                                                 |
| Agent `expected_context_cost` field                  | ABSENT  | 6 agent files carry no cost rating                                                     |
| Cost-aware sub-agent dispatch                        | ABSENT  | Orchestrator has no cost model                                                         |
| Unified `.state/sessions/<id>.jsonl` event log       | GAP     | State scattered across `/tmp/d7dev-hooks/<sid>/<marker>` files                         |
| Hook-edit guard (PreToolUse refuses `.claude/hooks/`)| ABSENT  | Behavioral rule only (`feedback_dont_edit_live_hooks.md`); no enforcement              |
| Content-hash retry fingerprinting                    | GAP     | retry-guard.sh uses first-120-char — known fragile (hook review)                       |
| Class-based bash whitelist                           | GAP     | bash-guard.sh uses explicit subcommand list (git status, ls, cat, etc.)                |
| SessionEnd structured summary emission               | PARTIAL | session-closeout.sh exists (untracked); no structured summary schema                   |
| UserPromptSubmit injection of date + checkpoint      | MATCH   | prompt-context.sh ships date + checkpoint age                                          |

## §5 Memory layer

| Recommendation                                              | Status  | Evidence                                                                           |
| ----------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------- |
| Four memory types (user/feedback/project/reference)         | MATCH   | All four types present; 47 memory files                                            |
| `MEMORY.md` one-line index                                  | MATCH   | Auto-loaded; ~60 lines                                                             |
| `_open.md` suffix for unresolved problems                   | MATCH   | 2 _open.md files currently (direct-traffic, statsig-late-arrival)                  |
| `origin_session_id` in frontmatter                          | PARTIAL | Some memories have it, some do not                                                 |
| `violates: [§N]` directive-linkage field                    | ABSENT  | No feedback memories map to directive weaknesses                                   |
| Top-N stalest memory injection on UserPromptSubmit          | ABSENT  | Only date + checkpoint injected                                                    |
| `_open.md` auto-promotion at 14+ days                       | ABSENT  | Manual tagging only                                                                |
| `_open.md` forced-resolution at 30+ days                    | ABSENT  | No forced-resolution mechanism                                                     |
| Memory-to-rule migration proposal at 3 citations            | ABSENT  | No citation counting                                                               |
| Session-transcript corpus as first-class artifact           | ABSENT  | Transcripts exist at `~/.claude/projects/`; no process reads them                  |

## §6 Workspace layer

| Recommendation                                | Status  | Evidence                                                                                |
| --------------------------------------------- | ------- | --------------------------------------------------------------------------------------- |
| Task directories under domain/date-slug       | MATCH   | etl/tasks, lookml/tasks, analysis/<domain> all follow convention                        |
| `README.md` strict frontmatter contract       | ABSENT  | Task READMEs have no frontmatter                                                        |
| `status` enum with `abandoned` as first-class | ABSENT  | No status tracking; abandoned tasks invisible                                           |
| `discovery/` sibling for knowledge writes     | ABSENT  | No enforcement                                                                          |
| Per-query-set subdirectory                    | PARTIAL | Convention documented in feedback memory; not hook-enforced                             |
| Query header declaring env/role/outputs       | ABSENT  | Queries have header comments but no standard schema                                     |
| Post-run output validation                    | ABSENT  | No automation                                                                           |

## §7 Knowledge layer

| Recommendation                             | Status  | Evidence                                                                                  |
| ------------------------------------------ | ------- | ----------------------------------------------------------------------------------------- |
| Four sub-sections                          | MATCH   | decisions/, runbooks/, data-dictionary/, domains/ all present                              |
| Discovery-gate enforcement                 | ABSENT  | Knowledge can be written without discovery/ sibling                                       |
| Cross-reference integrity check            | ABSENT  | No pre-commit validation                                                                  |

## §8 Reference layer

| Recommendation                     | Status  | Evidence                                                                                |
| ---------------------------------- | ------- | --------------------------------------------------------------------------------------- |
| Submodules or timestamped snapshots| PARTIAL | dbt submodule present; lookml submodule half-registered (known loose end)               |
| `MANIFEST.md` with ingestion date  | PARTIAL | `/ingest` command generates manifest; not all references have one                       |
| 30-day staleness flag              | ABSENT  | No automation                                                                           |

## §9 Execution sequence

| Recommendation                                       | Status  | Evidence                                                                                |
| ---------------------------------------------------- | ------- | --------------------------------------------------------------------------------------- |
| `/orient` at session start                           | MATCH   | Command exists; this session ran it                                                     |
| `/preflight` before task work                        | PARTIAL | Command exists; not consistently invoked                                                |
| Prior-investigation search enforcement               | GAP     | Behavioral rule (`feedback_prior_investigation_search.md`); not hook-enforced           |
| Three-pass workflow (§7) enforcement                 | GAP     | Directive exists; no deterministic check                                                |
| Writing scrub (§10) on stakeholder prose             | PARTIAL | writing-scrub.sh hook exists (untracked); scope may be narrow                           |
| Intervention classification (§11) gating delivery    | GAP     | Directive exists; no delivery gate                                                      |
| `/evolve` at task completion                         | GAP     | Opt-in; no auto-trigger                                                                 |
| Substantiation frame (distribution-at-rollup) drafted early | GAP | Feedback memory exists; no enforcement                                                  |

## §10 Evolution horizons (all ABSENT)

| #     | Horizon                                   | Status  |
| ----- | ----------------------------------------- | ------- |
| §10.1 | Semantic directive governance             | ABSENT  |
| §10.2 | Parallel hypothesis arbitration           | ABSENT  |
| §10.3 | Claim-to-provenance binding               | ABSENT  |
| §10.4 | Decay-aware knowledge substrate           | ABSENT  |
| §10.5 | Stakeholder epistemic modeling            | ABSENT  |
| §10.6 | Cross-session adversarial replay          | ABSENT  |
| §10.7 | Intervention lifecycle artifact           | ABSENT  |
| §10.8 | Rule efficacy as measurable               | ABSENT (see §3.2)                                                                 |
| §10.9 | Warehouse-state as live session context   | ABSENT  |
| §10.10| Epistemic drift detection                 | ABSENT  |
| §10.11| Retrospective-of-retrospectives           | ABSENT  |
| §10.12| Directive efficacy experiments            | ABSENT  |

## §12 Agent behavioral specification

| Area                              | Status   | Evidence                                                                                |
| --------------------------------- | -------- | --------------------------------------------------------------------------------------- |
| Communication norms               | PARTIAL  | Captured in memory + rule; enforcement is writing-scrub hook (narrow)                   |
| Epistemic discipline              | PARTIAL  | 12 feedback memories cover the rules; no structural enforcement                         |
| Tool-use patterns                 | MATCH    | Hooks + feedback memories cover this well                                               |
| Safety                            | MATCH    | Guardrails rule + hooks cover destructive operations                                    |
| Memory discipline                 | PARTIAL  | Convention documented; mid-session updates still inconsistent                           |

## §13 Bootstrap sequence

The current workspace was bootstrapped iteratively over multiple sessions rather than in a single canonical sequence. Step 0 (runtime substrate audit) was never performed formally — host capabilities were discovered through trial. This is the gap project 03 addresses.

## Summary counts

- MATCH: 13
- PARTIAL: 11
- GAP: 13
- ABSENT: 30

Total inspected: 67 recommendations.
