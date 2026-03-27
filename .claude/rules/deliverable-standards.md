---
name: Deliverable Standards
paths: ["analysis/**"]
---

# Deliverable & Verification Standards (§2, §8)

See context/informational/agent_directives_v3.md for full directive details.

## Deliverable Contracts (§2)

Before building any output (report, chart set, query file):

```
CONTRACT -- [deliverable name]:
PRECONDITIONS:
  - [what must be true before building starts]
POSTCONDITIONS:
  - [what must be true when complete]
  - [every section/component by name]
INVARIANTS:
  - [what must remain true across all versions]
```

For parallel versions: INVARIANTS define what must be identical. Use §6 enumeration to verify parity. Build from the contract's section list, not from memory.

## Adversarial Self-Questions (§8)

Before delivering any analysis or report, answer in writing:

```
ADVERSARIAL CHECK:
Q1 -- What would a skeptical reader challenge first?
A1: [answer]. Addressed in output: [yes/no]

Q2 -- What assumption, if wrong, would flip the conclusion?
A2: [the assumption and what would change]

Q3 -- What obvious next question have I not answered?
A3: [question]. Can answer with available data: [yes -> answer / no -> flag]

Q4 -- For each finding, what intervention does it imply?
A4: [finding -> intervention type per §11]. Mismatches: [list or NONE]
```

Q4 bridges to §11 Intervention Classification. If Q4 identifies a finding framed as informational that implies structural intervention, escalate before delivery.

## Intervention Classification (§11)

For each material finding:

```
INTERVENTION CLASS -- [finding]:
  FINDING: [one-sentence summary]
  PERSISTENCE TEST: If unchanged for 6 months, what is the business consequence?
  OWNER TEST: Whose decision changes this?
  SMALLEST FIX: What eliminates this from the next report?
  CLASSIFICATION: [INFORMATIONAL / OPERATIONAL / STRUCTURAL]
```

- **INFORMATIONAL:** Expected behavior, no action needed
- **OPERATIONAL:** Action within existing capabilities
- **STRUCTURAL:** Missing capability -- requires building something new

Do not deliver reports containing STRUCTURAL findings framed as INFORMATIONAL.
