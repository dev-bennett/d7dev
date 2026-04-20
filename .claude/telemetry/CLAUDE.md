# Telemetry workspace

@../../CLAUDE.md

## Purpose
Holds the local OpenTelemetry collector configuration, launchd plist template, and (gitignored) data/state directories for Epic 0.3's telemetry substrate.

## Files (committed)
- `otelcol-config.yaml` — collector config: OTLP + filelog receivers → scrub/batch processors → file exporters
- `com.d7dev.otelcol.plist.template` — launchd agent template for auto-start on login

## Directories (gitignored — local-only)
- `data/` — JSONL exporter output: `spans-*.jsonl`, `metrics-*.jsonl`, `logs-*.jsonl`
- `state/` — filelog receiver checkpoint (`file_storage` extension)
- `collector.log` — collector stdout/stderr (launchd)

## Local-only boundary
This directory holds PII (prompts, file paths, tool arguments). The gitignore excludes `data/`, `state/`, and `collector.log`. Do not move these outside the repo, sync them to a cloud drive, or back them up across boundaries. Loopback-only endpoint enforcement in `otelcol-config.yaml`.

## Linked artifacts
- Epic brief: `../../evolution/25-telemetry-substrate/brief.md`
- Runbook: `../../knowledge/runbooks/telemetry-substrate.md`
- Hook-bridge decision: `../../evolution/25-telemetry-substrate/decisions/hook-bridge-pattern.md`
- Host-version pin: `../../evolution/25-telemetry-substrate/host-version-pin.md`
