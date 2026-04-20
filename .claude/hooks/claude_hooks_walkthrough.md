# Claude Code Hooks — d7dev

A practical walkthrough of the hook system we've built in the d7dev analytical workspace: what hooks are, why they matter, and how they quietly improve the quality of work Claude Code ships.

Written for a mixed audience — technical engineers who may want to steal the pattern, and non-technical readers who want to understand why this matters for a team using AI-assisted work.

---

## 1. What is a "hook"?

A hook is a small script that Claude Code runs automatically at specific moments — when a session starts, when the user sends a message, before a file is edited, before a shell command runs, when the session ends. Hooks receive structured information about what's about to happen and can either pass silently, warn, or block the action.

**Analogy:** hooks are the seatbelts, lane-departure chimes, and backup-camera of AI-assisted work. The driver still does the driving; the car just makes certain mistakes harder and gives you an instrument panel to see what's happening.

**Why this matters more than "just tell Claude the rules":** rules in a prompt are advisory — Claude can forget or drift. Hooks are enforced by the harness, so they apply consistently regardless of whether the model is having a good day. They are the difference between "we agreed to do X" and "X is mechanically checked."

---

## 2. Why d7dev uses hooks

The d7dev workspace is an analytical command center: SQL queries for Snowflake, LookML for Looker, dbt models, and analysis outputs for stakeholders. Three failure modes drove us toward hooks:

1. **Rework loops.** The model would edit the same file 8, 10, 12 times trying the same fix. A hook counts edits and interrupts: "step back, this is a loop."
2. **Workflow discipline.** We require `/preflight` before scoped work and `/review` before commits. Hooks nudge when those are skipped.
3. **Stakeholder polish.** Our writing standards ban rhetorical phrases ("Surprisingly...", "This reveals...", vague intensifiers). A hook scans markdown edits for banned phrases before they land.

The hooks don't replace human judgment. They raise the cost of skipping the judgment we already agreed matters.

---

## 3. The hook inventory

| Hook | When it fires | What it checks | Blocking? |
|------|---------------|----------------|-----------|
| `health-check.sh` | Session start | Reports hook errors from prior sessions | Warn |
| `prompt-context.sh` | Every user prompt | Injects today's date, checkpoint age, memory staleness | Pass (injects context) |
| `session-gate.sh` | Before file write/edit | Every managed directory must have a `CLAUDE.md`; nudge `/preflight` after 3 writes | Block / warn |
| `retry-guard.sh` | Before file write/edit | Detects retry loops via content-hash fingerprint | Warn @ 5, block @ 8 |
| `writing-scrub.sh` | Before markdown write/edit | Scans for banned §10 phrases in stakeholder-facing prose | Warn |
| `bash-guard.sh` | Before shell command | Blocks `git add .`; nudges `/review` before commits; detects command loops | Block / warn |
| `workflow-tracker.sh` | After any action | Records `/preflight` + `/review` invocations; tracks chart scripts needing verification | Advisory only |
| `session-closeout.sh` | Session end (`SessionEnd` — `/exit` or terminal close) | Summarizes dangling charts, missing preflight, uncommitted work; cleans state | Advisory |

All hooks also write one line per invocation to `session-log.jsonl` — structured telemetry we use for retrospectives ("which files did we edit most this session? where did we spend time? how often did we hit a warn or block?").

---

## 4. How they compose — a session walkthrough

A concrete example of what happens when the analyst asks Claude to do some work:

1. **Session starts.** `health-check` reports any errors from the previous session's hooks.
2. **Analyst types a prompt.** `prompt-context` injects the absolute date and notes if the cross-session checkpoint is fresh. This prevents a known failure mode where the model uses a stale date.
3. **Claude tries to write a new file under `analysis/new-investigation/`.** `session-gate` blocks the write because that directory has no `CLAUDE.md`. Claude creates the `CLAUDE.md` first (which chains to its parent), then the actual file writes through.
4. **Claude edits the same SQL file five times iterating on a query.** `retry-guard` counts each edit — but its fingerprint now combines the file path with a hash of the *content* being written. Five genuinely different edits pass; five identical retries trigger a warning.
5. **Claude writes a stakeholder summary in markdown** containing "Surprisingly, the trend reversed." `writing-scrub` warns: the phrase is banned, rewrite as an observation.
6. **Claude runs `git commit`** without having run `/review` first. `bash-guard` warns and points the analyst at `/review`.
7. **Session ends.** `session-closeout` reports: "1 chart script written but not verified, 4 managed writes without `/preflight`, 14 uncommitted files." It cleans up per-session state.

None of these hooks slow the analyst down when work is proceeding cleanly. They fire only when a named, documented guardrail is being crossed.

---

## 5. What's in the box

A small amount of shared plumbing keeps the hooks consistent:

- `_lib.sh` — parses the JSON Claude Code sends to each hook, provides state/marker helpers, defines the `finish()` function that logs telemetry and exits with the right code.
- `/tmp/d7dev-hooks/<session_id>/` — where hooks coordinate within a session. Session-scoped so two parallel sessions don't interfere.
- `errors.log` — persistent log of hook crashes, surfaced at the next session start.
- `session-log.jsonl` — append-only structured log, one JSON line per hook invocation. Fuel for retros.
- `test-all.sh` — 30+ tests covering block/warn/pass behavior of every hook.

---

## 6. How hooks integrate with the repo

Hooks are wired in `.claude/settings.json` under the `hooks` key. Each event type (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`) has a list of scripts to run, optionally filtered by tool. Adding a new hook is three steps:

1. Write the script (source `_lib.sh`, call `init_hook`, call `read_input`, do your check, call `finish`).
2. Register it in `settings.json`.
3. Add a test in `test-all.sh`.

This puts hook logic in version control alongside the rest of the repo. Every team member who checks out `main` gets the same guardrails — no individual setup. When the team decides a new rule matters, we encode it once as a hook.

---

## 7. What this is worth

### For an engineering/technical reader
- **Deterministic enforcement.** Rules that used to live only in prompts or docs are now mechanically checked. Model drift stops being a quality risk.
- **Low operational cost.** Each hook runs in under 50ms. The whole set is bash + jq. No daemon, no dependencies beyond what's already on the machine.
- **Composable.** Adding a rule is one small file. We can express policy as code and ship it to everyone on the team atomically.
- **Observable.** The session log (`session-log.jsonl`) is raw material for retrospectives and for tuning thresholds over time.

### For a non-technical reader
- **Consistency.** Every session gets the same checks. The quality of the work doesn't depend on whether the AI is having a good day.
- **Fewer silent failures.** Things we've learned the hard way (e.g., "AI loops on the same file trying the same fix") are caught automatically instead of burning an hour of human time.
- **Shared standards.** When a marketing lead tells us "never use 'Surprisingly' in a stakeholder report," that preference becomes a mechanical check everyone benefits from, not a rule one person has to remember.
- **Better handoffs.** Session closeout tells the analyst what's dangling — unverified charts, uncommitted work — so nothing quietly falls through the cracks.

---

## 8. What hooks are *not*

- Not a replacement for review. They catch known failure modes — they don't judge the quality of an analysis.
- Not silent. They emit warnings that the analyst reads and decides about.
- Not infallible. Thresholds are tuned conservatively. If a hook is wrong, we fix the hook.
- Not AI-specific. The same pattern works for any automated or semi-automated pipeline that needs guardrails.

---

## 9. Running the tests

```bash
.claude/hooks/test-all.sh
```

33 tests, ~2 seconds. Runs in CI would catch regressions if we ever add that.

---

## 10. Where to start if you want this pattern in your own workspace

1. Pick one persistent failure mode you've seen in AI-assisted work. (Retry loops, skipping a review step, using a forbidden phrase — something concrete.)
2. Write one hook for it. ~30 lines of bash is usually enough.
3. Put the hook in `.claude/hooks/`, register it in `settings.json`, and live with it for a week.
4. Add telemetry and a test only after you're sure the rule is right. It's easier to tune behavior than to clean up a flaky test suite.

The core idea is boring on purpose: most of the value is in *having a place to encode decisions that used to live as tribal knowledge*. The hooks themselves are easy — the hard part is deciding what's worth enforcing.
