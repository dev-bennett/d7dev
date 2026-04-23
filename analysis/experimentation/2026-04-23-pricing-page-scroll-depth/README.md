# Pricing Page Scroll-Depth Banner Change — Post-Change Validation

**Status:** In Progress (Phase 0)
**Stakeholder:** Meredith Knott
**Request date:** 2026-04-23 (original due 2026-03-11, past)
**Ship date for change:** 2026-02-24
**Analyst:** Devon Bennett

## Request

> Change shipped: 2/24/26. Shrinking banner on Pricing Page to reduce scroll depth to get to the persona cards.
>
> Goals: Reduce page bounce rate. Increase clicks on Persona cards.

## Scope

Two stated goals plus persona-card funnel parity (Pricing → View Pricing → Persona → Plan → Subscribe). Pre-change baseline (Jan 7 – Feb 6) compared to post-2wk (Feb 24 – Mar 10) and post-8wk (Feb 24 – Apr 23).

## Deployment

Site-wide deploy on 2026-02-24. No Statsig or Fastly VCL experiment wrapper. Comparison is pre/post time-series only — no randomized control group.

## Deliverables

- `findings.md` — internal analyst record (full §1–§12 rigor)
- `message-to-meredith.md` — Slack-safe plain-text answer to Meredith
- `console.sql` — labeled single-SELECT query set; exports to `q<N>.csv`
- `diagnose/discovery.sql` — event-schema + daily-visitor discovery queries

## File layout

```
CLAUDE.md                                       # directory governance
README.md                                       # this file
stakeholder-request                             # Meredith's request (reference only)
product-analysis-not-from-data-team             # product team's pre-change analysis (reference only)
diagnose/
  CLAUDE.md
  discovery.sql                                 # D1–D5
  q<N>.csv                                      # discovery exports
console.sql                                     # Q1–Q7
q<N>.csv                                        # main query exports
findings.md
message-to-meredith.md
checkpoint.md
```

## Known risks

1. Event schema gap — "Clicked View Pricing" and "Selected Persona" are not in the event taxonomy; discovery must confirm them before the funnel can be reconstructed.
2. Site-wide comparison lacks a randomized control — seasonality and traffic-mix drift are confounders.
3. March contamination — Mar 5 – Mar 25 direct-traffic artifact sessions require filter correction.
4. April residual — 2026-04-17 OPEN spike means the Apr 13 – Apr 23 segment of the 8-week window carries uncertainty.
5. Product team's numbers may not reconcile exactly — gap is described, not asserted as product-team error.

## Plan

See `/Users/dev/.claude/plans/mossy-painting-pillow.md`.
