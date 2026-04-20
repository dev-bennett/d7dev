# Phase 1 verification — `/orient` console span capture

**Phase:** 1 (Enable + local console capture)
**Captured on:** _pending — requires fresh session after settings.json env-block change_
**Host version:** _record from `claude --version` at capture time_
**Session:** _redacted_

## Procedure
1. Land env-block change in `.claude/settings.json` (done 2026-04-20; commit hash _pending_).
2. Close the current Claude Code session.
3. Open a fresh session — env vars only take effect at session start.
4. Invoke `/orient`.
5. Observe stderr for OTel console output.
6. Capture representative examples of each signal below, redact, paste in.

## Four-signal checklist

### Signal 1 — Per-tool span carrying `tool.name`
**Expected:** ≥1 span per tool invocation (Read, Glob, Grep, Bash, Skill). Each has `tool.name` attribute.

Result: _pending_

Sample output (redacted):
```
<paste span output here; redact session.id and file paths>
```

### Signal 2 — Session-lifecycle log with `session.id`
**Expected:** ≥1 log record with `session.id` attribute present.

Result: _pending_

Sample:
```
<paste log record here; redact session.id>
```

### Signal 3 — Non-zero token-usage metric
**Expected:** Token counter (name host-dependent — record observed name) emits after first assistant turn with non-zero value.

Result: _pending_

Observed metric name: `<record here>`
Sample datapoint:
```
<paste metric datapoint>
```

### Signal 4 — Latency datapoint
**Expected:** ≥1 duration/latency datapoint from a completed tool call.

Result: _pending_

Observed metric name: `<record here>`
Sample:
```
<paste>
```

## Host-emits inventory (feeds `../host-version-pin.md`)
Populate after capture — list every span name, metric name, and log record type observed during this `/orient` run. This becomes the pinned host-emits snapshot.

| Signal type | Name | Attribute shape (keys only) |
|---|---|---|
| span | _e.g. `claude.tool.invoke`_ | `tool.name`, `session.id`, `duration_ms` |
| metric | _e.g. `gen_ai.client.token.usage`_ | `session.id`, `type` (input/output) |
| log | _e.g. `claude.session.start`_ | `session.id`, `cwd` |

## Exit-criteria gate
- [ ] All four signals observed
- [ ] Host-emits inventory filled
- [ ] Host version recorded in `../host-version-pin.md`
- [ ] No sensitive content present in this artifact after redaction
- [ ] Phase 1 marked complete in `../tracker.md`

## Notes
- Claude Code's OTel schema is host-versioned. Span/metric/log names may shift across CLI releases. Record exactly what was observed; downstream queries (Phase 3 runbook) must key off stable attributes, not these names.
- If any signal is absent, do NOT proceed to Phase 2 — investigate first (policy-limits override? env not picked up? wrong session?).

## Capture attempt log

### 2026-04-20 ~10:36 — UNUSABLE
- File captured: `verification/snapshot.txt` (~47 KB)
- Content type: Claude Code CLI chat transcript (rendered tool-call blocks, `⎿` frames, `INVENTORY_MANIFEST` output). Not OTel console-exporter output.
- All four signals absent (no spans with `tool.name`, no logs with `session.id`, no token-usage metric, no latency datapoint).
- Diagnosis: stderr was not captured; screen/UI output was pasted instead. OTel console exporter writes to stderr.
- Action: re-capture with stderr tee'd at CLI launch, e.g. `claude 2>&1 | tee /tmp/claude-otel.log`. Then overwrite `snapshot.txt` with the redacted log contents.
- Pre-checks still valid: env block in `.claude/settings.json` has `CLAUDE_CODE_ENABLE_TELEMETRY=1` and all three `OTEL_*_EXPORTER=console`. Policy-limits pre-check passed per `../tracker.md` Phase 1 note.

### 2026-04-20 ~12:14 — SUPERSEDED (closed)
- Resolution: rather than retry console-stderr capture, Phase 2 (collector + OTLP) was stood up and the settings env block was flipped from `console` to `otlp`. Signals are now captured at the collector file exporters, not on stderr.
- Evidence location: `.claude/telemetry/data/logs.jsonl` + `.claude/telemetry/data/metrics.jsonl`.
- Signal coverage at closure:
  - **Signal 1 (per-tool span with `tool.name`):** absent by design. Claude Code CLI 2.1.114 does not emit OTel traces — host-side activity is published as event logs with `source=d7dev.host` and an `event.name` discriminator (`user_prompt`, `tool_decision`, etc.). Downstream consumers key on logs, not spans. Recorded in `../host-version-pin.md`.
  - **Signal 2 (session-lifecycle log with `session.id`):** observed. `session.id` is attached as a resource attribute on every host + hook log record.
  - **Signal 3 (non-zero token-usage metric):** observed. Metric name: `claude_code.token.usage`, scope `com.anthropic.claude_code` 2.1.114, with `type ∈ {input, output, cacheRead, cacheCreation}` and per-model attributes. Non-zero values confirmed for `claude-opus-4-7[1m]` and `claude-haiku-4-5-20251001`.
  - **Signal 4 (latency datapoint):** satisfied via `claude_code.active_time.total` (unit=s, `type ∈ {user, cli}`) on the metrics pipeline and `elapsed_ms` attributes on hook log records. No dedicated per-tool-call duration metric observed in this host version.
- Host-emits inventory: populated in `../host-version-pin.md` "Observed host-emits (captured 2026-04-20)".
- Exit: Phase 1 closed via supersession. The four-signal checklist above is retained for historical reference and for use on host-version re-pins where the console exporter remains the fastest sanity check.
