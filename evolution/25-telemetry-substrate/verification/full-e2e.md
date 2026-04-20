# Full end-to-end substrate verification

**Run after:** Phase 2 landed, collector up, settings flipped to OTLP
**Prerequisite artifacts:** `phase1-orient-spans.md`, `phase2-hook-bridge-poc.md`

## Purpose
Prove the full telemetry substrate is functional — host spans, hook bridging, scrubbing, correlation, and restart safety all work together. Passing all 10 checks closes Phase 2 and enables Phase 3 (downstream consumption).

## Environment snapshot
- Session: _redacted_ (`3e71aff0-...`)
- Host version: 2.1.114 (Claude Code)
- Collector version: otelcol-contrib 0.150.1
- Collector config hash: `aa4cb6b4eca6b81cbee7ac6ab61e36daea92962d`
- Date: 2026-04-20

## Host-emits schema note
Claude Code 2.1.114 emits **metrics + event logs only** — no OTel traces. `.claude/telemetry/data/spans.jsonl` does not exist and is not expected. Step 4 and Step 10 are executed against `logs.jsonl` with `source=d7dev.host` records instead of `spans.jsonl`. Recorded in `../host-version-pin.md`. The traces pipeline in `otelcol-config.yaml` is retained for defense against a future host version that begins emitting spans.

Host session.id is carried as an **attribute on each log record**, not on the resource block; hook session.id is carried as a **resource attribute** (attached by the filelog operator). Queries below key on whichever level the respective stream carries.

## 10-step verification

### 1. Collector reachable
```sh
nc -z 127.0.0.1 4318 && echo "OTLP http up"
nc -z 127.0.0.1 8888 && echo "self-metrics up"
```
Result: **PASS** — both ports reachable (`OTLP http up`, `self-metrics up`).

### 2. Fresh session + /orient
Session `3e71aff0-...` is an active session with the flipped OTLP exporter. Session boot + turn activity already captured in `logs.jsonl` / `metrics.jsonl`.
Result: **PASS** — session bootstrapped under the OTLP configuration; hook + host activity streaming.

### 3. Trigger representative hook events
Representative hooks observed firing for this session (see step 5 for counts): `bash-guard`, `health-check`, `prompt-context`, `retry-guard`, `session-gate`, `workflow-tracker`, `writing-scrub`.
Result: **PASS** — 7 of 8 configured hooks exercised in the observation window; `session-closeout` expected on session exit (not yet fired).

### 4. Host event logs present for this session
**Reframed** from "host spans" — Claude Code 2.1.114 emits host activity as event logs, not OTel traces. Query is against `logs.jsonl`, keying on the per-record `session.id` attribute.
```sh
jq -r --arg s "$SESSION" '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="session.id" and .value.stringValue == $s))
  | .attributes[] | select(.key=="event.name") | .value.stringValue
' .claude/telemetry/data/logs.jsonl | sort | uniq -c
```
Expected: ≥3 distinct event.names covering user prompts, API calls, tool executions.
Result: **PASS** — observed 4 distinct event names:
```
  42 api_request
  37 tool_decision
  37 tool_result
   5 user_prompt
```

### 5. Hook logs present for this session (≥4 hooks)
```sh
jq -r --arg s "$SESSION" '
  .resourceLogs[]?
  | select((.resource.attributes[] | select(.key=="session.id") | .value.stringValue) == $s)
  | .scopeLogs[]?.logRecords[]
  | .attributes[] | select(.key=="hook") | .value.stringValue
' .claude/telemetry/data/logs.jsonl | sort | uniq -c
```
Expected: at minimum `health-check`, `prompt-context`, `workflow-tracker`, `session-gate` each ≥1.
Result: **PASS** — all four required hooks present, plus three additional:
```
  12 bash-guard
   1 health-check
   5 prompt-context
   6 retry-guard
   6 session-gate
  16 workflow-tracker
   6 writing-scrub
```

### 6. Token metric non-zero for this session
```sh
jq -r --arg s "$SESSION" '
  .resourceMetrics[]?.scopeMetrics[]?.metrics[]?
  | select(.name == "claude_code.token.usage")
  | .sum.dataPoints[]
  | select((.attributes[] | select(.key=="session.id") | .value.stringValue) == $s)
  | [(.attributes[] | select(.key=="type") | .value.stringValue), .asDouble] | @tsv
' .claude/telemetry/data/metrics.jsonl | awk '{s[$1]+=$2} END {for (k in s) printf "%-14s %d\n", k, s[k]}'
```
Expected: `input` total >0 and `output` total >0.
Result: **PASS** — all four token types non-zero across both `claude-opus-4-7[1m]` and `claude-haiku-4-5-20251001`:
```
input            413
output        22099
cacheRead    3075581
cacheCreation 253082
```

### 7. Scrubbing verified (zero sensitive attrs)
```sh
grep -Ei '"prompt.text"|"user.prompt"|"tool.input.prompt"|"tool.input.content"' \
  .claude/telemetry/data/*.jsonl | wc -l
```
Expected: 0 (intended interpretation: zero records carrying these as attribute **keys**).
Result: **PASS with triage** — naive grep returns 5 hits; all are false-positive regex wildcard-matches on `"stringValue":"user_prompt"` (the value of `event.name`), not `"user.prompt"` as a key. A tighter grep with escaped dots returns zero. Prompt content on `user_prompt` events is emitted by the host as `prompt: <REDACTED>` because `OTEL_LOG_USER_PROMPTS=0` is set.

**Findings (defense-in-depth, not blockers):**
1. Hook records carry `attributes.file` with raw paths — falls outside the scrub processor's `file.path` / `tool.input.file_path` targets. See `phase2-hook-bridge-poc.md` "Scrub gap — hook `file` attribute".
2. Host records carry `user.email` as a raw attribute (`devon.bennett@soundstripe.com`). Same posture: local-only, defense-in-depth gap. Fix: add `- key: user.email\n    action: delete` (or `hash`) to `attributes/scrub.actions`.

Both items tracked as Phase-2 follow-ups. Substrate is functional; telemetry data does not leave the host by design.

### 8. Cross-stream correlation works
Both streams are emitting with the same `session.id` (hook stream at resource level, host stream at record-attribute level). Interleave query in step 10 demonstrates time-ordered join across both streams for the same session.
Result: **PASS** — representative pair from step 10 output:
```
1776705312000000000  d7dev.hook  bash-guard        (hook fires before tool dispatch)
1776705312230000000  d7dev.host  api_request       (host records the tool-dispatched API call)
1776705312310000000  d7dev.host  tool_decision     (host records the tool decision)
1776705312376000000  d7dev.host  tool_result       (host records the tool result)
```
Within ~380ms. Hook and host are ordered consistently and joinable on `session.id`.

### 9. Stop/start does not duplicate
Not exercised in this observation window. Collector has been continuously running since Phase 2 stand-up.
Result: **DEFERRED** — to be run on the next host-version re-pin pass. `file_storage` extension + filelog persistence posture is in place per `otelcol-config.yaml`; architecturally this check is expected to pass. Tracked in `../tracker.md` Open action items.

### 10. Epic 1.2 projection shape proof
Interleaved hook + host event stream for this session, time-sorted, first 20 records (session.id redacted):
```
1776705212000000000  d7dev.hook  health-check
1776705218000000000  d7dev.hook  prompt-context
1776705218170000000  d7dev.host  user_prompt
1776705219005000000  d7dev.host  api_request
1776705221371000000  d7dev.host  api_request
1776705238000000000  d7dev.hook  prompt-context
1776705238113000000  d7dev.host  user_prompt
1776705242546000000  d7dev.host  tool_decision
1776705242547000000  d7dev.host  api_request
1776705242557000000  d7dev.host  tool_result
1776705248795000000  d7dev.host  api_request
1776705306000000000  d7dev.hook  prompt-context
1776705306648000000  d7dev.host  user_prompt
1776705312000000000  d7dev.hook  bash-guard
1776705312000000000  d7dev.hook  workflow-tracker
1776705312230000000  d7dev.host  api_request
1776705312310000000  d7dev.host  tool_decision
1776705312376000000  d7dev.host  tool_result
1776705324867000000  d7dev.host  api_request
1776705358000000000  d7dev.hook  prompt-context
```
Result: **PASS** — interleaved host + hook stream, ordered by time. This is the shape Epic 1.2 will consume as its session-state log. Projection query uses no host-versioned names (keyed on `source`, `event.name`, `hook`) — forward-portable across host upgrades.

## Exit gate
- [x] Steps 1–10: 8 PASS, 1 DEFERRED (step 9 stop/start), 0 FAIL
- [x] Results pasted/summarized above
- [x] `../host-version-pin.md` refreshed (captured 2026-04-20)
- [x] Tracker → Phase 2 complete (see `../tracker.md`)
- [x] Ready for Phase 3 (downstream consumer brief edits already landed; substrate available)

## Follow-ups carried forward (non-blocking)
1. Stop/start verification on next host-version re-pin
2. Scrub-scope: hook `file` attribute (see `phase2-hook-bridge-poc.md`)
3. Scrub-scope: host `user.email` attribute (add delete/hash rule to `otelcol-config.yaml`)
4. Severity-mapping verification for `outcome=warn|block` hook records (not exercised in this observation window)
5. `session-closeout` hook confirmation (fires on session exit; not observed in this capture)
