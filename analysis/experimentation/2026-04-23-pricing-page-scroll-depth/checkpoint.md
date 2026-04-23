# Checkpoint — 2026-04-23 (final)

## Final state

- All phases 0–6 complete. Phase 7 closeout — memory logging done; commit pending user approval.
- Deliverables in place:
  - `findings.md` — full §1–§12 pass, reconciled to re-run Q3 with corrected `entered_persona_flow` definition (`element IN ('View Pricing','Choose a Plan')`)
  - `message-to-meredith.md` — sentence-audited; three questions back to stakeholder
  - `console.sql` — Q1–Q7 (Q3 and Q7 updated after D15 revealed the second entry CTA)
  - `diagnose/discovery.sql` — D1–D17
  - `q1.csv`–`q7.csv` + `d1.csv`–`d17.csv` in place
- Two new `project_*_open.md` memories written + MEMORY.md index updated:
  - `project_page_category_classifier_broken_open.md`
  - `project_mixpanel_autocapture_collapse_open.md`

## Headline outcomes

- Goal 1 (reduce bounce): not met. Engagement-proxy bounce 34.4% → 37.0% (+2.6pp). Scroll-based bounce unmeasurable (autocapture collapsed 2/25).
- Goal 2 (increase persona clicks): not met. Cumulative persona selection 46.1% → 42.0% (-4.1pp); drop concentrates at the entry step (56.3% → 51.7%).
- Subscription rate lifted 3.25% → 4.07% (+25% relative), concentrated at plan→subscribe step (+8pp). Confounded by +8pp visitor-mix shift toward authenticated users (paid + free).

## Follow-on work (optional, pending Meredith's answers)

1. Within-cohort decomposition of the +8pp step-5 lift (anonymous / free / paid × pre / post). Answerable from existing data in a single pass.
2. Mixpanel UI scroll-depth pull for March–April if the property still exists in Mixpanel's own store.
3. Engineering: audit 2/24 deploy's Mixpanel SDK config + fix `stg_events.sql` page_category classifier.

---

# Prior work log

## Completed

- Phase 0: Directory setup (CLAUDE.md, README.md)
- Phase 1 D1 – D5 executed:
  - D1: `Viewed Pricing Page` = 15,324 distinct users on pricing path Jan 7 – Feb 6 (within 68 of product team's 15,256 — canonical visitor event)
  - D1: `Clicked Pricing Product` fires only 2 times / 1 user across baseline; NOT the product team's plan-click source
  - D1b: element-identifier columns exist in raw Mixpanel — `CTA_ID`, `CTA_NAME`, `ELEMENT`, `ELEMENT_TEXT`, `ELEMENT_URL`, `PERSONA`, `SIGN_UP_PAGE_PERSONA`, `STEP_TEXT`, `LINK_TEXT`, `BUTTON_URL`. Dedicated `PERSONA` column — persona selection IS reconstructible
  - D2a: scroll-depth column = `MP_RESERVED_MAX_SCROLL_PERCENTAGE` (TEXT) in raw source
  - D2b: only `$mp_page_leave` carries scroll (2.3M events / 156K users across window)
  - D2c: 21,194 pricing page-leave events in baseline with scroll data; avg 35.8% (product team's ~33% confirmed within noise); max 109 (overscroll — clip to 100 in main build)
  - D3: `Clicked Pricing Product` has only 15 events across all plans in baseline; Free Account top; confirms D1 — not the plan-click event
  - D4: `Viewed Sign Up Form` = 10,178 / 8,947 on signup page; `Signed Up` = 2,482 / 2,430; `free_account_registration` redundant; no `sign in` page events in baseline
- **D5: pricing-page traffic effectively disappears in fct_events starting 2026-03-17.** Jan 1 – Mar 16 baseline ~400–870 distinct_ids/day; Mar 17 collapses to 23; Mar 18 – Apr 23 shows 1–4/day with many days empty. Likely cause: `stg_events.sql` line 117 classifies `page_category = 'pricing'` via exact `path = 'pricing'` match; domain consolidation (mid-March rollout, stabilized ~03/26 per `project_domain_consolidation.md`) changed the pricing URL structure and the classifier silently stopped matching.

- Phase 1 D6 + D7 executed:
  - D6: `Viewed Pricing Page` event is healthy through Apr 23 (400–750 distinct users/day continuous). No collapse at Mar 17 at the event level.
  - D7: domain consolidation moved pricing from `app.soundstripe.com/pricing` to `www.soundstripe.com/library/pricing`. Pre-window 99% on `app.soundstripe.com/pricing` (15,193 users); post-rollout (Mar 26 – Apr 23) 98% on `www.soundstripe.com/library/pricing` (13,751 users); rollout (Mar 5–25) split. The `stg_events.sql` `page_category` classifier uses exact `path = 'pricing'` and does not match `library/pricing`. **Bug is in classifier; event is durable.**
  - **Workaround for this analysis:** use `event = 'Viewed Pricing Page'` as the visitor gate. Use `path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')` when a URL filter is needed.

- Phase 1 D8 executed:
  - `element` column on `Clicked Element` carries all funnel-step labels directly: `View Pricing` (64,857 events in baseline), 6 persona labels, 12 plan labels. `cta_name` / `cta_id` all null on pricing-page clicks. `element_text` mostly null. `persona` column additionally populated on downstream clicks for attribution.
- **Phase 1 closed.**
- Phase 2 complete — `findings.md` drafted with RATE DECLARATIONS, DELIVERABLE CONTRACT, and ALIGNMENT CHECKs.
- Phase 3 complete — `console.sql` written with Q1–Q6:
  - Q1: Daily `Viewed Pricing Page` visitors Jan 1 – Apr 23 (continuous time series)
  - Q2: Scroll-depth distribution (user-max; thresholds at 5, 20, 50, 95, 100)
  - Q3: 5-step funnel counts with step rate + cumulative rate
  - Q4: Persona breakdown (share + per-persona conversion, first-persona-click attribution)
  - Q5: Plan breakdown (share + per-plan conversion, first-plan-click attribution)
  - Q6: Character diagnostic (device, country, channel, existing_sub)
  - Each reports 4 window labels: `1_pre`, `2_post_2wk`, `3_post_8wk`, `4_post_8wk_clean`
  - `4_post_8wk_clean` excludes 2026-03-05 – 2026-03-25 per the 2026-04-01 correction pattern — eliminates the need for a separate Q7

## In Progress

- Phase 3 execution — console.sql Q1–Q6 need to be run in Snowflake and exported as `q1.csv` through `q6.csv` in the task root directory.

- Phase 3 execution: Q1–Q6 run, CSVs in task root.
- Phase 4 (VERIFY) + Phase 5 (INTERPRET) written in findings.md (type audits, identity check, enumeration, sentence-audited interpret pass with null-hypothesis blocks, adversarial check, intervention classification).
- Phase 6 (WRITING SCRUB + deliverables) — message-to-meredith.md written and sentence-audited (banned-phrase scrub applied).
- D9 run — scroll-depth cliff pinned at 2026-02-25 exactly. Event `$mp_page_leave` continues to fire at normal volume post-cutover; only the `mp_reserved_max_scroll_percentage` property became null. Warehouse-side recovery impossible.
- Q7 added to console.sql — engagement-based bounce proxy (pricing visitors with no downstream pricing-UI interaction). Substitutes for the scroll-depth bounce metric.

## In Progress

- Phase 3 addition — Q7 to run in Snowflake and export as `q7.csv`. Then update findings headline + message-to-meredith with the proxy bounce rate.
- Phase 7 — closeout pending: log structural-issue memories (classifier bug + scroll instrumentation) and commit.

## Open Items

- Q7 result pending.
- **Structural issues to log as project_*_open.md memories during Phase 7 closeout:**
  1. `stg_events.sql` `page_category` classifier uses exact-match on `pricing`, `checkout`, `signup`, `sign_in` paths — all four broken post-domain-consolidation. Repo-wide impact.
  2. `mp_reserved_max_scroll_percentage` stopped populating on pricing `$mp_page_leave` events on 2026-02-25. Platform-wide if the property is globally disabled.
- Follow-on analytical question (not in original scope): within-cohort decomposition of the 3.25% → 4.07% subscription-rate lift (existing vs new subscribers) to separate composition drift from behavior change. Pending user decision.

## Pending Decisions

- None currently.

## Key Context

- Site-wide deploy, no experiment wrapper (confirmed).
- Pre (Jan 7 – Feb 6), Post-2wk (Feb 24 – Mar 10), Post-8wk (Feb 24 – Apr 23).
- March 5–25 and April 13+ have known direct-traffic contamination; Q7 in console.sql will apply the 2026-04-01 correction filter.
- Product team's numbers (15,256 pricing visitors, 43.5% View Pricing, etc.) are targets for sizing-sanity comparison, not ground truth.
- `fct_events` filters out `$mp_page_leave` at stg_events.sql line 90 — any scroll data likely lives in raw `pc_stitch_db.mixpanel.export`.
- Plan file: `/Users/dev/.claude/plans/mossy-painting-pillow.md`.
