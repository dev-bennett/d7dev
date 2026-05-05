# WCPM Significance — Stats subdirectory

@../CLAUDE.md

Python statistical-test script + inputs + outputs for the WCPM pricing-test significance read-out.

## Files

- `wcpm_significance.py` — frequentist tests on per-arm WCPM add-on attach: Wilson 95% CI, pairwise two-proportion z-test with Bonferroni, Newcombe rate-difference CI, omnibus chi-square (Monte-Carlo permutation fallback if cell counts < 5), MDE/power analysis, and CUPED variance reduction with a pre-period engagement covariate. Stdout-friendly + writes `results.md`.
- `input_per_arm.csv` — handoff from `console.sql q09`: `arm,exposed_n,purchased_n` for Control / Mid Reduction / Deep Reduction.
- `input_cuped_per_arm.csv` — handoff from `console.sql q15`: per-arm sufficient statistics (n, sum_y, sum_x, sum_xy, sum_y2, sum_x2, units_with_pre_activity) for the CUPED computation. X = pre-period engagement (7-day fct_events count); Y = post-period WCPM attach event count.
- `results.md` — script output tables + interpretation + caveats (includes a CUPED section).
- `per_arm_attach.png` — chart per `feedback_chart_standards`: legend outside chart area, semantic colors, Wilson-CI error bars, axis labels readable.

## Running

```
cd /Users/dev/PycharmProjects/d7dev
python analysis/experimentation/2026-04-27-wcpm-test-significance/stats/wcpm_significance.py
```

Dependencies: `scipy`, `statsmodels`, `numpy`, `pandas`, `matplotlib`. All available via the repo's `pip install -e ".[dev]"`.

## Conventions

- One Python file. No notebooks (analysis must be reproducible from a single `python <file>` invocation).
- Verify chart visually after generation (`feedback_chart_standards`): run, view image, confirm no clipping / overlap before declaring success.
- All statistical decisions documented inline in the script's docstring AND in `../methodology.md` (§1 RATE blocks live there, not here).
