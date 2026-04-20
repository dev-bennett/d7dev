# Close-out steps — Epic 0.3 Telemetry substrate

**Created:** 2026-04-20
**Purpose:** Sequenced, copy-paste-able steps to take Epic 0.3 from "scaffolded" to "complete." The substrate artifacts are committed; the validation gates require local install and fresh-session captures that Claude cannot run.

When each gate passes, mark the corresponding checkbox here AND update `tracker.md`.

---

## 2026-04-20 — Pivot: console exporter unusable in interactive CLI

**Context.** Two capture attempts at Gate A.2 (UI paste on 2026-04-20 ~10:36; `script -q /tmp/claude-otel.log claude` on 2026-04-20 ~10:55 followed by `/orient` + Ctrl-D) both produced ANSI-rendered TTY output with zero OTel shape (no `tool.name`, no `session.id`, no `gen_ai.*`, no span/metric/log envelopes).

**Ruled out.** Settings env block is correct (`CLAUDE_CODE_ENABLE_TELEMETRY=1`, all three `OTEL_*_EXPORTER=console`). `~/.claude/policy-limits.json` does not block telemetry. `~/.claude/debug/latest` was not updated from the OTel-enabled session. Claude Code CLI v2.1.114.

**Diagnosis.** Claude Code v2.1.114 in interactive TTY mode does not render OTel console-exporter output to any surface we've found. Gate A as originally specified (console-exporter-first) is not achievable on this host.

**Pivot.** Reorder gates: stand up the collector now, flip exporters `console → otlp`, and use the collector's `file_exporter` output (`.claude/telemetry/data/spans.jsonl` / `metrics.jsonl` / `logs.jsonl`) as the Phase 1 four-signal evidence. The original Gate B steps B.1–B.5 (install, config-check, launchd, OTLP flip, file-presence check) move into the new Gate A as A.1–A.5; new A.6 is the JSONL signal-inventory scan; A.7 closes Gate A. The original Gate B becomes collector-side validation only (hook bridge, stop/start, scrubbing).

**Affected artifacts.**
- `close-out.md` (this file) — Gates A and B rewritten below.
- `verification/phase1-orient-spans.md` — capture-attempt log will record the second failure and the pivot outcome when Gate A closes.
- `host-version-pin.md` — host-emits inventory will be sourced from JSONL files instead of console output. Attribute keys and span/metric/log names are equivalent; only the carrier changes.

---

## Gate A — Collector up + Phase 1 signals via file exporter

**Status target:** Phase 1 log entry → `Complete: <date>`

### A.1 Install otelcol-contrib

`otelcol-contrib` is **not** in homebrew-core and has no official Homebrew tap. Install via the upstream tarball from `open-telemetry/opentelemetry-collector-releases`.

Resolve the latest tag, download, extract, and place on PATH:

```sh
# 1. Resolve latest release tag (strip leading 'v' for filename)
LATEST=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector-releases/releases/latest | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4)
VERSION=${LATEST#v}
echo "Installing otelcol-contrib $VERSION"

# 2. Download + extract (darwin_arm64 for Apple Silicon)
cd /tmp
curl -LO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/${LATEST}/otelcol-contrib_${VERSION}_darwin_arm64.tar.gz"
tar -xzf "otelcol-contrib_${VERSION}_darwin_arm64.tar.gz"

# 3. Install to /opt/homebrew/bin (matches the path hardcoded in com.d7dev.otelcol.plist.template)
sudo mv otelcol-contrib /opt/homebrew/bin/
sudo chmod +x /opt/homebrew/bin/otelcol-contrib

# 4. Remove Gatekeeper quarantine (unsigned binary)
sudo xattr -d com.apple.quarantine /opt/homebrew/bin/otelcol-contrib 2>/dev/null || true

# 5. Verify
otelcol-contrib --version
```

For Intel macs: replace `darwin_arm64` with `darwin_amd64` above, and replace `/opt/homebrew/bin/` with `/usr/local/bin/` (also update the `ProgramArguments[0]` path in `com.d7dev.otelcol.plist.template` before Gate A.3).

- [ ] Tarball downloaded
- [ ] Binary on PATH: `which otelcol-contrib` resolves
- [ ] `otelcol-contrib --version` prints a version
- [ ] Record version in `host-version-pin.md`

### A.2 Sanity-check config syntax

```sh
otelcol-contrib validate --config /Users/dev/PycharmProjects/d7dev/.claude/telemetry/otelcol-config.yaml
```

(If `validate` isn't a subcommand on your version: skip; it will fail fast at launch instead.)

- [ ] No errors

### A.3 Install launchd agent

```sh
cp /Users/dev/PycharmProjects/d7dev/.claude/telemetry/com.d7dev.otelcol.plist.template \
   ~/Library/LaunchAgents/com.d7dev.otelcol.plist
launchctl load  ~/Library/LaunchAgents/com.d7dev.otelcol.plist
launchctl start com.d7dev.otelcol
```

Verify reachable:

```sh
nc -z 127.0.0.1 4318 && echo "OTLP http up"
nc -z 127.0.0.1 8888 && echo "self-metrics up"
tail -20 /Users/dev/PycharmProjects/d7dev/.claude/telemetry/collector.log
```

- [ ] Both ports reachable
- [ ] `collector.log` shows `Everything is ready. Begin running and processing data.` (or equivalent)
- [ ] No `ERROR` lines

Troubleshoot if down:
- Config rejected → check `collector.log` for the exact error; path typos and YAML indent are the usual suspects
- Binary missing → `which otelcol-contrib`; plist's `ProgramArguments[0]` hardcodes `/opt/homebrew/bin/otelcol-contrib` (Apple Silicon). On Intel, edit to `/usr/local/bin/otelcol-contrib` before copying to LaunchAgents.

### A.4 Flip settings exporters console → OTLP

Edit `.claude/settings.json → env`. Replace:

```json
"OTEL_LOGS_EXPORTER": "console",
"OTEL_METRICS_EXPORTER": "console",
"OTEL_TRACES_EXPORTER": "console",
```

with:

```json
"OTEL_LOGS_EXPORTER": "otlp",
"OTEL_METRICS_EXPORTER": "otlp",
"OTEL_TRACES_EXPORTER": "otlp",
"OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4318",
"OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf",
```

Keep `OTEL_METRIC_EXPORT_INTERVAL` and `OTEL_LOG_USER_PROMPTS`.

- [ ] Edit complete
- [ ] Restart Claude Code session (env change requires restart)

### A.5 Confirm host spans flowing

In the fresh session, run any tool (a single Read works). Then:

```sh
ls -la /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/
# Expect: spans.jsonl, metrics.jsonl, logs.jsonl — non-zero size
```

- [ ] All three files present, non-zero
- [ ] Record collector config hash: `shasum /Users/dev/PycharmProjects/d7dev/.claude/telemetry/otelcol-config.yaml` → `host-version-pin.md`

### A.6 Phase 1 signal inventory from JSONL exporters

Invoke `/orient` in the fresh session if A.5 wasn't triggered by `/orient` already. Then scan the three JSONL streams for the four Phase 1 signals:

```sh
# Signal 1 — per-tool span with tool.name
grep -o '"tool.name":"[^"]*"' /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/spans.jsonl | sort -u

# Signal 2 — session-lifecycle log with session.id
grep -o '"session.id":"[^"]*"' /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/logs.jsonl | head -5

# Signal 3 — token-usage metric name(s)
jq -r '.resourceMetrics[]?.scopeMetrics[]?.metrics[]?.name' \
  /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/metrics.jsonl | sort -u | grep -iE 'token|usage'

# Signal 4 — latency/duration metric name(s)
jq -r '.resourceMetrics[]?.scopeMetrics[]?.metrics[]?.name' \
  /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/metrics.jsonl | sort -u | grep -iE 'duration|latency|time'
```

Fill `verification/phase1-orient-spans.md`:
- [ ] Signal 1 observed — paste ≥1 redacted span with `tool.name`
- [ ] Signal 2 observed — paste ≥1 redacted log with `session.id`
- [ ] Signal 3 observed — record metric name + paste one datapoint
- [ ] Signal 4 observed — record metric name + paste one datapoint
- [ ] Host-emits inventory table populated (every span name, metric name, log record type observed)
- [ ] Capture-attempt log updated: 2026-04-20 ~10:55 `script` attempt marked UNUSABLE (ANSI/UI, no OTel shape); JSONL-exporter capture succeeded

Populate `host-version-pin.md`:
- [ ] Claude Code CLI version (`claude --version` → 2.1.114 as of 2026-04-20)
- [ ] `otelcol-contrib --version`
- [ ] Config hash from A.5
- [ ] Validation date
- [ ] "Observed host-emits" section from the inventory above

### A.7 Close Gate A
- [ ] Tracker: Phase 1 `Complete: <today>`; Notes: console-exporter pivot + signals validated via file exporter
- [ ] If any signal absent in JSONL: **stop.** Possible causes: env vars not inherited after session restart, OTLP endpoint mismatch, collector not running (check `collector.log`), CLI version predates OTel support for that signal type.

---

## Gate B — Hook bridge + runtime validation

**Status target:** Phase 2 log entry → `Complete: <date>`

### B.1 Run hook-bridge POC

Trigger a hook event. Easiest path: attempt a Write to a managed directory that triggers `session-gate.sh`. The Write should succeed (or warn) — the goal is to get session-gate to fire and log an event.

- [ ] Event triggered
- [ ] Wait ~10s for filelog pipeline to process
- [ ] Run the query in `verification/phase2-hook-bridge-poc.md` step 4
- [ ] Record appears with `attributes.source == "d7dev.hook"`, correct `hook`, hashed `file.path`
- [ ] Fill in `phase2-hook-bridge-poc.md` acceptance checks

### B.2 Run stop/start no-duplicate test

Per `phase2-hook-bridge-poc.md`:

```sh
BEFORE=$(wc -l < /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/logs.jsonl)
launchctl kickstart -k gui/$(id -u)/com.d7dev.otelcol
sleep 5
AFTER=$(wc -l < /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/logs.jsonl)
echo "Before: $BEFORE   After: $AFTER"
```

- [ ] `AFTER - BEFORE` is 0 or 1 (NOT N where N = all prior lines)

### B.3 Run scrubbing validation

```sh
grep -Ei '"prompt.text"|"user.prompt"|"tool.input.prompt"|"tool.input.content"' \
  /Users/dev/PycharmProjects/d7dev/.claude/telemetry/data/*.jsonl
```

- [ ] Zero matches

### B.4 Close Gate B
- [ ] Tracker: Phase 2 `Complete: <today>`; Notes: hook-bridge POC outcome, stop/start result, any issues

---

## Gate C — Full end-to-end verification

**Status target:** `verification/full-e2e.md` filled; Epic status → complete

### C.1 Run the 10-step sequence
Open `verification/full-e2e.md` and execute each step in order, pasting results / pass-fail.

- [ ] Step 1 — both ports reachable
- [ ] Step 2 — fresh session + `/orient` complete
- [ ] Step 3 — hook events triggered (Write + Bash)
- [ ] Step 4 — ≥5 distinct host span names for session
- [ ] Step 5 — ≥4 hook names each ≥1
- [ ] Step 6 — input + output token totals both >0
- [ ] Step 7 — scrubbing grep returns 0
- [ ] Step 8 — cross-stream correlation shows host span + workflow-tracker hook for same session
- [ ] Step 9 — stop/start no-duplicate
- [ ] Step 10 — interleaved projection renders correctly

### C.2 Close Gate C
- [ ] Tracker: Phase 3 `Complete: <today>`; Notes: e2e pass
- [ ] Tracker "Current state": Status → complete
- [ ] `MASTER_TRACKER.md`:
  - Epic 0.3 task-line → `complete (YYYY-MM-DD)`
  - Rollup counts: not-started 21 → 20; in-progress 1 → 0; complete 1 → 2
  - "Immediate pick" → note 0.3 closed; 1.1 remains next critical-path; 1.2 now unblocked pending 1.1

---

## Gate D — Downstream brief notification

The five consumer epics (02, 05, 07, 23, 24) have consumption sections. Each will consume Epic 0.3 output during their own phased work; no action needed here unless one of those epics is about to start.

- [ ] No action at this time (consumer epics remain not-started)

---

## Post-completion follow-up tasks (out of scope for this epic)

Capture these as separate tasks; do not roll into Epic 0.3 closure.

1. **session-log.jsonl size rotation.** `.claude/hooks/session-closeout.sh` currently does NOT cap `session-log.jsonl` size. Once the filelog receiver is tailing it daily, slow growth over many months could degrade tail performance. Fix: add a size-check rotation (e.g. `>10 MB` → `mv to .prev`) to `session-closeout.sh`. Do in a fresh session; test manually; respects `feedback_dont_edit_live_hooks.md`.
2. **Collector disk-usage alert.** Extend `health-check.sh` with a `du -sh .claude/telemetry/data/` warn if >1 GB. Non-blocking advisory.
3. **Quarterly scrubbing audit.** Calendar reminder: every quarter, grep exporter output for known-sensitive tokens not in the current scrub list (paths, emails, API-key shapes). Update scrub processor if drift found.
4. **Pin refresh on Claude Code upgrade.** Any time `claude --version` changes, follow the "Re-validation checklist" in `host-version-pin.md`. Gate upgrades on pin refresh.
5. **otelcol-config.yaml v0.150+ schema updates.** Collector startup on otelcol-contrib 0.150.1 (2026-04-20) emits two non-blocking deprecation notices, both auto-migrated for now:
   - `"filelog" alias is deprecated; use "file_log" instead` — rename the receiver key in `otelcol-config.yaml` (service pipelines and receivers section).
   - OTTL statements in `transform/schema_version` need context prefixes: `attributes["schema.version"]` → `log.attributes["schema.version"]` (logs pipelines), `span.attributes["schema.version"]` (traces), `datapoint.attributes["schema.version"]` (metrics).
   Plus: the original `service.telemetry.metrics.address` syntax was replaced on 2026-04-20 with `readers: [{pull: {exporter: {prometheus: {...}}}}]` to satisfy the `migration.MetricsConfigV030` schema required by 0.123+. Record this in the host-version-pin when it's next refreshed.

---

## Artifacts referenced
- Runbook: `../../knowledge/runbooks/telemetry-substrate.md`
- Queries: `../../knowledge/runbooks/telemetry-queries.md`
- Collector config: `../../.claude/telemetry/otelcol-config.yaml`
- Launchd template: `../../.claude/telemetry/com.d7dev.otelcol.plist.template`
- Decision: `decisions/hook-bridge-pattern.md`
- Version pin: `host-version-pin.md`
- Verification artifacts: `verification/phase1-orient-spans.md`, `verification/phase2-hook-bridge-poc.md`, `verification/full-e2e.md`
- Framework rule: `../../analytical-orchestration-framework.md` §1.4 (host-version pinning)
- Tracker: `tracker.md`
