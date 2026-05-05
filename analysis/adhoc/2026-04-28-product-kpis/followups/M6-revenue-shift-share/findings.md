# M6 — Revenue/Session Shift-Share (YoY)

| | |
|---|---|
| **Triggering finding** | Parent doc tile 1: the deleted chart suggested rev/session collapsed ~50% over 24m. Decomposition needed to test what's volume vs. plan-mix. |
| **Window** | **Y1 = May 2024 – Apr 2025** vs **Y2 = May 2025 – Apr 2026** |
| **Headline question** | Of the rev/session change, what's volume vs. plan-mix vs. per-plan LTV? |
| **Source data** | M6_plan_mix_monthly.csv + finance.subscription_ltv_assumptions |
| **Output** | `M6_yoy_decomposition.csv` |

## Verdict — tile 1 narrative is INVERTED

**LTV-modeled revenue per session GREW +18% YoY.** It did not decline. The deleted chart's flat-$200-per-sub approximation produced a downward-looking series; the actual LookML measure (per-plan LTV-aware) is up.

The volume drop (subs/session -34%) is more than offset by a strong plan-mix shift toward higher-LTV plans (avg LTV/sub +79%).

## YoY pop-and-rate

| | Y1 | Y2 | YoY |
|---|---:|---:|---:|
| Sessions | 8,059,479 | 6,430,349 | -20.2% |
| New subs (modeled) | 18,930 | 9,949 | -47.4% |
| Revenue (modeled) | $3.57M | $3.37M | **-5.8%** |
| Avg LTV / sub | $188.83 | $338.56 | **+79.3%** |
| Subs / session | 0.235% | 0.155% | -34.1% |
| **Revenue / session** | **$0.4435** | **$0.5238** | **+18.1%** |

## Decomposition: rev/session = (subs/session) × (avg LTV/sub)

```
Δrev/session = +$0.0803 (+18.1%)
  within-volume (Δsubs/sess at old LTV):    -$0.1514  (-189% of total)
  within-mix    (ΔLTV/sub at old subs/sess): +$0.3517  (+438%)
  interaction:                              -$0.1200  (-149%)
```

The two main effects nearly cancel; the mix effect wins.

## Plan-mix shift (share of new subs)

| Plan | Y1 share | Y2 share | Δ |
|---|---:|---:|---:|
| Personal | 62.9% | 39.8% | **-23.1pp** |
| Pro | 32.3% | 54.3% | **+22.0pp** |
| Enterprise | 1.1% | 3.3% | +2.2pp |
| Pro-plus | 1.6% | 2.0% | +0.4pp |
| Twitch-pro | 1.8% | 0.3% | -1.5pp |
| Other | 0.2% | 0.3% | flat |

Personal → Pro (and rising Enterprise) is the entire mix-shift effect.

## Sensitivity to enterprise LTV

Enterprise LTV is not in `subscription_ltv_assumptions`; this analysis uses the parent doc's $6,000 anchor.

| Enterprise LTV | Y2 avg LTV/sub | Y2 rev/session | YoY |
|---|---:|---:|---:|
| $6,000 (this analysis) | $338.56 | $0.5238 | **+18%** |
| $3,000 | $263.53 | $0.4078 | -8% |
| $0 | $138.50 | $0.2143 | **-52%** |

The verdict pivots on the enterprise LTV input. **Confirm the figure with Finance before taking +18% to Meredith.** At $0 enterprise LTV the trend reverts to a -52% decline (closer to what the deleted chart was approximating) — but $0 is also implausible.

## Roll-up

| Tile | YoY-corrected verdict |
|---|---|
| 1 (Revenue/Session) | **Reclassify from MA + REAL → MIX-OFFSET + LTV-SENSITIVE.** Read directly from Looker (which uses per-plan LTV) rather than the deleted chart. Trend likely flat-to-up YoY. |
| 2 (LTV/Transaction) | Tracks avg LTV/sub. Up +79% YoY. Reclassify STAB → POSITIVE. |
| 3, 14 | Same dynamics as tile 1. |

## Recommendation

1. **Re-render tile 1 in Looker directly.** The LookML measure does the per-plan join correctly; the chart approximation didn't.
2. **Confirm enterprise LTV with Finance.** Whole verdict pivots on this.
3. **Add a "subscriber plan mix" tile** to Dashboard 19. Personal share -23pp / Pro share +22pp is the dashboard's most actionable composition signal — and it explains why tile 12 (expansion) is muted (fewer Personal subs left to upgrade to Pro).
4. **Audit the 'pro' bucket classifier.** It matches `pro%, music%, sfx%, standard%, premium%` — broad pattern that may be over-capturing legacy names. If Personal → Pro is partly classifier coverage, the mix-shift effect is overstated.
