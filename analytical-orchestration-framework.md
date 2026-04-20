# Analytical Orchestration Framework
### A reference architecture for an AI-agent-operated principal-analyst system

Generalized reference document. The structure is portable across any warehouse + transformation + BI stack.

---

## 0. Audience & Assumptions

This document targets an AI coding agent that will implement or evolve a workspace of this class from scratch. It contains three kinds of content:

1. Structural description of the layers that compose the workspace and the runtime substrate beneath them
2. Design rationales specifying why each choice exists in the form it does
3. Evolution horizons describing frontier problems the next-generation system should solve

Assumptions:

- A modern LLM coding agent with tool-calling (filesystem, shell, web) and sub-agent delegation
- A version-controlled working directory (git)
- A host runtime that provides hook events, permission allowlists, CLAUDE.md auto-loading, additional-context injection, session-transcript persistence, and native task/skill/plugin tool surfaces
- A typed persistent memory system (file-backed) scoped per project
- An invokable slash-command surface
- Optional multi-repository references via submodules or read-only snapshots

No proprietary platform is assumed. All domain-specific references have been abstracted.

---

## 1. Foundational Identity

### 1.1 Definition
The workspace is an orchestration brain: a decision-support surface composed of nine workspace-authored artifact classes sitting on top of a host runtime substrate.

Workspace-authored artifact classes:

- **Directives** — the epistemic law of the workspace
- **Rules** — layered conventions scoped to artifact types
- **Commands** — parameterized markdown runbooks invocable via `/<name>`
- **Agents** — scoped sub-personas with restricted tool palettes
- **Memory** — typed, file-backed recall across sessions, decay-aware
- **Hooks** — deterministic tool-call-time enforcement scripts
- **Workspaces** — task-scoped directories containing live analytical work
- **Knowledge** — canonical, curated, non-ephemeral reference material, discovery-gated
- **References** — read-only snapshots of external systems

The runtime substrate (§1.4) is not authored by the workspace but is a first-class structural component without which none of the above functions.

### 1.2 Exclusions
The workspace excludes:

- Production code. Production artifacts (warehouse models, BI definitions, ingestion configs) live in separate repositories and are surfaced here as read-only references or submodules.
- Task tracking. Task workspaces are artifacts of work and do not function as a queue or ticketing system.
- Human collaboration replacement. The system operates as a force multiplier for a principal analyst paired with an AI agent.

### 1.3 Core invariant
Every analytical claim produced by the system is traceable to three artifacts:

- (a) the written directive that governed its production
- (b) the query or transformation artifact that generated the underlying numbers
- (c) the verification artifact that challenged it

The invariant is enforced at the tool-call surface. §-block artifacts are machine-checkable. Claim-to-query bindings are workspace-local. Verification artifacts are directive-mandated outputs.

### 1.4 Runtime substrate
The framework sits on top of a host runtime (the LLM-agent CLI and its ecosystem). Every design choice in sections 3–9 assumes substrate properties the workspace does not author:

**Host capabilities depended on:**

- Declarative hook wiring on stable event names (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `SessionEnd`)
- A settings allowlist evaluated before any permission prompt
- Recursive CLAUDE.md auto-loading via `@<path>` import expansion
- Structured additional-context injection from hook stdout
- Append-only session-transcript persistence at known user-scope paths
- Native task tools (create, update, list, stop) distinct from workspace state
- A skill/plugin ecosystem invocable via structured tool call
- MCP/plugin integrations for external-system access (CRM, chat, storage, browser, ticketing, meetings)
- **Structured telemetry export via OpenTelemetry** (`CLAUDE_CODE_ENABLE_TELEMETRY` + OTLP exporters). Tool calls, session lifecycle events, token usage, and latencies emit as spans/metrics/logs consumable by a local collector. This is the verification substrate for any measurement claim the framework makes — without it, every claim about system behavior reduces to trusting transcripts. Substrate schema is host-versioned: downstream consumers pin collector config to a tested host version or use schema-agnostic queries. (See Epic 0.3 in `evolution/`.)

  **Host-version pinning operational rule.** The collector configuration (`<repo>/.claude/telemetry/otelcol-config.yaml`) is valid only against the Claude Code host version recorded in `<repo>/evolution/25-telemetry-substrate/host-version-pin.md`. When the host CLI upgrades, the operator must: (1) re-run the Phase 1 console-exporter verification to confirm span / metric / log names remain stable; (2) re-run the Phase 2 hook-bridge POC query to confirm the mapping still holds; (3) refresh the pin file with the new version and date; or (4) if the schema changed, update the collector config and every downstream consumer query that was not written schema-agnostically. This is a gating upgrade step, not an advisory. Attempting to read telemetry against a drifted host without re-validation produces silent miscounts that propagate to Epic 2.3 rule counters, Epic 5.2 cost reads, and Epic 6.8 / 6.9 outcome measurements.

**Scope separation:**

- **Project scope** (`<repo>/.claude/`): rules, commands, agents, hooks, local settings, allowlist overrides. Version-controlled with the workspace.
- **User scope** (`~/.claude/`): per-project memory directories, session-transcript corpus, global settings, todo state, plugin registry, user-level hooks. Not version-controlled with any single workspace.

Project-scope artifacts override user-scope where they overlap. Memory is user-scoped but keyed by project path, producing per-project memory directories under the user home.

**Runtime artifact classes adjacent to the workspace:**

- **Skills** — runtime-ecosystem utilities invoked via a structured tool call; sourced from plugins or marketplaces; distinct authoring and invocation semantics from commands (§4.1)
- **Session transcripts** — append-only JSONL corpus at user-scope (§5.8); substrate for replay, drift detection, and meta-retrospection
- **Native tasks** — runtime-provided task-tracking tools with lifecycle semantics separate from memory and workspace state
- **Plugins/MCP servers** — external-system integration surface, not authored in-workspace

A new implementation begins by auditing the host runtime's capability surface before scaffolding any project-scope artifacts. The bootstrap sequence (§13) assumes this audit is performed at step 0.

For this workspace, the completed substrate audit lives at `knowledge/runbooks/runtime-substrate-catalog.md` — it catalogs every user-scope and project-scope runtime resource, the precedence rules, canonical usage patterns, and known failure modes. Refresh per host-runtime major upgrade.

### 1.5 Stakeholder framing
Stakeholders for the framework include both **external consumers** (marketing, finance, engineering, product, RevOps — anyone receiving deliverables produced via the framework) AND the **workspace operator** (the principal analyst driving the framework's evolution and using its outputs). The operator is a first-class stakeholder, not an implementer in the background.

Consequences:
- Every artifact produced for the operator — briefs, trackers, roadmap documents, retrospectives, checkpoints, chat responses — is a stakeholder-facing artifact and is subject to the full discipline defined in §8 (Adversarial Check), §10 (Writing Mode), §11 (Intervention Classification) at delivery.
- The operator maintains an epistemic state (§10.5 stakeholder ledger) on par with external stakeholders: communications received, framings accepted, framings rejected, terms flagged as unfamiliar or prohibited. Existing feedback memories that capture operator preferences function as the seed for this ledger when Epic 6.5 ships.
- "Internal" and "scratch" are not exemptions from stakeholder-facing discipline. If the operator will read it, §10 applies.

---

## 2. Topology

Six workspace layers, each with different write-frequency, trust level, and persistence. The trust gradient runs top-to-bottom: governance is the most-trusted and least-modified; workspace is the most-modified; reference is externally authoritative and read-only. The runtime substrate (§1.4) is orthogonal to this gradient and sits beneath every layer.

| Layer         | Write frequency | Trust         | Scope                        | Canonical form                        |
| ------------- | --------------- | ------------- | ---------------------------- | ------------------------------------- |
| Governance    | Rare            | High          | Cross-cutting, immutable-ish | Directives + rule files               |
| Orchestration | Moderate        | High          | Workflow entry points        | Commands, agents, hooks, settings     |
| Memory        | Per session     | Mixed         | Cross-session recall         | Typed frontmatter markdown            |
| Knowledge     | Deliberate      | High          | Canonical, curated           | Decisions, runbooks, data dictionary  |
| Workspace     | Per task        | Low-Medium    | Scratch, drafts, exports     | `<domain>/<date>-<slug>/` directories |
| Reference     | Ingest-only     | Authoritative | External system snapshots    | Submodules or snapshot directories    |

Every directory in the tree carries a `CLAUDE.md` whose first line imports its parent (`@../CLAUDE.md`), forming a chain walkable from any leaf to root. Rule inheritance is a property of path depth; a leaf-level write has access to the full rule stack without re-import.

---

## 3. The Governance Layer

### 3.1 Directives
A single authoritative directive document defines ~13 numbered sections. Each section has **trigger / artifact / rule** semantics:

1. **TRIGGER** — the concrete situation that activates the directive
2. **ARTIFACT** — the explicit written block the agent must produce, wrapped in a fenced preamble (e.g., `<§N>...</§N>`) so structural completeness is deterministically verifiable
3. **RULE** — the test that must pass before the next step

Required sections at minimum:

| §   | Name                          | Purpose                                                                  |
| --- | ----------------------------- | ------------------------------------------------------------------------ |
| 1   | Rate Declarations             | Force numerator/denominator declaration before any ratio query           |
| 2   | Deliverable Contracts         | Preconditions/postconditions/invariants per output                       |
| 3   | Claim Verification            | Every causal/interpretive claim gets an independent disproof attempt     |
| 4   | Null Hypothesis Check         | For patterns in cohort/time/decay domains                                |
| 5   | Algebraic Identity Detection  | Surface `A = B × C` decompositions proactively                           |
| 6   | Enumeration Protocol          | Require written checklist and count parity                               |
| 7   | Three-Pass Workflow           | BUILD → VERIFY → INTERPRET, strict ordering                              |
| 8   | Adversarial Self-Questions    | Pre-delivery: skeptical-reader / flip-assumption / unanswered question   |
| 9   | Checkpoint Management         | Structured handoff artifact per task, with staleness rules               |
| 10  | Writing Mode                  | Banned rhetorical phrases; sentence-level information-only test          |
| 11  | Intervention Classification   | INFORMATIONAL / OPERATIONAL / STRUCTURAL for each material finding       |
| 12  | Definition–Use-Case Alignment | Temporal mechanic match between segment definition and triggering action |
| 13  | Query Efficiency              | Consolidation mandate; no redundant, subset, or tangential queries       |

Each section emits a written artifact. A deterministic linter runs against committed analytical outputs and fails when required §-blocks are missing or preambles are malformed. The linter verifies presence and structure. Content quality is governed by §3 and §8 via adversarial self-examination or a second LLM pass.

### 3.2 Rules
A flat `rules/*.md` directory. Each file is under 50 lines and auto-loaded via `@`-reference from the root directive file. Each rule carries machine-readable frontmatter:

```yaml
---
applies_to: ["*.sql", "analysis/**"]
implements: ["§1", "§13"]
last_reviewed: 2026-04-18
---
```

This enables:

- **Scoped loading.** Only rules relevant to the current artifact path are surfaced to the agent during an edit.
- **Efficacy measurement.** Each rule accumulates telemetry across sessions: fire count (prevented a violation via hook), violation count (caught in review), irrelevance count (never triggered). Rules with zero activity for 30 days are flagged for deprecation. Rules violated weekly are flagged for strengthening or hook-enforcement.

Rule content is concrete and testable. Example form: `"LEFT JOIN foreign keys may not have relationships tests."` Aspirational prose ("always be thorough") is excluded.

### 3.3 CLAUDE.md chain
Every managed subdirectory contains a `CLAUDE.md` with:

1. Directory purpose
2. `@../CLAUDE.md` parent reference
3. Optional directory-specific conventions

A pre-write hook verifies the chain at any depth before a file is created in a managed directory. The hook refuses the write if the chain is broken, and the agent must author the missing `CLAUDE.md` first. Chain integrity is enforced at the tool-call surface.

---

## 4. The Orchestration Layer

### 4.1 Commands vs skills
Commands and skills are distinct artifact classes with different authoring and invocation semantics:

- **Commands** are markdown runbooks authored in `<repo>/.claude/commands/<name>.md`. Project-scoped. Version-controlled with the workspace. Parameterized by the first word of `$ARGUMENTS`. Invocation: `/<name> <args>`.
- **Skills** come from the host runtime's plugin/marketplace ecosystem or user-scope skill directory. They carry structured metadata (description, trigger conditions) and are invoked via the `Skill` tool with structured arguments. Skills may be user-scoped (global across projects) or project-scoped via plugin installation.

The framework leverages both. Workspace-specific workflows (`/analyze`, `/transform`, `/orient`) are commands. Cross-cutting utilities (config updates, skill/plugin management, scheduled loops, API helpers, brand-voice application) are typically skills from the host ecosystem. A canonical command may invoke a skill as a sub-step.

Each command:

- Declares supported sub-actions via first-word dispatch
- Pre-reads relevant governance, references, prior work
- Produces directive artifacts at the appropriate phases
- Stages outputs to files
- Leaves a checkpoint behind

**Zero-prompt contract.** Every tool call a canonical command makes is pre-allowed in the settings allowlist. A canonical command run produces zero permission prompts. A prompt encountered indicates a missing allowlist entry and an operational bug. Any command change that adds a new tool invocation simultaneously adds the corresponding allowlist entry in the same commit.

Canonical command suite:

| Command       | Role                                                                  |
| ------------- | --------------------------------------------------------------------- |
| `/orient`     | Session-start infrastructure review                                   |
| `/preflight`  | Task-start environment + prior-work verification                      |
| `/analyze`    | Deep-dive investigatory analysis (three-pass enforced)                |
| `/transform`  | Warehouse transformation authoring                                    |
| `/bi-model`   | BI platform view/explore/dashboard authoring                          |
| `/monitor`    | Data quality and anomaly detection                                    |
| `/model`      | Quantitative business modeling                                        |
| `/kb-update`  | Canonical knowledge authoring                                         |
| `/scaffold`   | New analytical-domain directory tree creation                         |
| `/roadmap`    | Multi-step stakeholder roadmapping initiative                         |
| `/checkpoint` | Session-state init/update/review                                      |
| `/review`     | Uncommitted-change audit across all artifact types                    |
| `/test`       | Validation harness                                                    |
| `/status`     | Project-health dashboard                                              |
| `/ingest`     | Reference snapshot ingestion                                          |
| `/evolve`     | Post-task retrospective: detect friction, audit, integrate            |

`/evolve` auto-invokes when a command produces more than N file writes or after M minutes of session activity.

### 4.2 Agents
`agents/<name>.md` carries frontmatter (`name`, `description`, `model`, `expected_context_cost`) and prose behavior definition. Each agent is a sub-persona with a restricted tool palette.

`expected_context_cost` is a cardinal rating (low/medium/high) consumed by the orchestrator. The orchestrator handles a task in primary context when cost is comparable, and delegates to a sub-agent only when primary context is near budget or when the sub-agent's tool palette is strictly required. Duplicating a sub-agent's search in primary context is an anti-pattern.

Minimum agents: `analyst`, `data-engineer`, `bi-developer`, `modeler`, `kb-curator`, `architect`.

### 4.3 Hooks
Hooks are shell scripts wired to tool-lifecycle events. They are the enforcement surface for properties the LLM cannot hold reliably across turns.

| Event                     | Purpose                                                                                    |
| ------------------------- | ------------------------------------------------------------------------------------------ |
| `SessionStart`            | Rotate accumulated error log; verify infrastructure sanity                                 |
| `UserPromptSubmit`        | Inject today's date, checkpoint age, top-N stalest memories as additional context          |
| `PreToolUse` (Write/Edit) | CLAUDE.md chain check; content-hash retry-loop detection; writing-scrub; hook-edit guard   |
| `PreToolUse` (Bash)       | Block destructive git patterns; class-based command whitelist; review/commit ordering      |
| `PostToolUse`             | Append to unified session event log                                                        |
| `SessionEnd`              | Emit structured session summary; rotate state; append to retrospective corpus              |

Design constraints:

- **Unified session state.** A single `.state/sessions/<id>.jsonl` event log is the only state surface. Every hook appends. `/orient` and `/evolve` reduce the log.
- **Crash-safe.** Hooks exit `0` on crash and log to a persistent error file. Hook failures do not crash the session.
- **Immutable during a live session.** Edits to hook scripts can disable the hook runner for the remainder of the session. A `PreToolUse` hook-edit guard refuses Write/Edit operations under the hook directory without an explicit override phrase and prompts a session restart.
- **Event semantics are strict.** `Stop` fires per turn; `SessionEnd` fires per session (including `/clear`, resume, logout, prompt-input-exit). Per-session cleanup belongs on `SessionEnd`.
- **Retry fingerprinting uses content hash.** Edit-repetition detection hashes `(file_path, old_string)` rather than a truncated command string.
- **Bash whitelist is class-based.** Commands are evaluated against declared classes (`read_only_git`, `filesystem_read`, `date_and_env`, etc.). New commands are covered by their class without maintenance of an explicit list.

---

## 5. The Memory Layer

### 5.1 Types
Four memory types with distinct semantics:

| Type        | Purpose                                                         | Write trigger                                             |
| ----------- | --------------------------------------------------------------- | --------------------------------------------------------- |
| `user`      | Role, skills, collaboration preferences, permanent identity     | Any details about the person                              |
| `feedback`  | Corrections and validations of approach                         | Every correction AND every validated non-obvious approach |
| `project`   | Ongoing work state, active initiatives, timelines, stakeholders | When who/what/why/when changes                            |
| `reference` | External-system pointers                                        | When a resource is named                                  |

Memory is user-scoped (`~/.claude/projects/<project-path>/memory/`) and keyed by project path. This produces per-project memory directories rather than a single global memory pool.

### 5.2 File format
One memory per markdown file with YAML frontmatter: `name`, `description`, `type`, `origin_session_id`, optional `violates: [§N]` (for feedback memories that map to directive weaknesses). For `feedback` and `project` types, body structure is **rule/fact → `Why:` line → `How to apply:` line**.

### 5.3 Decay awareness
Memory records point-in-time observations. Age is a first-class signal:

- `UserPromptSubmit` injects the top-N stalest memories alongside the fresh-date context
- `/orient` computes staleness at load and flags any memory older than 14 days referenced in the current routing context
- Memories are re-verified against current state before citation as fact — a memory naming a file, flag, or function must pass an existence check before the agent recommends action on it

### 5.4 Index
A single `MEMORY.md` file holds up to 200 lines of one-line index entries. Auto-loaded every session. The index never holds memory bodies.

### 5.5 OPEN-state
Memories documenting unresolved problems use the `_open.md` suffix. `/orient` and `/evolve` enumerate them programmatically. An `_open.md` untouched for 14+ days is auto-promoted to the OPEN_PROBLEMS_QUEUE with a `STALE` tag. Untouched for 30+ days, the memory is flagged for forced resolution: update, escalate to a rule, or archive with explicit rationale.

### 5.6 Memory-to-rule migration
When the same feedback memory is cited in three separate sessions, the agent proposes promoting it from memory to a rule file. Enforcement cost is lower at the rule layer (hook or linter) than at the recall layer (memory). Memory retains context that cannot be derived from current state.

### 5.7 Memory exclusions
Memory does not store:

- Code patterns (derivable from current source)
- Git history (use `git log`)
- Debugging recipes (the fix is in the code; the commit carries the context)
- Anything already in a rule file or `CLAUDE.md`
- Ephemeral task state

### 5.8 Session-transcript corpus
Every session produces a JSONL transcript persisted by the host runtime at `~/.claude/projects/<project-slug>/<session-id>.jsonl`. The corpus is append-only across sessions and is a first-class artifact class:

- **Replay source** — prior findings can be re-challenged by replaying through current adversarial apparatus (§10.6)
- **Drift-detection input** — sequential framings of the same observable are comparable across transcripts (§10.10)
- **Meta-retrospective substrate** — `/evolve` retrospectives are session-scoped; meta-retrospection over the transcript corpus surfaces patterns invisible at session scope (§10.11)
- **Directive-efficacy measurement** — variant directive runs can be correlated with session outcomes via transcript analysis (§10.12)
- **Memory-to-rule signal** — counting citations of a specific memory across transcripts triggers the promotion proposal in §5.6

Transcripts are read-only from the workspace's perspective. Any process operating over the corpus (replay, drift detection, meta-retrospection, citation counting) is implemented as a scheduled or background reader rather than an in-session hook.

---

## 6. The Workspace Layer

### 6.1 Directory conventions
- `analysis/<domain>/<YYYY-MM-DD>-<slug>/` — deep-dive investigations
- `transformations/tasks/<YYYY-MM-DD>-<slug>/` — warehouse transformation drafts
- `bi/tasks/<YYYY-MM-DD>-<slug>/` — BI platform drafts with promotion guides
- `initiatives/<slug>/` — multi-workspace initiative tracking
- `scratch/` — ephemeral, non-committed
- `exploratory/` — committed, low-rigor, subset of the methodology
- `knowledge/{decisions,runbooks,data-dictionary,domains}/` — canonical reference

### 6.2 Per-task contract
Every task directory has a `README.md` with strict frontmatter:

```yaml
---
status: draft | in-progress | complete | abandoned
owner: <handle>
linked_initiatives: [<slug>, ...]
deliverable_paths: [<path>, ...]
abandonment_reason: <text>  # required iff status=abandoned
---
```

`abandoned` is a first-class status. Tasks that were descoped, stripped, or obsoleted carry `status: abandoned` and a reason. Abandoned tasks remain visible to `/orient` and `/evolve`.

### 6.3 Per-task structure
```
<workspace>/<date>-<slug>/
├── CLAUDE.md           # @../CLAUDE.md, purpose, conventions
├── README.md           # frontmatter contract above
├── console.sql         # (or equivalent) — the live query surface
├── inquiry.md          # the question, scope, constraints
├── findings.md         # the output, §-blocks included
├── checkpoint.md       # §9 handoff
├── discovery/          # warehouse queries grounding any knowledge claim
└── <query-set>/        # subdirectory per distinct query set
    ├── CLAUDE.md
    ├── queries.sql
    └── *.csv           # result exports
```

Per-query-set subdirectory is mandatory. CSV labels are namespace-local. Every query file has a header declaring target environment, role, and expected output paths. A post-run check validates the declared outputs exist and are non-empty.

### 6.4 Promotion pattern
- Transformations: PR to the transformation repo, with a production-prep step (DELETE affected incremental rows) before merge
- BI artifacts: documented in `promotion-guide.md` and implemented manually in the BI platform's IDE to preserve platform-native validation
- Knowledge: committed to `knowledge/` with date-stamped update lines and a `discovery/` sibling

---

## 7. The Knowledge Layer

Four sub-sections: `decisions/`, `runbooks/`, `data-dictionary/`, `domains/`.

**Discovery gate.** Any write into `knowledge/` requires a `discovery/` subdirectory at the same level containing the warehouse queries and results that sourced the claim. The hook refuses writes lacking this binding. Knowledge authored from samples, memory, or code reading alone is blocked at the enforcement surface.

**Cross-reference integrity.** Decisions link to affected data-dictionary entries and vice versa. A pre-commit check validates back-references. An article citing a field must reference a data-dictionary entry for that field; creating one if none exists is required.

---

## 8. The Reference Layer

External systems are surfaced as git submodules (for git-native sources) or timestamped snapshots (for non-git). Every reference carries a `MANIFEST.md` with ingestion date, source identifier, file count, and expected refresh cadence. References older than 30 days are stale-flagged. References are read-only; modification requires copying into a workspace first.

---

## 9. Directive-Driven Execution Sequence

For any analytical task:

1. `/orient` if session-start
2. `/preflight` (environment + prior-work verification)
3. **Prior-investigation search** — glob + grep the workspace for the same observable. If a prior investigation exists, its confirmed root cause becomes the leading hypothesis. The system refuses to proceed to query authoring until the search has been performed and logged.
4. §1 Rate Declarations for every ratio metric
5. §12 Definition–Use-Case Alignment for every segment/cohort
6. §2 Deliverable Contracts per output
7. §9 Checkpoint init
8. §7 BUILD pass — queries + charts + reports, output only
9. §7 VERIFY pass — Type Audits, Contract Checklists, Identity Checks, Enumeration, Alignment
10. §7 INTERPRET pass — Null Hypothesis, Claim Verification, Adversarial Questions
11. §11 Intervention Classification per material finding
12. §10 Writing Scrub on stakeholder prose
13. §9 Checkpoint update
14. `/evolve` if threshold reached

Steps 8–10 cannot interleave. Step 11 gates step 12: classification may reclassify findings and force rewrite before delivery.

**Substantiation frame.** For any claim about the character of an observable (e.g., scraping, bot, drift, artifact), the primary substantiating artifact is a single query containing: (a) per-population comparison across ≥3 cohorts, (b) distribution at a stakeholder-visible rollup, (c) concentration metric per cell. This query is drafted early in the BUILD pass. Single-dimensional aggregates and raw-sample inspection follow after this frame is produced.

---

## 10. Evolution Horizons

Frontier problems for the next-generation system. Each is unsolved by this framework. Each is achievable with existing tools. They are ordered by expected leverage.

### 10.1 Semantic governance of directive artifacts
Directive linting verifies §-block presence and structural completeness. Semantic governance adds a second LLM pass that reads the §-block and the associated artifact and produces an adversarial critique: does the declared numerator match what the query computes, does the JOIN chain preserve the declared denominator, does the Null Hypothesis block's verdict follow from the verification numbers. The critique is committed alongside the deliverable.

Calibration is the dominant implementation risk. A critic that fires on every artifact generates noise; one that fires on none provides no signal. Calibration requires running the critic against known-good historical outputs and tuning the false-positive rate below a session-friction threshold before rollout.

### 10.2 Parallel hypothesis arbitration
A single leading hypothesis per investigation is the current default. Parallel arbitration dispatches two sub-agents with distinct priors on any investigation triggered by an observable: one adopting the prior-investigation root cause as its starting hypothesis, one constructed to diverge. Each sub-agent produces the minimum discriminating query set. An arbitrator agent reads both outputs and either selects a winning hypothesis or prescribes the additional query that would discriminate. Cost is paid in parallel tokens rather than sequential user round-trips.

### 10.3 Claim-to-provenance binding at runtime
Every stakeholder-facing number is rendered with its full provenance chain: query → data source → transformation path → freshness window → any upstream late-arrival risk. The chain is computed at render time from workspace artifacts. One interaction from a delivered number exposes the SQL line, the transformation DAG, the ingestion lag, and the incremental window of the target model. Provenance is structural, not prose.

### 10.4 Decay-aware knowledge substrate
A typed knowledge graph backs the markdown memory surface. Entities: metric, table, stakeholder, initiative. Relationships: derived-from, owned-by, affects. Temporal validity attached to each claim (date range of applicability). Capabilities:

- Automatic conflict detection when two artifacts contradict each other on the same entity
- Expiration of time-bound claims without manual intervention
- Queries of the form "what did I know about X as of date Y"
- Second-order surfacing: initiative → metric → dictionary entry → upstream pipeline change

Markdown is the authoring surface. The graph is a derived index maintained by a background process.

### 10.5 Stakeholder epistemic modeling
A per-stakeholder epistemic model tracks what has been communicated to each stakeholder, what they have pushed back on, what concepts they have flagged as unfamiliar. A pre-delivery pass evaluates every draft against the model. The model is append-only and records only explicit exchanges (no inference from absence). Its outputs are primarily constraints on the draft: exclude terms previously flagged, avoid re-delivering previously-rejected findings, preserve continuity with prior communications.

### 10.6 Cross-session adversarial replay
Findings are challenged only at authoring time in the current generation. A scheduled replay pass runs the current adversarial apparatus over prior findings. When the current critic would flip a finding delivered weeks earlier (due to new memory, dependency change, or a newer directive), the system generates a correction artifact and surfaces it for stakeholder review. Replay cost competes with live work and is bounded by a scheduled budget.

### 10.7 Intervention lifecycle as first-class artifact
STRUCTURAL findings currently carry only a prose classification tag. The next generation emits a proposal artifact per STRUCTURAL finding: named owner, proposed fix, measurable success criterion, expected time-to-resolution, pointer to a tracking surface. The system monitors adoption: ticket opened, criterion met. Quarter-end reports surface unresolved STRUCTURAL findings as quantified organizational debt. Analysts produce closed interventions, not observations.

### 10.8 Rule efficacy as measurable and evolutionary
The rules directory is static in the current generation. The next generation runs each rule as a telemetered check and accumulates three counters: **fires** (hook or linter caught a would-be violation), **violations** (review or post-commit caught what the rule missed), **irrelevance** (rule never applied). Scheduled proposals:

- Deprecate rules with zero activity for 30 days
- Strengthen (hook-enforce, lint-integrate) rules violated weekly
- Consolidate rules whose violation patterns co-occur

Durable patterns migrate from rules into hooks, and from hooks into architectural impossibility. The rulebook shrinks over time.

### 10.9 Warehouse-state as live session context
Warehouse state is read on-demand via discovery queries in the current generation. The next generation injects a lightweight real-time context frame at session start: current incremental lags, recent schema-drift events, model dependency health, freshness breaches, pipeline run status. The agent receives this frame as part of session context and uses it to constrain query authoring before results come back empty. The frame is reduced from a continuously-updated monitoring surface.

### 10.10 Epistemic drift detection
An agent's framing of an observable can drift across sessions without a corresponding data inflection (from "steady" to "elevated" to "concerning" on unchanged numbers). A comparator agent ingests sequential findings on the same subject and flags tone-shift that exceeds metric-shift. When drift is detected, the system requires the current finding to state whether the change is in the data or in the language.

### 10.11 Retrospective-of-retrospectives
`/evolve` produces per-session retrospectives. A scheduled meta-retrospective runs over the retrospective corpus. Its output is corpus-level: patterns that recur across sessions, invisible at session scope. The meta-retrospective produces architectural proposals — new hooks, new directive sections, restructured commands — rather than memories or rules. This is the mechanism by which the framework itself evolves.

### 10.12 Directive efficacy experiments
Directive sections are treated as fixed in the current generation. The next generation treats them as hypotheses and runs A/B variants across sessions: a stricter §4, a looser §4, a reformulation emphasizing base rates. Session outcomes are correlated with the variant in effect. Experiment cycles run on the order of quarters, not sessions. Outcome measures are pre-registered to prevent post-hoc reinterpretation.

---

## 11. Anti-Patterns

- A `.md` file in `analysis/` describing work that has no §-blocks
- A `_open.md` memory untouched for 30+ days without update, promotion, or archival
- A hook script modified in a commit alongside unrelated analytical work
- A directory without a `CLAUDE.md`
- A commit whose subject starts with `WIP:` or `temp:`
- A stakeholder-facing artifact without a Sentence Audit
- A query file beginning with `-- TODO`
- A `reference/` snapshot without a `MANIFEST.md`
- A knowledge article without a `discovery/` sibling
- An agent dispatch for a task the primary context handled in the same turn
- A command that prompts for permission on a tool call
- A STRUCTURAL finding delivered as an INFORMATIONAL observation
- A claim presented without provenance
- A retraction issued before re-reading the evidence that supported the original claim
- A directive section whose efficacy has never been measured
- Runtime-substrate capabilities treated as implicit rather than explicitly depended on

---

## 12. Agent Behavioral Specification

### 12.1 Communication
- State the action before executing it, in one sentence
- Avoid narrating internal deliberation
- Match response length to task complexity
- End-of-turn summary: one or two sentences stating what changed and what is next
- Zero rhetorical contrast, reaction language, or self-congratulation
- Platform-safe formatting for external destinations
- Answer yes/no questions directly; describe the mechanism second; avoid case-building framing

### 12.2 Epistemic discipline
- Verify the cited artifact still exists before recommending from memory
- Cite the design doc / ticket / PR that establishes intent before claiming a bug
- Search from every available angle before declaring impossibility
- Re-read the evidence that supported the original claim before capitulating to pushback
- Run discovery queries against the live source before authoring knowledge
- Verify the checkpoint reflects current state before declaring a task complete
- Describe mechanical behavior; avoid asserting design intent from code alone

### 12.3 Tool use
- Use dedicated tools rather than shell equivalents
- Parallelize independent tool calls
- Author `CLAUDE.md` as the first file in any new directory
- Write queries to files, not to chat
- Delegate to sub-agents when primary context is at risk or the palette is strictly required

### 12.4 Safety
- Confirm with the user before any deletion
- Confirm before force-push, amend of published commits, or shared-state modification
- Avoid editing hooks during a live session
- Avoid bypassing directive steps under time pressure
- Verify an identifier before citing it; ask when verification is unavailable

### 12.5 Memory discipline
- Write feedback memories on both correction and validation
- Include `Why:` and `How to apply:` in feedback and project memories
- Propose memory-to-rule promotion when a pattern appears in three sessions
- Update or remove stale memories on discovery of new state

---

## 13. Bootstrap Sequence

0. **Runtime substrate audit** — inventory host capabilities (hook events, permission model, CLAUDE.md import semantics, additional-context injection, session-transcript persistence, task/skill/plugin tool surfaces, scope separation). Confirm the substrate supports every assumption in §1.4.
1. **Root `CLAUDE.md`** — identity, tech stack, directive execution sequence, rule imports
2. **Directives document** — the §1–§13 law
3. **Rule files** — one per artifact type, under 50 lines each, frontmatter-tagged
4. **Settings file** — permission allowlist (zero-prompt contract), hook wiring, environment vars
5. **Hook scripts** — canonical events, shared `_lib.sh`, unified session-state log
6. **Command library** — canonical commands, each under 150 lines, zero-prompt compliant
7. **Agent definitions** — canonical sub-personas with cost ratings
8. **Memory index** — empty `MEMORY.md` plus `user_profile.md` populated from the first conversation
9. **Workspace scaffolds** — each with its own `CLAUDE.md`
10. **Reference ingestion** — submodule or snapshot the production repositories; generate `MANIFEST.md`
11. **Telemetry substrate** — rule fire/violation/irrelevance counters; retrospective corpus directory; session event log rotation
12. **`/orient` validation** — first run must complete with zero permission prompts

A canonical command run at bootstrap end produces zero prompts, every rule file loads via `@`-reference, every hook logs to the unified state log, and `/evolve` runs clean against an empty corpus. Any deviation is a bootstrap bug to fix before declaring the workspace operational.

---

## 14. Document Inventory

This document contains:

- Sections 1–9: structural description and design rationales for the six workspace layers and the runtime substrate
- Section 10: twelve evolution horizons describing frontier problems and implementation shapes
- Section 11: enforceable anti-patterns
- Section 12: agent behavioral specification
- Section 13: bootstrap sequence for a new implementation
