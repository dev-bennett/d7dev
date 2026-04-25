---
table: soundstripe_prod.core.fct_sessions
last_calibrated: 2026-04-24-r2
schema_hash: b92eee133013eb75087729c926fd2ac95d890d6f6cbf6ec58225333ae9ce55b1
dbt_model: marts/core/fct_sessions.sql
row_count: 42000676
bytes_gib: 4.59
col_count: 79
---

# core.fct_sessions — Calibration

## Purpose (business meaning)

One row per consolidated web/app session. The canonical session-grain fact table for site analytics — traffic volume, channel attribution, engagement depth, and conversion events per visit. Sourced from Mixpanel via a multi-step dbt build chain that stitches cross-host and cross-device sessions using profile ID mapping and a 30-minute session-break heuristic. Covers sessions from ~2021 through the present; ~42M rows total. Used as the primary table for marketing attribution reporting, channel trend analysis, funnel conversion rates, and experiment session-level outcome measurement.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/fct_sessions.sql`
- **Upstream dbt refs (immediate):** `ref("fct_sessions_build_step2")`
- **Upstream dbt chain:**
  - `fct_sessions_build_step2` refs `ref("fct_sessions_build")` and `ref("distinct_id_mapping")`
  - `fct_sessions_build` is the per-raw-session staging step (Mixpanel → session boundaries)
  - `distinct_id_mapping` is the cross-host identity bridge (www ↔ app profile_id consolidation)
- **Materialization:** table (non-incremental mart)
- **Incremental watermark behavior:** n/a — full table rebuild. No incremental predicate; does not inherit fct_events' late-arrival drop issue directly.

### Cross-host session consolidation mechanic (fct_sessions_build_step2)

`fct_sessions_build_step2` merges raw per-host sessions into consolidated sessions via two steps:
1. `distinct_id_mapping` LEFT JOIN — maps old `distinct_id` to a consolidated `profile_id` (www ↔ app identity stitching)
2. Session-break heuristic — a new primary session opens when: (a) it's the user's first session, OR (b) the gap from the prior `SESSION_ENDED_AT` to current `SESSION_STARTED_AT` > 30 minutes

Post-consolidation cross-host sessions (e.g., a visit that touched both www.soundstripe.com and app.soundstripe.com within 30 minutes) are stitched into a single row. The `CONSOLIDATED_SESSIONS` and `CONSOLIDATED_DISTINCT_IDS` ARRAY columns carry all the component raw session IDs and distinct_ids merged into the consolidated record.

### Attribution waterfall in fct_sessions.sql

The final model applies a non-direct last-touch window over `profile_id` ordered by `session_started_at ASC`:
- `LAST_CHANNEL_NON_DIRECT` — `LAST_VALUE(CHANNEL) IGNORE NULLS OVER (...)` defaulting to `'Direct'` when no prior non-null channel exists
- Same pattern for `LAST_UTM_*_NON_DIRECT`, `LAST_REFERRER_NON_DIRECT`, `LAST_REFERRING_DOMAIN_NON_DIRECT`
- `CHANNEL` (raw) = the entry channel for this specific session (NVL → 'Direct')

## Columns (primary + frequently used)

Full schema: 79 columns. Listed here: PK + most-used columns by LookML dimension frequency and prior analysis usage.

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `session_id` | TEXT | `fct_sessions_build_step2.PRIMARY_SESSION_ID` | Consolidated session identifier. **Primary key in fct_sessions.** | NOT the same as `fct_events.session_id` — bridge via `dim_session_mapping` required |
| `distinct_id` | TEXT | `fct_sessions_build_step2.profile_id` | Consolidated visitor ID (post-identity-stitching). Not raw Mixpanel distinct_id. | NULL rows filtered in fct_sessions_build_step2 (`WHERE distinct_id IS NOT NULL`) |
| `last_channel_non_direct` | TEXT | Window function over `channel` | Non-direct last-touch channel attribution for this visitor's session history. **The standard attribution column for channel analysis.** | Defaults to `'Direct'` via NVL. Cross-session attribution: the value reflects the visitor's last known non-direct channel across all prior sessions, not only this session's entry |
| `channel` | TEXT | Entry channel for this session | Raw entry channel (what this session's referrer/UTM resolved to). | NVL → `'Direct'`. Differs from `last_channel_non_direct` — using `channel` for pre/post attribution comparisons changes the Direct share significantly |
| `session_started_at` | TIMESTAMP_NTZ | min(session_started_at) across merged raw sessions | Session start timestamp | Primary time axis; always date-scope queries |
| `session_ended_at` | TIMESTAMP_NTZ | max(session_ended_at) across merged raw sessions | Session end timestamp | NULL if session has no recorded end event |
| `session_duration_seconds` | NUMBER | DATEDIFF seconds: session_started → ended | Session duration in seconds | LookML `bounced_sessions` dimension uses ≤1s + no conversions as its bounce definition — different from the `bounced_sessions` column (which is `CASE WHEN pageviews = 1 THEN 1 ELSE 0 END`) |
| `landing_page_host` | TEXT | max(LANDING_PAGE_HOST) across merged sessions | Hostname of the session's landing page | Pre-2026-03-16: `www.soundstripe.com` or `app.soundstripe.com`. Post-consolidation: `soundstripe.com`. **Host values change at the cutover date** — host-based filters or pivots break across 2026-03-16 |
| `landing_page_path` | TEXT | max(LANDING_PAGE_PATH) across merged sessions | Path of the session's landing page | Pre-consolidation app paths (e.g., `/search`) map to `/library/search` post-consolidation |
| `landing_page_category` | TEXT | `LANDING_PAGE_CATEGORY` from fct_sessions_build | Classifier-derived page category | `page_category` classifier in `stg_events.sql` is broken for pricing/checkout/signup/sign_in since 2026-03-17. OPEN. Do not filter on these categories — use path-based filters instead |
| `bounced_sessions` | NUMBER | `CASE WHEN pageviews = 1 THEN 1 ELSE 0 END` | 1 if session had exactly one pageview, else 0 | Model definition: single-pageview = bounce. LookML view defines bounce differently (duration ≤1s AND no conversions). The two differ — specify which definition you're using |
| `has_app_view` | NUMBER | max(has_app_view) across merged sessions | 1 if the session included at least one page view on the former app domain (`app.soundstripe.com` or post-consolidation `/library/*` pages) | Available and confirmed in schema (col 43). Use to segment sessions that touched app-equivalent content |
| `has_www_view` | NUMBER | max(has_www_view) across merged sessions | 1 if the session included at least one page view on the marketing site (`www.soundstripe.com` domain pages) | Available and confirmed in schema (col 44). Symmetric to `has_app_view` |
| `country` | TEXT | Mixpanel IP resolution | IP-based country | **Contaminated 2026-03-05→2026-03-25 for Direct channel** — Fastly shield POP IPs produced false DE/NL/CA. Second contamination window 2026-04-14→2026-04-17 (CN/APAC). See pitfalls |
| `browser` | TEXT | Mixpanel | Browser name | Chrome dominated both contamination windows — not a reliable discriminator alone |
| `pageviews` | NUMBER | sum(pageviews) across merged sessions | Total pageviews in the session | |
| `created_subscription` | NUMBER | sum(CREATED_SUBSCRIPTION) | 1 or more if the session produced a subscription | |
| `enterprise_form_submissions` | NUMBER | sum(enterprise_form_submissions) | Enterprise pricing-page form submissions | |
| `signed_up` | NUMBER | sum(signed_up) | Sign-up events in the session | |
| `consolidated_sessions` | ARRAY | array_agg(distinct SESSION_ID) | All raw session IDs merged into this consolidated session | Useful for debugging consolidation logic; not needed in typical analyses |

Full schema (79 cols): `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema = 'CORE' AND table_name = 'FCT_SESSIONS' ORDER BY ordinal_position`.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.dim_session_mapping` | `fct_sessions.session_id = dim_session_mapping.session_id` | 1:N (one consolidated session → many raw session IDs) | Bridge to fct_events; see below |
| `core.fct_events` | via `dim_session_mapping` only: `dim_session_mapping.session_id_events = fct_events.session_id` | M:1 per event → consolidated session | **Never join fct_events directly to fct_sessions on session_id.** The two session_id namespaces are different. Two-hop bridge is mandatory. See `knowledge/query-patterns/session_event_bridge.sql` |
| `core.dim_users` | `fct_sessions.user_id = dim_users.id` | M:1 | Only valid for authenticated sessions; NULL user_id = anonymous |

## Grain & identity

- **Grain:** one row per consolidated session (post cross-host stitching)
- **Primary key:** `session_id` (= `PRIMARY_SESSION_ID` from `fct_sessions_build_step2`)
- **Distinct-user column:** `distinct_id` (post-consolidation `profile_id`, not raw Mixpanel distinct_id). For authenticated-user analyses, prefer `user_id`
- **Session counter:** `session_counter` is a within-visitor ordinal session number (ROW_NUMBER over profile_id ordered by `session_started_at`). Useful for new-visitor vs. return-visitor segmentation

## Typical usage patterns

- **Date scoping:** scope on `session_started_at`. ~42M rows total; rows/day ≈ 37K (based on ~42M / ~3 years). A 30-day window scans ~1.1M rows. Query cost is low relative to fct_events (P50 ~1s, bytes typically <1 MB for aggregates)
- **Channel analysis:** use `last_channel_non_direct` for marketing attribution; use `channel` only when the intent is "what brought the user here today" regardless of history
- **Pre/post cutover comparisons (2026-03-16 domain consolidation):** filter on `landing_page_host` with awareness that the host values change at the cutover. Use `has_app_view` / `has_www_view` for content-type segmentation that survives the host rename
- **Contamination exclusion:** for Direct channel analyses touching 2026-03-05→2026-03-25 or 2026-04-14→2026-04-17, apply the contamination filter: `NOT (last_channel_non_direct = 'Direct' AND country IN ('DE','NL','CA') AND bounced_sessions = 1)` for the first window; `NOT (last_channel_non_direct = 'Direct' AND country IN ('CN','SG','VN','HK','JP') AND bounced_sessions = 1)` for the second
- **Canonical queries:** `knowledge/query-patterns/session_event_bridge.sql` — bridge pattern from fct_sessions to fct_events

## Known pitfalls

### 1. Contamination zone 1: 2026-03-05→2026-03-25 (Fastly shield POP / pre-render artifact)

Confirmed (engineering, Luke Capizano, 2026-04-01). During the domain consolidation rollout, the pre-rendering service cache clears triggered infrastructure-sourced Chrome sessions classified as Direct. Fastly shield POP locations (DE/NL/CA) dominated `country` for Direct sessions during this window. ~160K+ excess Direct sessions over the period. Sessions peak at 75K/day (2026-03-18) vs ~7-8K baseline.

Signature: `last_channel_non_direct = 'Direct'`, `country IN ('DE','NL','CA')`, `bounced_sessions = 1`, `browser = 'Chrome'`, `landing_page_host` transitions from `www.soundstripe.com` to `soundstripe.com` mid-window.

Source: `analysis/data-health/2026-04-01-direct-traffic-spike/2026-04-01-direct-traffic-spike.md`

### 2. Contamination zone 2: 2026-04-14→2026-04-17 (APAC / library path enumeration — OPEN)

Second spike, unconfirmed root cause. Direct sessions concentrated on APAC countries (CN dominant, SG/VN/HK/JP) with 97% bounce, ~33s avg duration, 95% of spike events on `/library/sound-effects/{id}`, `/library/songs/{id}`, `/library/video*` paths. Leading hypothesis is another pre-render/sitemap recrawl event; scraping hypothesis is unconfirmed and should not be assumed. Requires engineering confirmation (Fastly access logs).

Signature: `last_channel_non_direct = 'Direct'`, `country IN ('CN','SG','VN','HK','JP')`, `bounced_sessions = 1`, `landing_page_path LIKE '/library/%'`

Source: `analysis/data-health/2026-04-17-direct-traffic-spike/CLAUDE.md` (OPEN)

### 3. `channel` vs `last_channel_non_direct` — semantic difference in pre/post comparisons

`channel` = the raw entry channel for the specific session (what referrer/UTM the current session had). `last_channel_non_direct` = the non-direct last-touch channel across the visitor's entire prior session history (windowed LAST_VALUE over all sessions for that profile_id, defaulting to 'Direct').

For any pre/post domain consolidation comparison, using `channel` will show an inflated Direct share because the consolidation-period artifact sessions are classified as Direct at entry. Using `last_channel_non_direct` persists prior non-direct attribution and produces different counts. Specify which column you are using and why. See `analysis/data-health/2026-04-17-direct-traffic-spike/console.sql` for query patterns that use `last_channel_non_direct`.

### 3a. Anonymous distinct_id sprawl post-2026-03-16 cutover (NEW, 2026-04-24)

Discovered during domain consolidation impact analysis (`analysis/data-health/2026-04-24-domain-consolidation-impact/`, q17). Logged-in user counts (Organic Search) are stable pre and post (~7,800/week pre, ~8,100/week post — basically flat). Anonymous distinct_ids (Organic Search) surged from ~16-18K/week pre-cutover to ~28-29K/week post-cutover (+76%). Sessions/distinct_id ratio dropped from ~1.6 (stable across 2025 fall and 2026 pre) to ~1.4 post-cutover.

Mechanism: same as documented for `statsig_stable_id` in `project_wcpm_1to1_mapping_exclusion` — cookie-scope/SDK-init changes at the cutover caused anonymous identity fragmentation. Same humans now generate more distinct_ids per real visit. (Cannot be fully disambiguated from "more low-intent SEO traffic" without GSC data, but the logged-in stability + ratio drop is strongly suggestive.)

**Implication for any post-2026-03-16 vs pre-2026-03-16 comparison:**
- Sessions are insulated (a session is a session regardless of identity). Use sessions for traffic comparisons crossing the cutover.
- Visitors (`COUNT(DISTINCT distinct_id)`) is inflated post-cutover. Do NOT use raw distinct_id-based visitor counts as a clean traffic-incrementality metric crossing the cutover.
- Logged-in users (`COUNT(DISTINCT user_id) WHERE user_id IS NOT NULL`) is stable but represents a different population (returning customers); not an SEO-target metric.

Recommendation: until cookie/SDK reconciliation is verified post-cutover, use sessions as the primary visitor-volume proxy for cross-cutover comparisons. Visitor count divergence between fct_sessions and dim_daily_kpis (7-16% q15) is consistent with this pattern.

### 4. Landing page host change at 2026-03-16 cutover

Pre-cutover: `landing_page_host IN ('www.soundstripe.com', 'app.soundstripe.com')`. Post-cutover: all traffic lands on `soundstripe.com` with `/library/*` path prefix for former app pages. Any query that filters or pivots on `landing_page_host` using pre-consolidation values will silently exclude or misclassify post-consolidation sessions. Use `has_app_view` / `has_www_view` for content-type attribution that is stable across the cutover, or build host logic that handles both naming conventions.

Source: `analysis/data-health/2026-04-01-direct-traffic-spike/2026-04-01-direct-traffic-spike.md`; confirmed in dbt SQL via `LANDING_PAGE_HOST` max aggregation in `fct_sessions.sql`.

### 5. Direct session_id join to fct_events is wrong

`fct_events.session_id` and `fct_sessions.session_id` are in different namespaces. `fct_events` carries the raw per-event session_id from Mixpanel; `fct_sessions` carries the consolidated `PRIMARY_SESSION_ID`. A direct JOIN on `session_id` will produce incorrect cardinality — rows will silently not match or fan out. Always bridge via `dim_session_mapping.session_id_events → dim_session_mapping.session_id`. See `knowledge/query-patterns/session_event_bridge.sql`.

Source: `knowledge/query-patterns/session_event_bridge.sql`; memory `reference_session_event_join.md`

### 6. `landing_page_category` / `page_category` broken for key pages since 2026-03-17 (OPEN)

The `stg_events.sql` exact-match page category classifier fails for pricing/checkout/signup/sign_in categories because the domain consolidation moved these paths under `/library/`. `landing_page_category` in `fct_sessions` inherits this broken classifier. Do not filter on `landing_page_category IN ('pricing', 'checkout', 'signup', 'sign_in')` — use path-based filters: `landing_page_path LIKE '%/library/pricing%'`, etc.

Source: `project_page_category_classifier_broken_open.md` (OPEN)

### 7. `bounced_sessions` column vs LookML `bounced_sessions` dimension — two different definitions

The warehouse column `bounced_sessions = CASE WHEN pageviews = 1 THEN 1 ELSE 0 END`. The LookML view defines `bounced_sessions` as a yesno dimension: `session_duration_seconds <= 1 AND no conversion events`. These are not the same population. The LookML definition excludes short sessions that had a conversion; the column includes all single-pageview sessions regardless of duration. Specify which definition you are using when reporting bounce rates.

### 8. Cross-session `last_channel_non_direct` — attribution can reference sessions outside your analysis window

`last_channel_non_direct` is computed via a LAST_VALUE window that is unbounded from the beginning of the visitor's history. If a visitor had a paid-search session in 2023 and a Direct session in 2026, `last_channel_non_direct` on the Direct session will show `'Paid Search'`. This is correct behavior for attribution purposes but means the attributed channel is not necessarily visible in the analysis window. When counting "paid sessions" in a date window, using `last_channel_non_direct` will include sessions where the attributing click event falls outside the window.

## Cost profile (from query_history; EMBEDDED_ANALYST, 9 recent queries against this table)

- **P50 elapsed:** ~922 ms
- **P95 elapsed:** ~4,292 ms (one full-scan outlier visible at 9.2 GB scanned)
- **P50 bytes scanned:** ~33 KB (aggregate/metadata queries)
- **Typical date-scoped aggregates:** <1s elapsed, <200 KB bytes scanned
- **Full-table scan (no date predicate):** ~4–5s elapsed, ~4.6 GiB scanned
- **Avoid:** unbounded date scans; `SELECT *` on large windows; joining to fct_events without bridging (risk of cartesian fan-out)

Note: 9 rows in history is above the 3-row floor for reporting but is a small sample. P95 is likely understated.

## Prior analyses referencing this table

- `analysis/data-health/2026-04-01-direct-traffic-spike/` — Direct traffic spike investigation; confirmed Fastly POP artifact 2026-03-05→2026-03-25; defines the contamination filter signature. Primary columns used: `last_channel_non_direct`, `landing_page_host`, `bounced_sessions`, `country`, `browser`, `session_duration_seconds`, `session_started_at`, `pageviews`
- `analysis/data-health/2026-04-17-direct-traffic-spike/` — Second spike (APAC; 2026-04-14→2026-04-17); root cause OPEN; uses same columns + `landing_page_path`
- `analysis/experimentation/2026-04-18-wcpm-test-audit/` — WCPM experiment pulse reconciliation; used `distinct_id` for session-level experiment attribution
- `analysis/data-health/2026-04-13-investigation/` — Additional data health check referencing fct_sessions
- `analysis/lifecycle/current_subscriber/v1_proposal/` — Subscriber lifecycle segment sizing; session-level engagement metrics
- `analysis/enterprise/pql/tasks/2026-04-15-knowledge-discovery/` — PQL contact shape investigation; session-level enterprise conversion fields

## LookML semantics

Primary view: `context/lookml/views/Mixpanel/fct_sessions.view.lkml` (`sql_table_name: soundstripe_prod."CORE".FCT_SESSIONS`)

Additional custom views derived from fct_sessions:
- `context/lookml/views/_Custom_Views/sessions_w_entry_page.view.lkml`
- `context/lookml/views/_Custom_Views/site_activty_with_entry_page_180_day_lookback.view.lkml`
- `context/lookml/views/_Custom_Views/fct_sessions_daily_rollup.view.lkml`
- `context/lookml/views/_Custom_Views/enterprise_at_risk.view.lkml`

Key measures in `fct_sessions.view.lkml`:
- `sessions` — `COUNT_DISTINCT(session_id)` — primary traffic volume measure; drills to `last_channel_non_direct`, `subscribes`, `subs_per_session`
- `unique_visitors` — `COUNT_DISTINCT(distinct_id)` — visitor-grain headcount
- `subscribes` — `COUNT_DISTINCT(session_id) FILTER purchased_subscription = 'Yes'` — subscription-converting sessions
- `subscribe_conversion_rate` — `DIV0(subscribes, sessions)` — session-level subscribe CVR
- `mqls` — sum of `mqls_pricing_page + mqls_enterprise_page + mqls_schedule_demo` — distinct sessions with any enterprise MQL form submission; see LookML for enterprise lead sub-measures
- `bounced_sessions` dimension — LookML-layer bounce definition (duration ≤1s AND no conversions) differs from warehouse column definition (single pageview)
- `www_landing_sessions` / `has_app_view` / `www_app_ctr` — cross-domain engagement measures that are **only valid pre-consolidation** when `landing_page_host` had meaningful www vs. app segmentation. Post-consolidation these measures require reinterpretation via `has_app_view` / `has_www_view` columns

Note: `mql_pricing_page` measure in the LookML has a syntax error (`${TABLE}.enterprise)_form_submissions` — extra parenthesis). It references `enterprise_form_submissions` but will fail to compile. Use `mqls_pricing_page` (the `COUNT DISTINCT` version) instead.
