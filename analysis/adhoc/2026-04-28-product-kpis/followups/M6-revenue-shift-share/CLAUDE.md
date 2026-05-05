# M6 — Revenue/Session Shift-Share

@../CLAUDE.md

§5 algebraic-identity decomposition of revenue/session: `rev/session = (subs/session) × (avg_LTV/sub)`. Splits the 24-month decline into volume effect (fewer subs/session) vs. plan-mix effect (subs going to higher- or lower-LTV plans).

## Files

- `queries.sql` — m6_q01 (LTV table snapshot) + m6_q02 (24m plan-mix at acquisition)
- `M6_plan_mix_monthly.csv` — raw plan-mix data (24 months × 6-7 plan tiers × 1-3 billing intervals)
- `M6_revenue_per_session_decomposition.csv` — per-month rollup with subs, modeled revenue, avg LTV/sub, plan shares, both reported and corrected denominators
- `findings.md` — verdict and roll-up

## LTV assumption note

The `finance.subscription_ltv_assumptions` table is a single snapshot (current). Historical LTVs are not available; this analysis assumes per-plan LTV is constant across the 24-month window. Enterprise LTV is not in the table; `findings.md` (parent) uses $6,000 as the anchor and we adopt the same. **Sensitivity to enterprise LTV is documented in this folder's `findings.md`.**
