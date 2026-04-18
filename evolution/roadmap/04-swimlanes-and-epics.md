# Step 4 — Swimlanes & Epics

Groups from Step 3 map to swimlanes; each swimlane contains one or more epics with explicit scope, included ideas, and mapped existing project directories.

Swimlanes are ordered by dependency depth (0 = no upstream dependencies, 6 = depends on most other swimlanes).

## Swimlane 0 — Substrate & bootstrap hygiene
*No upstream dependencies. Provides inputs to every downstream swimlane.*

### Epic 0.1 — Runtime substrate catalog
**Scope:** Inventory and document host-runtime capabilities, user-scope resources, project-scope resources, scope precedence, and commands-vs-skills distinction. Formalize the 9 workspace-authored artifact classes in the root CLAUDE.md. Produce a canonical bootstrap record.
**Ideas:** I13, I15, I21, I53 (Group G1)
**Mapped project directories:** `../03-runtime-substrate-audit/`
**Produces:** `knowledge/runbooks/runtime-substrate-catalog.md`, CLAUDE.md update, updated `/orient` reference

### Epic 0.2 — Zero-prompt & command-call integrity
**Scope:** Every canonical command runs with zero permission prompts. Bash whitelist evaluates by class, not by enumerated subcommand.
**Ideas:** I22, I29 (Group G2)
**Mapped project directories:** `../01-zero-prompt-contract-audit/`
**Produces:** `scripts/audit_command_permissions.py`, settings allowlist hygiene

### Epic 0.3 — Telemetry substrate (OpenTelemetry)
**Scope:** Enable `CLAUDE_CODE_ENABLE_TELEMETRY`; stand up a local OTLP collector (console exporter for dev, file/duckdb exporter for persistent capture); document what the host emits as spans/metrics/logs; establish a query pattern and retention policy. Downstream measurement epics consume this substrate rather than hand-roll their own instrumentation.
**Ideas:** I55 (Group G13)
**Mapped project directories:** `../25-telemetry-substrate/` (new)
**Produces:** env-block additions in settings, local OTLP collector config, retention script, query examples
**Rationale for P1 placement:** Without structured telemetry, every downstream claim about system behavior depends on transcript reading plus trust. User explicitly requires verification, not promise. OTel enablement is low-effort (env block) with high leverage — it becomes the primary substrate for Epic 1.2 event log, Epic 2.3 rule telemetry, Epic 5.2 dispatch cost measurement, Epic 6.8 meta-retrospective, and Epic 6.9 directive experiments.

## Swimlane 1 — Enforcement foundation
*Depends on: 0.1 (substrate inventory informs hook surface decisions).*

### Epic 1.1 — Hook lifecycle & safety
**Scope:** Hooks cannot be accidentally disabled mid-session; retry detection uses content hash; queued-edit workflow exists.
**Ideas:** I27, I28 (Group G3)
**Mapped project directories:** `../06-hook-edit-guard/`
**Produces:** `hook-edit-guard.sh`, content-hash fingerprinting in retry-guard

### Epic 1.2 — Unified session & event state substrate
**Scope:** Replace scattered per-marker state with a single consolidated event stream per session consumed by `/orient` and `/evolve`. Primary substrate is the OTel stream enabled in Epic 0.3 (spans/metrics/logs exported to the local collector); a local JSONL projection from the collector serves sessions that want a plain-text view. Hooks emit structured events (stdout or OTel shim) rather than writing per-marker files. SessionEnd emits structured summary. Lifecycle commands (`/evolve` at task-completion, `/preflight` at task-start) auto-invoke at the appropriate boundaries.
**Ideas:** I23, I26, I30, I54 (Group G4)
**Upstream:** 0.3 (OTel substrate) + 1.1 (safe hook evolution)
**Mapped project directories:** `../02-unified-session-state-log/`
**Produces:** Hook migration away from per-marker state; collector → JSONL projection script; `/orient` + `/evolve` consumers; `/evolve` + `/preflight` auto-invocation wiring

## Swimlane 2 — Governance machinery
*Depends on: 1.1 (safe hook evolution), 1.2 (event log for telemetry).*

### Epic 2.1 — Directive artifact linter
**Scope:** Fenced §-block preambles; structural-completeness linter integrated with `/review` and `/test`.
**Ideas:** I17, I18 (subset of Group G5)
**Mapped project directories:** `../04-directive-linter/`
**Produces:** `scripts/directive_lint.py`, migrated analysis files, CI integration

### Epic 2.2 — Directive enforcement at delivery
**Scope:** Three-pass workflow structurally enforced; §11 intervention-classification gates delivery; substantiation-frame drafted early; writing-scrub covers all stakeholder prose and is operationally validated; core-invariant traceability enforced at tool-call surface.
**Ideas:** I14, I48, I49, I50, I51, I52 (subset of Group G5)
**Mapped project directories:** *(new — create a dedicated epic plan)*
**Produces:** Hook(s) gating delivery artifacts; writing-scrub scope expansion

### Epic 2.3 — Rule lifecycle & telemetry
**Scope:** Rule files carry frontmatter (`applies_to`, `implements`, `last_reviewed`); three counters per rule (fires / violations / irrelevance); monthly proposals for deprecate / strengthen / consolidate.
**Ideas:** I19, I20, I08 (Group G6)
**Mapped project directories:** `../05-rule-efficacy-telemetry/`

## Swimlane 3 — Memory & transcript substrate
*Depends on: 1.2 (event log for citation detection and stale-memory injection).*

### Epic 3.1 — Memory decay & promotion
**Scope:** Top-N stalest memories injected each prompt; `_open.md` auto-promote at 14d, force-resolve at 30d; `origin_session_id` consistent across memories; `violates:[§N]` field on feedback memories.
**Ideas:** I31, I32, I33, I34, I35 (subset of Group G7)
**Mapped project directories:** `../08-top-n-stalest-memory-injection/`, `../09-open-memory-auto-promotion/`

### Epic 3.2 — Memory-to-rule migration
**Scope:** Feedback memory cited across 3+ sessions triggers a promotion proposal with draft rule body.
**Ideas:** I36 (subset of Group G7)
**Mapped project directories:** `../10-memory-to-rule-migration/`

### Epic 3.3 — Session-transcript corpus access
**Scope:** Transcript directory is readable via a structured interface (indexer or API) consumable by memory-to-rule migration, adversarial replay, drift detection, meta-retrospective, and directive experiments.
**Ideas:** I37 (Group G8)
**Mapped project directories:** *(new — upstream of 10, 19, 22, 23, 24)*

## Swimlane 4 — Workspace & knowledge hygiene
*Depends on: 1.1 (hook safety for new enforcement).*

### Epic 4.1 — Workspace contract & query hygiene
**Scope:** Task README frontmatter; `abandoned` as first-class status; per-query-set subdirectory enforcement; query header schema; post-run output validation; scratch vs exploratory separation.
**Ideas:** I16, I38, I39, I40, I41, I42 (Group G9; I49 is part of Epic 2.2 writing-scrub)
**Mapped project directories:** `../11-task-readme-frontmatter/`

### Epic 4.2 — Knowledge discovery gate + cross-reference integrity
**Scope:** `knowledge/` writes require a `discovery/` sibling; decision-to-data-dictionary back-references are validated pre-commit.
**Ideas:** I43, I44 (subset of Group G10)
**Mapped project directories:** `../12-discovery-gate-enforcement/`

### Epic 4.3 — Reference-layer manifest & staleness
**Scope:** Every reference carries `MANIFEST.md` with ingestion date and refresh cadence; 30-day staleness flag surfaces in `/orient`.
**Ideas:** I45, I46 (subset of Group G10)
**Mapped project directories:** *(new — smaller scope, feasible as single-phase project)*

## Swimlane 5 — Orchestration intelligence
*Depends on: 0.1 (agent definitions), 1.2 (event log for dispatch logging), 2.1 (linter for critic input).*

### Epic 5.1 — Prior-investigation enforcement
**Scope:** Starting an investigation refuses query-file writes until a search artifact has been written to the task directory.
**Ideas:** I47 (subset of Group G11)
**Mapped project directories:** `../13-prior-investigation-enforcement/`

### Epic 5.2 — Cost-aware agent dispatch
**Scope:** Agents carry `expected_context_cost`; orchestrator uses cost in dispatch; duplicated search guarded.
**Ideas:** I24, I25 (subset of Group G11)
**Mapped project directories:** `../07-agent-cost-dispatch/`

### Epic 5.3 — Semantic directive critique
**Scope:** Second-pass LLM critic reads §-block + artifact and emits structured critique calibrated against known-good corpus.
**Ideas:** I01 (subset of Group G11)
**Mapped project directories:** `../14-semantic-directive-governance/`

### Epic 5.4 — Parallel hypothesis arbitration
**Scope:** Two advocate sub-agents + arbitrator for triggered investigations.
**Ideas:** I02 (subset of Group G11)
**Mapped project directories:** `../15-parallel-hypothesis-arbitration/`

## Swimlane 6 — Corpus-level & self-evolution
*Depends on: 3.3 (transcript access), 4.1 (workspace contract), 5.3 (critic), and knowledge-graph substrate.*

### Epic 6.1 — Decay-aware knowledge substrate
**Scope:** Typed knowledge graph backs the markdown memory/knowledge surface; conflict detection; temporal-validity queries.
**Ideas:** I04 (subset of Group G10)
**Mapped project directories:** `../17-knowledge-graph-substrate/`

### Epic 6.2 — Warehouse-state live context frame
**Scope:** Lightweight context frame with incremental lag, freshness, schema drift injected at session start.
**Ideas:** I09 (subset of Group G12)
**Mapped project directories:** `../21-warehouse-state-context-frame/`

### Epic 6.3 — Claim-to-provenance rendering
**Scope:** Finding-to-query binding; query header schema; rendering pipeline with click-through provenance.
**Ideas:** I03 (subset of Group G12)
**Mapped project directories:** `../16-claim-provenance-rendering/`

### Epic 6.4 — Intervention lifecycle tracker
**Scope:** STRUCTURAL findings emit intervention proposal artifacts; tracked to closure; quarterly rollup surfaces organizational debt.
**Ideas:** I07 (subset of Group G12)
**Mapped project directories:** `../20-intervention-lifecycle-tracker/`

### Epic 6.5 — Stakeholder epistemic model
**Scope:** Per-stakeholder ledger constrains delivery.
**Ideas:** I05 (subset of Group G12)
**Mapped project directories:** `../18-stakeholder-epistemic-model/`

### Epic 6.6 — Cross-session adversarial replay
**Scope:** Scheduled replay of prior findings through current critic; correction artifacts.
**Ideas:** I06 (subset of Group G12)
**Mapped project directories:** `../19-cross-session-adversarial-replay/`

### Epic 6.7 — Epistemic drift detection
**Scope:** Comparator detects tone-shift exceeding metric-shift across sequential findings on same subject.
**Ideas:** I10 (subset of Group G12)
**Mapped project directories:** `../22-epistemic-drift-detection/`

### Epic 6.8 — Meta-retrospective
**Scope:** Corpus-level retrospection producing architectural proposals.
**Ideas:** I11 (subset of Group G12)
**Mapped project directories:** `../23-meta-retrospective/`

### Epic 6.9 — Directive efficacy experiments
**Scope:** A/B test directive variants on quarter cycles with pre-registered outcomes.
**Ideas:** I12 (subset of Group G12)
**Mapped project directories:** `../24-directive-efficacy-experiments/`

## Epic inventory

Total: 23 epics across 7 swimlanes (Swimlane 0 now has 3 epics with 0.3 added).

## Gaps closed vs previous flat structure
- **Epic 2.2** (directive enforcement at delivery) is new — it groups 6 ideas (I14, I48, I49, I50, I51, I52) that had no project owner previously.
- **Epic 3.3** (session-transcript corpus access) is new — the shared dependency blocking 10, 19, 22, 23, 24 now has an explicit owner.
- **Epic 4.3** (reference manifest & staleness) is new — I45, I46 had no project owner previously.
- **Epic 0.1** absorbs three doc-level items (I13 9-class enumeration, I21 commands-vs-skills, I53 bootstrap record) that were orphaned in the flat structure.
- **Epic 1.2** now explicitly covers I54 (/preflight auto-invocation) in addition to /evolve auto-invocation, closing the §9 PARTIAL "/preflight consistent invocation" gap.

## Coverage status after Step 4
Every non-MATCH item in GAP_ANALYSIS.md is assigned to exactly one epic, OR is flagged as emergent, OR is out-of-scope. Plus one user-introduced item (I55 OTel) now owned by Epic 0.3.

- 53 I-items → 23 epics (one I-item per epic owner; some epics own multiple I-items)
- 2 emergent items (GAP_ANALYSIS §12 epistemic discipline + memory discipline) covered by the aggregate of epics 2.1, 2.2, 3.1, 3.3, 5.1, 5.3
- 1 out-of-scope item (lookml submodule half-registration) tracked in memory, not here

## Mapping note
Existing project directories `../01-*` through `../24-*` become **task-level plans within epics**. No file moves required; the mapping above is the authoritative epic↔task-directory index. New epics (2.2, 3.3, 4.3) need new task-level directories (to be created as a follow-up to Step 7 if undertaken).
