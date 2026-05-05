---
title: April 2026 Enterprise Closed-Won ARR — Tracker vs. Looker
date: 2026-05-04
status: draft
---

# April 2026 Enterprise Closed-Won — Reconciliation

| Source | April 2026 total |
|---|---|
| Looker — Closed Won ARR | **\$134,849** |
| Internal sales tracker | **\$123,099** |
| Difference | **+\$11,750** |

## Why the totals differ

The Looker tile counts deals from HubSpot's `Enterprise Pipeline` or `Renewal Pipeline` only. The tracker mixes those with deals from the `API & Partnerships` pipeline (sublicensing). Two opposing flows produce the \$11,750 gap:

**Tracker rows that Looker does not count — 2 deals, −\$3,000.** Both are sublicensing closes in `API & Partnerships`:
- Queensberry — \$2,000
- Wevi.ai — \$1,000

**Looker-counted deals not in the tracker — 4 deals, +\$14,750.** All four are closed-won in `Enterprise Pipeline`:
- By The Grape of God — \$8,000
- About Diabetes - Russia — \$5,500
- Butter App API SFx Upgrade — \$750
- Studio McGee +1 Team Seat Upgrade — \$500

Net: +\$14,750 − \$3,000 = +\$11,750.

## Implication

The two larger Looker-only wins (By The Grape of God \$8K, About Diabetes - Russia \$5.5K, totaling \$13.5K) are full enterprise new-deal wins that appear to have been omitted from the tracker. The Butter App and Studio McGee rows are small upgrades and are likely intentional tracker omissions.

The two tracker exclusions (Queensberry, Wevi.ai) are sublicensing wins reported separately from enterprise ARR by design.

Per-row classification and the underlying SQL are in `reconciliation.csv`, `warehouse_only.csv`, and `console.sql`.
