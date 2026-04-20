# Session Retrospective — WCPM Pricing Test Audit

Date: 2026-04-18
Scope: WCPM pricing test audit from initial stakeholder inquiry through close-out, including findings doc and Slack message to Meredith.
Related artifact: `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md`

## Session summary

Stakeholder (Meredith) reported a discrepancy between Mixpanel's 27 WCPM add-on purchasers and Statsig's 12 in the `wcpm_pricing_test` pulse. The audit reconciled the gap exactly via q0–q18, closing on this decomposition:

- 27 − 4 − 1 − 8 − 2 = 12
- −4: Mixpanel weekly-bucket UI backfilling pre-experiment days into the first weekly row
- −1: fct_events row orphaned at the Statsig model's incremental watermark
- −8: users whose paths to WCPM purchase don't hit the experiment's exposure trigger
- −2: users assigned to the test after they had already purchased

Per-arm in the pulse matched exactly: Control 2 (1 existing + 1 new), Mid Reduction 8 (3 + 5), Deep Reduction 2 (0 + 2). A structural issue in the `statsig_clickstream_events_etl_output` dbt model was surfaced (late-arrival drop) and tracked as open work.

## Friction points

| # | Friction | Classification |
|---|---|---|
| 1 | Over-scoped initial discovery (grepped dbt wide when task folder was given) | JUDGMENT |
| 2 | Fabricated `current_plan_id` as Meredith's filter column | JUDGMENT |
| 3 | Over-claimed Existing/New label inversion as STRUCTURAL bug | JUDGMENT |
| 4 | Didn't thoroughly search dbt submodule for Statsig exposure source | PROCESS |
| 5 | Didn't check LookML submodule in parallel | PROCESS |
| 6 | Treated "not in dbt" as "no exposure table exists" — missed discovery-query reflex | JUDGMENT |
| 7 | Colliding CSV labels for multi-statement q8 (existing memory already covers this) | EXECUTION |
| 8 | Missed lowercase-table double-quoting until told | EXECUTION |
| 9 | Retracted a correct claim under pushback; had to reverse the reversal | JUDGMENT |
| 10 | "Worth a row-level spot check" hedge instead of running the diagnostic | COMMUNICATION |
| 11 | findings.md left stale across 5+ sections after q17/q18 landed | PROCESS |
| 12 | Fabricated stakeholder use case ("pricing call") in Slack draft | COMMUNICATION |
| 13 | Claimed "working as designed" without seeing the design | COMMUNICATION |

## Patterns

**A: Over-claiming from weak evidence** (friction 2, 3, 12, 13). The same mistake took four different shapes — inventing a column name, asserting a label inversion, inventing a use case, and claiming intent-compliance. Pattern is: jumping from a plausible interpretation to an assertive claim without ground-truth confirmation. Addressed by new `feedback_no_overclaim_from_code_reads.md`.

**B: Under-searching before concluding absence** (friction 4, 5, 6). `feedback_exhaust_search_before_concluding.md` already existed but only covered record-level searches. Extended with an addendum for table/object searches that requires full-submodule search plus `information_schema` warehouse discovery.

**C: Piecemeal edits without end-to-end audit** (friction 11). After the q17/q18 evidence restructured Finding 4 from "maybe worth a check" to a STRUCTURAL finding, findings.md's headline, observed-numbers table, awareness items, adversarial check, recommended actions, and retractions all needed updates. Caught by user ("did you check if the whole document was up to date?"). Not memory-captured yet — covered by existing `feedback_session_retrospective.md`.

**D: Length and hedging creep in stakeholder output** (friction 10, 12, 13). Already extended `feedback_communication_style.md` mid-session with three new banned patterns: don't invent stakeholder use cases, don't claim "working as designed" without the design, don't add unrequested offers.

**E: Reflexive capitulation under pushback** (friction 9). Specifically distinct from the other patterns because the correction was wrong (typo) and my original claim was correct. Addressed by new `feedback_hold_correct_claims_under_pushback.md`.

## Wins

- Finding 4 evidence chain (q17 → q18a/b/c/d) is a clean end-to-end audit. Once the user pushed me to stop hedging, the diagnostic produced a specific distinct_id, a specific PK, a specific timing window, and a specific mechanism — all verifiable from the exports.
- Reconciliation math is exact (27 − 4 − 1 − 8 − 2 = 12) with per-arm match to the pulse CSV.
- Once told about per-query-per-csv labels, lowercase-identifier quoting, and `unit_id` vs `stable_id` column mapping, applied them consistently for the rest of the session.
- `context/lookml/views/Statsig/exposures.view.lkml` was identified immediately on the prompt to search LookML — good second instinct once the first was corrected.

## Audit checklist

```
[PASS]    1. CLAUDE.md chain — task dir has CLAUDE.md with @../CLAUDE.md; chain walkable to root
[PASS]    2. Stale docs — findings.md fully audited and updated end-to-end; task-dir CLAUDE.md status updated to Complete
[ACTION]  3. Memory freshness — +project_statsig_model_late_arrival_open, +feedback_no_overclaim_from_code_reads, +feedback_hold_correct_claims_under_pushback; extended feedback_exhaust_search_before_concluding (+submodule addendum), feedback_verify_before_writing (+column-from-values addendum), feedback_communication_style (+three banned patterns, mid-session)
[PASS]    4. Rule coverage — existing rules cover the violated patterns; no new rules needed
[ACTION]  5. Command coverage — /preflight not invoked despite task matching "Investigatory analysis" routing row. Session-gate hook's preflight nudge fires at 3+ managed writes but did not cause me to invoke /preflight. Not changing the hook this session (feedback_dont_edit_live_hooks); logging as a behavior miss
[ACTION]  6. Knowledge gaps — Statsig architecture undocumented (exposures vs first_exposures_* vs statsig_clickstream_events_etl_output); Mixpanel weekly-bucket backfill behavior undocumented. Deferred — not written this retro, flagging as follow-up
[PASS]    7. Agent coverage — analyst work; interactive mode appropriate given rapid stakeholder turnaround
[ACTION]  8. Orphaned files — q15/q16 in console.sql marked OBSOLETE with deprecation comment
[PASS]    9. Task hygiene — task-dir CLAUDE.md status updated to Complete
[FLAG]   10. Open design problems —
            a) Statsig late-arrival drop (STRUCTURAL, tracked in project_statsig_model_late_arrival_open.md)
            b) WCPM test trigger coverage on purchase path (design question, owner unknown)
            c) XmR signal annotation/reference table (carried over from prior retros)
```

## Updates applied

- Memory: +3 new (`project_statsig_model_late_arrival_open`, `feedback_no_overclaim_from_code_reads`, `feedback_hold_correct_claims_under_pushback`); edits to `feedback_exhaust_search_before_concluding`, `feedback_verify_before_writing`, `feedback_communication_style`
- MEMORY.md: +3 index entries
- Rules: 0 (existing rules cover the violated patterns)
- Commands: 0
- Knowledge: 0 (Statsig architecture article deferred — noted as a follow-up)
- CLAUDE.md: task-dir status updated to Complete
- Cleanup: q15/q16 in console.sql marked obsolete with deprecation comment
- Task status: Complete

## Open design problems (carried forward)

1. **Statsig clickstream model late-arrival drop (STRUCTURAL).** Incremental predicate `event_ts::date >= max(event_ts)::date` silently excludes late-arriving fct_events rows. Repo-wide impact on any metric in the model. Smallest fix: widen to a lookback window (`dateadd(day, -N, max(...))`). Requires a dbt PR and a full-refresh or scoped backfill. Tracked in `project_statsig_model_late_arrival_open.md`.
2. **WCPM test trigger coverage on purchase path.** 8 of 23 add-on purchasers never hit the test's exposure trigger; 2 hit it after purchasing. Pattern suggests the trigger isn't on the WCPM checkout path itself. Whether this matches test intent is unknown — needs a conversation with whoever wired the test. Not a bug; design question.
3. **XmR signal annotation/reference table** — carried over from prior retros per `project_xmr_open_design.md`. Unchanged.

## Highest-leverage change

`feedback_no_overclaim_from_code_reads.md`. Four separate friction points in one session (2, 3, 12, 13) were the same mistake in different costumes: asserting intent from code or plausibility without confirming with the owner. Each one required a retraction, each retraction ate a round-trip, and at least one (the label-inversion claim) came close to being written into findings as a STRUCTURAL bug that would have sent the team off on a wrong-direction fix. A single memory capturing the general rule — describe mechanical behavior, ask about intent, never assert — should prevent the repeat.
