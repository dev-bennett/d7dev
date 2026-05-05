@../CLAUDE.md

# 2026-04-30 — Mixpanel Mac/OS Validation

Validation that `pc_stitch_db.mixpanel.export` carries device/OS attributes sufficient to identify Mac (desktop macOS) users.

**Triggered by:** Dave Kart's Slack ask 2026-04-30 — Soundstripe Live (previously Cue) beta target list. Verbatim message + interpretation in `context.md`.

**Status:** data validation done. Awaiting target user list from Dave to execute the per-user lookup.

## Source

- Table: `pc_stitch_db.mixpanel.export` (raw Mixpanel export via Stitch)
- Calibration: `knowledge/data-dictionary/calibration/pc_stitch_db__mixpanel__export.md`
- Note: device/OS columns are dropped from `core.fct_events` — must query the raw export for this dimension.

## Files

- `context.md` — originating Slack ask, interpretation, open questions for Dave, next-step plan
- `console.sql` — q1 schema discovery, q2 fill rates, q3 OS distribution at user grain, q4 user-agent spot-check
- `findings.md` — validation result and canonical filter
