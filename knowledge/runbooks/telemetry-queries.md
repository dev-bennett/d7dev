# Telemetry queries — example jq pipelines

**Last updated:** 2026-04-20
**Linked runbook:** `telemetry-substrate.md`
**Substrate data:** `.claude/telemetry/data/{spans,metrics,logs}.jsonl` (+ dated rotations)

## Purpose
Reference queries over the local OpenTelemetry collector output. All queries are `jq` pipelines — no database required. The collector writes OTLP/JSON per line; each line is one exporter batch with `resourceSpans[]`, `resourceMetrics[]`, or `resourceLogs[]` arrays.

## Conventions
- Paths assume working directory is the repo root
- Replace `<SESSION_ID>` with the actual session id for session-scoped queries
- Queries use `.resourceLogs[].scopeLogs[].logRecords[]` shape (OTLP/JSON). Exact field paths depend on the collector's OTLP/JSON format — adjust one level if the collector version changes the envelope
- All queries are read-only and safe to run against live data

## Prerequisites
- `jq` installed (`brew install jq`)
- Collector running (Phase 2): `nc -z 127.0.0.1 4318 && echo up`
- At least one session has run since the collector came up

---

## Query 1 — Tool-call frequency (last session)

Count span emissions per tool name from the current day's span stream.

```sh
jq -r '
  .resourceSpans[]?.scopeSpans[]?.spans[]
  | .attributes[]
  | select(.key == "tool.name")
  | .value.stringValue
' .claude/telemetry/data/spans.jsonl \
  | sort | uniq -c | sort -rn
```

Output: counts like `  42 Read`, `  18 Bash`, etc.

---

## Query 2 — Session-level token cost

Sum token-usage metric datapoints for a given session.

```sh
SESSION='<SESSION_ID>'
jq -r --arg s "$SESSION" '
  .resourceMetrics[]?
  | select((.resource.attributes[] | select(.key=="session.id") | .value.stringValue) == $s)
  | .scopeMetrics[]?.metrics[]
  | select(.name | test("token.usage"; "i"))
  | .sum.dataPoints[]?
  | {type: ((.attributes[] | select(.key=="type" or .key=="gen_ai.token.type") | .value.stringValue) // "unknown"),
     value: (.asInt // .asDouble)}
' .claude/telemetry/data/metrics.jsonl \
  | jq -s 'group_by(.type) | map({type: .[0].type, total: (map(.value | tonumber) | add)})'
```

Output: `[{"type":"input","total":142380}, {"type":"output","total":29475}]`

---

## Query 3 — Hook fire counts by hook name

From the hook-bridged log stream (events carrying `source=d7dev.hook`).

```sh
jq -r '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="source" and .value.stringValue=="d7dev.hook"))
  | .attributes[]
  | select(.key=="hook")
  | .value.stringValue
' .claude/telemetry/data/logs.jsonl \
  | sort | uniq -c | sort -rn
```

Output: fire count per hook name. Feeds Epic 2.3 rule-fire telemetry after `rule.id` attribution lands.

---

## Query 4 — Hook outcome distribution (pass / warn / block / crash)

Ratio of outcomes per hook.

```sh
jq -r '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="source" and .value.stringValue=="d7dev.hook"))
  | [
      (.attributes[] | select(.key=="hook")    | .value.stringValue),
      (.attributes[] | select(.key=="outcome") | .value.stringValue)
    ]
  | @tsv
' .claude/telemetry/data/logs.jsonl \
  | sort | uniq -c | sort -rn
```

Output: `   42 session-gate   pass`, `    5 session-gate   warn`, etc. Flag any hook with `crash` lines — `errors.log` should also show them.

---

## Query 5 — Latency P50 / P95 / P99 per tool type

Reads `elapsed_ms` from hook log records (host-side tool latency is on the span `duration` and requires a different pipeline — see Query 6). Uses a helper to compute percentiles.

```sh
jq -r '
  .resourceLogs[]?.scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="source" and .value.stringValue=="d7dev.hook"))
  | [
      (.attributes[] | select(.key=="tool")       | .value.stringValue // ""),
      (.attributes[] | select(.key=="elapsed_ms") | (.value.intValue // .value.doubleValue // 0))
    ]
  | @tsv
' .claude/telemetry/data/logs.jsonl \
  | awk -F'\t' '$1 != "" { a[$1] = a[$1] " " $2 }
    END {
      for (tool in a) {
        n = split(a[tool], vals, " "); delete vals[""];
        # sort
        asort(vals);
        p50 = vals[int(n*0.50)+1]; p95 = vals[int(n*0.95)+1]; p99 = vals[int(n*0.99)+1];
        printf "%-12s  n=%-5d  p50=%-5d  p95=%-5d  p99=%-5d\n", tool, n, p50, p95, p99
      }
    }'
```

Output: latency percentiles per tool.

---

## Query 6 — Cross-stream correlation (host span duration vs hook elapsed_ms)

Join host-emitted tool-invoke spans with the corresponding `workflow-tracker` hook log, both keyed on `session.id`. Establishes a baseline for hook overhead.

```sh
SESSION='<SESSION_ID>'

# Host side: tool name + duration
jq -r --arg s "$SESSION" '
  .resourceSpans[]?
  | select((.resource.attributes[] | select(.key=="session.id") | .value.stringValue) == $s)
  | .scopeSpans[]?.spans[]
  | select(.attributes[]? | select(.key=="tool.name"))
  | {
      tool: (.attributes[] | select(.key=="tool.name") | .value.stringValue),
      dur_ns: ((.endTimeUnixNano | tonumber) - (.startTimeUnixNano | tonumber)),
      ts: .startTimeUnixNano
    }
  | [.ts, .tool, (.dur_ns / 1000000 | floor)]
  | @tsv
' .claude/telemetry/data/spans.jsonl > /tmp/host-tool-durations.tsv

# Hook side: workflow-tracker elapsed_ms by tool
jq -r --arg s "$SESSION" '
  .resourceLogs[]?
  | select((.resource.attributes[] | select(.key=="session.id") | .value.stringValue) == $s)
  | .scopeLogs[]?.logRecords[]
  | select(.attributes[]? | select(.key=="hook" and .value.stringValue=="workflow-tracker"))
  | [.timeUnixNano,
     (.attributes[] | select(.key=="tool")       | .value.stringValue),
     (.attributes[] | select(.key=="elapsed_ms") | (.value.intValue // .value.doubleValue // 0))]
  | @tsv
' .claude/telemetry/data/logs.jsonl > /tmp/hook-elapsed.tsv

paste /tmp/host-tool-durations.tsv /tmp/hook-elapsed.tsv | head -20
```

Output: per-invocation host duration vs hook overhead. Used to prove Phase 2 acceptance (hooks add negligible latency).

---

## Redacted-value check (scrubbing validation)

Run after Phase 2 verification to prove the scrubbing processor is working.

```sh
# Should return 0 matches
grep -Ei '"prompt.text"|"user.prompt"|"tool.input.prompt"|"tool.input.content"' \
  .claude/telemetry/data/*.jsonl
```

If any match: the collector's `attributes/scrub` processor is misconfigured or host emitted an attribute the processor does not cover. Inspect, add rule, re-run.

---

## Rotation + disk usage

Daily spot check — runs in <1s, safe in health-check.

```sh
du -sh .claude/telemetry/data/
ls -lh .claude/telemetry/data/*.jsonl 2>/dev/null | sort -k5 -h | tail
```

Expected ceiling: ~1.5 GB (3 streams × 50 MB × 10 backups). If approaching the ceiling, check that the collector's `rotation.max_backups` is applied (collector restart may be required to pick up config change).

---

## Troubleshooting

**No output from any query.** Collector not running, or log files empty. Check `nc -z 127.0.0.1 4318` and `tail .claude/telemetry/collector.log`.

**`jq: error` with "null cannot be iterated."** OTLP/JSON envelope version differs from assumption. Inspect one record: `jq 'keys' < .claude/telemetry/data/logs.jsonl | head`. Adjust field paths.

**Query 2 returns 0.** Session ID mismatch, or session predates collector startup. Confirm with `jq -r '.. | .["session.id"]? // empty' .claude/telemetry/data/logs.jsonl | sort -u`.

**Query 5 returns NaN for p95/p99.** Sample size too small. Needs ≥20 invocations of that tool in the stream.
