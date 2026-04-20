# Telemetry substrate (OpenTelemetry)

**Last updated:** 2026-04-20
**Owner:** workspace operator (sole maintainer)
**Linked epic:** Evolution Epic 0.3 — `evolution/25-telemetry-substrate/`
**Framework section:** `../../analytical-orchestration-framework.md` §1.4

## Purpose
Enable structured observability of the Claude Code host runtime (tool calls, session events, token usage, latency) via native OpenTelemetry. Bridges workspace hook events into the same pipeline so all runtime signal consumes through one local collector. Downstream epics (1.2 session event log, 2.3 rule efficacy, 5.2 agent cost, 6.8 meta-retrospective, 6.9 directive experiments) read this substrate rather than hand-rolling instrumentation.

Substrate is **local-only**. No network egress beyond loopback. Stream carries PII (prompts, file paths, tool arguments) and must not cross sync or backup boundaries.

## Prerequisites
- macOS with shell access
- Claude Code CLI (version recorded in `evolution/25-telemetry-substrate/host-version-pin.md`)
- No telemetry-disabling entries in `~/.claude/policy-limits.json` (verified 2026-04-20: file restricts remote-control, web setup, MCP isolation only; no telemetry restrictions)
- For Phase 2+: Homebrew, loopback network access (127.0.0.1:4317/4318/8888)

## Scope boundary
| In scope | Out of scope |
|---|---|
| Local OTLP collector, file exporters, retention policy | External backends (Jaeger, Tempo, cloud APM) |
| Hook-event bridging via filelog receiver | Migrating hooks off `session-log.jsonl` |
| Scrubbing of known-sensitive attributes | Application-level instrumentation of `scripts/` |
| Schema-agnostic query patterns for downstream epics | Automated alerting (owned by downstream epics) |

---

## Phase 1 — Enable + console capture

### Environment variables (in `.claude/settings.json → env`)
| Variable | Value | Rationale |
|---|---|---|
| `CLAUDE_CODE_ENABLE_TELEMETRY` | `1` | Turns on native OTel export |
| `OTEL_LOGS_EXPORTER` | `console` | Phase 1: emit to stderr; no collector needed |
| `OTEL_METRICS_EXPORTER` | `console` | Same |
| `OTEL_TRACES_EXPORTER` | `console` | Same |
| `OTEL_METRIC_EXPORT_INTERVAL` | `60000` | 60s — prevents flood during interactive sessions |
| `OTEL_LOG_USER_PROMPTS` | `0` | Explicit denial; prompt content never emitted |

Phase 1 does NOT set `OTEL_EXPORTER_OTLP_ENDPOINT` — console and OTLP endpoint are mutually exclusive in this plan; endpoint flips in Phase 2 after collector is verified running.

### Verification procedure (4-signal checklist)
A fresh session (restart Claude Code after the env change) invoking `/orient` must produce, on stderr:
1. **≥1 span per tool invocation** (Read, Glob, Grep, Bash, Skill) carrying `tool.name` attribute
2. **≥1 session-lifecycle log** with `session.id` present
3. **Non-zero token-usage metric** after the first assistant turn
4. **≥1 latency datapoint** on a completed tool call

Capture a redacted sample to `evolution/25-telemetry-substrate/verification/phase1-orient-spans.md` and mark each of the four signals observed.

### Known-sensitive field inventory (feeds Phase 2 scrubbing)
- `prompt.*`, `user.prompt`, any attribute containing `prompt` — **delete**
- `file.path`, `tool.input.file_path` — **hash** (preserves uniqueness, drops path content)
- `tool.input.command` (Bash) — **regex-scrub** for `key=…`, `token=…`, `Bearer …`, `password=…`
- `session.id` — **keep** (workspace-scoped identifier; used for correlation)

### Host-emits inventory (populated from Phase 1 capture)
_To be filled from the first successful `/orient` run._ Captures: span names, metric names, log record types. Pinned to the host version recorded in `evolution/25-telemetry-substrate/host-version-pin.md`.

---

## Phase 2 — Local collector + persistence

### Install otelcol-contrib

The contrib distribution is required: `filelog` receiver and `file` exporter exist only in contrib.

```sh
brew install opentelemetry-collector-contrib
otelcol-contrib --version
```

Record the version in `../../evolution/25-telemetry-substrate/host-version-pin.md` (collector version + config hash).

### Config walkthrough

Config lives at `.claude/telemetry/otelcol-config.yaml`. Key sections:

| Block | Purpose |
|---|---|
| `extensions.file_storage/otel` | Persists filelog tail position across restarts (no double-ingestion) |
| `receivers.otlp` | Accepts host-emitted OTLP on `127.0.0.1:4318` (http) and `:4317` (grpc). Loopback-only |
| `receivers.filelog` | Tails `.claude/hooks/session-log.jsonl` + `.prev`; JSON-parses; tags `source=d7dev.hook`; maps `outcome` → severity |
| `processors.attributes/scrub` | Deletes prompt content; hashes `file.path` + `tool.input.file_path`; ensures `source` set |
| `processors.transform/schema_version` | Stamps `schema.version=0.3.0` on every record (enables consumer-side version gating) |
| `exporters.file/{spans,metrics,logs}` | Writes JSONL to `.claude/telemetry/data/` with rotation (50 MB / 14 days / 10 backups) |
| `service.pipelines.logs/hooks` | The bridge — filelog → scrub → file/logs |

The collector emits its own self-metrics on `127.0.0.1:8888`. These are not routed through the pipelines.

### Launchd install (default)

Install the user-scope plist once:

```sh
cp .claude/telemetry/com.d7dev.otelcol.plist.template \
   ~/Library/LaunchAgents/com.d7dev.otelcol.plist
launchctl load  ~/Library/LaunchAgents/com.d7dev.otelcol.plist
launchctl start com.d7dev.otelcol
```

Verify:

```sh
nc -z 127.0.0.1 4318 && echo "collector up"
tail -f .claude/telemetry/collector.log
```

Reload after a config change:

```sh
launchctl kickstart -k gui/$(id -u)/com.d7dev.otelcol
```

Uninstall:

```sh
launchctl stop   com.d7dev.otelcol
launchctl unload ~/Library/LaunchAgents/com.d7dev.otelcol.plist
rm ~/Library/LaunchAgents/com.d7dev.otelcol.plist
```

### Manual invocation (debug fallback)

```sh
otelcol-contrib --config .claude/telemetry/otelcol-config.yaml
```

Foreground; Ctrl-C to stop. Use this when debugging config changes before committing — stdout/stderr are visible.

### Retention policy

Per exporter: 50 MB max per file, 14 days max age, 10 max backups. Three streams (spans, metrics, logs) → 1.5 GB worst-case local disk.

Rationale:
- 14 days matches memory-staleness threshold (framework §5.3)
- 50 MB keeps individual files small enough for `jq` to stream without memory pressure
- 10 backups × 14 days is ~20 weeks of occasional-use data, plenty for Epic 6.8 meta-retrospective windows (quarterly)

If Epic 6.8 needs longer retention, parameterize `rotation.max_days` per stream — do not disable rotation (PII accumulates).

Disk-usage spot check: `du -sh .claude/telemetry/data/` (or see `telemetry-queries.md → Rotation + disk usage`).

### Flip console → OTLP

After the collector is verified running (Phase 2 acceptance gate), flip exporters in `.claude/settings.json → env`:

```json
"OTEL_LOGS_EXPORTER": "otlp",
"OTEL_METRICS_EXPORTER": "otlp",
"OTEL_TRACES_EXPORTER": "otlp",
"OTEL_EXPORTER_OTLP_ENDPOINT": "http://127.0.0.1:4318",
"OTEL_EXPORTER_OTLP_PROTOCOL": "http/protobuf"
```

Remove the three `console` exporter lines (keep `OTEL_METRIC_EXPORT_INTERVAL` and `OTEL_LOG_USER_PROMPTS`).

**Do not commit this edit unless the collector is up.** If the endpoint is unreachable, the host silently drops telemetry. Pre-flip check: `nc -z 127.0.0.1 4318` must pass.

### Hook-bridge POC (Phase 2 acceptance)

Decision record: `../../evolution/25-telemetry-substrate/decisions/hook-bridge-pattern.md` (pattern c — filelog tail).

POC procedure:
1. Confirm collector running.
2. In a fresh session, trigger a `session-gate.sh` event (e.g. a Write to a managed directory that would fail or warn the chain check).
3. Wait ~10s for filelog operator pipeline to process.
4. Query the logs/hooks stream:

```sh
jq -r '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="source" and .value.stringValue=="d7dev.hook"))
  | select(.attributes[]? | select(.key=="hook" and .value.stringValue=="session-gate"))
  | .body
' .claude/telemetry/data/logs.jsonl | tail
```

5. Expected: recent session-gate event with outcome, tool, hashed file.path (not raw path).
6. Capture the query + output in `../../evolution/25-telemetry-substrate/verification/phase2-hook-bridge-poc.md`.

### Stop/start test (Phase 2 acceptance)

Verifies `file_storage` extension prevents double-ingestion across collector restarts.

```sh
# Note current line count in logs
wc -l .claude/telemetry/data/logs.jsonl

# Stop and restart
launchctl kickstart -k gui/$(id -u)/com.d7dev.otelcol
sleep 5

# Trigger one known hook event, confirm only one new log record added (not duplicates of all prior ones)
wc -l .claude/telemetry/data/logs.jsonl
```

---

---

## Phase 3 — Downstream consumption

### Schema-agnostic keying table

OTel span names, metric names, and log record types are **host-versioned**: they may shift when the Claude Code CLI upgrades. Downstream queries must prefer workspace-stable keys over host-versioned names wherever possible. The pin file (`../../evolution/25-telemetry-substrate/host-version-pin.md`) is the source of truth for which names were validated at which host version; when the pin refreshes, re-validate any query that keyed off a host-versioned name.

| Key | Origin | Stability | Use for |
|---|---|---|---|
| `resource["session.id"]` | Workspace (host-emitted, scoped per Claude Code session) | **Stable** — name and semantics fixed in OTel resource convention | All cross-stream joins; per-session rollups |
| `attributes.source` | Workspace (collector operators add `d7dev.host` or `d7dev.hook`) | **Stable** — workspace-authored tag | Distinguish host spans from bridged hook events |
| `attributes.hook` | Workspace (`_lib.sh:log_event()` writes hook name) | **Stable** — workspace-authored | Filter hook-event streams by hook identity |
| `attributes.outcome` | Workspace (`_lib.sh:log_event()` writes pass/warn/block/info/crash) | **Stable** — workspace-authored vocabulary | Hook outcome distribution; rule violation counts |
| `attributes["rule.id"]` | Workspace (Epic 2.3 adds when hook check implements a named rule) | **Stable** after Epic 2.3 Phase 2 | Rule-fire counter aggregation |
| `attributes["directive.variant"]` | Workspace (Epic 6.9 adds at SessionStart) | **Stable** after Epic 6.9 Phase 1 | Variant rollup for directive experiments |
| `attributes["schema.version"]` | Workspace (collector `transform` processor stamps `0.3.0`) | **Stable** — workspace-authored | Version-gate consumer queries |
| Host span names (e.g. `claude.tool.invoke`) | Host (Claude Code CLI) | **Host-versioned** — observed at pin date | Filter only when name is in `host-version-pin.md` |
| Host metric names (e.g. `gen_ai.client.token.usage`) | Host | **Host-versioned** | Filter only when name is in `host-version-pin.md`; prefer matching on `.name | test(...)` with a substring anchor |
| `tool.name` attribute | Host | **Usually stable but verify on upgrade** | Per-tool rollups |
| `type` / `gen_ai.token.type` attribute | Host | **Host-versioned** | Split token cost into input vs output |

**Query practice:** when a query must key on a host-versioned name, it cites this runbook and the pin file. The pin-file refresh checklist includes a step to inspect consumer-brief query snippets and re-validate any that key off the changed names.

### Consumer query patterns

Each downstream epic's `brief.md` carries a `## Telemetry substrate consumption (from Epic 0.3)` section that names its stream, its keying, and any host-versioned names it depends on. Index:

| Epic | Directory | Primary stream | Key workspace-stable attributes |
|---|---|---|---|
| 1.2 Unified session event log | `../../evolution/02-unified-session-state-log/` | `logs.jsonl` + `spans.jsonl` | `session.id`, `source`, `hook`, `outcome` |
| 2.3 Rule efficacy telemetry | `../../evolution/05-rule-efficacy-telemetry/` | `logs.jsonl` (hook-bridged) | `rule.id`, `outcome` |
| 5.2 Agent cost dispatch | `../../evolution/07-agent-cost-dispatch/` | `metrics.jsonl` | `session.id`, (host) `gen_ai.token.type` |
| 6.8 Meta-retrospective | `../../evolution/23-meta-retrospective/` | All three streams across rotated backups | `session.id`, `source`, `hook`, `rule.id` |
| 6.9 Directive efficacy experiments | `../../evolution/24-directive-efficacy-experiments/` | `logs.jsonl` + `metrics.jsonl` + `spans.jsonl` | `directive.variant`, `session.id` |

Queries appear in `telemetry-queries.md`. Each consumer epic's brief names the specific query shape it relies on; query updates that affect a named shape should be cross-referenced to the consumer brief for re-validation.

---

## Related
- Query examples runbook: `telemetry-queries.md` (Phase 2)
- Host-version pin: `../../evolution/25-telemetry-substrate/host-version-pin.md` (Phase 2)
- Hook-bridge decision: `../../evolution/25-telemetry-substrate/decisions/hook-bridge-pattern.md` (Phase 2)
- Framework §1.4 host-version pinning rule: `../../analytical-orchestration-framework.md` (Phase 3 amendment)
