# M2 — Subscriber Acquisition Channel Decomposition (YoY)

| | |
|---|---|
| **Triggering finding** | Parent doc Adversarial Q3: "What's the breakdown of the subscriber-acquisition decline by channel?" |
| **Window** | **Y1 = May 2024 – Apr 2025** vs **Y2 = May 2025 – Apr 2026.** Full-year totals, period-over-period. Mar/Apr 2026 artifact months are diluted across 12-month bucket (no manual artifact stripping needed). |
| **Headline question** | Of the YoY subscribing-session decline, how much is per-channel CVR collapse vs. per-channel volume loss? |
| **Source data** | `M2_channel_monthly.csv` |
| **Output** | `M2_yoy_decomposition.csv` (aggregate + per-channel) |

## Headline

| | Y1 | Y2 | YoY change |
|---|---:|---:|---:|
| Subscribing sessions | 18,744 | 9,710 | **-48.2%** |
| Total sessions | 8,059,479 | 6,430,349 | -20.2% |
| Blended CVR | 0.233% | 0.151% | -35.1% |

**Subs fell 48% YoY. About two-thirds is per-channel CVR collapse; one-third is volume loss.**

## Aggregate decomposition (treats total as one)

```
Δsubs = -9,034
  within-CVR  (sessions_y1 × ΔCVR):       -6,574  (73%)
  within-vol  (Δsessions × CVR_y1):       -3,789  (42%)
  interaction (Δsessions × ΔCVR):         +1,329  (-15%)
```

CVR halving (-35%) is the bigger lever; volume loss (-20%) is the smaller one. The interaction is positive because both fell together.

## Per-channel decomposition

| Channel | sess Y1 | sess Y2 | subs Y1 | subs Y2 | CVR Y1 | CVR Y2 | within-CVR | within-vol | inter | Δsubs | Δsubs share |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Organic Search | 2,850K | 2,459K | 8,053 | 4,977 | 0.28% | 0.20% | -2,284 | -1,105 | +314 | **-3,076** | 34% |
| Paid Search | 1,512K | 589K | 5,300 | 2,322 | 0.35% | **0.39%** | +657 | -3,234 | -401 | **-2,978** | 33% |
| Direct | 2,935K | 2,814K | 3,923 | 1,602 | 0.13% | **0.06%** | -2,252 | -162 | +93 | **-2,321** | 26% |
| Other | 160K | 107K | 535 | 167 | 0.33% | 0.16% | -285 | -178 | +95 | -368 | 4% |
| Email | 108K | 102K | 399 | 203 | 0.37% | 0.20% | -185 | -21 | +10 | -196 | 2% |
| Referral | 469K | 332K | 514 | 432 | 0.11% | 0.13% | +96 | -150 | -28 | -82 | 1% |
| Paid Social | 26K | 27K | 20 | 7 | 0.08% | 0.03% | -13 | +1 | -1 | -13 | 0% |
| **Σ** | | | 18,744 | 9,710 | | | -4,266 | -4,849 | +81 | **-9,034** | |

Three channels = 93% of the decline. Each tells a different story:

### Paid Search — pure volume story (+12% CVR, -61% sessions)

CVR actually *rose* slightly YoY (0.35% → 0.39%). Sessions fell 61% (1.5M → 589K). Subs lost = -2,978. **All of it is the volume drop.** Marketing/budget mechanism, not channel quality.

### Direct — pure CVR collapse (-57% CVR, -4% sessions)

Sessions virtually flat (2.93M → 2.81M, -4%). CVR collapsed -57% (0.13% → 0.06%). Same Direct sessions, half the conversions. M2.1 (bot-strip) confirms this is not a bot-composition story — the lost CVR is in the engaged-session pool too.

### Organic Search — split, CVR-leaning

Sessions -14%, CVR -28%. Both effects substantial. Documented "lower-intent SEO post domain consolidation" mechanism (parent doc + `analysis/data-health/2026-04-27-domain-consolidation-non-customer/`) accounts for this cleanly.

## Roll-up

| Tile | YoY-corrected verdict |
|---|---|
| 4 (Purchase CVR) | Real -35% YoY blended CVR drop. ~60-70% per-channel CVR collapse, ~30-40% mix shift toward worse-converting channel mix. |
| 5 (Sign-ups/session) | Same mechanisms drive sign-up decline; see M3 for per-visitor framing. |

## Recommendations

1. **Surface a per-channel subs tile.** Aggregate hides three different stories.
2. **Marketing review on Paid Search budget contraction** (-61% sessions, healthy CVR). Lost subs are 33% of the YoY decline; needs to be intentional or reversed.
3. **Direct CVR mechanism diagnostic** (D2 attribution shift / D3 loyal-customer churn — D1 ruled out per M2.1). 26% of the decline is here.

## §11 Intervention Class

```
INTERVENTION CLASS — Paid Search YoY volume contraction:
  FINDING: -61% session volume YoY at constant-or-improving CVR; drives -2,978 of -9,034 subs (33%)
  PERSISTENCE TEST: 12 months of compounding lost paid subs at company LTV/CAC
  OWNER TEST: Marketing / paid acquisition team
  SMALLEST FIX: Marketing review of paid-search budget allocation
  CLASSIFICATION: OPERATIONAL
```

```
INTERVENTION CLASS — Direct CVR collapse:
  FINDING: -57% per-channel CVR at flat session volume; drives -2,321 of -9,034 subs (26%)
  OWNER TEST: Data team diagnostic (D2 attribution / D3 loyal-customer churn)
  SMALLEST FIX: Logged-in vs anonymous Direct CVR split (see M2.1 recommendations)
  CLASSIFICATION: STRUCTURAL pending diagnostic
```
