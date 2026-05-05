# Contract + RATE Declarations + Alignment Checks

Pre-BUILD methodology lock per `context/informational/agent_directives_v3.md` §2, §1, §12.

---

## §2 — Deliverable Contract: `findings.md`

```
CONTRACT — Product KPIs 24-Month Trend Review (findings.md):

PRECONDITIONS:
  - All 14 in-scope tile measure SQL definitions traced from LookML view files (DONE — see README.md table)
  - Calibration artifacts current for fct_sessions, fct_sessions_attribution, dim_daily_kpis, fct_events (DONE — 2026-04-24-r2)
  - Prior NC-traffic findings ingested (DONE — q8 sprawl null result is load-bearing context)
  - 24-month monthly window defined: session_started_at >= '2024-05-01' AND session_started_at < '2026-05-01'

POSTCONDITIONS:
  - findings.md contains: (1) data-quality regime overview, (2) per-KPI verdict table with 14 rows, (3) per-declining-KPI deep-dive section, (4) recommendations bundle, (5) §8 Adversarial Check Q1-Q4
  - charts/ contains exactly 14 PNGs, one per in-scope KPI, named tile_##_<slug>.png
  - console.sql contains all queries q01-qN with §1 RATE blocks and Type Audits inline
  - Per-KPI verdict cell cites the diagnostic query that supports it (e.g., "see q03 — Direct channel mix +47pp Mar 5-25")
  - Sentence Audit performed on findings.md; zero §10 banned phrases

INVARIANTS:
  - Every in-scope tile (#1-14) appears as exactly one row in the verdict table
  - Headline framing distinguishes "measurement artifact" / "real mix-shift" / "real product/business signal" — these three labels are the only valid metric-validity verdict categories
  - For each declining KPI, the data-quality contamination is quantified at the input layer (numerator and denominator separately) rather than asserted from project memory
  - For any "X caused Y" claim, ≥2 alternative mechanisms enumerated per `feedback_enumerate_mechanisms_before_attribution`
  - One headline metric per KPI; do not pivot under pushback (`feedback_commit_to_one_metric`)
  - Per-KPI recommendation classified per §11 (INFORMATIONAL / OPERATIONAL / STRUCTURAL); no STRUCTURAL framed as INFORMATIONAL
```

---

## §1 — RATE Declarations (10 rate measures)

### Tile 1: Global Revenue per Session

```
RATE: total_revenue_per_session
NUMERATOR: SUM(license_revenue + total_ltv_1_yr + mql_assumed_1yr_revenue) over all sessions in the month
  - license_revenue = market_purchase_amount + sfx_purchase_amount + single_song_purchase_amount (sums per session)
  - total_ltv_1_yr is sourced from subscription_ltv_assumptions joined to fct_sessions (NOT a fct_sessions column)
  - mql_assumed_1yr_revenue = mqls_count × 0.05 × 6000 (modeled, not realized revenue)
DENOMINATOR: COUNT(DISTINCT session_id) — all sessions in the month, no engagement filter
TYPE: dollars_per_session (modeled-LTV denominated)
NOT: sessions excluding artifact contamination — the dashboard pulls raw sessions, including artifact Direct sessions
NOT: realized revenue / sessions — this is modeled 1yr LTV plus modeled MQL value, not realized cash
```

### Tile 3: Global Revenue per Session — App Engaged Sessions (45s+)

```
RATE: total_revenue_per_session_engaged
NUMERATOR: same as tile 1 — modeled total_revenue from sessions matching filter
DENOMINATOR: COUNT(DISTINCT session_id) WHERE engaged_session_ind = 'Yes' AND has_app_view IN ('Yes','No')
TYPE: dollars_per_engaged_session
NOT: sessions including bounces — engagement filter is the discriminator
NOTE: `has_app_view IN ('Yes','No')` is functionally no filter (it includes both values). Either intended or a relic of legacy filter UI.
```

### Tile 4: Purchase Conversion Rate (per Session)

```
RATE: overall_conversion_rate
NUMERATOR: COUNT(DISTINCT session_id WHERE purchased_subscription = 'Yes') + COUNT(DISTINCT session_id WHERE purchased_license = 'Yes')
  — counted independently; a session that did both contributes 2 to numerator
DENOMINATOR: COUNT(DISTINCT session_id) — all sessions in the month
TYPE: converting_session_count / total_session_count (not a probability — can exceed 100% in theory if heavy multi-purchase, in practice ≪1%)
NOT: distinct converting sessions / sessions — the additive numerator double-counts sessions with both kinds of purchase
NOT: gross conversions / unique visitors — denominator is session-grain
```

### Tile 5: Sign Ups per Session

```
RATE: sign_ups_per_session
NUMERATOR: COUNT(DISTINCT distinct_id WHERE SIGNED_UP > 0) — VISITOR-GRAIN
DENOMINATOR: COUNT(DISTINCT session_id) — SESSION-GRAIN
TYPE: distinct_signing_up_visitors / total_sessions
NOT: distinct_signing_up_sessions / total_sessions — that would be the natural session-rate; this measure uses a visitor numerator
NOT: signed_up_visitors / unique_visitors — denominator is sessions, not visitors
GRAIN MISMATCH FLAG: numerator is visitor-grain (distinct_id count), denominator is session-grain (distinct session_id count). The rate dilutes when visitors return for multiple sessions; e.g., if every visitor returns once, the rate halves with no underlying behavior change. This is a definitional issue worth surfacing as a recommendation.
```

### Tile 6: MQL Form Submissions per Session

```
RATE: mqls_per_session
NUMERATOR: ${mqls_pricing_page} + ${mqls_enterprise_page} + ${mqls_schedule_demo}
  where each component is COUNT(DISTINCT distinct_id WHERE <form>_submissions > 0) — VISITOR-GRAIN
  Components are summed, so a visitor who submitted multiple form types is counted once per type (up to 3x).
DENOMINATOR: COUNT(DISTINCT session_id) — SESSION-GRAIN
TYPE: distinct_MQL_visitor_form_submissions / total_sessions
NOT: distinct_MQL_visitors / total_sessions — three components, summed, so multi-form visitors counted multiple times
NOT: MQL events / sessions — events are not summed; visitor-distinct flags are
GRAIN MISMATCH FLAG: same as tile 5. Plus the 3-component sum can double/triple-count visitors who submitted multiple types of forms.
```

### Tile 7: % Subscribers Downloading Songs: 0–7 Days

```
RATE: song_downloading_subscriber_rate_param @ days_since_sub = 7
NUMERATOR: COUNT(DISTINCT soundstripe_subscription_id WHERE has_downloaded_songs_w_param = true)
  where has_downloaded_songs_w_param = (datediff('days', start_date, session_started_date) < 7 AND downloaded_songs > 0)
DENOMINATOR: COUNT(DISTINCT soundstripe_subscription_id) — all subscribers in the period (no maturity filter)
TYPE: subscribers_with_download_in_first_7d / total_subscribers_in_period
NOT: subscribers_with_download / subscribers_who_have_completed_7d (would require a maturity filter that the measure does not apply)
WATCHOUT: subscribers whose 7-day window has not yet completed at month-end inflate the denominator while contributing 0 to the numerator. Recent-month values systematically biased low until the cohort matures. Verify whether the dashboard handles this correctly or if recent-month values are artificially depressed.
```

### Tile 9: % Subscribers Downloading Songs: 30–60 Days

```
RATE: engaged_subscriber_rate_30_to_60
NUMERATOR: COUNT(DISTINCT soundstripe_subscription_id WHERE is_sub_30_to_60 = true)
  where is_sub_30_to_60 = (datediff('days', start_date, session_started_date) BETWEEN 30 AND 59 AND datediff('days', start_date, end_date) >= 60)
DENOMINATOR: subs_60_plus = COUNT(DISTINCT soundstripe_subscription_id WHERE datediff('days', start_date, end_date) >= 60) — only subs that survived ≥60 days
TYPE: subscribers_with_engagement_in_d30_60 / subscribers_who_lasted_60d
NOT: engaged subscribers / all subscribers — denominator is gated by 60-day survival
RIGHT-CENSORING FLAG: subs whose end_date hasn't reached 60 days yet are excluded from BOTH numerator and denominator. The most recent 2 months of data are sparse / biased.
```

### Tile 10: Sessions per Engaged Subscriber: 30–60 Days

```
RATE: sessions_per_engaged_subscriber_30_to_60
NUMERATOR: COUNT(DISTINCT session_id) — within the time-window filter applied at query time
DENOMINATOR: COUNT(DISTINCT soundstripe_subscription_id WHERE is_sub_30_to_60 = true)
TYPE: sessions / engaged_30-60d_subscribers
NOT: total sessions / total subscribers — both are filtered to the engaged-30-60 segment
NOTE: tile dashboard filter further restricts is_sub_30_to_60 = 'Yes', which is redundant with the measure's internal filter. Clarify which level of filter binds.
```

### Tile 11: Engaged Visitor Sign-Up CVR

```
RATE: visitor_sign_up_cvr (filtered: engaged_session_ind = 'Yes')
NUMERATOR: COUNT(DISTINCT distinct_id WHERE SIGNED_UP > 0) — within the engaged-session population
DENOMINATOR: unique_non_registered_visitors = COUNT(DISTINCT distinct_id WHERE session_started_at_time <= COALESCE(users.created_time, '2099-12-31')) — visitors whose session preceded their account creation (or who never registered)
TYPE: signing-up_visitors / never-yet-registered_visitors
NOT: signing_up_visitors / all_engaged_visitors — denominator excludes already-registered users
NOT: signing_up_sessions / engaged_sessions — both are visitor-grain
INSULATION HYPOTHESIS: artifact Direct sessions have ~97% bounce; the engaged_session_ind filter excludes them. This tile should be the LEAST contaminated of the per-session-rate group. Verify in BUILD-B q06.
```

### Tile 12: Subscription Expansion 0–30 Days

```
RATE: expansion_rate
NUMERATOR: COUNT(DISTINCT subscription_id WHERE subscription_change = 'expansion')
  — expansion = new_ltv_1_yr > prior_ltv_1_yr from CHARGEBEE_SUBSCRIPTION_CHANGES within 30 days of subscription start
DENOMINATOR: COUNT(DISTINCT subscription_id) — all subscriptions in the period (filtered to prior_plan IN ('personal','pro','pro-plus'))
TYPE: expanding_subscriptions / total_qualifying_subscriptions
NOT: expansions / all_subs — restricted to specific prior_plan values
NOT: revenue from expansion / revenue from all subs — this is a count rate, not a revenue rate
```

---

## §1 — RATE-adjacent (averages and ratios that are not strict rates)

### Tile 2: 1 Yr LTV Per Transaction

```
AVERAGE: avg_transaction_and_sub_1yr_revenue
NUMERATOR: license_revenue + total_ltv_1_yr (modeled, not realized)
DENOMINATOR: license_transactions + subscribes (count of converting sessions)
TYPE: dollars_per_transaction (modeled)
NOT: revenue / sessions — this is per converting session, not per session
NOT: realized average — uses modeled total_ltv_1_yr from subscription_ltv_assumptions
```

### Tile 8: Songs Downloaded per Downloading Subscriber: 0–30 Days

```
RATIO: songs_downloaded_by_subscriber_param @ 30
NUMERATOR: SUM(downloaded_songs WHERE has_downloaded_songs_w_param = true with param=30)
DENOMINATOR: COUNT(DISTINCT soundstripe_subscription_id) — all subscribers in period (NOT just downloading subscribers)
TYPE: songs_downloaded_in_first_30d_by_downloaders / total_subscribers_in_period
NAMING NOTE: tile is titled "per Downloading Subscriber" but the measure denominator is `subscribers` (all), not `songs_downloading_subscribers_param`. The measure name `songs_downloaded_by_subscriber_param` matches the denominator semantics; the tile title misrepresents.
```

### Tile 13: Avg 1Yr LTV Expansion Value 0–30 Days

```
AVERAGE: avg_1_yr_value_of_expansion
NUMERATOR: SUM(new_ltv_1_yr - prior_ltv_1_yr WHERE subscription_change = 'expansion')
DENOMINATOR: subscription_expansions = COUNT(DISTINCT subscription_id WHERE subscription_change = 'expansion')
TYPE: dollars_per_expansion_event
NOT: total expansion revenue / total subs — denominator is expansion-only
```

---

## §12 — Alignment Checks (action-driving categories)

### Sign-Ups per Session (tile 5) → Growth team intervention

```
ALIGNMENT CHECK — sign_ups_per_session:
  INTERVENTION: Growth-team prioritization of signup-funnel work; signup-page A/B tests; CTA placement decisions
  TEMPORAL MECHANIC OF INTERVENTION: event-driven (a signup event fires once when a user creates an account)
  TEMPORAL MECHANIC OF DEFINITION: visitor-grain count over a session-grain denominator across a calendar month
  MATCH: PARTIAL — event-driven intervention should ideally be sized by event volume, not as a rate of distinct visitors per session. The rate dilutes with visitor-return-frequency in a way that obscures actual signup volume. The dashboard would more directly inform growth decisions if it showed signup-events / month alongside the rate.
  SIZING SANITY: Order of magnitude expectation: 1-3% for signup rates per session in this kind of business. If the rate appears << 1% mid-window, the visitor-grain numerator is the likely cause. Confirm in BUILD-A q01.
```

### MQL Form Submissions per Session (tile 6) → Enterprise pipeline intervention

```
ALIGNMENT CHECK — mqls_per_session:
  INTERVENTION: Enterprise sales pipeline staffing; MQL handoff SLAs; pricing-page form A/B tests
  TEMPORAL MECHANIC OF INTERVENTION: event-driven (form submission)
  TEMPORAL MECHANIC OF DEFINITION: 3-component visitor-distinct-flag SUM over session-grain denominator
  MATCH: PARTIAL — same dilution issue as tile 5. Plus the 3-component sum can double/triple-count visitors. Enterprise sales would prefer raw form-submission counts by form type (which `pricing_page_form_views`, `enterprise_page_form_views`, `mqls_schedule_demo` provide separately). The combined rate is less actionable than its components.
  SIZING SANITY: MQL rates are typically <1% of sessions. Expected baseline ~0.05-0.2%. Confirm.
```

### Purchase CVR per Session (tile 4) → Product/growth intervention

```
ALIGNMENT CHECK — overall_conversion_rate:
  INTERVENTION: Product/growth team prioritization; pricing/checkout page tests; payment-flow optimization
  TEMPORAL MECHANIC OF INTERVENTION: event-driven (purchase event)
  TEMPORAL MECHANIC OF DEFINITION: session-rate (additive numerator of subscribing + license-purchasing sessions over total sessions)
  MATCH: YES at session grain. Caveat: additive numerator allows >100% in theory, but in practice subscriptions and license purchases rarely co-occur in the same session.
  SIZING SANITY: Combined CVR is typically 0.3-0.7% baseline. Trailing-month CVR may appear 0.2-0.4% if artifact sessions inflate the denominator while subscriptions+licenses do not. Verify.
```

### % Subscribers Downloading 0–7d (tile 7) / 30–60d (tile 9) → Lifecycle email intervention

```
ALIGNMENT CHECK — downloading_subscriber_rate (both tiles):
  INTERVENTION: Lifecycle email program (welcome, day-3, day-7 nudges); product onboarding sequence
  TEMPORAL MECHANIC OF INTERVENTION: state-driven (each subscriber traverses a 0-7d / 30-60d window once; intervention fires when the subscriber enters that state)
  TEMPORAL MECHANIC OF DEFINITION: cohort-window measurement (subscribers in their N-day window during the calendar period)
  MATCH: YES for tile 9 (the 30-60d window is fully observable for any subscriber whose end_date >= start_date + 60d, denominator is subs_60_plus which gates this). PARTIAL for tile 7: the 7-day window is open-ended on the upper edge of the most recent month, which censors recent-month values low until the cohort matures.
  SIZING SANITY: For an active product, % subscribers downloading in 0-7d should be 30-60% baseline. If recent month shows 5-15%, censoring is the likely cause, not engagement decline.
```

---

## Type Audit hooks

Each query in `console.sql` will produce a TYPE AUDIT block referencing back to its corresponding RATE block above. The general template:

```
TYPE AUDIT — q##:
  Declared denominator (RATE block: <tile name>): <population>
  JOIN chain: <enumerate JOINs in order>
  Column used as denominator: <exact reference>
  Does JOIN type enforce declared denominator? <YES/NO + reasoning>
  RESULT: PASS / FAIL
```
