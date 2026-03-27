---
name: Writing Standards
paths: ["analysis/**", "knowledge/**"]
---

# Stakeholder Writing Standards (§10)

See context/informational/agent_directives_v3.md for full directive details.

All stakeholder-facing prose must be in analyst mode: observations and evidence, not reactions or rhetoric.

## Sentence Test

For each sentence ask: "Does this contain information, or a reaction to information?" If reaction, rewrite.

## Banned Phrases (never use in stakeholder output)

- "Not X -- but Y" (rhetorical contrast)
- "Surprisingly" / "Interestingly" / "Notably"
- "This reveals" / "This suggests" / "This indicates"
- "The key takeaway is"
- "It's worth noting" / "It bears mentioning"
- "Robust" as a vague intensifier

## Use Instead

- "[Metric] [moved] from [X] to [Y] over [period]."
- "[Metric A] declined [N]pp. [Metric B] declined [M]pp."
- "If [assumption], then [implication]. If not, [alternative]."

## Sentence Audit

Before delivering stakeholder text, produce:

```
SENTENCE AUDIT -- [section]:
[1] "[sentence]" -> [PASS: information / FAIL: reaction -- rewrite]
[2] ...
```

## Platform-Safe Formatting

When producing text for external platforms (Asana, Slack, email):
- No bare `$` characters (LaTeX/math reinterpretation)
- No backtick-wrapped code unless the platform renders it
- No HTML entities or raw angle brackets
- When in doubt, use plain text
