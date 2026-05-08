# Session Retrospective — 2026-05-05

## Session summary

Asana ticket 1214517536022273 ("Catalog Genre Breakdown") — refresh of the September 22, 2025 catalog-by-genre snapshot for an enterprise sales prospect. Workflow: /orient → plan-mode scaffold of `analysis/enterprise/tasks/2026-05-05-catalog-genre-breakdown/` → xlsx import + decode → first build pass (wrong scope: full released catalog 30,860 incl. content-partner) → user correction on date interpretation and scope → second build pass (Soundstripe-original only, 11,320 songs) → 21-bucket grouping question investigated and surfaced honestly to user → handoff to user for the Asana reply → 4-commit backlog cleanup of accumulated uncommitted work → /evolve.

Final deliverable: `findings.md` + `q01_genre_breakdown.csv` (54 primary genres) + `q02_genre_x_vocal.csv` (genre × vocal-class cross-tab) + Sept-22 reference xlsx + 2026-05-05 deliverable xlsx.

## Friction points (classified)

| # | Friction | Class |
|---|---|---|
| F1 | Read "0922" as September 2022 instead of September 22, 2025. Built first deliverable with a "3.5 years" framing. | JUDGMENT |
| F2 | Ran queries against full released catalog (30,860 songs incl. content-partner) instead of Soundstripe-original (11,320). The README scaffold listed segmentation under "Open questions for kickoff" but I didn't enforce it as a gate before BUILD. | PROCESS |
| F3 | Framed the vd1/vd2 vs background/full mismatch as ambiguity in column labelling, when the real cause was the wrong scope filter. Rationalized the label question rather than unwinding to question scope. | JUDGMENT |
| F4 | After scaffolding, paused for user to kick off /preflight when auto-mode + "ready" was a clear go-signal. User: "are you going to do it? What are you waiting for". | COMMUNICATION |
| F5 | Staged `lookml/reference/` (embedded git worktree of LookML submodule) into commit 2; recovered with `git rm --cached -rf`. | EXECUTION |
| F6 | Stale already-staged empty `tracker.csv` at parent path triggered a path-not-found error during commit-1 staging. | EXECUTION |

## Patterns

- **P1 — Reference mismatch is a scope hypothesis, not a framing problem.** F1, F2, F3 are the same root failure: when a derived number doesn't match a known reference (Sept-22 baseline 11,500 vs my 30,860 = 2.7×), the load-bearing assumption (scope, filter, date) is the suspect, not the framing. `feedback_cross_check_stakeholder_benchmarks` (>2x gap = bug) was loaded into context at orient and was not applied. The 2.7× gap should have triggered a scope re-audit on the first query result; the date ambiguity ("0922" YYMM vs MMDD) should have been flagged when a 2.7× growth ratio over 3.5 years was implausible. Instead I rationalized the label-mapping anomaly as "vocal-degree ambiguity" — a downstream symptom of the scope error.
- **P2 — Scaffold "Open questions" are gates, not prompts.** F2. The README I wrote during scaffolding correctly identified the scope question, then I forgot to enforce it as a precondition for the BUILD pass. Open questions in a scaffold are load-bearing alignment checks (the §12 generalization), not iteration prompts.
- **P3 — Auto-mode + "ready" + clear next-step is a go-signal.** F4. Single-instance lesson; don't pause to confirm next step under auto-mode.

## Wins

- W1. Plan-mode scaffold structure mirrored the peer enterprise task workspace cleanly; user approved without revision.
- W2. xlsx decoded by unzipping and reading OOXML directly; no external Python dependency.
- W3. After scope correction, vocal-degree mapping resolved unambiguously (instrumental 73.83% / background 18.14% / full 8.03% vs Sept-22 73.55% / 18.08% / 8.37%). Scope correction confirmed as the single load-bearing fix.
- W4. As-of-2025-09-22 reconstruction (11,164 vs xlsx 11,500, within 3%) directly answered the 21-bucket-grouping question — it was a hand-rolled rollup, not a warehouse dimension; today's 54 distinct primary genres existed in 2025 too.
- W5. When the 21-bucket mapping couldn't be reverse-engineered from data alone, surfaced the limitation honestly with three explicit paths rather than guessing.
- W6. Four atomic commits along clean logical boundaries; embedded git-repo issue caught and unstaged before damage; submodule weirdness left alone rather than committed wrong.

## Audit checklist

```
[x]  1. CLAUDE.md chain — PASS. New workspace chains via @../../CLAUDE.md to root.
[x]  2. Stale docs — PASS. Orient briefing rewritten this session; root unchanged.
[x]  3. Memory freshness — FAIL→fixed. feedback_cross_check_stakeholder_benchmarks
       extended with BUILD-pass + filename-date guidance. New memory
       feedback_scaffold_open_questions_are_gates added. MEMORY.md index updated.
[x]  4. Rule coverage — FAIL→fixed. analysis-methodology.md §Stakeholder benchmark
       cross-check extended with BUILD-time application paragraph + 3 failure modes
       (scope/filter, filename-date, population definition). Other rules followed
       correctly (snowflake-mcp.md file-first preserved, sql-snowflake.md Type
       Audits inline, guardrails.md specific-path staging).
[x]  5. Command coverage — Mostly PASS. /preflight not invoked (would have surfaced
       scope gate); /calibrate not invoked for dim_all_songs_v2 first-touch (soft-warn
       tier — dim grain, simple aggregate); inline calibration was performed. New
       calibration artifact written this evolve. No new command warranted.
[x]  6. Knowledge gaps — FAIL→fixed. content.dim_all_songs_v2 calibration artifact
       written documenting Soundstripe-only filter + vocal_degree mapping.
[x]  7. Agent coverage — PASS. analyst / warehouse-calibrator both available;
       neither needed for this scope.
[x]  8. Orphaned files — PASS in workspace.
[x]  9. Task hygiene — PASS. README + findings status reflect "complete — handed
       off to user."
[x] 10. Open design problems —
       - lookml/reference/ is an embedded git worktree (gitdir → ../../.git/modules/
         context/lookml). Works locally; invisible to d7dev. Either document via
         .gitignore + runbook, or reinit properly. **Not committed this session.**
       - context/lookml/ shows ?? untracked despite being registered in .gitmodules.
         Submodule needs `git submodule update --init context/lookml` (deferred).
       - 21-bucket genre rollup mapping for the Asana ticket — left to user
         discretion (option 1: ship 54-genre detail / 2: build new 21-bucket
         rollup with explicit mapping / 3: ask Garrett for the original mapping).
[x] 11. Calibration artifact updates — content.dim_all_songs_v2 created (new
       artifact, schema_hash fc3bdd93, last_calibrated 2026-05-05); _index.md
       updated.
```

## Updates applied

| Type | Count | Files |
|---|---:|---|
| Rule edit | 1 | `.claude/rules/analysis-methodology.md` (Stakeholder benchmark cross-check — BUILD-time application paragraph) |
| Feedback memory (extended) | 1 | `feedback_cross_check_stakeholder_benchmarks.md` (BUILD-pass application + filename-date guidance) |
| Feedback memory (new) | 1 | `feedback_scaffold_open_questions_are_gates.md` |
| Calibration artifact (new) | 1 | `content__dim_all_songs_v2.md` (schema_hash fc3bdd93, Soundstripe-only filter + vocal_degree mapping) |
| Calibration index | 1 | `_index.md` (new row for content.dim_all_songs_v2) |
| MEMORY.md index | 1 | New scaffold-gates entry; updated cross-check entry |
| Retrospective | 1 | This file |

## Open design problems (carried forward)

1. **`lookml/reference/`** — local embedded git worktree of the LookML submodule, undocumented, untracked in d7dev. Either document the convention via `.gitignore` + runbook, or reinit properly via `git submodule add` / `git worktree add`. User decision.
2. **`context/lookml/` submodule uninitialized** in current worktree (registered in .gitmodules but missing from `git submodule status`). Single command to fix: `git submodule update --init context/lookml`. User discretion.
3. **21-bucket genre rollup for the Catalog Genre Breakdown deliverable** — left to user. Three options stated in `findings.md`: ship 54-genre detail / build new 21-bucket rollup / get Garrett's mapping.
4. **Continuing carry-forward from prior retros** (unchanged this session): Direct CVR mechanism diagnostic, Organic CVR mechanism diagnostic, Plan-mix classifier audit, Song Downloads tile title/denominator mismatch, +18% Y2 headlines pending Finance LTV anchor, $0-realized enterprise sub mystery, chart_03 ship-or-replace decision, transformations.chargebee_subscription_changes calibration follow-up, finance.subscription_ltv_assumptions structural append.

## Highest-leverage change

**Extending `feedback_cross_check_stakeholder_benchmarks.md` and `analysis-methodology.md` to apply the >2× gap rule at BUILD pass, with explicit failure-mode taxonomy (scope/filter, filename-date, population definition).** F1 + F2 + F3 — three of the six friction points and the entire rework cycle that took the deliverable through two builds — share this single root cause. The original cross-check rule existed and was loaded into context at orient time; failure was not applying it at the right pass. The extension makes the rule fire at the moment a row count is computable against a reference, before any chart/CSV gets built on top of a wrong scope. The new feedback memory `feedback_scaffold_open_questions_are_gates` is the complementary upstream defense: if the scope question is enforced as a gate, the wrong-scope query never runs.

The new calibration artifact for `content.dim_all_songs_v2` is second-highest leverage — captures the Soundstripe-only filter (`soundstripe_original_percentage = 100`, NOT `content_partner_id IS NULL`) and the vocal_degree 0/1/2 → instrumental/background/full mapping, both of which are non-obvious gotchas that future work on this table would otherwise re-derive.
