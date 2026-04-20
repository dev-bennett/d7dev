# Grounding Questions — WCPM Pricing Test Audit

Before writing diagnostic SQL, I need to pin down what each tool is actually counting and how units are exposed. Fill in answers inline under each question. Blanks I should not guess I've left as `<answer>`.

## Observed numbers

- Mixpanel export ("Uniques of Purchased Add-on", 2026-03-09 → 2026-04-13, weekly): **27 total** (8+7+5+4+1+2)
- Statsig pulse export (`wcpm_pricing_test`, 2026-03-13 → 2026-04-18, summed across arms):
  - Existing Subscriber add-ons: **4**
  - New Subscriber add-ons: **8**
  - Combined: **12**
  - Total amount: **914.76 USD** (264.87 + 418.95 + 230.94)
- Gap: Mixpanel 27 vs. Statsig 12 (Statsig under-counts by 15, ~56%).

## Structural note I'm starting from

Statsig's metrics in this export are `metric_type = user_warehouse` — sourced from a Snowflake user-level sync, scoped to exposed units only (18,224 across three arms). Mixpanel's export has no exposure filter. Some gap is therefore expected. The audit's job is to quantify each component of the gap (exposure filter, identity resolution, metric-definition mismatch, window difference) and confirm nothing is broken.

---

## Q1 — Mixpanel report definition

The Mixpanel link (`mixpanel.com/s/b30sb`) renders the 27-count, but the export doesn't show the underlying query. From the report page I need:

- **Q1a — What event is being counted?** (e.g. `Purchased Add-on`, `Subscription Updated`, a revenue event, etc.)
  - `Uniques of: Purchased Add-on`
- **Q1b — What filter(s) scope it to WCPM specifically?** (SKU / product name / content_partner_slug / something else)
  - `any in list: warner-chappell-production-music-monthly-usd, warner-chappell-production-music-yearly-usd`
- **Q1c — Is any experiment, cohort, or audience filter applied in the Mixpanel report?** (e.g. "users exposed to wcpm_pricing_test", a cohort, `$experiment_started` event)
  - `no - just the date range`
- **Q1d — What is the exact attribution window?** The column header says "Mar 13 → Apr 18, 5:05PM" but the data buckets begin 2026-03-09. Is the report using the event timestamp or a user-first-exposed-at timestamp? And is Mar 9–12 intentionally included or an artifact of weekly bucketing?
  - `the experiment started on the 13th. The data buckets dates appear to be truncated to week which is why you're seeing that.`

## Q2 — Statsig metric definition

The two metrics that matter are `WCPM Add Ons - Existing Subscriber` and `WCPM Add Ons - New Subscriber`, both `user_warehouse` type. From the Statsig metric-definition screen I need:

- **Q2a — What is the Snowflake source** (table name, ideally including the database/schema) for each of these two metrics?
  - 1Y-LTV Generated
Explanation
Measures the sum of LTV_1_YR_GM
Metric Settings
There is one filter applied:
EVENT = Created Subscription
The metric can be broken down by: PLAN_ID
CUPED is enabled with a lookback window of 7 days
Configuration
Metric Type: 
sum
Metric Source: 
clickstream_events_etl
(Sat, 18 Apr 2026 01:01:05 GMT)
Value Column: 
LTV_1_YR_GM

  - WCPM Add Ons - Existing Subscriber
Description
Number of existing subscriptions that are adding the wcpm add on
Explanation
Measures the sum of ADD_ON_PURCHASE_EXISTING_SUB
Metric Settings
There aren't any filters applied
CUPED is enabled with a lookback window of 7 days
Configuration
Metric Type: 
sum
Metric Source: 
clickstream_events_etl
(Sat, 18 Apr 2026 01:01:05 GMT)
Value Column: 
ADD_ON_PURCHASE_EXISTING_SUB

  - WCPM Add Ons - New Subscriber
Description
Number of new subscriptions that include the wcpm add on

Explanation
Measures the sum of ADD_ON_PURCHASE_NEW_SUB
Metric Settings
There aren't any filters applied
CUPED is enabled with a lookback window of 7 days
Configuration
Metric Type: 
sum
Metric Source: 
clickstream_events_etl
(Sat, 18 Apr 2026 01:01:05 GMT)
Value Column: 
ADD_ON_PURCHASE_NEW_SUB

- **Q2d — What is the sync cadence?** (nightly / hourly / on demand) — relevant because a lagging sync can explain a same-day gap vs. Mixpanel's near-realtime events.
  - `daily at 0500 CDT`
- **Q2e — What identity column joins the user_warehouse row to the Statsig unit?** (expected: `statsig_stable_id` or a user_id mapped through identity resolution)
  - `statsig_stable_id`

## Q3 — Experiment assignment and exposure

Statsig arm sizes: Control 6,115 / Mid 5,972 / Deep 6,137 (total **18,224**). Those are exposed units, not total site visitors.

- **Q3a — What is the exposure trigger?** (page load on a specific URL, click, API call, first session with X, etc.)
  - `there are none selected other than "not a bot"`
- **Q3b — Who is eligible?** (authenticated users only / free-tier + visitors / subscribers only / geo filter / etc.)
  - `not specified`
- **Q3c — Is the exposure event instrumented in Mixpanel as well?** (e.g. `$experiment_started` or a custom equivalent) — if yes, I can compute "exposed-user purchasers" in Mixpanel and reconcile against the Statsig 12 directly.
  - `statsig_stable_id is a property accessible in most (maybe all) mixpanel events`

## Q4 — Reconciliation scope

- **Q4a — Which window do you want to treat as canonical for the audit?**
  - [infer....... duh] Statsig experiment window: 2026-03-13 → 2026-04-18
  - [ ] Mixpanel report window as exported: 2026-03-09 → 2026-04-13 (closed)
  - [ ] Match both to a single shared window (specify): `<answer>`
- **Q4b — What's Meredith's actual decision question?**
  - [ ] "Is the Statsig test results readout trustworthy for making a pricing call?" (→ focus audit on Statsig attribution and exposure integrity)
  - [ ] "Is the Mixpanel dashboard a reliable business-level source for WCPM add-on purchases?" (→ focus audit on Mixpanel event instrumentation)
  - [ ] Both
  - Additional context: `what a silly question to ask`

## Q5 — Anything else you already know

- **Q5a — Has the statsig stable-id sync been verified recently?** (I know `statsig_stable_id` flows Mixpanel → fct_events → `_external_statsig`; any known issues?)
  - `no - no known issues - also this is something you should validate, not ask`
- **Q5b — Has anyone else (AJ, Luke, Taylor, Engineering) already poked at this?**
  - `no`
- **Q5c — Any WCPM-related product/pricing change deployed inside the test window** that could change which SKUs qualify as "add-ons"?
  - `not clear - irrelevant for now`

---

## What I'll do once these are filled in

1. Reproduce the Mixpanel 27-count in Snowflake using the event + filter from Q1. Confirm match.
2. Reproduce the Statsig 12-count (by arm, Existing/New split) using the user_warehouse source from Q2. Confirm match.
3. Decompose the 15-person gap into:
   - Pre-window purchases (Mar 9–12)
   - Exposed-but-not-in-source (identity resolution failures)
   - Non-exposed purchasers (eligible but never triggered)
   - Metric-definition mismatch (e.g. event fires on an action that never creates a user_warehouse row)
4. Report each component with a count, classify as INFORMATIONAL / OPERATIONAL / STRUCTURAL per §11, and recommend the action (if any) for each.
