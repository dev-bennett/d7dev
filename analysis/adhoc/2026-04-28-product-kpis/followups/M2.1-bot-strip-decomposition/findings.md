# M2.1 — Bot-Strip Variant of M2 (YoY)

| | |
|---|---|
| **Triggering finding** | M2 mechanism D1 — "Pre-cutover Direct artifact creeping in" — was the leading hypothesis but **untested by data** |
| **Window** | **Y1 = May 2024 – Apr 2025** vs **Y2 = May 2025 – Apr 2026** |
| **Headline question** | After stripping baseline bot/scraper sessions across the 24-month window, does the channel-level CVR pattern survive? |
| **Bot-strip predicate** | `duration < 5 AND no conversion AND no signup AND no MQL form`. Converting sessions preserved by construction. |
| **Output** | `M2_1_yoy_decomposition.csv` |

## Verdict

**Bots don't explain the decline. Even on engaged-only sessions, the YoY CVR collapsed.**

The M2 D1 hypothesis (rising bot composition is the Direct CVR story) is **ruled out**. Bot-stripped Direct CVR fell -56% YoY — same magnitude as the unstripped read.

## Aggregate decomposition (treats total as one)

| | All sessions (M2 original) | Bot-stripped |
|---|---:|---:|
| sess Y1 → Y2 | 8,059K → 6,430K (-20%) | 4,074K → 3,146K (-23%) |
| CVR Y1 → Y2 | 0.233% → 0.151% (**-35%**) | 0.460% → 0.310% (**-33%**) |
| within-CVR | -6,574 (73%) | -6,125 (68%) |
| within-vol | -3,789 (42%) | -4,271 (47%) |
| interaction | +1,329 | +1,396 |
| Δsubs | -9,034 | -9,000 |

Stripping bots doubles absolute CVR levels but barely changes the relative drop (-35% raw vs -33% bot-stripped). The CVR-halving headline is robust.

Bot strip rate: 49% of sessions stripped in Y1, 51% in Y2 — a small rise in bot share but not enough to drive the CVR pattern.

## Per-channel YoY (bot-stripped)

| Channel | CVR Y1 | CVR Y2 | within-CVR | within-vol | inter | Δsubs |
|---|---:|---:|---:|---:|---:|---:|
| Paid Search | 0.59% | **0.57%** | -178 | -2,889 | +97 | -2,970 |
| Direct | 0.44% | **0.19%** | **-2,187** | -295 | +165 | -2,318 |
| Organic Search | 0.43% | 0.31% | -2,227 | -1,142 | +316 | -3,053 |
| Other | 0.58% | 0.35% | -209 | -261 | +102 | -368 |
| Email | 0.59% | 0.38% | -143 | -82 | +30 | -196 |
| Referral | 0.20% | 0.21% | +13 | -93 | -2 | -82 |
| Paid Social | 0.24% | 0.16% | -7 | -9 | +3 | -13 |
| **Σ** | | | -4,938 | -4,772 | +710 | **-9,000** |

### What changes from the original (all-sessions) decomposition

- **Paid Search: confirmed pure-volume story.** Bot-stripped CVR essentially flat (0.59% → 0.57%, -3%). Within-CVR effect is tiny (-178); volume drop accounts for everything (-2,889).
- **Direct: D1 ruled out.** Bot-stripped within-CVR (-2,187) is similar to unstripped (-2,252). Direct's "real" sessions converted -56% worse YoY. Mechanism is D2 (attribution shift) or D3 (loyal-customer churn) — not bot composition.
- **Organic: unchanged story.** Bot-stripped within-CVR (-2,227) ≈ unstripped (-2,284). The "lower-intent SEO" framing is robust to bot stripping.

## Roll-up

| M2 mechanism | YoY verdict |
|---|---|
| D1 — Pre-cutover Direct bot artifact | **RULED OUT.** Bot-stripped CVR fell same -56%. |
| D2 — Attribution shift (third-party cookies, etc.) | Plausible. Not directly tested. |
| D3 — Loyal-customer churn | Most parsimonious remaining hypothesis. Test: split Direct into logged-in vs anonymous; trend logged-in CVR YoY. |
| D4 — Infrastructure shift | Deprioritized (Fastly was already in path pre-domain-consolidation). |

## Recommendation

Run **Direct logged-in-vs-anonymous diagnostic** as the next sub-analysis (M2.2). 1 query. If logged-in CVR is stable, lost CVR is anonymous "low-intent type-in" (consistent with D3 — loyal customers churning out of Direct). If logged-in CVR is also down, real returning-customer churn — escalate to retention team.
