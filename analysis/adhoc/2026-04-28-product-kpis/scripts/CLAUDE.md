# Scripts — Product KPIs 24-Month Trend Review

@../CLAUDE.md

Python utilities for table generation. Charts are produced downstream by the analyst in their preferred tool from these tabular outputs (the in-house PNG generator was deleted as unsatisfactory).

## Files

- `tables.py` — derives per-tile rates and writes one CSV per tile plus a wide summary to `../tables/`. Pure stdlib (csv + datetime + pathlib). Reads `../q01.csv`, `../q02.csv`, `../q03.csv`, `../q07.csv`. Mirrors the LookML measure formulas of Dashboard 19 with two known approximations (tile 1/3/14 LTV-modeled revenue; tile 11 visitor-engaged proxy denominator) — see `../tables/CLAUDE.md`.

## Run

```
python3 scripts/tables.py
```

Run from the task workspace root (`analysis/adhoc/2026-04-28-product-kpis/`).
