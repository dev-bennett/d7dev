# Session Retrospective — 2026-05-06 → 2026-05-07

## Session summary

Long, multi-task session covering four major workstreams:

1. **Danielle's Snowflake-rules PR review** ([cx-ai-ops#6](https://github.com/SoundstripeEngineering/cx-ai-ops/pull/6)) — reviewed her adapted rules, surfaced the `HUBSPOT_PLATFORM_DATA` database (which her PR claimed didn't exist), provisioned `IMPORTED PRIVILEGES` to `SELECT_ANALYST`, drafted approve-with-edits review.
2. **Enterprise reporting variance reconciliation** (`analysis/adhoc/2026-05-05-enterprise-reporting-comparison/`) — closed the 5-variance investigation, generated `looker_only_pql_contacts_20260506.csv` (652 rows) and `looker_only_pql_deals_20260506.csv` (19 rows) for Ryan/Dave's PQL deep-dive.
3. **MQL discrepancy fix follow-up** (`etl/tasks/2026-04-07-mql-discrepancy-fix/`) — refreshed the workspace, deployed the follow-up coverage fixes, hit two deployment incidents (broken backfill_from Jinja, then over-broad `enterprise_schedule_demo` expansion), reverted Change 1A, redeployed.
4. **Engineering follow-ups workspace** (`etl/tasks/2026-05-06-enterprise-reporting-fixes/`) — stood up a new task workspace for the two remaining variance fixes (free-email filter on `dim_mql_mapping`; Stitch→HPD source swap on `stg_deals`).

## Friction points

| # | Incident | Classification | Cost |
|---|---|---|---|
| 1 | Drafted Danielle's review body in `/tmp/` | PROCESS / JUDGMENT | Devon corrected, file moved to proper task dir |
| 2 | Drafted per-object GRANTs on imported share `HUBSPOT_PLATFORM_DATA` (rejected by Snowflake; only `IMPORTED PRIVILEGES ON DATABASE` works) | EXECUTION | Two error-and-retry round trips before Devon got it through |
| 3 | Inserted `q15` mid-file in `console.sql` ahead of `q14` (out of numerical order) — Devon flagged as recurring pattern | EXECUTION | One reorder pass |
| 4 | First q17 used loose filter (`any_associated_hs_is_pql='1'`) instead of mirroring q08's strict filter — returned 1 deal instead of 19 | JUDGMENT | Had to re-run with apples-to-apples logic |
| 5 | Claimed "HubSpot moved 13→10" when the 10 was deal-grain and q08 is contact-grain (q08 was actually unchanged at 13) | EXECUTION / COMMUNICATION | Devon: "did you do this?" — required re-running q02/q08 to verify |
| 6 | Initially called Ryan's "27−13=14" framing "unverified arithmetic" — that was the stakeholder's stated tile-comparison gap, not my inference to dismiss | COMMUNICATION | Devon corrected; reframing required |
| 7 | `backfill_from` Jinja drafted with literal-coalesced-into-aggregate-subquery pattern — compiled to `select <literal> from {{ this }}` returning N rows. dbt errored with "Single-row subquery returns more than one row" | EXECUTION | Multi-hour `fct_sessions_build` rebuild wasted; required deploying the fix and re-running |
| 8 | Preserved 2026-04-07 draft Change 1A (adding `Clicked Contact Sales` / `Enterprise Intent` to `enterprise_schedule_demo`) without validating event volumes. Deployed → inflated Looker `mqls_schedule_demo` 49× because the new signal is 1,997 events / 1,567 distinct_ids vs. 36/32 for the existing signal, and the consuming Looker measure has no HubSpot anchor | PROCESS / JUDGMENT | Multi-hour DELETE + rebuild to revert |
| 9 | After reverting Change 1A, updated model + implementation-guide + README but forgot `commit-message.txt` and `pr-description.md`. Devon caught: "did you update my commit and pr description?" | PROCESS | One additional edit pass |

## Patterns

**A. Failure to validate stale plans before recommending action.** Incidents #2 (HPD = imported share, signals were in the data I had), #8 (preserved the 1-month-old Change 1A draft without re-checking event-volume assumptions). When refreshing or preserving an older plan, I treat it as authoritative without re-verifying core assumptions. The blast radius scales with how long the plan has been sitting — a month-old plan needs the same verification as a fresh one.

**B. Sloppy claim-verification under pace pressure.** Incidents #5 (the "13→10" inference presented as fact), #6 (dismissive "unverified arithmetic" framing without re-reading findings.md). Under pace pressure I substituted inference for verification and presented inferences as facts. Devon had to push back twice in the same hour.

**C. Incomplete edit passes when scope shifts.** Incidents #3 (q15 placed without considering existing ordering), #9 (revert touching only some of the companion artifacts). When making a non-trivial change, I edit the obvious file and miss the satellite docs that are part of the same artifact bundle.

**D. Placement / routing discipline.** Incident #1 (`/tmp/`), incident #8 (signal in `fct_sessions_build` instead of `dim_mql_mapping`). Both are routing-discipline failures — putting an artifact in the wrong place even when the artifact itself is fine.

## Wins

- **Quickly diagnosed and quantified the Change 1A regression** (event-volume query within minutes of the report; 49× ratio surfaced clearly).
- **HUBSPOT_PLATFORM_DATA discovery for Danielle** — identified a substantial database she didn't have visibility on; provisioned access correctly on second try.
- **Variance 2 grain analysis (q17 corrected)** — apples-to-apples deal-grain filter mirroring q08 produced the right answer; the 27 vs 13 vs 19 vs 14 reconciliation table was clear.
- **Workspace structure for `etl/tasks/2026-05-06-enterprise-reporting-fixes/`** — sub-task-per-fix layout with notes.md flagging the `stg_deals_event_log` downstream migration honestly rather than papering over it.
- **Memory writing cadence** — five new memories captured during the session (imported-database-grants, query-label-ordering, backfill_from-canonical, event-volume-validation, complete-edit-pass).

## Audit checklist

```
[✓] 1. CLAUDE.md chain — PASS
[✓] 2. Stale docs — PASS (post-update)
[✓] 3. Memory freshness — PASS (5 new memories indexed in MEMORY.md)
[✓] 4. Rule coverage — UPDATED: dbt-standards.md gained backfill_from canonical pattern + event-volume-validation rule
[✓] 5. Command coverage — PASS (no new commands warranted)
[~] 6. Knowledge gaps — ACTION DEFERRED: HUBSPOT_PLATFORM_DATA tables (object_properties, list_memberships, objects_deals, associations_deals_to_companies) lack calibration artifacts despite heavy session use. Open candidate for /calibrate later
[✓] 7. Agent coverage — PASS
[✓] 8. Orphaned files — PASS (/tmp/danielle-pr6-review removed earlier in session)
[✓] 9. Task hygiene — PASS (mql-discrepancy-fix conditionally complete pending Devon verification; enterprise-reporting-comparison closed; enterprise-reporting-fixes ready)
[ ] 10. Open design problems — see below
```

## Updates applied

| Type | Count | Files |
|---|---:|---|
| Memory | 5 (during session) + 1 (this retro) | `feedback_imported_database_grants.md`, `feedback_query_label_ordering.md`, `feedback_backfill_from_canonical_pattern.md`, `feedback_validate_event_volume_before_field_expansion.md`, `feedback_complete_edit_pass_when_reverting.md` |
| MEMORY.md index | 5 entries added | (matching the 5 above) |
| Rule | 1 file updated | `.claude/rules/dbt-standards.md` (canonical backfill_from pattern + event-volume-validation rule) |
| Calibration | 1 artifact + index | `core__fct_sessions.md` pitfall #9 added (mqls_schedule_demo lacks HubSpot anchor); `_index.md` last-calibrated bumped 2026-04-24 → 2026-05-07 |
| CLAUDE.md (subdirectory) | 5 created | enterprise-reporting-fixes (root + 2 sub), enterprise-reporting-comparison (status updated), mql-discrepancy-fix (status updated) |
| Knowledge runbook | 0 | (no runbook-worthy new procedure emerged) |
| Cleanup | 1 dir | `/tmp/danielle-pr6-review/` removed in-session |

## Open design problems

1. **MQL fix pending Devon verification (2026-05-08).** Final state should show `mqls_schedule_demo` returned to ~30 distinct sessions YTD-2026 (matching pre-incident `Clicked Element` / `Enterprise Contact Form` volume) and the `MQLs (Mixpanel) - Source` chart's schedule_demo bucket back to a small slice. If Devon's morning check shows otherwise, task re-opens.
2. **HUBSPOT_PLATFORM_DATA calibration artifacts deferred.** Heavy session use of `object_properties`, `list_memberships`, `objects_deals`, `associations_deals_to_companies` without calibration artifacts. Recommend `/calibrate` for at least `object_properties` and `objects_deals` as those will be touched again by `etl/tasks/2026-05-06-enterprise-reporting-fixes/fix2_deals_source_swap_to_hpd/`. Not blocking, but the next deployment of fix2 should not be the first time these tables get a calibration first-touch decision.
3. **`stg_deals_event_log.sql` rewrite scoping** (in fix2 workspace). Documented in fix2's notes.md as part of the same PR but not yet drafted. When Devon picks up fix2, drafting the rewritten model file would reduce surprise.

## Highest-leverage change

**The event-volume-validation rule added to `dbt-standards.md`** is the single highest-leverage change. Incident #8 cost the most time (multi-hour rebuild × 2 — once to deploy, once to revert), and the failure mode (preserving an old draft without re-checking event volumes) is one I'm structurally prone to when refreshing stale task workspaces. The new rule turns "validate event volume before expanding a `sum(case when ...)` aggregation that feeds a Looker measure with no HubSpot anchoring" into a concrete, testable BUILD-pass check rather than a habit I have to remember.
