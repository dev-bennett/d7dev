# 2026-05-05 — Enterprise Activity → HubSpot Companies via Polytomic

@../CLAUDE.md

## Scope

Wire the deferred Polytomic sync for `marts/enterprise/fct_enterprise_user_activity_for_scoring`
(merged in PR #719, never connected to HubSpot). Phase A only — covers the
~1,249 Chargebee-billed enterprise customers (≈18% of HubSpot enterprise
deals); the remaining ~5,500 non-Chargebee enterprise deals are deferred
to Phase B (separate identity-bridge work).

## Conventions

- dbt promotion follows `feedback_dbt_promotion_sop` — work in dbt Cloud
  web IDE on `develop_dab`, PR base is `main`, no local CLI.
- Standard artifact set: README + findings + runbook + commit-message.txt
  + pr-description.md + dbt-updates/ + verify/.
- Stakeholder-facing prose (README, findings) goes through the §10
  Writing Scrub.
- Calibration check on touched tables before queries are kept.
