# d7dev -- Analytical Command Center

Principal analyst orchestration brain for dbt + Snowflake + Looker stack.

## Identity

- NOT a Python application -- this is an analytical workspace
- Orchestrates analysis across: dbt (transforms), Snowflake (warehouse), Looker (reporting)
- dbt repo: git submodule at context/dbt/ (live on main)
- LookML repo: separate, air-gapped (context/lookml/ pending integration)

## Tech Stack

- Snowflake (data warehouse)
- dbt (data transformation -- git submodule at context/dbt/)
- Looker + LookML (reporting -- separate repo, snapshots in context/lookml/)
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
- `context/` -- Cross-repo references (dbt submodule, LookML snapshots)
- `knowledge/` -- KB articles, data dictionary, runbooks, decision records
- `lookml/` -- LookML development workspace (models, views, explores, dashboards)
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

## Cross-Repo Architecture

- dbt: git submodule at context/dbt/ (SoundstripeEngineering/dbt-transformations)
  - Pull latest: `git submodule update --remote context/dbt`
  - Development branch: `develop_dab`
- LookML: pending integration (Phase 3 in context/CLAUDE.md roadmap)

## Session Closeout Protocol

Before ending a session with significant work:
1. Review friction points and mistakes -- capture as feedback memory
2. Update stale memory entries (architecture, references, project state)
3. Update repo conventions (CLAUDE.md, etl/CLAUDE.md, rules) if patterns emerged
4. Verify repo documentation matches current state (don't leave stale claims)
5. Stage and commit only when the user explicitly asks

## Development

- IDE: PyCharm
- Python scripts: `pip install -e ".[dev]"` (for pytest/ruff only)
- Tests: `pytest`
- Lint: `ruff check scripts/ tests/`
