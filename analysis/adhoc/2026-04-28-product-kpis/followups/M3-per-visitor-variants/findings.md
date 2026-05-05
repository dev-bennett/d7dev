# M3 — Per-visitor variant of tiles 5, 6, 11 (YoY)

| | |
|---|---|
| **Triggering finding** | Parent doc cross-cutting #1: visitor / session grain mismatch on tiles 5 and 6 |
| **Window** | **Y1 = May 2024 – Apr 2025** vs **Y2 = May 2025 – Apr 2026** |
| **Headline question** | When grain is fixed (per-visitor numerator over per-visitor denominator), does the per-session decline persist, dampen, or invert? |
| **Source data** | `../../q01.csv` |
| **Output** | `M3_yoy_per_visitor.csv` |

## Verdict

**The signup-rate decline is real on per-visitor grain too — fixing the grain doesn't make it go away.** But engaged-visitor signup propensity (tile 11) is roughly flat. The decline is primarily a *traffic-mix shift toward less-engaged visitors*, not a per-visitor-propensity collapse.

## YoY pop-and-rate

| | Y1 | Y2 | YoY |
|---|---:|---:|---:|
| Sessions | 8.06M | 6.43M | -20.2% |
| Visitors (distinct) | 4.91M | 4.36M | **-11.1%** |
| Signed-up visitors | 312,924 | 196,701 | **-37.1%** |
| Engaged visitors | 1,577K | 1,051K | -33.4% |
| Engaged + signed-up | 312,924 | 196,701 | -37.1% |
| MQL visitors (3-comp) | 1,454 | 2,124 | **+46.1%** |

Visitors fell less than sessions (-11% vs -20%) — sessions-per-visitor fell, meaning the average visitor came back fewer times. This *amplifies* the per-visitor rate decline relative to per-session.

## Rate comparison

| Tile | Y1 | Y2 | YoY |
|---|---:|---:|---:|
| 5: signups / session | 3.88% | 3.06% | **-21.2%** |
| 5 fixed: signups / visitor | 6.38% | 4.51% | **-29.3%** |
| 6: MQLs / session | 0.018% | 0.033% | **+83%** |
| 6 fixed: MQLs / visitor | 0.030% | 0.049% | **+64%** |
| 11: engaged signup CVR | 19.84% | 18.72% | **-5.6%** |

**Per-visitor signup rate fell -29% YoY, *more* than per-session (-21%).** Fixing the grain doesn't help — it makes the decline look worse.

But: engaged signup CVR (tile 11) only fell -5.6%. **Engaged visitors still convert about as well as they did. The decline is in the non-engaged portion of the traffic.** Engaged visitors: 32% of all visitors in Y1, 24% in Y2. Engagement share dropping is the proximate cause.

**MQL volume *grew* +46% YoY** despite the broader decline. Tile 6's "STAB" verdict in the parent doc understated this.

## Roll-up

| Tile | YoY-corrected verdict |
|---|---|
| 5 | Real -21% per-session, -29% per-visitor decline. *Reclassify from MA + REAL + DEF → REAL + DEF.* Mix shift toward non-engaged visitors is the mechanism. |
| 6 | **Reclassify from STAB → REAL POSITIVE.** MQL volume +46% YoY. Underlying signal hidden by per-session rate denominator. |
| 11 | STAB / mild dip stands. Best per-channel-clean acquisition tile on the dashboard. |

## Recommendation

- **Promote tile 11** to headline acquisition KPI; dropped only -5.6% YoY (vs the doomy reads on tiles 4, 5).
- **Add `sign_ups_per_visitor` LookML measure** alongside per-session.
- **Reframe tile 6:** the rate is not the story; volume is. MQLs grew +46% YoY — surface as an absolute-count tile.
- **The acquisition decline is a *visitor-engagement-mix* problem.** Engaged visitors convert about as well as before; unengaged share is rising. M2 channel decomp shows where the unengaged share is coming from.
