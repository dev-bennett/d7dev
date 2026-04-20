# Phase C — Ryan Feb-Shift Diagnostic

@../CLAUDE.md

Diagnostic queries for Ryan Severns' (Floodlight Growth, RevOps) 2026-04-15 question: avg lead score for free sign-ups was steady at ~0.5 Aug-Jan 2025 and jumped to ~0.65 in Feb 2026 onward. Did scoring logic change?

## Strategy — stratify across ambiguities

Two unknowns block a direct answer:

1. **Which score field?** 8 candidates live on HubSpot contacts:
   `hubspotscore`, `lead_score_2_0`, `hs_predictivecontactscore_v2`, `customer_health_score`, `new_member_health_score`, `ryan___lead_score_value`, `snowflake__lead_score` (Polytomic write-back), plus the bucket label `hs_predictivescoringtier`.
2. **Which "free account sign-ups" population?** Three plausible definitions:
   (a) HubSpot contacts with `lifecyclestage IN ('subscriber','lead')` and no `chargebee_customer_id`
   (b) Mixpanel `fct_sessions.SIGNED_UP=1` joined back to HubSpot
   (c) HubSpot contacts with `has_free_account = 'true'`

C-series queries compute monthly means across all candidate score fields × all cohort definitions. The field + cohort combination whose Aug-Jan mean ≈ 0.5 and Feb-Apr mean ≈ 0.65 is Ryan's slice — the data settles the ambiguity without asking him.

Once the slice is identified, C3-C7 decompose the shift: bucket-distribution shift, source-mix shift, per-source means, null-rate change, and Polytomic write-back timing. C8 audits the Feb 2026 dbt commits that likely changed the scoring population.

## Rate Declaration (§1)

```
RATE:        mean_lead_score_per_signup_cohort_month
NUMERATOR:   sum of [candidate_score_field] over contacts in [cohort_definition] with signup date in month M
DENOMINATOR: count of contacts in [cohort_definition] with signup date in month M where the score field is non-null
TYPE:        score / signup-cohort-count-with-score
NOT:         mean score over all contacts at measurement time — that confounds cohort composition with when the score was assigned
             (C7 separates signup-date cohort from score-assignment time for the Polytomic-written field).
```

## Files

- `queries.sql` — C1 through C7 (SQL)
- `C8-git-audit.sh` — shell script for dbt-submodule git-log review (C8 is not SQL)
- `cN.csv` — one CSV per query after running in Snowflake
- `FINDINGS.md` — written after CSVs return, with Type Audits, Null Hypothesis block, Adversarial Check, Intervention Classification, Writing Scrub, and a stakeholder-ready plain-text message block for the user to paste to Ryan
