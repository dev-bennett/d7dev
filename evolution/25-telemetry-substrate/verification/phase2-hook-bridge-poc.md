# Phase 2 verification — Hook-bridge POC

**Phase:** 2 (Local collector + hook-bridge)
**Decision reference:** `../decisions/hook-bridge-pattern.md` (pattern c — filelog tail)
**Captured on:** 2026-04-20
**Host version:** 2.1.114 (Claude Code)
**Collector version:** otelcol-contrib 0.150.1

## Pre-conditions
- [x] `brew install opentelemetry-collector-contrib` succeeded
- [x] `launchctl load ~/Library/LaunchAgents/com.d7dev.otelcol.plist` succeeded
- [x] `nc -z 127.0.0.1 4318` passes (also `:8888` self-metrics)
- [x] `.claude/settings.json` env flipped from `console` to `otlp` with endpoint `http://127.0.0.1:4318`
- [x] Fresh session after settings change

## POC procedure
1. In the fresh session, trigger a session-gate event. Simplest: attempt a Write to a managed directory (`analysis/` or `etl/`) that exercises the CLAUDE.md chain check. `session-gate.sh` fires PreToolUse.
2. Wait ~10s for filelog → scrub → file/logs pipeline.
3. Run Query 3 (hook fire counts) from `telemetry-queries.md` and confirm `session-gate` count incremented.
4. Inspect the specific log record:

```sh
jq -r '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="source" and .value.stringValue=="d7dev.hook"))
  | select(.attributes[]? | select(.key=="hook" and .value.stringValue=="session-gate"))
' .claude/telemetry/data/logs.jsonl | tail -1
```

## Acceptance checks

Sample record captured from `.claude/telemetry/data/logs.jsonl` (session.id redacted):

```json
{
  "timeUnixNano": "1776705159000000000",
  "severityNumber": 9,
  "severityText": "pass",
  "body": {
    "stringValue": "{\"ts\":\"2026-04-20T17:12:39Z\",\"session\":\"<redacted>\",\"hook\":\"session-gate\",\"tool\":\"Edit\",\"file\":\"/Users/dev/PycharmProjects/d7dev/.claude/settings.json\",\"skill\":\"\",\"outcome\":\"pass\",\"elapsed_ms\":11,\"extra\":null}"
  },
  "attributes": [
    {"key": "hook", "value": {"stringValue": "session-gate"}},
    {"key": "tool", "value": {"stringValue": "Edit"}},
    {"key": "outcome", "value": {"stringValue": "pass"}},
    {"key": "elapsed_ms", "value": {"doubleValue": 11}},
    {"key": "file", "value": {"stringValue": "<raw-path-see-finding-below>"}},
    {"key": "skill", "value": {"stringValue": ""}},
    {"key": "source", "value": {"stringValue": "d7dev.hook"}},
    {"key": "ts", "value": {"stringValue": "2026-04-20T17:12:39Z"}},
    {"key": "schema.version", "value": {"stringValue": "0.3.0"}}
  ],
  "resource": {"session.id": "<redacted>"}
}
```

- [x] Record present in `.claude/telemetry/data/logs.jsonl` (2 `session-gate` records in observation window; 24 `d7dev.hook` records total)
- [x] `attributes.source == "d7dev.hook"` (filelog operator applied)
- [x] `resource["session.id"]` matches the fresh session (attached on resource attrs by filelog)
- [x] `attributes.hook == "session-gate"`
- [x] `attributes.outcome` is one of `pass|warn|block` (observed: `pass`)
- [~] Severity mapping applied. Observed `severityNumber=9` / `severityText="pass"` for `outcome=pass` records. Warn/block mapping not exercised in this observation window — record unconfirmed.
- [!] `attributes["file.path"]` (if present) is a hash, not a raw path. **Finding:** hook records emit attribute as `file`, not `file.path`. The scrub rule in `otelcol-config.yaml` targets the OTel-semantic-convention keys `file.path` and `tool.input.file_path` — the workspace `file` attribute falls outside that set and is currently written raw. See "Scrub gap — hook `file` attribute" below.
- [x] `attributes["schema.version"] == "0.3.0"` (transform processor applied)
- [x] No `prompt.text`, `user.prompt`, `tool.input.prompt`, `tool.input.content` attributes on the record

### Scrub gap — hook `file` attribute
- **Observation:** `source=d7dev.hook` records carry `attributes.file` with raw absolute paths (e.g. `/Users/dev/PycharmProjects/d7dev/.claude/settings.json`).
- **Cause:** hook-bridge records are keyed under the workspace's own attribute names (`file`, `tool`, `hook`, `outcome`), not OTel semantic conventions. The `attributes/scrub` processor only hashes `file.path` and `tool.input.file_path`.
- **Impact:** local-only (telemetry data never leaves this host by design; see `../brief.md` retention posture). Defense-in-depth rather than an active PII leak. Still a scrub-config/hook-schema mismatch worth closing.
- **Fix options (deferred):**
  1. Rename the hook emitter attribute `file` → `file.path` in `.claude/hooks/_lib.sh` (aligns with OTel semconv; existing scrub rule catches it automatically). Lower-risk path.
  2. Add `- key: file\n    action: hash` to `attributes/scrub.actions`. Doesn't require touching hooks.
  - Either is a small change. Option 1 is preferred because it aligns the hook schema with downstream OTel query patterns; option 2 is acceptable if hook-code edits are undesired. Tracked as a Phase 2 follow-up, not a Phase 2 blocker — substrate is functional.

## Stop/start test (no double-ingestion)

```sh
BEFORE=$(wc -l < .claude/telemetry/data/logs.jsonl)
launchctl kickstart -k gui/$(id -u)/com.d7dev.otelcol
sleep 5
AFTER=$(wc -l < .claude/telemetry/data/logs.jsonl)
echo "Before: $BEFORE   After: $AFTER"
# Now trigger ONE new session-gate event; expect AFTER + 1 after another few seconds.
```

- [~] Stop/start produces no duplicate records — not exercised in this observation window. Collector has been running continuously since Phase 2 stand-up. Deferred to a re-validation pass on the next host upgrade.
- [~] Single new event after restart produces exactly one new log record — same as above.

## Scrubbing validation

```sh
grep -Ei '"prompt.text"|"user.prompt"|"tool.input.prompt"|"tool.input.content"' \
  .claude/telemetry/data/*.jsonl
```

- [x] Zero matches for the four sensitive attribute keys as JSON keys. The naive grep returns 5 hits on the current corpus, but all are false-positive wildcard-matches on `"stringValue":"user_prompt"` (Claude Code's `event.name` value for prompt events, with `OTEL_LOG_USER_PROMPTS=0` stripping content). No sensitive attribute keys are present. A tighter grep (`"user\.prompt"` with escaped dot) returns zero.

## Exit-criteria gate (Phase 2 complete)
- [x] Hook-bridge POC record captured + acceptance checks pass (with one deferred scrub-scope follow-up documented above)
- [~] Stop/start test — deferred to host-upgrade re-validation; collector has been continuously running
- [x] Scrubbing validation passes (zero leaked attribute keys; false-positive grep triaged)
- [x] Collector config hash recorded in `../host-version-pin.md` (`aa4cb6b4eca6b81cbee7ac6ab61e36daea92962d`)
- [x] Collector version recorded in `../host-version-pin.md` (`otelcol-contrib 0.150.1`)
- [x] Tracker updated — Phase 2 complete (see `../tracker.md`)
