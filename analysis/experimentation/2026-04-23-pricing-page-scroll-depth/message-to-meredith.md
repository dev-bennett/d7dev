Meredith — pricing-page banner change review (shipped 2/24). Comparing the Jan 7 – Feb 6 pre-baseline to post windows of 2 weeks and 8 weeks (with the 3/5 – 3/25 domain-consolidation contamination window excluded).

On the two stated goals:

- Bounce rate: the scroll-depth property on Mixpanel's page-leave event stopped populating around 2/25. Click-position properties on click events also stopped around the same date. Both are Mixpanel autocapture scalars and they collapsed together. Mixpanel Session Replay was turned on 3/1, which captures the same behavior in replay recordings but is not queryable from our warehouse. Scroll-based bounce from the product team's prior analysis is not reproducible from our data post-2/25. Substitute metric: engagement-based bounce rate (pricing visitors who took no downstream pricing action) moved from 34.4% to 37.0% — a 2.6pp increase. Mixpanel UI may still carry the scroll property in its own store; pulling a scroll report directly from Mixpanel would confirm the scroll-based number.

- Persona card clicks: cumulative persona-selection rate moved from 46.1% to 42.0% over the 8-week post window — a 4pp decrease. Decomposition: the drop happens at the entry step (56.3% → 51.7% of visitors clicked into the persona flow, -4.6pp). Once users entered the flow, the step rate to persona selection held (82% → 81%). Context: the 2/24 deploy added a second persona-flow entry CTA ("Choose a Plan") alongside "View Pricing" — the funnel now counts both as entry. Even with the broader definition, fewer users engaged the flow overall.

Finding outside the stated goals:

- Subscription conversion rate moved from 3.25% (pre) to 4.07% (8-week post, clean). Relative lift 25%. The lift concentrates at the bottom of the funnel: plan-clickers who subscribed within 7 days moved from 27.5% to 35.5% — a step-rate lift of 8pp. Top-of-funnel rates all stayed flat or declined; step 5 carried the cumulative improvement.

- Caveat on the step-5 lift: the pricing-page visitor mix shifted toward authenticated users with a plan_id set (paid OR free account) — 26% pre, 34% post, +8pp. Authenticated users convert on plan clicks at higher rates than anonymous visitors. Some meaningful share of the 8pp step-5 lift is probably visitor-composition, not behavior change. A within-cohort split (anonymous vs free vs paid, pre vs post) would separate the two — see question 3 below.

Three structural issues I need to flag:

- Mixpanel autocapture collapse around 2/25 (above). Affects scroll-depth and click-position data on pricing and possibly other pages. Owner: engineering / data platform.

- The pricing URL moved from app.soundstripe.com/pricing to www.soundstripe.com/library/pricing during the March domain consolidation. Our warehouse's page-category classifier uses exact-match on the old paths. Any dashboard or downstream model filtering on that classifier silently returns near-zero for pricing, checkout, signup, and sign-in from mid-March onward. I'll log this as a separate fix on my end.

- The header "Pricing" link was renamed to "See Pricing" and now fires as Clicked Sign Up Button instead of Clicked Pricing Link. Any existing Mixpanel funnels or LookML measures filtering on the old event + label pair return near-zero for post-2/24.

Three questions back to you:

1. Was the autocapture change in the 2/24 deploy intentional (e.g., migrating to Session Replay), or did the banner-shrink deploy accidentally alter Mixpanel config? Engineering is best placed to confirm.

2. Was the "Choose a Plan" CTA intentionally added alongside "View Pricing" in the same deploy? Product context would help me frame the funnel-shape change correctly.

3. Do you want the within-cohort decomposition (anonymous / free / paid × pre / post) on the +8pp step-5 lift to separate composition from behavior?

Full analysis: analysis/experimentation/2026-04-23-pricing-page-scroll-depth/findings.md
