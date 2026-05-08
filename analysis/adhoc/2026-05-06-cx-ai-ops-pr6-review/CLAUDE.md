# cx-ai-ops PR #6 Review — 2026-05-06

@../CLAUDE.md

## Purpose

Close out Danielle's review request on [SoundstripeEngineering/cx-ai-ops#6](https://github.com/SoundstripeEngineering/cx-ai-ops/pull/6) — `SNOWFLAKE_RULES.md` adapting d7dev's Snowflake MCP rules into her cx-ai-ops repo.

## Scope

Answer her four §14 open questions, surface any factual issues found during verification, and provision the Snowflake grants she needs to actually run the rules as written.

## Files

- `initial_request.md` — Devon's request as posted, plus the original PR body for context
- `review-body.md` — drafted PR review comment (Approve, with §1 fix flagged before merge)
- `grant-hpd-to-select-analyst.sql` — ACCOUNTADMIN-runnable GRANTs giving SELECT_ANALYST access to `HUBSPOT_PLATFORM_DATA.V2_DAILY`
- `verification.sql` — post-grant checks Devon (or Danielle) runs to confirm the grants landed

## Key findings (driving the review)

1. `HUBSPOT_PLATFORM_DATA` exists, contradicting §1 of the PR. It's HubSpot's native data share (V2_DAILY: 784 tables, 1.63B rows, last refreshed 2026-05-05). Materially the right home for HubSpot event-grain analysis — different population from `PC_STITCH_DB.HUBSPOT_NEW`.
2. SELECT_ANALYST currently has zero grants on HUBSPOT_PLATFORM_DATA (verified via `snowflake.account_usage.grants_to_roles`). HPD ownership = ACCOUNTADMIN; Devon holds ACCOUNTADMIN, so the grants are his to issue.
3. `PC_STITCH_DB.HUBSPOT_NEW.TICKETS` columns confirmed (328 cols), with the `PROPERTY_*`/`PROPERTY_HS_*` Stitch flattening prefix worth surfacing in the rules — `pipeline` is `PROPERTY_HS_PIPELINE`, not `pipeline`.

## Conventions

- Verbatim element names from the PR (§ numbers, schema names) when referencing back to her doc.
- All deliverables live here, not in `/tmp/`.
