Run a session-start infrastructure review. Invoke with `/orient` at the start of a session before any task work.

**PURPOSE:** Force a complete inventory of the d7dev repo's accumulated infrastructure (rules, commands, agents, memory, CLAUDE.md chain, hooks, knowledge, initiatives, task workspaces) so the session proceeds rooted in built knowledge rather than re-deriving or ignoring it. Each phase emits a mandatory structured block — skipping a phase produces a visibly empty block.

**EXECUTION MODE:** End-to-end hands-off. Zero user interaction between phases. Zero permission prompts. All required tool calls are pre-allowed in `.claude/settings.json`. Do not ask questions. Do not stop between phases. Run all five phases, then emit readiness and stop.

---

**PHASE 1 — INVENTORY**

Read all infrastructure files in parallel where possible. Use `Read` directly on absolute paths. Use `Glob` to discover CLAUDE.md and memory files.

**Verbatim reads (content must live in main context):**
- `.claude/rules/*.md` — every file
- `.claude/commands/*.md` — every file (this one included; skip re-reading if already in context)
- `context/informational/agent_directives_v3.md` — core directive reference (§1–§13)
- Root `CLAUDE.md`
- `~/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/*.md` — every memory file (use Bash `ls` to enumerate, then Read each)
- `.claude/settings.json` and `.claude/settings.local.json` (if present)
- `.claude/hooks/session-gate.sh`, `.claude/hooks/prompt-context.sh`, `.claude/hooks/bash-guard.sh`
- `context/CLAUDE.md`

**Catalog-only (list without full read):**
- `.claude/agents/*.md` — frontmatter/description only
- `.claude/hooks/*.sh` (other than the three above) — list filenames
- Non-root `CLAUDE.md` files — `Glob **/CLAUDE.md` and list paths only; full text is auto-loaded by the harness when navigating into those directories
- `knowledge/decisions/`, `knowledge/runbooks/`, `knowledge/data-dictionary/`, `knowledge/domains/` — `ls` + title line of each markdown file

**Substrate deep-dive (on-demand only, not part of the verbatim reads):** `knowledge/runbooks/runtime-substrate-catalog.md` holds the full catalog of every user-scope and project-scope Claude runtime resource, precedence rules, and known failure modes. Read it when a task touches settings, hooks, skills, plugins, memory keying, or CLAUDE.md chain design — not on every /orient run.

**Block conditions (abort /orient with error):**
- `context/informational/agent_directives_v3.md` missing or unreadable
- Root `CLAUDE.md` missing
- Not inside a git repo (`git rev-parse --show-toplevel` fails)

**Gate:** emit this fenced block before advancing to Phase 2. One row per file read or cataloged. Empty cells are visible omissions.

````
INVENTORY_MANIFEST
| # | path | mode | attestation (one phrase) |
|---|------|------|--------------------------|
| 1 | .claude/rules/analysis-methodology.md | verbatim | ... |
| ... | ... | ... | ... |
````

---

**PHASE 2 — STATE**

Capture current repo reality in parallel tool calls:

- `git status` (never `-uall`)
- `git log -20 --oneline`
- `git log main..HEAD --oneline` (unmerged work on current branch)
- `git submodule status` (context/dbt and context/lookml HEADs)
- `git rev-parse HEAD` (for briefing header)
- `git rev-parse --abbrev-ref HEAD` (branch name)
- Read `.claude/hooks/checkpoint.md` if it exists; compute age in days from `date` command
- `ls -t analysis/data-health/*-session-retrospective.md | head -1` then Read the most recent retrospective; scan for "Open design problems" section
- `ls -d initiatives/*/` (active initiatives)
- `ls -dt etl/tasks/*/ | head -10` and `ls -dt lookml/tasks/*/ | head -10` (recent task workspaces)
- `ls -dt analysis/*/ | head -15` (recent analysis domain directories)
- `ls -t ~/.claude/projects/-Users-dev-PycharmProjects-d7dev/*.jsonl 2>/dev/null | head -1` — note filename + mtime of most recent session transcript

**Gate:** emit this block.

````
STATE_SUMMARY
  branch:                  <branch>
  head:                    <short-sha> <subject>
  uncommitted_files:       <count>
  unmerged_commits:        <count> (on current branch vs main)
  submodule_heads:         context/dbt=<sha> context/lookml=<sha>
  checkpoint_age_days:     <N or "none">
  last_retrospective:      <YYYY-MM-DD or "none" (if ≥7d, mark STALE)>
  active_initiatives:      <count>
  in_flight_task_dirs:     <count across etl/tasks, lookml/tasks>
  recent_analysis_dirs:    <top 5 slugs>
  last_session_transcript: <filename or "none"> (mtime <N>d ago)
````

---

**PHASE 3 — CLASSIFY**

Emit the static ROUTING_TABLE below, then compute the per-session OPEN_PROBLEMS_QUEUE.

````
ROUTING_TABLE (static — update this section when infrastructure changes)

Task type                        | Command(s)              | Rules                                                                     | Agent             | Memory anchors                                                                                                                                           | Required pre-step
---------------------------------|-------------------------|---------------------------------------------------------------------------|-------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------
ETL / dbt model work             | /preflight then /etl    | dbt-standards, sql-snowflake, guardrails                                  | data-engineer     | feedback_dbt_environments, feedback_dbt_model_placement, feedback_dbt_schema_test_consistency, feedback_backfill_var, feedback_snowflake_permissions     | ls etl/tasks/ for prior work on same model
LookML work                      | /preflight then /lookml | lookml-standards, guardrails                                              | lookml-developer  | feedback_lookml_promotion_workflow, reference_looker_repo                                                                                                | read existing view in target dir for conventions
Investigatory analysis           | /preflight then /analyze| analysis-methodology, deliverable-standards, writing-standards            | analyst           | feedback_investigatory_workflow, feedback_prior_investigation_search, feedback_distribution_rollup_substantiation, feedback_exhaust_search_before_concluding, feedback_follow_the_data_not_the_frame, feedback_discovery_before_knowledge, reference_session_event_join | **Glob analysis/\*\*/\*<slug>\* for prior investigations BEFORE any query**
Business modeling                | /model                  | analysis-methodology, deliverable-standards                               | modeler           | (topic-specific project memory)                                                                                                                          | identify canonical data dictionary source
Knowledge base / docs            | /kb-update              | writing-standards, guardrails                                             | kb-curator        | feedback_discovery_before_knowledge                                                                                                                      | run warehouse discovery queries before drafting
Roadmapping                      | /roadmap                | roadmapping-methodology                                                   | —                 | user_roadmapping_process                                                                                                                                 | confirm current step (1–7) of initiative
Data quality / monitoring        | /monitor                | analysis-methodology                                                      | analyst           | feedback_investigatory_workflow                                                                                                                          | —
Retrospective / repo hygiene     | /evolve                 | (all)                                                                     | —                 | feedback_session_retrospective                                                                                                                           | —
Cross-workspace initiative work  | check initiatives/ first| (depends on workspace involved)                                           | —                 | user_roadmapping_process                                                                                                                                 | read initiative README before any workspace edit
Content / brand work             | marketing:* skills      | —                                                                         | marketing:*       | —                                                                                                                                                        | —
````

Compute OPEN_PROBLEMS_QUEUE from these sources (Glob + Read):
1. Every `~/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/project_*_open.md` (explicit naming convention)
2. The "Open design problems" section of the most recent `analysis/data-health/*-session-retrospective.md`
3. Any `*_open.md` memory unchanged for ≥14 days (flag as STALE)
4. In-flight task workspaces with README status `draft` or `in-progress`

**Gate:** emit both blocks.

````
OPEN_PROBLEMS_QUEUE
[N] <title> — <source> — <one-line status> (<age if stale>)
...
````

---

**PHASE 4 — BRIEF**

Produce the briefing artifact AND a 10-line chat summary. Artifact is ephemeral (overwrite every invocation).

**Artifact path:** `.claude/hooks/session-briefing.md` (this write is pre-allowed in `settings.json`).

**Artifact template:**

```markdown
# Session Briefing — <YYYY-MM-DD HH:MM>

- **Branch:** <branch>
- **HEAD:** <short-sha> <subject>
- **Last retrospective:** <YYYY-MM-DD> (<stale flag if ≥7d>)
- **Last checkpoint:** <topic or "none"> (<Nd old>)

## Stakeholders
- <inferred from memory: user_profile + active project memories>

## Active initiatives
- <initiatives/*/> with current phase/step

## In-flight task workspaces
- <etl/tasks/*, lookml/tasks/*, analysis/**/ dated dirs with status>

## Open problems
- <OPEN_PROBLEMS_QUEUE from Phase 3>

## Stale flags
- <checkpoint ≥3d, retro ≥7d, *_open.md memory ≥14d without update>

## Calibration status
- <count of artifacts in knowledge/data-dictionary/calibration/; count stale (>30d or schema-hash drift); any tables flagged by recent `_sweep_*.md` output>

## Routing table
(See `.claude/commands/orient.md` for the full table; this session's most likely task types given in-flight work: <list>)
```

**Gate:** write the file, then emit the 10-line chat summary (headers + counts, no full-body dump).

---

**PHASE 5 — READINESS**

Emit exactly:

```
READY.
Reviewed: N rules, M commands, K agents, P memory files, Q CLAUDE.md paths, R directive sections.
Routing table committed. <X> open problems queued. <Y> stale items flagged.
If the next task falls under a row in the routing table and I skip a required pre-step, correct me.
```

Then stop. Do not ask what to do next. Await the user's next prompt.
