"""Build chart-ready CSVs for each [Chart:] placeholder in ../findings.md.

Pure stdlib. Reads source CSVs in the task root and ../followups/, writes one
CSV per chart to ../charts-data/.

Run: python scripts/build_charts_data.py  (from task root)
"""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

TASK_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = TASK_ROOT / "charts-data"

Y1_START = "2024-05-01"
Y1_END = "2025-05-01"  # exclusive
Y2_START = "2025-05-01"
Y2_END = "2026-05-01"  # exclusive


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open() as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def chart_01_subscribing_sessions_by_channel() -> None:
    """§1 — long format: month_start, channel, subscribing_sessions."""
    src = TASK_ROOT / "followups/M2-channel-decomposition/M2_channel_monthly.csv"
    rows = read_csv(src)
    out = [
        {
            "month_start": r["month_start"],
            "channel": r["channel"],
            "subscribing_sessions": r["subscribing_sessions"],
        }
        for r in rows
    ]
    write_csv(
        OUT_DIR / "chart_01_subscribing_sessions_by_channel.csv",
        out,
        ["month_start", "channel", "subscribing_sessions"],
    )


def chart_02_plan_mix_y1_vs_y2() -> None:
    """§2 — long format: window, plan_tier, subs (aggregated across billing_interval and months within Y1/Y2)."""
    src = TASK_ROOT / "followups/M6-revenue-shift-share/M6_plan_mix_monthly.csv"
    rows = read_csv(src)
    agg: dict[tuple[str, str], int] = defaultdict(int)
    for r in rows:
        m = r["month_start"]
        if Y1_START <= m < Y1_END:
            window = "Y1 (May 2024 - Apr 2025)"
        elif Y2_START <= m < Y2_END:
            window = "Y2 (May 2025 - Apr 2026)"
        else:
            continue
        agg[(window, r["plan_tier"])] += int(r["subs"])

    plan_order = ["personal", "pro", "enterprise", "other"]
    out = []
    for window in ["Y1 (May 2024 - Apr 2025)", "Y2 (May 2025 - Apr 2026)"]:
        for plan in plan_order:
            out.append({"window": window, "plan_tier": plan, "subs": agg.get((window, plan), 0)})
        for (w, p), v in agg.items():
            if w == window and p not in plan_order:
                out.append({"window": w, "plan_tier": p, "subs": v})

    write_csv(
        OUT_DIR / "chart_02_plan_mix_y1_vs_y2.csv",
        out,
        ["window", "plan_tier", "subs"],
    )


def chart_03_signup_rate_visitor_vs_engaged() -> None:
    """§3 — wide format: month_start, all_visitor_signup_rate, engaged_visitor_signup_cvr."""
    src = TASK_ROOT / "followups/M3-per-visitor-variants/M3_per_visitor_rates.csv"
    rows = read_csv(src)
    out = [
        {
            "month_start": r["month_start"],
            "all_visitor_signup_rate": r["tile_05_signups_per_visitor"],
            "engaged_visitor_signup_cvr": r["tile_11_engaged_signup_cvr_per_engaged_visitor"],
        }
        for r in rows
    ]
    write_csv(
        OUT_DIR / "chart_03_signup_rate_visitor_vs_engaged.csv",
        out,
        ["month_start", "all_visitor_signup_rate", "engaged_visitor_signup_cvr"],
    )


def chart_04_mql_3component() -> None:
    """§4 — wide format: month_start, pricing_submissions, enterprise_submissions, demo_submissions."""
    src = TASK_ROOT / "followups/M4-mql-3-component/M4_mql_components.csv"
    rows = read_csv(src)
    out = [
        {
            "month_start": r["month_start"],
            "pricing_submissions": r["visitors_mql_pricing"],
            "enterprise_submissions": r["visitors_mql_enterprise"],
            "demo_submissions": r["visitors_mql_demo"],
        }
        for r in rows
    ]
    write_csv(
        OUT_DIR / "chart_04_mql_3component.csv",
        out,
        ["month_start", "pricing_submissions", "enterprise_submissions", "demo_submissions"],
    )


def chart_05_expansion_rate_vs_chargebee_events() -> None:
    """§5 — wide format: month_start, expansion_rate_30d, chargebee_distinct_plan_changes."""
    q03_rows = read_csv(TASK_ROOT / "q03.csv")
    expansion: dict[str, float] = {}
    for r in q03_rows:
        denom = float(r["qualifying_subs_for_expansion_rate"])
        num = float(r["expansions_qualifying"])
        expansion[r["month_start"]] = (num / denom) if denom > 0 else 0.0

    cb_rows = read_csv(
        TASK_ROOT / "followups/M1-tile12-expansion-root-cause/M1_chargebee_event_volume.csv"
    )
    cb_total: dict[str, str] = {r["month_start"]: r["total_change_events"] for r in cb_rows}
    cb_plan: dict[str, str] = {r["month_start"]: r["distinct_plan_changes"] for r in cb_rows}

    months = sorted(set(expansion) | set(cb_total))
    out = [
        {
            "month_start": m,
            "expansion_rate_30d": f"{expansion[m]:.6f}" if m in expansion else "",
            "chargebee_total_change_events": cb_total.get(m, ""),
            "chargebee_distinct_plan_changes": cb_plan.get(m, ""),
        }
        for m in months
    ]
    write_csv(
        OUT_DIR / "chart_05_expansion_rate_vs_chargebee_events.csv",
        out,
        [
            "month_start",
            "expansion_rate_30d",
            "chargebee_total_change_events",
            "chargebee_distinct_plan_changes",
        ],
    )


def chart_06_dl_30_60d_raw_vs_lagged() -> None:
    """§6 — wide format: cohort_month, raw_rate_30_60, lagged_clean_rate_30_60.

    Both series use the SAME denominator and numerator definitions as the
    LookML tile 9 measure (engaged_subs_30_60_qualifying / subs_60_plus).
    The only difference between the two series is which cohorts are emitted:

    - raw_rate_30_60: emitted for ALL cohorts in window. Right-censored
      cohorts (sub_start + 60d > today) have very few subs_60_plus and
      produce a real cliff at the right edge.
    - lagged_clean_rate_30_60: emitted only for fully-observable cohorts
      (sub_start + 60d <= today, i.e. cohort_fully_observable=1 in M5).

    For every fully-observable cohort, the two series are IDENTICAL by
    construction. The chart's purpose is to show that the apparent recent-
    edge collapse on the dashboard tile is a right-censoring artifact, not
    an engagement decline.

    Prior version of this function used subscribers_in_cohort as the raw
    denominator and subs_60_plus as the lagged denominator. That made the
    two series differ by ~10pp at every month due to a denominator mismatch
    (early-churners diluting the raw rate), not right-censoring. That was
    misleading and has been corrected.
    """
    q02_rows = read_csv(TASK_ROOT / "q02.csv")
    raw: dict[str, float | None] = {}
    for r in q02_rows:
        denom = float(r["subs_60_plus"])
        num = float(r["engaged_subs_30_60_qualifying"])
        raw[r["month_start"]] = (num / denom) if denom > 0 else None

    m5_rows = read_csv(
        TASK_ROOT / "followups/M5-engagement-lagged-windows/M5_engagement_lagged.csv"
    )
    lagged: dict[str, str] = {}
    for r in m5_rows:
        if r["cohort_fully_observable"] == "1":
            lagged[r["sub_start_month"]] = r["tile_9_pct_dl_30_60d"]

    months = sorted(set(raw) | set(lagged))
    out = [
        {
            "cohort_month": m,
            "raw_rate_30_60": (
                f"{raw[m]:.6f}" if (m in raw and raw[m] is not None) else ""
            ),
            "lagged_clean_rate_30_60": lagged.get(m, ""),
        }
        for m in months
    ]
    write_csv(
        OUT_DIR / "chart_06_dl_30_60d_raw_vs_lagged.csv",
        out,
        ["cohort_month", "raw_rate_30_60", "lagged_clean_rate_30_60"],
    )


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    chart_01_subscribing_sessions_by_channel()
    chart_02_plan_mix_y1_vs_y2()
    chart_03_signup_rate_visitor_vs_engaged()
    chart_04_mql_3component()
    chart_05_expansion_rate_vs_chargebee_events()
    chart_06_dl_30_60d_raw_vs_lagged()
    print(f"Wrote 6 chart-ready CSVs to {OUT_DIR}")


if __name__ == "__main__":
    main()
