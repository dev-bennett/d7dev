# Session Retrospective — 2026-04-24

Full-session retrospective for the day's work: standing up the Snowflake MCP governance, query-patterns KB, warehouse calibration mechanism, and the result-completeness rule.

## Session summary

Three major work streams, all completed:

1. **Snowflake MCP governance foundation.** Allow-listed the MCP tool, created `.claude/rules/snowflake-mcp.md`, `/sql` command, `knowledge/query-patterns/` KB with 5 seed queries, governance ADR at `knowledge/decisions/2026-04-24-snowflake-mcp-governance.md`, 2 memory entries. Smoke-tested all 5 seed queries against real Snowflake; DML rejection confirmed.
2. **Rule tuning via real-data research.** Queried warehouse reality (EMBEDDED_ANALYST has USAGE on exactly 1 warehouse), table sizes (`fct_events`: 1.29B rows / 75 GiB), and cost profile from `query_history`. Deleted Rule 1.3 (warehouse escalation was theater — no alternate warehouse exists for the role), scoped the `LIMIT 100` rule to >1M-row tables, softened row/col thresholds, added MCP tool constraints section.
3. **Warehouse calibration mechanism.** Scaffolded `knowledge/data-dictionary/calibration/` (CLAUDE.md, `_index.md`, `_template.md`), created `warehouse-calibrator` subagent, `/calibrate` command, "Calibration before query" rule section, wired into `/sql`, `/preflight`, `/analyze`, `/orient`, `/evolve`. Seeded 2 of 6 artifacts (`core.fct_events`, `_external_statsig.exposures`) directly in main thread; remaining 4 pending due to subagent hot-reload limit.
4. **Result-completeness rule** (added after user flagged proven fabrication from truncated results). New rule section, post-execution check in `/sql`, feedback memory, and a paste-ready Slack PSA as a runbook.

## Friction points (classified)

| # | Friction | Class | Detail |
|---|---|---|---|
| 1 | Hardcoded 6-table "high-risk" list in the calibration rule | JUDGMENT | User pointed out the warehouse has hundreds of tables; mechanism had to be universal. Rewrote as size/grain/query-shape decision matrix |
| 2 | Missed the inbound-truncation failure mode on first pass | JUDGMENT | Initial rule protected OUTBOUND (transcript flooding) but not INBOUND (Claude interpreting truncated data as complete). User had to flag it as a gap despite my having written the rule |
| 3 | PSA draft 1 written for analysts | COMMUNICATION | Audience was "all Claude Enterprise users, 99% non-SQL." Should have asked or inferred from the brief |
| 4 | PSA draft 2 too paranoid | COMMUNICATION | Made the tool look like more work than it saves. User pushed back: "this convinces me not to use the tool" |
| 5 | Recommended "ask Claude to verify" as PSA remedy | JUDGMENT | User had proven this doesn't work — Claude had gaslit them until they produced downstream truth. Had to remove and replace with external-verification guidance |
| 6 | Schema-hash convention mismatch | EXECUTION | Computed hash via bash `shasum` with newlines; Snowflake `LISTAGG` can't use `CHR(10)` as constant separator. Self-caught during verification but cost a fix-up pass and a re-compute of 2 seeded artifacts |
| 7 | Subagent hot-reload attempt | PROCESS | Created `warehouse-calibrator`, then tried to invoke it immediately. 6 parallel invocations errored with "Agent type not found." Fell back to 2 calibrations in main thread; 4 pending a fresh session |

## Patterns across friction

**Pattern A — Enumerate-specific-instances-over-classes.** Friction #1, #3, and arguably #2 share a common shape: I picked the concrete examples I happened to have context for (6 tables, analyst audience, outbound truncation) and let them ossify into the design. User corrections were all "widen the scope to the underlying class." Captured as `feedback_design_for_classes_not_instances.md`.

**Pattern B — Protection without symmetry.** Friction #2 (outbound-only result handling) and indirectly Rule 1.3 (protecting a nonexistent escalation path) share this. The first-pass rule addressed one half of a symmetric concern. Mitigation: when writing governance, consciously enumerate both directions of data flow and both branches of any binary before committing to a rule.

**Pattern C — Verification-as-afterthought.** Friction #6 (schema_hash) and #7 (subagent hot-reload) both surfaced at invocation/verification time, not at design time. Both are cheap to catch pre-design with a "will this actually work end-to-end in my current context?" check. Mitigation: when building a mechanism that will be used immediately, simulate one full end-to-end invocation in plan-time, not at execute-time.

## Wins

- **Research-backed rule tuning** produced concrete cuts. Citing real numbers (EMBEDDED_ANALYST has 1 warehouse; `fct_events` = 1.29B rows; date-scoped aggregate = $0.001) changed both the rule shape and the confidence in the remaining rules
- **Plan mode usage** scoped both the governance foundation and calibration work cleanly. User approved both plans without modification
- **Self-caught the schema_hash convention mismatch** during verification rather than delivering a broken mechanism
- **Tone pivots on PSA** were rapid once the user redirected — three drafts to land on the right audience, tone, and action posture
- **DML rejection test** ran and returned the expected `003001: Insufficient privileges` — confirmed the role is read-only by the warehouse itself, no hook needed

## Audit checklist (Phase 2)

| # | Item | Status | Detail |
|---|---|---|---|
| 1 | CLAUDE.md chain | PASS | All three new subdirs walk to root |
| 2 | Stale docs | FIXED | Added `query-patterns/` and `calibration/` pointers to root CLAUDE.md directory map |
| 3 | Memory freshness | PASS | 4 new memory entries (2 reference, 2 feedback), + 2 added during retrospective. No duplicates |
| 4 | Rule coverage | PASS | All 11 files reviewed; `snowflake-mcp.md` new; `sql-snowflake.md`, `analysis-methodology.md`, `guardrails.md` updated; `writing-standards.md` exercised (followed) |
| 5 | Command coverage | PASS | All 18 commands reviewed; `/sql` + `/calibrate` new; `/analyze`, `/preflight`, `/orient`, `/evolve` modified |
| 6 | Knowledge gaps | FIXED | Created `knowledge/runbooks/claude-mcp-result-completeness-psa.md` as reusable stakeholder PSA |
| 7 | Agent coverage | PASS | `warehouse-calibrator` created; hot-reload limit now documented |
| 8 | Orphaned files | PASS | No session-produced orphans |
| 9 | Task hygiene | FIXED | Appended status note to `analysis/adhoc/2026-04-24-fct-events-recent-500/CLAUDE.md` |
| 10 | Open design problems | LOGGED | 3 items (see below) |
| 11 | Calibration artifact updates | PASS | No new table-specific gotchas this session; systemic MCP-tool constraints live in the rule |

## Updates applied

- **Memory:** 6 new entries total (4 during session, 2 added in retrospective — `feedback_design_for_classes_not_instances`, `feedback_subagent_hot_reload_limit`)
- **Rules:** 1 new (`snowflake-mcp.md`), 3 modified (`sql-snowflake.md`, `analysis-methodology.md`, `guardrails.md`)
- **Commands:** 2 new (`/sql`, `/calibrate`), 4 modified (`/analyze`, `/preflight`, `/orient`, `/evolve`)
- **Knowledge:** 1 runbook (PSA), 1 ADR (Snowflake MCP governance), 5 seed query patterns, 2 calibration artifacts, 1 calibration template + index + CLAUDE.md
- **CLAUDE.md:** Root updated — added `/sql`, `/calibrate`, Snowflake architecture line, directory-map pointers for `query-patterns/` and `calibration/`
- **Agents:** 1 new (`warehouse-calibrator`)
- **Settings:** 1 permission added (`mcp__claude_ai_Snowflake__sql_exec_tool` in `settings.local.json`)

## Open design problems

1. **Four pending calibration artifacts** — `core.fct_sessions`, `core.dim_daily_kpis`, `marketing.stg_exposures`, `pc_stitch_db.mixpanel.export`. Blocked by subagent hot-reload limit. Action: invoke `/calibrate <schema.table>` for each in a fresh session. The first-touch rule in `snowflake-mcp.md` will block any MCP query against those tables until calibration is complete
2. **Subagent hot-reload limit** — structural Claude Code harness behavior; cannot be fixed in-repo. Documented as `feedback_subagent_hot_reload_limit.md`. Practical mitigation: plan subagent-backed capabilities in two sessions (build, then use)
3. **Rule-layer enforcement of Result Completeness has no hook backstop** — the rule depends on my discipline to run the truncation-notice / LIMIT-saturation / sanity-vs-first-touch checks. The user has precedent of Claude doubling down on wrong answers. If a future session produces a fabricated claim from a capped result, the escalation path is a PreToolUse hook on MCP calls — not a v1 choice (hooks are fragile per `feedback_dont_edit_live_hooks`), but the contingency

## Highest-leverage change

**The result-completeness rule and `/sql` post-execution check** — hands-down. This addresses a proven failure mode with a non-trivial blast radius: Claude producing fabricated stakeholder-facing numbers from capped query results and standing behind them under pushback. Everything else in the session (governance, calibration, query KB) is infrastructure that pays off over time; the completeness rule prevents a specific, known, already-observed category of wrong-answer incidents.

The PSA runbook is the complement — it distributes the same awareness to the non-technical users who consume Claude's answers without seeing the SQL, with three pattern-matchable tells they can flag to the data team.

## Handoff

Next session should:
1. Invoke `/calibrate` for the 4 pending high-touch tables (in any order — they're independent)
2. If any future `/sql` invocation against a non-calibrated table surfaces a new pattern of fan-out, wrong grain, or upstream drop, propose appending it to the target table's calibration artifact via `/evolve`
3. Treat the open design problem #3 (no hook backstop) as a tripwire — if the Result Completeness Check is skipped or bypassed in future sessions, escalate to hook-layer enforcement at that point
