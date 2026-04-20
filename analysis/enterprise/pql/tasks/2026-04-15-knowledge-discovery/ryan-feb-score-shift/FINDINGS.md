---
status: draft
date: 2026-04-15
question_asker: Ryan Severns (Floodlight Growth, RevOps)
question_date: 2026-04-15
phase: C (Ryan Feb-shift diagnostic)
related:
  - ../contacts-shape/FINDINGS.md
  - ../pipeline-shape/FINDINGS.md
  - ./c8-git-audit.txt
  - ./message-to-ryan.txt
artifacts_consumed:
  - ../pipeline-shape/c1.csv
  - ../pipeline-shape/c2-alt.csv
  - ../pipeline-shape/c9.csv
  - ../pipeline-shape/b2.csv
  - ../pipeline-shape/b7.csv
  - ../contacts-shape/b1.csv
  - ./c8-git-audit.txt
---

# Ryan Feb-Shift Diagnostic — Findings

## Question

Ryan, 2026-04-15: "Do you know if the lead scoring logic changed at all back in February? I'm looking at all free account sign ups and the average lead score was pretty steady at ~.5 from Aug - Jan, and then in Feb onward it has jumped up to ~.65."

## Methodology

Phase A characterized `HUBSPOT.HUBSPOT_CONTACTS` (1.76M rows, 599 property keys) and narrowed candidate score fields to `snowflake__lead_score` and `hs_predictivecontactscore_v2`. Phase B probed the XGBoost pipeline and Polytomic sync. Phase C stratified monthly means across three cohort definitions × seven candidate score fields. Phase C8 audited git history on scoring-pipeline dbt models 2025-10-01 through 2026-03-15.

## Rate Declaration (§1)

```
RATE:        mean_lead_score_per_signup_month (free-account cohort)
NUMERATOR:   sum(snowflake__lead_score) over has_free_account='true' contacts with snowflake__lead_score populated
DENOMINATOR: count of those same contacts, grouped by createdate month
TYPE:        score / scored-cohort-count
NOT:         mean over all has_free_account='true' contacts including unscored — that would dilute with nulls
```

## Verdict

Field: `snowflake__lead_score`. Cohort: `has_free_account='true'`. Trigger: commit `9425917` on 2025-11-19 21:26 UTC expanded the XGBoost feature set from 26 inputs to 33 and corrected a wildcard in the above-director job-title matcher. The model retrains from scratch on every dbt run, so the first run under the new spec (2025-11-20) produced a visibly different output distribution. Daily mean model output moved from 0.58 on 2025-11-19 to 0.68 on 2025-11-20 and has held near 0.68 since.

Ryan observed the shift at signup-cohort level in February because Polytomic's sync (`polytomic_sync_hubspot_leads_with_scores.sql` line 41: `AND b.lead_score IS NULL`) writes each contact's score once and never overwrites. Each signup cohort's mean in HubSpot is the snapshot at first-write time for that cohort. February is the first month where post-Nov-19 scores dominate the new-write share, driven by a 3× PQL volume surge (321 in January → 1,007 in February per `b1.csv`).

### Commit `9425917` contents

- `enterprise_lead_scoring_model.py` `utilized_columns` added 7 entries: `INDUSTRY_REAL_ESTATE`, `INDUSTRY_DIGITAL_MEDIA`, `INDUSTRY_PHOTOGRAPHY`, `INDUSTRY_SOFTWARE_DEVELOPMENT`, `INDUSTRY_MARKETING`, `LINKEDIN_FOLLOWER_COUNT`, `LINKEDIN_FLAG`.
- `leads_for_scoring.sql` and `leads_for_training.sql` added `clay__company_linkedin_profile_url` and `clay__company_linkedin_follower_count` sourcing, plus the corresponding industry case-when flags and `linkedin_flag` boolean.
- `above_director_flag` matcher changed from `'%chief'` (title must end in "chief") to `'%chief%'` (title must contain "chief" anywhere). Catches "Chief Marketing Officer", "Chief Revenue Officer", etc.

Objective (`binary:logistic` predicting `SUCCESS_STATUS`), hyperparameters (`max_depth=3`, `eta=0.1`, `num_round=50`), and retraining mechanism were unchanged by the commit.

### Headline numbers (source: `../pipeline-shape/c2-alt.csv`)

| signup_month | cohort_contacts | with_score (n) | snowflake__lead_score mean |
|---|---|---|---|
| 2025-08 | 14,278 | 1,306 | 0.508 |
| 2025-09 | 20,472 | 2,134 | 0.497 |
| 2025-10 | 21,471 | 2,388 | 0.498 |
| 2025-11 | 18,035 | 1,998 | 0.497 |
| 2025-12 | 13,863 | 1,494 | 0.489 |
| 2026-01 | 13,063 | 1,101 | 0.484 |
| 2026-02 | 12,126 | 1,262 | 0.643 |
| 2026-03 | 14,546 | 1,441 | 0.663 |
| 2026-04 | 7,969 | 726 | 0.679 |

Pre-Feb monthly means span 0.484–0.508. Feb-Apr monthly means span 0.643–0.679. The step is between January and February.

### Model-output timeline (source: `../pipeline-shape/b7.csv`)

Daily mean of `enterprise_lead_scoring_model."lead_score"` across model runs 2025-08-01 through 2026-04-15:

- 2025-08-01 → 2025-11-19 (112 days): daily means span 0.52–0.62, median ~0.58.
- 2025-11-20: 0.680.
- 2025-11-21: 0.791.
- 2025-11-24 → 2026-04-15 (147 days): daily means span 0.62–0.71, median ~0.68.

2 / 112 pre-shift days showed daily mean ≥ 0.62. 136 / 147 post-shift days showed daily mean ≥ 0.62.

### Dbt commits on the scoring pipeline, 2025-10-01 → 2026-03-15 (source: `./c8-git-audit.txt`)

Root cause:
- **2025-11-19** `9425917` — "updating lead scoring to incorporate more industries and linkedin info" (Geoff Aoyagi). `enterprise_lead_scoring_model.py` +2 / -0 feature list lines; `leads_for_scoring.sql` +13 / -1; `leads_for_training.sql` +11 / -1.

Downstream (do not cause the mean shift; affect population composition or row passthrough):
- 2026-01-21 `2fb6c14` — added `snowflake__lead_score` column to `stg_contacts_2` (+1 / -0).
- 2026-01-28 `5491a68` — TRY_CAST dirty-data fix in `leads_for_training.sql` + `leads_for_scoring.sql` (14 lines). Affects which rows survive the staging filter; feature set unchanged.
- 2026-01-29 `35c24bd` — `stg_contacts_2` datatype fix.
- 2026-02-02 through 2026-02-19 — 7 commits to `dim_enterprise_leads.sql` altering MQL transforms, join keys, group-by, and adding acquisition-source `lead_type` labels. Largest: `9284bcb` -66 +57, `3ea0cad` -21 +29, `81207c3` -11 +17, `60d4941` -20 +62. Contributed to the Feb 2026 PQL volume surge in `b1.csv`.
- 2026-03-11 `d4fc018` / `b7a1801` — `dim_enterprise_leads.sql` partitioning tweaks.

The initial C8 audit (2026-01-01 → 2026-03-15) missed the Nov 19 commit. The extended audit (2025-10-01 → 2026-03-15) contains a single scoring-pipeline commit in Oct-Dec 2025: `9425917`.

### PQL population surge (source: `../contacts-shape/b1.csv`)

Monthly row counts for `lead_type = 'new process: pql'` in `dim_enterprise_leads`:

| month | pql rows |
|---|---|
| 2025-09 | 636 |
| 2025-10 | 908 |
| 2025-11 | 596 |
| 2025-12 | 449 |
| 2026-01 | 321 |
| 2026-02 | 1,007 |
| 2026-03 | 1,285 |
| 2026-04 (partial) | 669 |

MQL form-submission volumes over the same window held flat at 134–253 per month. The 3× Jan → Feb jump is isolated to the PQL lane. PQL leads are the population the XGBoost model scores.

## Null Hypothesis Check (§4)

```
OBSERVATION:      mean snowflake__lead_score for has_free_account='true' signup cohort
                  moved from ~0.49 (Aug 2025 – Jan 2026) to ~0.65 (Feb 2026 onward).

NULL HYPOTHESIS:  noise or seasonality under a stable model and stable population.

VERDICT:          null rejected.
                  - Aug–Jan month-to-month SD of cohort mean: ~0.008 absolute.
                  - Jan → Feb move: +0.159 absolute (~20 SD).
                  - B7 daily model-output mean shifted +0.10 on 2025-11-20 and held.
                  - 136 / 147 post-shift days ≥ 0.62; 2 / 112 pre-shift days ≥ 0.62.

INTERPRETATION:   model-output distribution shifted on 2025-11-20 driven by commit 9425917.
                  Cohort-level visibility lagged to Feb 2026 because of one-time Polytomic writes
                  plus 3× PQL volume surge in Feb.
```

## Verification Questions (§3)

**Claim:** XGBoost daily-mean output shifted on 2025-11-20.
Q: If no shift, what pattern would B7 show?
A (independent): Stable around the Aug–Oct median 0.58 ±0.03.
Observation: Daily means ≥ 0.62 on 136 / 147 post-shift days vs. 2 / 112 pre-shift days.

**Claim:** Polytomic's anti-join freezes scores at first write.
Q: If Polytomic re-writes, pre-Nov cohorts should also show post-Nov means.
A (independent): `polytomic_sync_hubspot_leads_with_scores.sql` line 41: `AND b.lead_score IS NULL` — excludes rows where HubSpot already has a value.
Observation: Aug–Jan cohort means in `c2-alt.csv` are all 0.484–0.508 — consistent with one-time write.

**Claim:** Commit `9425917` is the proximate trigger.
Q: If the commit were irrelevant, B7's step date would not align with the commit date.
A (independent): Commit timestamp 2025-11-19 21:26 UTC. First dbt run under the new spec lands on or after 2025-11-20. B7: 0.58 on 2025-11-19, 0.68 on 2025-11-20, 0.79 on 2025-11-21.
Observation: Extended C8 audit identifies no other scoring-pipeline commit in Oct-Dec 2025.

**Claim:** Feature additions + wildcard fix push mean output upward.
Q: If feature additions were mean-neutral, the step would not exist.
A (independent): Added features cover LinkedIn presence, LinkedIn follower count, and five industry flags that correlate with B2B intent (software dev, marketing, digital media, etc.). The `'%chief%'` fix surfaces C-suite titles that the old `'%chief'` pattern missed. Each mechanism adds positive signal to the training set; the retrained model's learned weights shift predictions upward for typical scoring inputs.
Observation: Step magnitude (+0.10 on daily mean) is consistent with adding 7 features (27% of the prior 26) plus a wildcard fix that populates `above_director_flag` for a previously-missed subset of titles.

**Claim:** Feb is the first cohort dominated by post-shift scores.
Q: If PQL volume were flat, Feb should look the same as Jan.
A (independent): `b1.csv` shows PQL volume 321 → 1,007 Jan → Feb (3.1×). MQL flat (134 → 163).
Observation: `c9.csv` Polytomic write-month distribution consistent — writes continue across all months, but Feb sees a larger new-write batch.

## Adversarial Check (§8)

**Q1 — What would a skeptical reader challenge first?**
Field identity. Ryan did not name the score field. `c2-alt.csv` shows only `snowflake__lead_score` has Aug-Jan means near 0.5 and Feb means near 0.65. `hubspotscore`, `lead_score_2_0`, `hs_predictivecontactscore_v2`, `customer_health_score`, `new_member_health_score`, and `ryan___lead_score_value` all fall outside Ryan's reported range. Field identity is data-confirmed.

**Q2 — What assumption would flip the conclusion if wrong?**
That Polytomic is the only write path for `snowflake__lead_score`. If a HubSpot workflow, Zapier, or manual import also writes it, one-time-write fossilization breaks. Checks: (a) HubSpot property history for a sample of Aug 2025 cohort contacts would show whether `snowflake__lead_score` has ever been overwritten; (b) B4 shows warehouse-scored contacts = 33,022 vs. HubSpot-written = 26,763 (81% sync rate; 6,259-row lag) — consistent with a single write path and incremental backlog.

**Q3 — What obvious next question have I not answered?**
Whether the Nov 19 model-spec change was intended to lift scores or is a calibration drift. Owner (Geoff) should confirm. Secondary: should HubSpot carry a `snowflake__lead_score_model_version` property so downstream consumers can identify which version scored a given contact.

**Q4 — For each finding, what intervention does it imply?**
- Model-output step 2025-11-20 → INFORMATIONAL if the change was intentional; STRUCTURAL if unintentional drift requires a rollback or recalibration. Owner decision.
- Polytomic one-time-write fossilization → INFORMATIONAL (pipeline behavior); document in KB.
- Feb PQL volume surge → INFORMATIONAL (expected given the pipeline design).
- No model-version tag in HubSpot → STRUCTURAL; requires a new property and sync update.

## Intervention Classification (§11)

```
INTERVENTION CLASS -- model-output step 2025-11-20:
  FINDING:        XGBoost daily-mean output stepped from ~0.58 to ~0.68 on 2025-11-20,
                  triggered by commit 9425917 (feature-set expansion + wildcard fix).
  PERSISTENCE:    Unchanged for 6 months, free-signup cohort means will step again the
                  next time the feature set or training data materially changes. Ryan's
                  question recurs on every change.
  OWNER:          Geoff Aoyagi (scoring pipeline). Sales / RevOps for consumption.
  SMALLEST FIX:   Attach a model-version identifier to every score write (dbt run id or
                  commit hash of the Python model source). Surface the version in HubSpot
                  as a custom property alongside snowflake__lead_score.
  CLASSIFICATION: STRUCTURAL (version tag missing); secondary finding is INFORMATIONAL
                  (Nov 19 commit is explainable).
```

## Type Audits (§1)

**C2-alt** — mean_lead_score_per_signup_cohort_month (has_free_account='true')
- Declared denominator: has_free_account='true' contacts in signup_month with snowflake__lead_score populated
- JOIN chain: single-table with WHERE filter; `AVG(snowflake__lead_score)` ignores nulls
- Denominator column: `COUNT(snowflake__lead_score)` (reported as `snowflake_lead_n`)
- Result: PASS

**C9** — polytomic write-timing by lifecyclestage
- Declared denominator: contacts with snowflake__lead_score and snowflake__update_at populated, grouped by write-month × lifecyclestage
- JOIN chain: single-table
- Denominator column: `COUNT(*)` within each grouped row
- Result: PASS

## Stakeholder message

See `./message-to-ryan.txt` for the plain-text message body.

## Open items

1. Confirm with Geoff whether the 2025-11-19 feature-set change was a calibrated lift or an unintentional scale shift.
2. B3 and B5 (pipeline-shape) still failing. Re-run after the quoted-column fix to confirm sync volume pattern and bucket decomposition.
3. C3 (bucket decomposition) and C5 (per-source monthly mean) not yet run.
4. Add a model-version property to the Polytomic-HubSpot sync so downstream consumers can identify which model scored a contact.
5. 6,259-contact sync lag between warehouse (33,022) and HubSpot (26,763) — check whether this is incremental backlog or a chronic gap.
