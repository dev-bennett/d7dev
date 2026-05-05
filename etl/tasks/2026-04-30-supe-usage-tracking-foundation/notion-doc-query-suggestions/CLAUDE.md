@../CLAUDE.md

# Notion-doc query suggestions

Drafts of starter queries for AJ's "Data Team Reference — Supe Usage Tracking Tables" Notion page. Responsive to AJ's 2026-04-30 ask: *"Let me know if … there are queries you'd want me to add to the doc."*

## Files

- `queries.sql` — labeled query drafts (q1+, Postgres dialect to match AJ's existing examples in the doc)
- `slack-followup-to-aj.md` — paste-ready Slack message linking the queries

## Targeted candidates (from README §5)

1. Cohort lifetime margin per contract — extends AJ's period-to-date view
2. Cost-per-request anomaly detection — top-percentile flagging on `estimated_cost_cents`
3. Rate-limit headroom × velocity — % of `supe_operation_limit` consumed × days remaining
4. Cache-hit rate segmented by request shape
5. Failure-class decomposition — `failed_customer_fault` vs `failed_platform_fault` × `finish_reason`
6. NullContract activity monitor — count of events with `contract_id IS NULL` per api_key per week

## Dialect

Postgres. AJ's existing examples in the doc use `MAKE_DATE`, `INTERVAL`, `FILTER (WHERE ...)`, `::numeric` — keep those for consistency. Snowflake translation lives in dbt staging, not in his customer-facing doc.

## Status

Not yet drafted. Schema-review reply went out separately (see `../slack-reply-to-aj.md`).
