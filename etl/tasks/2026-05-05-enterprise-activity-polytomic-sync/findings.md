# Findings — Enterprise activity → HubSpot Companies (Polytomic sync)

## Geoff's deferred sync — what was missing

`fct_enterprise_user_activity_for_scoring` (merged via PR #719) outputs
one row per `(CUSTOMER_ID, SUBSCRIPTION_ID)` where both fields are
**Chargebee** identifiers. AM and CS need the engagement metrics on
HubSpot **Companies** (account-level), not HubSpot Contacts.

HubSpot Company has no Soundstripe-side custom property — no
`chargebee_customer_id`, no `soundstripe_account_id`. So Polytomic had
no Company-side column to upsert against. Syncing to HubSpot Contact on
`chargebee_customer_id` (which Contact does carry) is grain-mismatched
(one customer fans out to many contacts) and useless for AM dashboards.

### Enterprise customer base — Chargebee vs non-Chargebee, at the right grain

`dim_enterprise_deals` contains 6,725 deals across 4,635 distinct
HubSpot Companies. The 6,725 deal count is misleading because it
mixes deals at every stage (lost, in progress, won) and every
historical period (renewals, duplicate-deal-per-customer, etc.) — most
non-Chargebee deals are simply prospects that never closed.

Filtered to **won deals only** (the actual paying enterprise
customer base):

| stage_category | distinct companies | with chargebee | without chargebee |
|---|---:|---:|---:|
| **won** | **1,004** | **779 (78%)** | **518 (52%)** † |
| in progress | 681 | 5 | 677 |
| lost | 3,862 | 103 | 3,784 |

† some won companies have BOTH chargebee and non-chargebee deals on
their record (started with one billing model, switched), so the cells
don't sum to 1,004.

**Of ~1,004 won enterprise customer companies in HubSpot:**
- ~779 (78%) have ever had a Chargebee subscription on at least one of
  their deals — the addressable population for Phase A.
- ~225 (22%) have never been Chargebee-billed at all — the Phase B
  population.

The "object-specific join key" Geoff was missing was the bridge
between his Chargebee-grain output and HubSpot's Company grain.

## Phase A solution (this task)

Bring `companyid` (HubSpot's native object_id) into the model output by
joining `subscriber_activity` to `finance.dim_enterprise_deals` on
`chargebee_customer_id`. The deal mart already exposes
`CHARGEBEE_CUSTOMER_ID` (verified via information_schema). Polytomic
syncs to HubSpot Company on `companyid` — no HubSpot custom property
required for the join itself.

### Output schema

| Column | Notes |
|---|---|
| `companyid` (NUMBER, not null, unique) | HubSpot Company object_id; sync upsert key |
| `active_users` | distinct Soundstripe user_ids active in days 1-61 |
| `chargebee_customer_count` | distinct Chargebee customers attributed to the company (typically 1; surfaces fan-out) |
| `chargebee_subscription_count` | distinct Chargebee subscriptions feeding the counters |
| `sessions_prior_30` | events in days 32-61 |
| `sessions_last_30` | events in days 1-31 |
| `song_downloads_prior_30` / `_last_30` | sale + download events |
| `projects_created_prior_30` / `_last_30` | project-create events |

### Coverage and fan-out (validated against `transformations.subscriber_activity`)

| Metric | Value |
|---|---:|
| HubSpot Companies in model output | **483** |
| Distinct Chargebee customers represented | 489 |
| Distinct Soundstripe users | 1,076 |
| Total event rows feeding the model | 371,595 |
| Won enterprise customer companies (eligible base) | **~1,004** |
| Won customer companies with any Chargebee history (Phase A addressable) | **~779** |
| **Phase A coverage of won enterprise customers** | **~48%** (483 / 1,004) |
| Won customers with Chargebee history but no model output (gap to investigate) | ~296 (779 − 483) |

The ~296-company gap between "Chargebee-history won customers" and
"customers in model output" is mostly customers with no activity in
the trailing 61-day window, plus some likely linkage misses (e.g.,
deals where chargebee_customer_id wasn't backfilled to the deal mart
even though the customer is still in `subscription_periods`). Worth a
spot-check after the dev build.

### Fan-out behavior to flag for sales-ops

A single Chargebee customer can map to up to 17 HubSpot Companies in
`dim_enterprise_deals` (avg 1.32). The proposed model broadcasts the
same engagement counters to each associated company — likely correct
for a holding-company-with-subsidiaries case, possibly noise for a
historical-deals-with-renewed-companies case. `verify/v03` audits the
fan-out distribution; review before activating sync.

## Phase B — non-Chargebee enterprise (~225 companies)

Out of scope here. Population: the ~225 won enterprise customers that
have never been Chargebee-billed (22% of the won enterprise base, not
82% as I initially mis-claimed). Requires:

- A canonical `soundstripe_account_id` field on HubSpot Company or Deal,
  populated by a sales-ops workflow at deal-close time.
- A parallel CTE in `subscriber_activity` (or a sibling model) that
  sources enterprise activity from `dim_enterprise_deals` joined to
  `soundstripe.users`/`accounts` rather than from `subscription_periods`.
- UNION of Chargebee-enterprise and non-Chargebee-enterprise outputs,
  both keyed on `companyid`.

Document and queue separately once Phase A is shipping.

## Decisions for Devon

1. **HubSpot Company custom-property names** for the Polytomic-mapped
   counters (Sales/RevOps owns creation in HubSpot). Suggested:
   `ss_active_users`, `ss_sessions_last_30`, `ss_sessions_prior_30`,
   `ss_session_delta`, `ss_song_downloads_last_30`,
   `ss_song_downloads_prior_30`, `ss_projects_created_last_30`,
   `ss_projects_created_prior_30`. Or shortened — Sales preference.
2. **Fan-out review before activation** — confirm the broadcast-to-all-
   companies behavior is what AM/CS want for the customers with > 1
   associated company. Run `verify/v03` and inspect the top fan-out
   cases manually before activating the sync.
3. **Phase B prioritization** — when to scope the identity-bridge work
   for the ~5,500 non-Chargebee enterprise deals.
