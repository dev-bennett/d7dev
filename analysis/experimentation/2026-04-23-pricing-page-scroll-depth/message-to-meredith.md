Meredith — pricing-page banner change review (shipped 2/24). Comparing the Jan 7 – Feb 6 pre-baseline to post windows of 2 weeks and 8 weeks (with the 3/5 – 3/25 domain-consolidation contamination window excluded).

On the two stated goals:

- Bounce rate: the scroll-depth property on Mixpanel's page-leave event stopped populating around 2/25. Click-position properties on click events also stopped around the same date. Both are Mixpanel autocapture scalars and they collapsed together. Mixpanel Session Replay was turned on 3/1, which captures the same behavior in replay recordings but is not queryable from our warehouse. Scroll-based bounce from the product team's prior analysis is not reproducible from our data post-2/25. Substitute metric: engagement-based bounce rate (pricing visitors who took no downstream pricing action) moved from 34.4% to 37.0% — a 2.6pp increase. Mixpanel UI may still carry the scroll property in its own store; pulling a scroll report directly from Mixpanel would confirm the scroll-based number.

- Persona card clicks: cumulative persona-selection rate moved from 46.1% to 42.0% over the 8-week post window — a 4pp decrease. Decomposition: the drop happens at the entry step (56.3% → 51.7% of visitors clicked into the persona flow, -4.6pp). Once users entered the flow, the step rate to persona selection held (82% → 81%). Context: the 2/24 deploy added a second persona-flow entry CTA ("Choose a Plan") alongside "View Pricing" — the funnel now counts both as entry. Even with the broader definition, fewer users engaged the flow overall.

Finding outside the stated goals — the aggregate conversion number looks good, but timing does not support attribution to the 2/24 deploy:

- Aggregate subscription rate moved from 3.25% (pre window Jan 7 – Feb 6) to 4.07% (post-8wk-clean) — a 25% relative lift.

- Weekly conversion rate (3-week rolling avg): 3.18% in early January → 3.64% → **4.05% by mid-February** → 4.05% mid-March → 4.10% late March / April. The rate reached ~4% three weeks BEFORE the 2/24 deploy and plateaued. No step change at the deploy week.

- Visitor composition also shifted (free-account share rose from 25% in early January to 28% by mid-February, step change to 33% in the week of 3/16, holding 31–35% through April). The 3/16 step aligns with the domain-consolidation rollout stabilizing, not the banner deploy. However, the conversion rate did not rise further when composition stepped up in mid-March — free share kept climbing through April, but conversion held at ~4%. Composition timing does not explain the conversion lift either.

- The +25% pre-vs-post aggregate lift is real as a window-difference, but the rise happened during the January – mid-February period and plateaued before any candidate cause tested here. The origin of the January – mid-February drift is not diagnosed by this analysis.

- Masked by the aggregate: free-account cumulative conversion actually declined 10.80% → 9.73% over the same pre-vs-post comparison. Per-cohort step-5 rates rose (anon 7.9% → 11.2%, free 53.4% → 64.7%) but free-cohort step-2 rate fell (56.5% → 47.2%), so the free-cohort cumulative ended lower.

Three structural issues I need to flag:

- Mixpanel autocapture collapse around 2/25 (above). Affects scroll-depth and click-position data on pricing and possibly other pages. Owner: engineering / data platform.

- The pricing URL moved from app.soundstripe.com/pricing to www.soundstripe.com/library/pricing during the March domain consolidation. Our warehouse's page-category classifier uses exact-match on the old paths. Any dashboard or downstream model filtering on that classifier silently returns near-zero for pricing, checkout, signup, and sign-in from mid-March onward. I'll log this as a separate fix on my end.

- The header "Pricing" link was renamed to "See Pricing" and now fires as Clicked Sign Up Button instead of Clicked Pricing Link. Any existing Mixpanel funnels or LookML measures filtering on the old event + label pair return near-zero for post-2/24.

Three questions back to you:

1. Was the autocapture change in the 2/24 deploy intentional (e.g., migrating to Session Replay), or did the banner-shrink deploy accidentally alter Mixpanel config? Engineering is best placed to confirm.

2. Was the "Choose a Plan" CTA intentionally added alongside "View Pricing" in the same deploy? Product context would help me frame the funnel-shape change correctly.

3. The conversion rate rose from ~3.2% to ~4.0% during January and mid-February, before the 2/24 deploy, and plateaued. Any context on what else changed in the pricing / sign-up / Chargebee path from early January to mid-February (marketing campaigns, pricing changes, attribution window changes, funnel instrumentation updates, seasonal patterns in prior years)? That would help explain the pre-deploy drift.

Full analysis: analysis/experimentation/2026-04-23-pricing-page-scroll-depth/findings.md
