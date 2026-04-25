# d7dev — A Technical Walkthrough

**Audience.** Engineers who've used Cursor / Aider / Claude Code, understand dbt + Snowflake + Looker, and have seen "AI-assisted analysis" demos.

**How to read this.** The document is layered in three tiers. Tier 1 is a 60-second elevator. Tier 2 extends Tier 1 with a 5-minute demo-level tour. Tier 3 extends Tier 2 with a 10+-minute technical deep-dive. Each tier is a strict prefix of the next — stop whenever you have what you came for.

---

## The hook (read this first)

AI-assisted analysis on a real warehouse fails *open* by default.

Ask Claude Code to "show me the top 10 pricing-page sessions last week," let it run a query with `LIMIT 100`, and if the population is larger than 100 you get a ranked sample that looks like the population. The LLM will interpret the sample as complete, produce a stakeholder-facing claim ("pricing traffic is dominated by these referrers"), and stand behind it when challenged. The SQL tool's output cap, server-side truncation, and self-imposed LIMITs all produce the same failure shape: a partial result that the model treats as total.

This is not hypothetical. It happened. The rule that now blocks it lives at `.claude/rules/snowflake-mcp.md` under "Result completeness":

> **Three ways a result can be partial without visibly saying so**
> 1. **Self-imposed `LIMIT`** — a query with `LIMIT N` that returns exactly N rows is almost certainly capped
> 2. **MCP tool auto-reroute (~111K chars)** — overflow lands in a file; the in-context response is just a warning
> 3. **Snowflake session result-size cap** — large result sets can be truncated server-side

Every MCP query against the warehouse now runs a post-execution completeness check before any downstream claim is built on it. The check is codified in the rule, invoked by the `/sql` command, reinforced by a feedback memory, and summarized in a runbook PSA shipped to non-technical users who consume the outputs.

**d7dev's claim** is that this specific failure-mode is now impossible-by-default, and it got there by treating methodology — including the post-mortem of one bad incident — as code.

---

## Tier 1 — 60 seconds

**What it is.** An analytical command center layered on top of Claude Code for a dbt + Snowflake + Looker stack. The repo holds the analyses themselves (`analysis/data-health/`, `analysis/experimentation/`, etc.). The `.claude/` substrate holds 11 rules, 18 commands, 7 agents, 64 persistent memory files, and a set of hooks that enforce discipline at the tool layer. Methodology, memory, and verification live as code.

**What differentiates it from Cursor / Aider / plain Claude Code / "AI analysis" demos.** Four things:

1. **Multi-session.** Memory files at `~/.claude/projects/.../memory/` accumulate across sessions (feedback, project state, references). A calibration artifact written today for `core.fct_events` grounds every MCP query against that table thereafter.
2. **Verification-first.** Every analytical task follows a three-pass workflow — BUILD, then VERIFY (Type Audits, Contract Checklists, Identity Checks, Enumeration Checklists), then INTERPRET. Pass 2 produces written artifacts you can inspect.
3. **Methodology-as-code.** Rules like "JOIN type is the denominator" and "aggregate-first when asking a population question" are checked-in files in `.claude/rules/`.
4. **Self-evolving.** The `evolution/` directory is a real product roadmap for the substrate itself — 25 task directories across 7 swimlanes, priorities P1–P5, epics including meta-retrospective (6.8) and directive-efficacy A/B experiments (6.9). The system studies its own effectiveness.

**The demo moment — `/orient`.** Running `/orient` at session start produces a routing table. Excerpt:

```
Task type                | Command(s)              | Rules                                                        | Agent             | Required pre-step
-------------------------|-------------------------|--------------------------------------------------------------|-------------------|-------------------
ETL / dbt model work     | /preflight then /etl    | dbt-standards, sql-snowflake, guardrails                     | data-engineer     | ls etl/tasks/ for prior work
LookML work              | /preflight then /lookml | lookml-standards, guardrails                                 | lookml-developer  | read existing view in target dir
Investigatory analysis   | /preflight then /analyze| analysis-methodology, deliverable-standards, snowflake-mcp   | analyst           | Glob analysis/**/*<slug>* for prior investigations FIRST
Direct Snowflake query   | /sql                    | snowflake-mcp, sql-snowflake                                 | —                 | calibration check on first-touch tables
Warehouse calibration    | /calibrate              | snowflake-mcp                                                | warehouse-calibrator | confirm missing or stale calibration
```

Every class of analytical task has a defined recipe: rules, agent, memory anchors, and required pre-step.

**When it pays back.** Multi-session analytical work; high-stakes outputs (board reports, experiment readouts, compliance-adjacent findings); accumulating warehouse complexity; multiple stakeholders asking related questions over weeks. **When it's overkill.** One-off exploratory scripts, disposable prototypes, one-person small codebases.

---

## Tier 2 — 5 minutes (extends Tier 1)

Tier 1 covered *what* d7dev is and *why* it's different. Tier 2 shows the working parts.

### The three-pass workflow

Every analytical task executes in this sequence. The passes do not interleave.

**Pass 1 — BUILD.** SQL, charts, report assembly. Output only. No commentary, no interpretation.

**Pass 2 — VERIFY.** Written verification artifacts. For every rate metric, a RATE declaration + a Type Audit:

```
RATE: pricing_page_conversion
NUMERATOR:   distinct sessions that reached /checkout/success
DENOMINATOR: distinct sessions that viewed /pricing
TYPE:        sessions_converted / sessions_at_pricing
NOT:         sessions_viewing_checkout (that would inflate the denominator pre-pricing-visit)

TYPE AUDIT — pricing_page_conversion:
  Declared denominator: distinct sessions viewing /pricing
  JOIN chain: pricing_sessions LEFT JOIN checkout_sessions ON session_id
  Column used as denominator: COUNT(DISTINCT ps.session_id)
  Does JOIN type enforce declared denominator? YES — LEFT JOIN preserves all pricing sessions
  RESULT: PASS
```

The directive is explicit: **the JOIN type IS the denominator**. A LEFT JOIN preserves the left-side population; an INNER JOIN restricts to the intersection. If declared denominator and JOIN-implied denominator disagree, the query is wrong and the Type Audit FAILs. No query advances to visualization without a passing audit.

Pass 2 also requires Contract Checklists (from `§2` of the directives), Identity Checks (`§5`, detecting A = B × C decompositions), Enumeration Checklists (`§6`, never enumerate from memory), and a manually-computed spot-check for at least one row.

**Pass 3 — INTERPRET.** Written commentary. Each interpretive claim gets a Verification Question (stated, answered independently, compared to the claim), a Null Hypothesis block (if the pattern is in a trigger domain like cohort shift or engagement decay), and Adversarial Questions (what would a skeptical reader challenge; what assumption, if wrong, flips the conclusion). Findings that imply "building something new" get classified as STRUCTURAL per `§11` and escalated with gap framing ("the product does not handle X; proposed fix Y").

A real example sits at `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` — the WCPM pricing-test audit, which uncovered a step-rate nesting bug via Type Audit discipline and produced a repo-wide project memory entry about enforced 1:1 identity mapping dropping ~13.5% of exposed users from Pulse.

### The closed-loop session lifecycle

```
/orient   → inventory + state + routing table + open-problems queue + briefing
/preflight → pre-task verification: environment, targets, prior work, calibration status
task      → /analyze | /etl | /lookml | /sql | /calibrate | /model | /kb-update | ...
/evolve   → friction detection + pattern capture + memory update + rule edits
```

Each session ends with `/evolve`. The retrospective at `analysis/data-health/2026-04-24-session-retrospective.md` shows the pattern:

1. Friction observed (Claude produced fabricated top-N from a LIMIT-100-capped result)
2. Friction classified (`JUDGMENT` — "missed the inbound-truncation failure mode")
3. Pattern generalized (enumerate-specific-instances-over-classes; protection-without-symmetry)
4. Captured as `feedback_no_fabrication_from_capped_results.md` and `feedback_design_for_classes_not_instances.md` in memory
5. Rule edit landed in `.claude/rules/snowflake-mcp.md` (new "Result completeness" section)
6. Post-execution check wired into `/sql`
7. PSA runbook shipped at `knowledge/runbooks/claude-mcp-result-completeness-psa.md` for non-technical readers

Friction becomes methodology. Methodology ships as a rule + a command hook + a memory entry + a runbook — in one session.

### The CLAUDE.md chain

Every managed directory (`analysis/`, `etl/`, `lookml/`, `knowledge/`, `initiatives/`, and now `docs/`) has a `CLAUDE.md` file. Every file chains upward via `@../CLAUDE.md`. The root CLAUDE.md lists the rules. The rules get loaded into every session's prompt context. The chain is walkable from any leaf — which means the methodology is always reachable regardless of which subdirectory the agent is working in. The repo has 50 CLAUDE.md files.

The session-gate hook (`.claude/hooks/session-gate.sh`) blocks any Write or Edit to a managed directory that lacks a CLAUDE.md. If you try to drop a new task workspace without the chain, the tool-call errors out.

### Hooks as enforcement

Guardrails live at the tool layer:

- **`session-gate.sh`** — blocks writes to managed dirs without CLAUDE.md; nudges `/preflight` after 3 managed writes in a row without one
- **`bash-guard.sh`** — blocks `git add .` and `git add -A` (forces file-by-file staging); warns on command repetition at 4× and 7× (guardrail against retry-loops); forces a chart-verification before `git commit` if unverified chart scripts exist
- **`prompt-context.sh`** — on every UserPromptSubmit, injects today's date (prevents the stale-date bug where the model invents a date from training context), checkpoint age, and MEMORY.md staleness into the prompt
- **`retry-guard.sh`**, **`writing-scrub.sh`**, **`workflow-tracker.sh`** — enforce discipline at Write/Edit and track workflow state across tool calls

These are small bash scripts in `.claude/hooks/`. They fire on events documented in `.claude/settings.json`: SessionStart, UserPromptSubmit, PreToolUse (matchers: `Write|Edit`, `Bash`), PostToolUse, SessionEnd. The whole substrate is legible in one directory.

### Memory as compounding knowledge

`MEMORY.md` at `~/.claude/projects/.../memory/MEMORY.md` is an index. The individual files (64 at last count) are categorized: `user_*` (Devon's role/preferences), `project_*` (current initiatives, open investigations), `reference_*` (pointers to external systems and key warehouse tables), `feedback_*` (rules learned from specific friction — "don't mock DB in integration tests because Q3 2025 prod migration broke," etc.).

Feedback memories encode *why* as well as *what*, so future sessions can judge edge cases against the original motivation. Example: `feedback_cross_check_stakeholder_benchmarks.md` — "when a stakeholder doc reports a prior value for your metric, compare explicitly in the Verify pass; >2x gap almost always = a bug, not a definitional difference." That memory was written after a session delivered a metric value 3× off a stakeholder benchmark without flagging it.

At session start, MEMORY.md is loaded into context (truncated at 200 lines), and `prompt-context.sh` injects staleness warnings when the index hasn't been touched in >14 days. Memory is not a vector-search blob — it's a curated, human-readable index with pointers.

---

## Tier 3 — 10 minutes (extends Tier 2)

Tier 2 showed the working parts. Tier 3 shows how the substrate got here, where it's going, and the honest cost.

### Evolution — the substrate has its own roadmap

The `evolution/` directory is structured as a real product roadmap, produced via the 7-step roadmapping process (scope → brainstorm → groupings → swimlanes/epics → priorities → roadmap artifact → epic project plans). The output: 25 task directories across 7 swimlanes (0–6, dependency-ordered), 23 named epics with priorities P1–P5, and a `MASTER_TRACKER.md` status rollup updated at `/evolve`.

**Foundational work done (all P1, all Swimlane 0):**

- **Epic 0.1 — Runtime substrate audit.** Catalog every user-scope and project-scope Claude runtime resource (rules, commands, agents, hooks, skills, memory, plugins, CLAUDE.md chain, settings), the precedence rules, and known failure modes. Lives at `knowledge/runbooks/runtime-substrate-catalog.md`.
- **Epic 0.2 — Zero-prompt contract audit.** A 44-entry allowlist of tool calls guaranteed to succeed without a permission prompt, enforced by a regression guard in `/test`. Means `/orient` and similar session-start commands can run hands-off.
- **Epic 0.3 — Telemetry substrate.** OpenTelemetry instrumentation. OTLP endpoint live on `:4318`. Hook-bridge POC verified (hook events → OTLP). The observability stream that every downstream measurement epic consumes.

**Next critical path (P1, open):**

- **Epic 1.1 — Hook lifecycle & safety.** Currently the sole remaining P1 at Swimlane 0/1. Addresses the known fragility of hook editing mid-session (captured in `feedback_dont_edit_live_hooks`).
- **Epic 1.2 — Unified session-state log.** Blocks downstream Epics 2.1 and 2.3. Once landed, rule-efficacy telemetry and the directive linter can start.

**Cognitive-layer work (higher swimlanes, P3+):**

- **Epic 5.4 — Parallel hypothesis arbitration** (multiple competing explanations evaluated in parallel rather than serially)
- **Epic 6.1 — Knowledge graph substrate** (explicit graph over entities like tables, metrics, analyses, rules)
- **Epic 6.3 — Claim provenance rendering** (every stakeholder-facing claim traces back to the query that produced it)

**Meta-self-evolution (P3–P4):**

- **Epic 6.8 — Meta-retrospective.** A retrospective-of-retrospectives over the `/evolve` corpus to surface corpus-level patterns and emit architectural proposals. Maps to the framework's `§10.11`.
- **Epic 6.9 — Directive efficacy experiments.** A/B-test directive-section variants across sessions; correlate outcomes; iterate text based on measured efficacy. Maps to `§10.12`.

Epic 6.9 treats the methodology itself as a measurement problem. The rule at `.claude/rules/analysis-methodology.md` is not assumed to be correct. Correctness is established by measuring whether sessions running variant A produce more auditable / fewer defective outputs than variant B.

### Warehouse calibration — substrate growth as a design pattern

The calibration mechanism at `knowledge/data-dictionary/calibration/` demonstrates how d7dev grows without top-down scoping.

**The rule:** the first time an MCP query touches a table, check whether a calibration artifact exists at `knowledge/data-dictionary/calibration/<schema>__<table>.md`. The artifact captures dbt lineage, column inventory, known pitfalls, cost profile, and frontmatter (`last_calibrated`, `schema_hash`, `row_count`). If current (≤30 days, matching schema hash), proceed. If missing or stale, the first-touch decision matrix in `snowflake-mcp.md` decides:

- Table is large (>1M rows) OR fact-grain (`fct_*`, `*events*`) OR raw/external schema OR query has 3+ joins → **block**. Invoke `/calibrate <schema.table>` before proceeding.
- Table is small (<100K rows) AND dim-grain (`dim_*`) AND the query is simple → **soft-warn**. Proceed, surface the gap at session end as a promotion candidate.
- Fan-out red flag at any time → **block** and calibrate the problematic table.

**What grows:** each calibration pays off across every future session that queries the table. `core__fct_events.md` (1,013 words) captures the 1.29B-row, 75-GiB event table's lineage, 70-column inventory, incremental watermark behavior, and the Statsig late-arrival-row-drop pitfall. The next session that writes a query against `fct_events` reads that context into the prompt and doesn't rediscover any of it.

**What's universal:** there's no whitelist of "tables that need calibration." The rule is a first-touch decision matrix based on discoverable properties (row_count, bytes, naming, query shape). Any table in the warehouse is a candidate. Five artifacts exist today; one more (`pc_stitch_db.mixpanel.export`) is pending and will block any MCP query against that raw source until calibrated.

The `warehouse-calibrator` subagent at `.claude/agents/warehouse-calibrator.md` backs the `/calibrate` command. Given a schema-qualified table name, it reads the dbt model + schema.yml, the LookML view, Snowflake `information_schema` + `query_history`, prior analyses, and memory — synthesizes into the artifact. Hands-off.

### Substrate-as-product

The claim engineers should evaluate: **the methodology itself ships as a product**.

Evidence:
- Rules in `.claude/rules/*.md` are versioned, tested (`/test` runs validations across Python/SQL/LookML + rules checks), and iterated at `/evolve`
- Commands in `.claude/commands/*.md` are composable workflows (`/preflight` → `/analyze` → `/evolve`), with their own contracts and pre-steps
- Agents in `.claude/agents/*.md` are role-specialized (analyst, data-engineer, lookml-developer, kb-curator, modeler, architect, warehouse-calibrator) and dispatched via the routing table
- The `evolution/` roadmap treats the substrate as a product with swimlanes, priorities, retrospectives, meta-retrospectives
- Memory accumulates across sessions and persists across the life of the workspace

This is a testable claim. The same repo at month 0 and month 6 should demonstrate measurable improvement in a specific failure-mode rate (hallucinated stakeholder claims, fan-out bugs, step-rate nesting errors). Epic 6.9 is how that measurement gets formalized.

### When NOT to use this

The cost is real.

**~2 hours to internalize** the rules and command vocabulary before you get value. Type Audits, Alignment Checks, Contract Checklists are verbose on purpose — they slow down the first draft. Rapid-prototyping speed takes a hit.

**The substrate is shaped for a specific role.** d7dev is built for Devon Bennett's role: sole data-team member at Soundstripe, principal analyst across dbt + Snowflake + Looker, multi-stakeholder questions spanning weeks. Much of the methodology is calibrated to that workload (multi-session memory, calibration-first MCP, retrospective cadence). A team of engineers running sprints against a microservice codebase would not need most of this — they would need different hooks, different rules, a different routing table.

**Adoption ≠ cloning.** The pattern is reusable; the specific rules are not. A new analytical workspace built on the same pattern would want its own rules (what does verification look like for your domain?), its own memory seed (what does your team already know?), and its own evolution roadmap (what's your substrate's P1?). Fork-and-modify is the intended adoption path.

**Overkill cases.**
- One-off exploratory scripts — the Type Audit overhead dominates the analysis
- Disposable prototypes — no compounding benefit from memory
- Very small codebases — hook enforcement friction exceeds the value of enforcement

### What's next-week interesting for an engineer reader

- **Epic 1.1 — Hook lifecycle & safety.** The known sharp edge of the substrate today. Load-bearing for every subsequent epic. Worth watching.
- **Epic 6.9 — Directive efficacy experiments.** The moment the methodology becomes a measurement problem is the moment this stops being "opinionated config" and starts being "evidence-based config."
- **The calibration mechanism** at `knowledge/data-dictionary/calibration/` is the clearest example of substrate that pays back across sessions. Read `core__fct_events.md` to see what "ground truth for a warehouse table" looks like when it's been written once and reused every session thereafter.

`evolution/MASTER_TRACKER.md` holds the current swimlane-ordered status. `evolution/README.md` holds the task-directory index.

---

## Closing

If Cursor is code-completion-for-the-working-file, and Claude Code is a terminal-native AI coworker, d7dev is a *discipline layer* above Claude Code — the thing that prevents the AI from failing open at scale. The methodology, memory, and verification machinery are the product. Claude Code is the execution engine.

Everything in this document is legible at paths cited in-line. Start with `CLAUDE.md` at the root; run `/orient` in a session; read the most recent retrospective at `analysis/data-health/2026-04-24-session-retrospective.md`; skim `evolution/README.md`. That's the full tour.
