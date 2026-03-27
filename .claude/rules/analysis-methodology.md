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
