---
name: Analysis Methodology
paths: ["analysis/**"]
---

# Analytical Rigor Standards

See context/informational/agent_directives_v3.md for full directive details.

## Three-Pass Workflow (§7)

All analytical work follows three sequential passes. Do not interleave them.

1. **BUILD:** Write SQL, produce charts, assemble reports. Output only. No commentary, no interpretation.
2. **VERIFY:** Produce all verification artifacts -- Type Audits (§1), Contract Checklists (§2), Identity Checks (§5), Enumeration Checklists (§6), spot-check one row manually.
3. **INTERPRET:** Write analytical commentary with Null Hypothesis Blocks (§4), Verification Questions (§3), Adversarial Questions (§8), Intervention Classification (§11).

Pass 2 cannot be skipped. Pass 3 cannot begin until Pass 2 is complete.

## Claim Verification (§3)

For each interpretive claim: (1) state the claim, (2) formulate a verification question that could disprove it, (3) answer that question independently without looking at the original claim, (4) compare, (5) revise if they conflict.

**Absence Rule:** "No rows exist for X" is an observation. "X never happened" is a causal claim. Data absence has multiple explanations -- state what the data shows and flag that the cause is undetermined.

## Null Hypothesis Check (§4)

When interpreting cohort shifts, seasonal patterns, engagement decay, or correlated metrics:

```
NULL CHECK:
  OBSERVATION: [what the data shows]
  NULL HYPOTHESIS: [what this looks like if nothing unusual is happening]
  VERDICT: [null explains it / null does NOT explain it -- with numbers]
  INTERPRETATION: [framing consistent with verdict]
```

If null explains it, do not frame the pattern as alarming or notable.

## Algebraic Identity Detection (§5)

When 3+ related rate metrics are computed from the same data, check for A = B x C or weighted-average decompositions. Surface shift-share decompositions proactively.

## Definition-Use Case Alignment (§12)

When defining segments/cohorts that drive actions, verify temporal mechanic alignment:

```
ALIGNMENT CHECK -- [category]:
  INTERVENTION: [what action will this category trigger?]
  TEMPORAL MECHANIC OF INTERVENTION: [event-driven / state-driven / hybrid]
  TEMPORAL MECHANIC OF DEFINITION: [snapshot / event-based / rolling window]
  MATCH: [YES/NO]
  SIZING SANITY: [expected magnitude vs. query output]
```

Do not proceed to query authoring for any category that fails alignment.

## Investigatory Analysis (Signal Detection, Data Quality, Anomaly Investigation)

Investigatory work follows a modified sequence: context gathering precedes query authoring.

1. **CONTEXT:** Gather all available domain context BEFORE writing diagnostic SQL.
   - If the user states a suspected cause, investigate that cause first
   - Seek PRDs, deployment timelines, architecture docs, changelogs for the relevant system
   - Read the dbt model lineage (source → staging → marts) for any tables you'll query
   - Identify the fields available in the model before writing queries that reference them
2. **BUILD:** Write diagnostic queries directly to the working file (visitors.sql or equivalent). Do not show queries in chat for the user to copy.
3. **ITERATE:** After each query round, check the filesystem for result files before composing analysis. The user may export results faster than you respond.
4. **VERIFY/INTERPRET:** Same as the standard three-pass workflow -- verification artifacts, null hypothesis checks, claim verification.

Hypothesis discipline: let the data constrain hypotheses, but also let available context constrain them. If a known infrastructure change coincides with a data anomaly, the infrastructure change is the leading hypothesis until evidence contradicts it.

**Correction filter validation:** When building a filter to exclude contaminated data, validate against control periods before presenting results. If the corrected metric in the affected window is systematically higher or lower than both the pre-contamination and post-fix control periods, the filter is miscalibrated. Use all available prior query results to inform the filter — do not ignore dimensions (e.g., landing host, geo) that the data already exposed as relevant.

## Core Standards

- Every analysis must state: question, methodology, data sources, limitations
- Quantify uncertainty -- ranges, confidence intervals, sample sizes
- Distinguish correlation from causation explicitly
- Document assumptions and their sensitivity
- Reproducibility: include the SQL/query that produced each finding
- Timestamp all analyses; note data freshness
- Flag analyses as draft/reviewed/final
- Metric definitions must reference the canonical data dictionary
- When a finding contradicts prior knowledge, investigate before reporting
- Output format: use templates from analysis/_templates/
