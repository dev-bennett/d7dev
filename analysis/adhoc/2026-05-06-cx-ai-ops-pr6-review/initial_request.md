# Initial Request

## From Devon

Danielle has asked for my review on this PR where she will be introducing some of my recommended guardrails into her repo to handle her own snowflake mcp connector usage. Provide me with some guidance on how to help close out this review request - and no need to reach for recommendations if the way it is currently set up will work well for her to start using the connector relatively safely.

https://github.com/SoundstripeEngineering/cx-ai-ops/pull/6

Follow-up: confirm whether SELECT_ANALYST has access to hubspot_platform_data — that should be the default DB for her function. If not, run whatever is necessary to grant her access.

## PR context (SoundstripeEngineering/cx-ai-ops#6)

- Author: @desumm21 (Danielle)
- Branch: `docs/snowflake-rules` → `main`
- Files: `CLAUDE.md` (+9), `SNOWFLAKE_RULES.md` (+282, new)
- State: OPEN, docs-only
- Connection profile per PR: account `QZ67029`, role `SELECT_ANALYST` (read-only), warehouse `DATA_SCIENCE`

### Her four open questions (§14 of SNOWFLAKE_RULES.md)

1. Was `hubspot_platform_data` a real third schema, or a misremembering? She'd verified `PC_STITCH_DB.HUBSPOT_NEW.*` and `SOUNDSTRIPE_PROD.HUBSPOT.*` and didn't find HPD.
2. Should `knowledge/` (referenced for `query-patterns/` and `data-dictionary/calibration/`) live in cx-ai-ops or elsewhere?
3. Should any rules be promoted to global `~/.claude/CLAUDE.md`?
4. Spot-check `PC_STITCH_DB.HUBSPOT_NEW.TICKETS` columns — does it actually expose `pipeline`, `subject`, `hs_pipeline_stage`, owner ID, created/updated dates, source?
