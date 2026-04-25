# d7dev -- Analytical Command Center

Principal analyst orchestration brain for dbt + Snowflake + Looker stack.

## Identity

- NOT a Python application -- this is an analytical workspace
- Orchestrates analysis across: dbt (transforms), Snowflake (warehouse), Looker (reporting)
- dbt repo: git submodule at context/dbt/ (live on main)
- LookML repo: git submodule at context/lookml/ (live on master)

## Tech Stack

- Snowflake (data warehouse)
- dbt (data transformation -- git submodule at context/dbt/)
- Looker + LookML (reporting -- git submodule at context/lookml/)
- Python 3.12+ (utility scripts only, in scripts/)

## Analytical Execution Sequence

All analytical work follows the agent directives in context/informational/agent_directives_v3.md.
The core workflow for any analytical task:

1. Rate Declarations (§1) for every rate metric
2. Definition-Use Case Alignment (§12) for segments/cohorts
3. Deliverable Contracts (§2) for each output
4. Checkpoint init (§9)
5. BUILD pass (§7) -- queries, charts, reports. No commentary.
6. VERIFY pass (§7) -- Type Audits, Contract Checklists, Identity Checks, Enumeration Checklists
7. INTERPRET pass (§7) -- Null Hypothesis, Verification Questions, Adversarial Questions
8. Intervention Classification (§11) for material findings
9. Writing Scrub (§10) on stakeholder-facing prose
10. Checkpoint update (§9)

## Error Protocol

When you discover an error: state it directly. "I made an error in [X]. [What was wrong]. [The fix]." No preamble. No apology beyond the statement. If a human correction contradicts the data, say so -- do not silently accept corrections that don't match the numbers.

## Pushback Protocol

**Push back when:**
- A human correction would change a verifiable number -- verify first, then accept or challenge
- A human frames a finding in a way the data does not support -- cite the contradicting data
- A human requests skipping verification steps -- state what goes unchecked and the risk

**Defer when:**
- The human provides domain context you cannot verify (e.g., "Q1 had a tracking change")
- The human states a style or formatting preference
- The human makes a strategic judgment about what to emphasize for their audience

## Rules

@.claude/rules/sql-snowflake.md
@.claude/rules/snowflake-mcp.md
@.claude/rules/lookml-standards.md
@.claude/rules/dbt-standards.md
@.claude/rules/analysis-methodology.md
@.claude/rules/deliverable-standards.md
@.claude/rules/writing-standards.md
@.claude/rules/python-standards.md
@.claude/rules/git-workflow.md
@.claude/rules/roadmapping-methodology.md
@.claude/rules/guardrails.md

## Directory Map

- `analysis/` -- Analysis outputs organized by domain, timestamped
- `context/` -- Cross-repo references (dbt submodule, LookML submodule)
- `knowledge/` -- KB articles, data dictionary, runbooks, decision records
  - `knowledge/query-patterns/` -- Canonical reusable SQL patterns (seeded 2026-04-24)
  - `knowledge/data-dictionary/calibration/` -- Per-table technical-truth artifacts (lineage, columns, joins, pitfalls, cost); universal mechanism per `.claude/rules/snowflake-mcp.md`
- `initiatives/` -- Cross-workspace initiative tracking (ties ETL + LookML + knowledge + analysis together)
- `lookml/` -- LookML development workspace (reference/, tasks/)
- `etl/` -- ETL task workspaces, transform drafts, data quality checks (see etl/CLAUDE.md)
- `scripts/` -- Python utilities and automation
- `tests/` -- Test suite for Python scripts
- `.claude/rules/` -- Auto-loaded conventions for all file types
- `.claude/commands/` -- Slash commands for analytical workflows
- `.claude/agents/` -- Specialized analytical subagents

## Available Commands

- `/analyze <topic>` -- Deep-dive analysis on a domain or metric
- `/model <domain>` -- Build or update a business model
- `/lookml <action>` -- LookML development (create view, explore, dashboard, validate)
- `/etl <action>` -- ETL pipeline development (write transform, quality check)
- `/monitor` -- Data quality and anomaly monitoring
- `/ingest <repo>` -- Ingest a compressed repo snapshot into context/
- `/kb-update <topic>` -- Add or update knowledge base articles
- `/scaffold <domain>` -- Create a new analytical domain scaffold
- `/roadmap <domain>` -- Manage a roadmapping initiative (scope, consolidate, prioritize, plan)
- `/review` -- Review uncommitted changes across all file types
- `/test [args]` -- Run validations (Python, SQL, LookML)
- `/status` -- Analytical project health dashboard
- `/checkpoint [init|update|review]` -- Session state management
- `/preflight [task]` -- Pre-flight check: verify environment, targets, existing patterns before starting work
- `/evolve [scope]` -- Post-task retrospective: detect friction, audit repo health, integrate improvements
- `/orient` -- Session-start infrastructure review: mandatory inventory of rules, commands, agents, memory, CLAUDE.md chain, initiatives, task workspaces; produces briefing and routing table before any task work
- `/sql <question>` -- Execute SQL against Snowflake via MCP, wrapped in three-pass discipline (pre-check KB + task dir, calibration check, RATE/ALIGNMENT blocks, cost caps, post-execution audits). See `.claude/rules/snowflake-mcp.md`
- `/calibrate <table | domain | --stale | --refresh <table>>` -- Ground MCP queries in dbt + LookML + Snowflake + analysis-history context. Produces per-table calibration artifacts at `knowledge/data-dictionary/calibration/`. Universal mechanism — any warehouse table is a candidate; first-touch rule in `.claude/rules/snowflake-mcp.md` decides block-vs-warn based on size/grain

## Cross-Repo Architecture

- dbt: git submodule at context/dbt/ (SoundstripeEngineering/dbt-transformations)
  - Pull latest: `git submodule update --remote context/dbt`
  - Development branch: `develop_dab`
- LookML: git submodule at context/lookml/ (SoundstripeEngineering/looker)
  - Pull latest: `git submodule update --remote context/lookml`
  - Development: prepare in lookml/tasks/, user promotes via Looker IDE
- Snowflake: direct execution via `mcp__claude_ai_Snowflake__sql_exec_tool` (role EMBEDDED_ANALYST, warehouse DATA_SCIENCE). Governance in `.claude/rules/snowflake-mcp.md`; canonical reusable queries in `knowledge/query-patterns/`; per-table calibration artifacts (lineage, columns, joins, pitfalls, cost) in `knowledge/data-dictionary/calibration/` — accumulate organically as tables are queried (universal mechanism, not a whitelist)

## Session Closeout Protocol

Before ending a session with significant work:
1. Update initiative files in `initiatives/` for any cross-workspace work (changelog entry + artifact links)
2. Review friction points and mistakes -- capture as feedback memory
3. Update stale memory entries (architecture, references, project state)
4. Update repo conventions (CLAUDE.md, etl/CLAUDE.md, rules) if patterns emerged
5. Verify repo documentation matches current state (don't leave stale claims)
6. Update task README.md status in etl/tasks/ and lookml/tasks/ for completed work
7. Stage and commit only when the user explicitly asks

## Development

- IDE: PyCharm
- Python scripts: `pip install -e ".[dev]"` (for pytest/ruff only)
- Tests: `pytest`
- Lint: `ruff check scripts/ tests/`
