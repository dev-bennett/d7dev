---
name: Writing Standards
paths: ["analysis/**", "knowledge/**", "evolution/**", "initiatives/**", "etl/tasks/**", "lookml/tasks/**", "**/README.md", "**/brief.md", "**/tracker.md", "**/checkpoint.md"]
---

# Stakeholder Writing Standards (§10)

See context/informational/agent_directives_v3.md for full directive details.

All stakeholder-facing prose must be in analyst mode: observations and evidence, not reactions or rhetoric.

**Stakeholder-facing scope.** Includes every artifact produced for a consumer other than the author — external destinations AND workspace-internal destinations where the operator (principal analyst) consumes agent-authored artifacts. Briefs, trackers, roadmap documents, epic plans, retrospectives, checkpoints, findings, and chat responses are all stakeholder-facing. "Internal" is not an exemption. See framework doc §1.5.

## Sentence Test

For each sentence ask: "Does this contain information, or a reaction to information?" If reaction, rewrite.

## Banned Phrases (never use in stakeholder output)

- "Not X -- but Y" (rhetorical contrast)
- "Surprisingly" / "Interestingly" / "Notably"
- "This reveals" / "This suggests" / "This indicates"
- "The key takeaway is"
- "It's worth noting" / "It bears mentioning"
- "Robust" as a vague intensifier

## Element Names — Verbatim from Source

When a stakeholder doc refers to a dashboard tile, Looker explore field, dbt model, ETL pipeline, or other named artifact, use the **verbatim title from the source file** — not an internal index, ordinal, or shorthand.

- Dashboard tiles → use the `title:` from the LookML file, character-for-character (including punctuation, casing, dashes).
- dbt models → use the model name as it appears in the `.sql` filename, not "the staging model" or "the new model."
- Fields/dimensions → use the LookML `label:` (or, if absent, the `name:`), not the analyst's mental shorthand.

**Why:** the stakeholder reads by the visible label. "Tile 12" forces them to mentally translate; "Subscription Expansion: 0-30 Days" matches what they see on screen. Internal indices have no business in stakeholder text when the verbatim source is one `grep` away.

**How to apply:** before delivering any stakeholder doc that references named artifacts, do a Verbatim Pass — `grep` the source for the canonical labels and replace any internal shorthand. If a label is awkward in prose, use it anyway. Don't "improve" the title.

## No Workflow-Seat Writing

Stakeholder docs read from the reader's seat, not from the analyst's workflow position.

**Banned (each is a sentence the reader cannot make sense of without my context):**

- References to your own work history: "the deleted chart," "the original version," "as initially proposed," "the prior approach."
- Process narration: "we tested whether...", "after stripping...", "the decomposition shows...". Replace with the finding directly: "Bot-stripped Direct CVR fell -56% YoY" (not "After stripping bots, we found Direct CVR fell -56%").
- Internal artifact labels: "M2 found...", "in the q03 query...", "per the calibration artifact...". Pull the finding into the doc; don't reference its container.
- References to separate prior analyses as "the documented X" / "per the prior analysis" / "post-cutover lower-intent traffic shift" / similar. The reader hasn't read your other docs. If a fact from a separate analysis is load-bearing, restate the fact in this doc with a one-line citation; don't write the doc as if it's a sequel.
- Unverified quality characterizations dressed up as established facts: "lower-intent SEO traffic," "loyal-customer churn," "high-intent buyer cohort." If you didn't run the analysis to verify the quality claim, don't assert it.
- Methodology asides that explain why a tile is computed the way it is unless the stakeholder asked.

**Why:** the reader doesn't know about the deleted chart, doesn't know what M2 is, doesn't have the calibration artifact open. Sentences requiring my context to read are noise to them.

**How to apply:** after drafting any stakeholder doc, scan each sentence and ask "could a stakeholder who hasn't seen any of my work read this?" If a sentence requires my workflow context, either rewrite it as the bare finding or delete it. The Sentence Audit (above) and the Verbatim Pass together cover this.

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

Applies to **any rendered output** — external platforms (Asana, Slack, email) AND markdown rendered by GitHub, IDE previews (PyCharm/VS Code), or a documentation viewer. The bare-`$` LaTeX/MathJax bug breaks all of them, not just external destinations.

- No bare `$` characters in prose or table cells. Escape with `\$` (works in markdown and most renderers) or drop the symbol and write the unit ("3.57M USD"). Three or more bare `$` on a line silently swallows whole spans of text into math blocks.
- No backtick-wrapped code unless the platform renders it
- No HTML entities or raw angle brackets
- When in doubt, use plain text

Run a quick `grep -n '\$' <file>` before delivering any markdown that contains currency amounts; any unescaped `$` is a bug.
