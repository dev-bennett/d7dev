# Project 25: Telemetry substrate (OpenTelemetry)

## Overview
Claude Code supports OpenTelemetry export when `CLAUDE_CODE_ENABLE_TELEMETRY=1` is set alongside OTLP exporter configuration. Enabled, the host emits structured spans, metrics, and logs for every tool invocation, session lifecycle event, token usage, and latency. Without it, verification of any system-behavior claim reduces to reading transcripts and trusting the narrative. The user has explicitly rejected this mode of work: downstream measurement epics must rest on a verifiable substrate, not on agent self-reports.

This project enables the substrate and documents consumption patterns for the five downstream epics that depend on it.

## Linked framework section
`../../analytical-orchestration-framework.md` §1.4 Runtime substrate (observability). User-introduced after the initial gap audit.

## Linked epic
Epic 0.3 — Telemetry substrate (OpenTelemetry), P1, Swimlane 0

## End goal
1. `CLAUDE_CODE_ENABLE_TELEMETRY=1` set in the project settings env block alongside `OTEL_LOGS_EXPORTER`, `OTEL_METRICS_EXPORTER`, `OTEL_EXPORTER_OTLP_ENDPOINT`
2. A local OTLP collector (console exporter for dev; file / duckdb / sqlite exporter for persistent capture) is running and configurable via documented launchd or standalone command
3. A documented retention policy (how long spans/metrics/logs are kept; what rotation looks like)
4. A query pattern documented in `knowledge/runbooks/telemetry-queries.md` with concrete examples (tool-call frequency, session-level token cost, hook fire counts, latency percentiles)
5. Downstream epics reference the collector output as their primary measurement substrate:
   - Epic 1.2 (unified session event log) projects collector output to JSONL rather than rolling its own
   - Epic 2.3 (rule efficacy) aggregates counters from OTel metrics
   - Epic 5.2 (cost-aware dispatch) reads token-cost from OTel
   - Epic 6.8 (meta-retrospective) reads corpus-level metrics from OTel
   - Epic 6.9 (directive efficacy experiments) reads outcome metrics from OTel

## Phased approach

### Phase 1 — Enable + local console capture
**Complexity:** Low
**Exit criteria:** OTel spans + metrics visible on the console during a normal session; env block committed in `.claude/settings.json`; user has verified a `/orient` run produces expected span output.
**Steps:**
- Add env block to `.claude/settings.json`:
  ```json
  "env": {
    "CLAUDE_CODE_ENABLE_TELEMETRY": "1",
    "OTEL_LOGS_EXPORTER": "otlp",
    "OTEL_METRICS_EXPORTER": "otlp",
    "OTEL_EXPORTER_OTLP_ENDPOINT": "http://localhost:4318"
  }
  ```
- For initial verification, use a console exporter (no endpoint) or install a minimal local collector
- Run `/orient` and confirm spans emit
- Document what the host emits vs what it doesn't (this informs which downstream epics can consume which signals)

### Phase 2 — Local collector + persistence + hook-bridge design
**Complexity:** Medium
**Exit criteria:** A local OTLP collector (otelcol-contrib recommended) runs as a background process; writes spans/metrics/logs to disk with a documented retention policy; a query example works end-to-end; the hook→OTel bridging pattern is chosen and documented so Epic 1.2 can consume hook events through the same substrate as host events.
**Steps:**
- Choose collector (otelcol-contrib for flexibility)
- Configuration: OTLP receiver, file exporter (JSON Lines), optional duckdb/sqlite exporter for queryability
- Installation script or launchd config
- Retention: rotate by size + age; retention policy documented; local-only boundary enforced (no sync, no backup crossing)
- **Hook-bridge design decision.** Pick one of: (a) hooks emit structured events to stdout/stderr in a documented schema; collector's filelog/tail receiver ingests them. (b) sidecar script wraps hook invocations via a `PostToolUse` observer. (c) hooks write to a file the collector tails. Decision is documented, and a single proof-of-concept hook demonstrates the pattern end-to-end before Epic 1.2 migrates.
- Query examples committed to `knowledge/runbooks/telemetry-queries.md`

### Phase 3 — Downstream consumption
**Complexity:** Medium-High
**Exit criteria:** Epic 1.2 (unified event log) and Epic 2.3 (rule telemetry) have documented consumption patterns referencing the collector output; example queries ship in the knowledge runbook.
**Steps:**
- Coordinate with Epic 1.2 to make OTel the primary event substrate; hooks emit via stdout shim or direct OTel SDK
- Coordinate with Epic 2.3 to aggregate rule-fire counters from OTel metrics rather than hand-rolled state files
- Coordinate with Epic 5.2 to read real token-cost from OTel rather than estimating
- Update downstream epic briefs to reflect OTel consumption

## Dependencies
- None upstream. This is a leaf-node P1 enabler.

## Risks

### Surface risks (manage via configuration)
- **Collector disk footprint.** Mitigation: retention policy with rotation; cap on disk usage.
- **Telemetry captures sensitive data (prompts, tool arguments, stakeholder info).** The stream carries PII wherever it flows — collector storage, JSONL projections consumed by Epic 1.2, any query script. Mitigation: local-only retention; no external export; no crossing of sync/backup boundaries; scrubbing filters for known-sensitive fields documented. Downstream epics consuming the stream (1.2, 2.3, 5.2, 6.8, 6.9) inherit this constraint and must not persist spans to locations that cross the local boundary.
- **Dev-mode console exporter floods stdout.** Mitigation: prefer file/collector exporter over console outside of Phase 1 verification.

### Structural risks (must be addressed during the phased work, not just noted)

- **Hook→OTel emission gap.** The host runtime emits spans natively when telemetry is enabled, but the project-scope shell hooks in `.claude/hooks/*.sh` cannot emit OTel spans without either an OTel SDK in-script (impractical for bash) or a bridging mechanism. The env-block enablement looks like a single-switch operation; in reality, making hook events queryable via the same OTel substrate requires additional work: (a) hooks emit structured events to stdout/stderr in a schema the collector understands, (b) the collector has a filelog or tail receiver configured to ingest them, or (c) a sidecar script wraps hook invocations and emits spans on their behalf. This is Phase 2 scope, not Phase 1. A pre-Phase-2 design decision is required on which pattern to use and where the bridging code lives.

- **Host-runtime schema versioning with downstream-consumer blast radius.** OTel span names, attributes, and granularity are a function of the host-runtime version. When the host changes (new Claude Code release), span schemas may change. Every downstream epic consuming the stream is affected: Epic 1.2 event-log projection, Epic 2.3 rule counter aggregations, Epic 5.2 cost metrics, Epic 6.8 meta-retrospective queries, Epic 6.9 experiment outcome measurements. Two mitigations required:
  1. Pin the collector config to the known-tested host version; gate host upgrades on collector/query compatibility testing.
  2. Downstream consumers use schema-agnostic queries where possible (match on attribute presence, not exact attribute names) and version-test against a small corpus of known-good spans.
  Framework doc §1.4 should explicitly note this version-pinning requirement when referencing Epic 0.3.

## Out of scope
- External observability backend (Jaeger, Tempo, cloud APM). Local-only by default.
- Application-level instrumentation of custom Python scripts in `scripts/` — that's a separate concern if it becomes needed.
- Automated alerting on telemetry signals — downstream epics (rule efficacy proposals, drift detection) handle their own alerting patterns.

## Downstream beneficiaries
- Epic 1.2 (unified session event log)
- Epic 2.3 (rule efficacy telemetry)
- Epic 5.2 (cost-aware agent dispatch)
- Epic 6.8 (meta-retrospective)
- Epic 6.9 (directive efficacy experiments)

## Why P1
Without verifiable telemetry, every downstream claim about "did the agent follow the rule," "did the hook fire," "did the directive catch the violation," "did the critic flip the finding" reduces to reading assistant-authored transcripts. The user has stated this explicitly: work that depends on "me accepting the output based on a promise" is not acceptable. OTel is the substrate that makes all subsequent work verifiable rather than promissory.
