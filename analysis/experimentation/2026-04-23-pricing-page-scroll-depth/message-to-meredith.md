Meredith — pricing-page banner change review (shipped 2/24). Comparing the Jan 7 – Feb 6 pre-baseline to post windows of 2 weeks and 8 weeks (with the 3/5 – 3/25 domain-consolidation contamination window excluded).

On the two stated goals:

- Bounce rate: the scroll-depth property on Mixpanel's page-leave event stopped populating around 2/25. Click-position properties on click events also stopped around the same date. Both are Mixpanel autocapture scalars and they collapsed together. Mixpanel Session Replay was turned on 3/1, which captures the same behavior in replay recordings but is not queryable from our warehouse. Scroll-based bounce from the product team's prior analysis is not reproducible from our data post-2/25. Substitute metric: engagement-based bounce rate (pricing visitors who took no downstream pricing action) moved from 34.4% to 37.0% — a 2.6pp increase. Mixpanel UI may still carry the scroll property in its own store; pulling a scroll report directly from Mixpanel would confirm the scroll-based number.

- Persona card clicks: cumulative persona-selection rate moved from 46.1% to 42.0% over the 8-week post window — a 4pp decrease. Decomposition: the drop happens at the entry step (56.3% → 51.7% of visitors clicked into the persona flow, -4.6pp). Once users entered the flow, the step rate to persona selection held (82% → 81%). Context: the 2/24 deploy added a second persona-flow entry CTA ("Choose a Plan") alongside "View Pricing" — the funnel now counts both as entry. Even with the broader definition, fewer users engaged the flow overall.

Finding outside the stated goals — the aggregate conversion lift is real as a window-difference but not attributable to the banner; the mechanism behind the lift is ambiguous:

- Aggregate subscription rate moved from 3.25% (pre window Jan 7 – Feb 6) to 4.07% (post-8wk-clean) — a 25% relative lift.

- Decomposing the absolute subscriber-count increase by cohort (cohort = `current_plan_id` value at first pricing view): the measured free-account visitor count at pricing grew from 3,611 to 5,868 (+2,257, +62%). At the pre free-rate of ~10.8%, that "volume" alone accounts for ~102% of the +239 aggregate sub delta. Anonymous grew only +559 visitors and contributed ~+43 subs via a small rate lift. Free-cohort cumulative rate actually fell (10.80% → 9.73%).

- Critical caveat on the mechanism. I cannot distinguish between two explanations for the measured free-share rise, and they have very different implications:
    - (A) More actual free-account traffic is being routed to pricing post-consolidation (e.g., by dashboard CTAs, redirects, or marketing).
    - (B) Identity reconciliation improved under domain consolidation. Pre-consolidation, a logged-in free user on `app.soundstripe.com` who hit `www.soundstripe.com/pricing` may not have had `current_plan_id` populated at that event and was counted as anonymous. Post-consolidation, auth state travels cleanly to `library/pricing`, and the same underlying population is now correctly classified as free. Under this mechanism, the pre-baseline composition was biased by under-identification and the "conversion rate rose 25%" headline is partly a measurement artifact rather than behavior change.
    - Both are consistent with the data here. Neither is attributable to the 2/24 banner deploy. Both sit within the domain-consolidation timeframe. Confirming (A) vs (B) vs a mix needs engineering input on how the Mixpanel identity SDK was configured on the legacy app subdomain vs the new `library/pricing` route.

- Weekly conversion rate (3-week rolling avg) reached ~4% by mid-February — three weeks before the 2/24 deploy — and plateaued. The free-account share stepped up in the week of 3/16, but aggregate conversion did not step further after mid-February.

- Masked by the aggregate: free-cohort cumulative conversion measured at 10.80% pre vs 9.73% post. Under mechanism (A) that is a real decline. Under mechanism (B) it may be partly a mix-correction artifact (more "borderline" users now classified as free, pulling the average down).

- Methodology note: an earlier version of this message reported a +8pp plan-click → subscribe step-rate lift. That was computed from a non-nested numerator/denominator pair and was wrong. Corrected via Q9 with proper plan-click attribution: 20.1% pre → 26.2% post (+6.2pp), within-cohort anon 6.3→8.4, free 40.3→49.4. Your product-team analysis reported 7.3%; the gap is definitional — their denominator included plan-screen controls (Plan tier toggle, Interval dropdown, etc.) while mine restricts to specific plan-name clicks.

Three structural issues I need to flag:

- Mixpanel autocapture collapse around 2/25 (above). Affects scroll-depth and click-position data on pricing and possibly other pages. Owner: engineering / data platform.

- The pricing URL moved from app.soundstripe.com/pricing to www.soundstripe.com/library/pricing during the March domain consolidation. Our warehouse's page-category classifier uses exact-match on the old paths. Any dashboard or downstream model filtering on that classifier silently returns near-zero for pricing, checkout, signup, and sign-in from mid-March onward. I'll log this as a separate fix on my end.

- The header "Pricing" link was renamed to "See Pricing" and now fires as Clicked Sign Up Button instead of Clicked Pricing Link. Any existing Mixpanel funnels or LookML measures filtering on the old event + label pair return near-zero for post-2/24.

Three questions back to you:

1. Was the autocapture change in the 2/24 deploy intentional (e.g., migrating to Session Replay), or did the banner-shrink deploy accidentally alter Mixpanel config? Engineering is best placed to confirm.

2. Was the "Choose a Plan" CTA intentionally added alongside "View Pricing" in the same deploy? Product context would help me frame the funnel-shape change correctly.

3. The conversion rate rose from ~3.2% to ~4.0% during January and mid-February, before the 2/24 deploy, and plateaued. Any context on what else changed in the pricing / sign-up / Chargebee path from early January to mid-February (marketing campaigns, pricing changes, attribution window changes, funnel instrumentation updates, seasonal patterns in prior years)? That would help explain the pre-deploy drift.

4. Identity reconciliation question for engineering: on the pre-consolidation stack, was a user authenticated on `app.soundstripe.com` expected to carry `current_plan_id` in their Mixpanel super-property on a `www.soundstripe.com/pricing` page view, or could they appear as having `current_plan_id = null` on pricing until re-identified? Post-consolidation under `library/pricing`, is identity reliably retained? The answer decides whether mechanism (A) or (B) above dominates.

Full analysis: analysis/experimentation/2026-04-23-pricing-page-scroll-depth/findings.md
