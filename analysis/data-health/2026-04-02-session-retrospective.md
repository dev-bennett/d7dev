# Session Retrospective: 2026-04-02

- **Date:** 2026-04-02
- **Author:** d7admin
- **Scope:** Event tracking capture, in-app notifications dbt pipeline, Stitch replication fix, LookML dashboard build, repo restructuring

## Session Summary

Built a complete end-to-end reporting pipeline for in-app notifications: browser event capture → dbt staging/transforms/marts → Stitch replication fix → LookML dashboard. Also established the tracking domain in knowledge/, created an event capture runbook, connected the LookML repo as a submodule, and restructured the lookml/ workspace for scalability.

## Friction Points

### PROCESS (workflow/sequencing errors)

1. **Browser connector rabbit hole.** Spent multiple rounds trying to set up Chrome extension MCP, guessing package names, before pivoting to the manual JS interception approach that worked immediately. Should have assessed feasibility faster and gone to the fallback.

2. **Queries in chat instead of files.** Initially showed JS snippets and SQL in chat for user to copy-paste. User corrected this -- all queries should be written to files. Repeated this pattern multiple times before it stuck.

3. **No subdirectory per query set.** Wrote multiple query files to the same `baseline/` directory with overlapping `--qa/--qb` labels, causing CSV export overwrites. User had to clean up. Should have created a new subdirectory for each distinct query set from the start.

4. **Baseline queries against source, not reporting layer.** After the Stitch fix, ran verification queries against `pc_stitch_db.soundstripe.user_notifications` (source) instead of `soundstripe_prod.marketing.fct_notification_deliveries` (the actual reporting table). User caught this -- the whole point was to validate the downstream dataset.

5. **dbt Cloud dev vs prod.** Told user to run `dbt run --full-refresh` repeatedly, not realizing the dbt Cloud dev console targets `soundstripe_dev`, not `soundstripe_prod`. Wasted significant time before discovering the target database mismatch. Should have asked "what database does your dbt environment target?" upfront.

6. **LookML promotion workflow.** Initially planned to copy files directly into `context/lookml/` (the submodule). User corrected: the workflow is to prepare in `lookml/` workspace and manually implement in Looker IDE. Should have understood the air-gap from the start.

7. **lookml/ workspace not structured for scale.** Dumped draft files, promotion guides, commit messages, and screenshots at the top level of lookml/. User called this out as anti-scalable after just one task. Should have followed the ETL task directory pattern from the beginning.

### JUDGMENT (wrong hypothesis/framing)

8. **Proposed new `marts/notifications/` directory.** Should have checked existing mart directories first. `marts/marketing/` already existed and was the correct home. Assumed the domain warranted its own namespace without verifying.

9. **Schema tests contradicting join semantics.** Wrote a `relationships` test on `cms_entry_id` (fact → dim) despite the fact table using a LEFT JOIN that intentionally allows NULL matches. Also wrote `accepted_values` on `notification_type` without confirming the full value set. Both caused dbt errors on promotion.

10. **Snowflake result caching theory.** When the fact table wasn't updating, proposed Snowflake result cache as the cause and added a `pre_hook` to disable it. This was wrong -- the actual cause was dbt targeting the wrong database. Wasted a round on a false hypothesis.

11. **LookML `from:` vs `view_name:`.** Used `from: fct_notification_deliveries` in the explore, which aliases field references to the explore name. Caused 5 Looker validation errors. Should have used `view_name:` to preserve original field references.

### EXECUTION (mechanics errors)

12. **Dashboard file extension.** Used `.dashboard.lkml` instead of `.dashboard.lookml`. The repo convention was discoverable from the existing dashboard file.

13. **Wrong schema reference in staging view.** Wrote `soundstripe_prod.soundstripe.stg_user_notifications` instead of `soundstripe_prod.staging.stg_user_notifications`. User had to correct the schema name.

14. **JS snippet too complex for paste.** Initial event interceptor was a single minified block that caused syntax errors when pasted into DevTools. Had to break it into 3 separate paste blocks.

15. **Source file not provided as complete replacement.** Gave user a fragment showing 6 new table names to add to `src_soundstripe.yml` instead of providing the complete file with tables in alphabetical order. User called this out -- they shouldn't have to manually find insertion points.

### COMMUNICATION

16. **Premature "what's next?" prompts.** After completing the staging layer, said "ready for you to review or tell me what's next" instead of proactively recognizing that transforms and a reporting dataset were obviously the next step. User corrected: "should you be telling me that?"

17. **Providing commands for user to copy-paste from chat.** Multiple instances of showing SQL or shell commands in chat instead of writing them to files. The user's workflow is: open file in IDE, run from there.

## Wins

1. **Stitch replication key diagnosis.** Correctly identified that `id` as replication key = append-only, missing all `read_at` updates. The diagnostic query set was well-structured and each query narrowed the hypothesis.

2. **Event capture workflow.** The JS interceptor approach (once simplified) worked cleanly. The runbook is reusable.

3. **Three-tier dbt pipeline design.** Staging → intermediate (EAV pivot) → dim + fact was the right architecture. The EAV pivot via conditional aggregation was clean.

4. **Post-fix baseline methodology.** Running the full exploration query set against the reporting layer after the fix gave clear before/after comparison.

5. **LookML dashboard structure.** The 9-tile layout with scorecards → time series → breakdowns → detail table is a solid pattern. Dashboard QA passed on first render.

6. **Decision record for Stitch fix.** `knowledge/decisions/2026-04-02-user-notifications-stitch-replication-key.md` captures the full context, evidence, and action plan.

## Patterns

### Pattern 1: "Build first, verify placement later"
Friction points 8, 12, 13, 15 all stem from writing code before fully understanding where it goes and how it fits into existing structures.
**Root cause:** Not reading the target directory/file/repo before writing.
**Fix:** Read the target before writing anything. For dbt: `ls` the marts directory. For LookML: read the existing dashboard file extension. For sources: read the existing yml file.

### Pattern 2: "Assume the user's environment"
Friction points 5, 6, 10 stem from assuming how the user's toolchain works (dbt Cloud targets prod, Looker repo accepts direct git pushes, Snowflake caching is the issue).
**Root cause:** Not asking about the user's environment when debugging infrastructure issues.
**Fix:** When something isn't working as expected in the user's environment, ask about the environment first (target database, role, permissions, deployment path).

### Pattern 3: "Chat output instead of file output"
Friction points 2, 14, 15, 17 are all variants of showing things in chat that should be files.
**Root cause:** Defaulting to conversational output instead of file-based deliverables.
**Fix:** Everything the user will execute, reference, or paste goes in a file. Chat is for status updates and decisions only.
