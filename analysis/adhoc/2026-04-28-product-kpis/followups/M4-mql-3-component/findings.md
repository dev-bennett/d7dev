# M4 — MQL 3-Component Decomposition (YoY)

| | |
|---|---|
| **Triggering finding** | Parent doc cross-cutting #5: tile 6 is a 3-component visitor sum that may double-count visitors who submit multiple form types |
| **Window** | **Y1 = May 2024 – Apr 2025** vs **Y2 = May 2025 – Apr 2026** |
| **Headline question** | What are the 3 components' separate trend lines? Should tile 6 be split? |
| **Source data** | `../../q01.csv` (3 components pulled separately) |
| **Output** | `M4_yoy_components.csv` |

## Verdict

**Tile 6 hides a positive growth story.** Total MQL volume grew +46% YoY. The aggregate flat-rate framing in the parent doc is wrong — pricing form drove a +68% YoY increase, demo form +109%. Only enterprise form fell.

| Component | Y1 | Y2 | YoY | Y1 share | Y2 share |
|---|---:|---:|---:|---:|---:|
| Pricing form | 1,035 | 1,741 | **+68.2%** | 71.2% | 82.0% |
| Enterprise form | 338 | 214 | **-36.7%** | 23.2% | 10.1% |
| Demo form | 81 | 169 | **+108.6%** | 5.6% | 8.0% |
| **TOTAL** | **1,454** | **2,124** | **+46.1%** | 100% | 100% |

## Reads

- **Pricing form is the workhorse** and grew sharply. 82% of all MQLs in Y2.
- **Enterprise form fell -37% YoY.** Only declining component. Worth flagging — the enterprise-pipeline implication may matter more than the topline rise.
- **Demo form doubled** off a small base. May be a tracking change or a real new user behavior.

## Roll-up

| Tile | YoY-corrected verdict |
|---|---|
| 6 | **Reclassify from STAB + DEF → POSITIVE + DEF.** MQL volume up +46% YoY. The flat-looking per-session rate masks the growth (because session denominator fell -20% and numerator grew). |

## Recommendation

- **Replace tile 6 (rate) with three count tiles:** Pricing-form / Enterprise-form / Demo-form submissions per month. The aggregate rate is uninterpretable; the components have very different stories.
- **Flag the Enterprise-form -37% YoY** to sales operations. Most other things are growing; this one isn't.
- **Verify the Demo doubling is real.** Check whether tracking for the demo form changed in 2025.
