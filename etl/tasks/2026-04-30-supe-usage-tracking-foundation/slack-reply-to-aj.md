Reply to AJ Robertson — Slack thread on PR #4147 (Supe usage tracking foundation).
Plain text. Paste-ready (no markdown tables; backticks render as code in Slack).

---

One correctness thing on the gross-margin starter query: `customer_overage_rate_cents` is the per-event overage rate, charged only beyond `Contract.supe_operation_limit`, but the query sums it across all billable/cached_billable rows — conflates "rate × all billable events" with "rate × events beyond limit." Hidden today since the seed sets `overage_rate_cents = 0` everywhere; once a real rate lands, in-limit events get counted as revenue.

Tiny doc nit: the `supe_usage_events` index table lists FK-auto indexes on `api_key_id` and `supe_search_id`, but both are suppressed via `index: false` in the migration. Composite `(api_key_id, occurred_at)` and the partial-unique on `supe_search_id WHERE NOT NULL` cover.

Will follow up separately with query suggestions for the doc.
