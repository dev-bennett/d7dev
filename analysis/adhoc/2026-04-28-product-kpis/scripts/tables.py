"""Generate computed-rate tables for the 14 in-scope Product KPI tiles.

Replaces the deleted scripts/charts.py PNG generator. Same rate formulas, same
artifact-corrected variants for the session-denominator tiles, same censoring
flags for the cohort-window tiles — but written to CSV instead of rendered.

Inputs:
    ../q01.csv  fct_sessions tile components
    ../q02.csv  fct_subscriber_activity_mixpanel tile components
    ../q03.csv  subscription_changes_retention tile components
    ../q07.csv  real-vs-artifact session decomposition

Outputs (../tables/):
    kpi_summary.csv         wide; one row per month, all 14 tiles side-by-side
    tile_NN_<slug>.csv      long; one tile per file (14 files)
    regime_windows.csv      2 rows; cutover + APAC artifact windows for overlays
"""

from __future__ import annotations

import csv
from datetime import date
from pathlib import Path
from typing import Any, Callable

WORKSPACE = Path(__file__).resolve().parent.parent
TABLES = WORKSPACE / "tables"

DOMAIN_CUTOVER_START = date(2026, 3, 5)
DOMAIN_CUTOVER_END = date(2026, 3, 25)
APR_SPIKE_START = date(2026, 4, 14)
APR_SPIKE_END = date(2026, 4, 17)


def load_csv(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            parsed: dict[str, Any] = {"month_start": date.fromisoformat(row["month_start"])}
            for k, v in row.items():
                if k == "month_start":
                    continue
                if v == "" or v is None:
                    parsed[k] = None
                else:
                    try:
                        parsed[k] = float(v)
                    except ValueError:
                        parsed[k] = v
            rows.append(parsed)
    return rows


def safe_div(num: float | None, den: float | None) -> float | None:
    if num is None or den is None or den == 0:
        return None
    return num / den


def write_long(path: Path, header: list[str], rows: list[list[Any]]) -> None:
    with path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        for r in rows:
            w.writerow(["" if v is None else v for v in r])


def censor_flag(month: date, cutoff: date) -> int:
    return 1 if month >= cutoff else 0


def main() -> None:
    TABLES.mkdir(exist_ok=True)
    q01 = load_csv(WORKSPACE / "q01.csv")
    q02 = load_csv(WORKSPACE / "q02.csv")
    q03 = load_csv(WORKSPACE / "q03.csv")
    q07 = load_csv(WORKSPACE / "q07.csv")

    real_sessions: dict[date, float] = {}
    for r in q07:
        if r["bucket"] == "1_real":
            real_sessions[r["month_start"]] = r["sessions"]

    months_q01 = [r["month_start"] for r in q01]
    months_q02 = [r["month_start"] for r in q02]
    months_q03 = [r["month_start"] for r in q03]

    by_q01 = {r["month_start"]: r for r in q01}
    by_q02 = {r["month_start"]: r for r in q02}
    by_q03 = {r["month_start"]: r for r in q03}

    # ---- TILE 1: revenue / session (LTV-approximated) ----
    t1_rows: list[list[Any]] = []
    for r in q01:
        mqls = (r["visitors_mql_pricing"] or 0) + (r["visitors_mql_enterprise"] or 0) + (r["visitors_mql_demo"] or 0)
        revenue = (r["license_revenue"] or 0) + (r["subscribing_sessions"] or 0) * 200 + mqls * 300
        rate_rep = safe_div(revenue, r["sessions_total"])
        rate_cor = safe_div(revenue, real_sessions.get(r["month_start"], r["sessions_total"]))
        t1_rows.append([r["month_start"], rate_rep, rate_cor, r["subscribing_sessions"], 0])
    write_long(TABLES / "tile_01_revenue_per_session.csv",
               ["month_start", "rate_reported", "rate_corrected", "subscribing_sessions", "censored_flag"],
               t1_rows)

    # ---- TILE 2: avg LTV / transaction ----
    t2_rows: list[list[Any]] = []
    for r in q01:
        revenue = (r["license_revenue"] or 0) + (r["subscribing_sessions"] or 0) * 200
        denom = (r["subscribing_sessions"] or 0) + (r["license_sessions"] or 0)
        t2_rows.append([r["month_start"], safe_div(revenue, denom), denom, 0])
    write_long(TABLES / "tile_02_ltv_per_transaction.csv",
               ["month_start", "avg_revenue_per_transaction", "transactions", "censored_flag"],
               t2_rows)

    # ---- TILE 3: revenue / engaged session ----
    t3_rows: list[list[Any]] = []
    for r in q01:
        rev_eng = (r["license_revenue_engaged"] or 0) + (r["subscribing_sessions"] or 0) * 200
        t3_rows.append([r["month_start"], safe_div(rev_eng, r["sessions_engaged"]), r["sessions_engaged"], 0])
    write_long(TABLES / "tile_03_revenue_per_engaged_session.csv",
               ["month_start", "rate_reported", "engaged_sessions", "censored_flag"],
               t3_rows)

    # ---- TILE 4: purchase CVR / session ----
    t4_rows: list[list[Any]] = []
    for r in q01:
        num = (r["subscribing_sessions"] or 0) + (r["license_sessions"] or 0)
        rate_rep = safe_div(num, r["sessions_total"])
        rate_cor = safe_div(num, real_sessions.get(r["month_start"], r["sessions_total"]))
        t4_rows.append([r["month_start"], rate_rep, rate_cor, num, 0])
    write_long(TABLES / "tile_04_purchase_cvr.csv",
               ["month_start", "rate_reported", "rate_corrected", "conversions", "censored_flag"],
               t4_rows)

    # ---- TILE 5: sign-ups / session (visitor numerator over session denominator) ----
    t5_rows: list[list[Any]] = []
    for r in q01:
        rate_rep = safe_div(r["visitors_signed_up"], r["sessions_total"])
        rate_cor = safe_div(r["visitors_signed_up"], real_sessions.get(r["month_start"], r["sessions_total"]))
        t5_rows.append([r["month_start"], rate_rep, rate_cor, r["visitors_signed_up"], 0])
    write_long(TABLES / "tile_05_signups_per_session.csv",
               ["month_start", "rate_reported", "rate_corrected", "signed_up_visitors", "censored_flag"],
               t5_rows)

    # ---- TILE 6: MQLs / session (3-component visitor sum, may double-count) ----
    t6_rows: list[list[Any]] = []
    for r in q01:
        mqls = (r["visitors_mql_pricing"] or 0) + (r["visitors_mql_enterprise"] or 0) + (r["visitors_mql_demo"] or 0)
        rate_rep = safe_div(mqls, r["sessions_total"])
        rate_cor = safe_div(mqls, real_sessions.get(r["month_start"], r["sessions_total"]))
        t6_rows.append([
            r["month_start"], rate_rep, rate_cor, mqls,
            r["visitors_mql_pricing"], r["visitors_mql_enterprise"], r["visitors_mql_demo"], 0,
        ])
    write_long(TABLES / "tile_06_mqls_per_session.csv",
               ["month_start", "rate_reported", "rate_corrected", "mql_visitors_3component_sum",
                "mql_pricing", "mql_enterprise", "mql_demo", "censored_flag"],
               t6_rows)

    # ---- TILE 7: % subs downloading 0-7d ----
    t7_rows: list[list[Any]] = []
    for r in q02:
        m = r["month_start"]
        t7_rows.append([m, safe_div(r["subs_dl_first_7d"], r["subscribers_in_cohort"]),
                        r["subscribers_in_cohort"], censor_flag(m, date(2026, 4, 1))])
    write_long(TABLES / "tile_07_pct_dl_first_7d.csv",
               ["month_start", "rate_reported", "subscribers_in_cohort", "censored_flag"],
               t7_rows)

    # ---- TILE 8: songs / subscriber 0-30d ----
    t8_rows: list[list[Any]] = []
    for r in q02:
        m = r["month_start"]
        t8_rows.append([m, safe_div(r["songs_dl_first_30d_total"], r["subscribers_in_cohort"]),
                        r["subscribers_in_cohort"], censor_flag(m, date(2026, 3, 1))])
    write_long(TABLES / "tile_08_songs_per_sub_0_30d.csv",
               ["month_start", "songs_per_subscriber", "subscribers_in_cohort", "censored_flag"],
               t8_rows)

    # ---- TILE 9: % subs downloading 30-60d ----
    t9_rows: list[list[Any]] = []
    for r in q02:
        m = r["month_start"]
        t9_rows.append([m, safe_div(r["engaged_subs_30_60_qualifying"], r["subs_60_plus"]),
                        r["subs_60_plus"], censor_flag(m, date(2026, 3, 1))])
    write_long(TABLES / "tile_09_pct_dl_30_60d.csv",
               ["month_start", "rate_reported", "subs_60_plus", "censored_flag"],
               t9_rows)

    # ---- TILE 10: sessions / engaged sub 30-60d ----
    t10_rows: list[list[Any]] = []
    for r in q02:
        m = r["month_start"]
        t10_rows.append([m, safe_div(r["sessions_in_30_60_window_engaged"], r["engaged_subs_30_60_total"]),
                         r["engaged_subs_30_60_total"], censor_flag(m, date(2026, 3, 1))])
    write_long(TABLES / "tile_10_sessions_per_engaged_30_60.csv",
               ["month_start", "sessions_per_engaged_sub", "engaged_subs_30_60", "censored_flag"],
               t10_rows)

    # ---- TILE 11: engaged visitor sign-up CVR ----
    t11_rows: list[list[Any]] = []
    for r in q01:
        t11_rows.append([r["month_start"],
                         safe_div(r["engaged_visitors_signed_up"], r["visitors_engaged"]),
                         r["visitors_engaged"], 0])
    write_long(TABLES / "tile_11_engaged_signup_cvr.csv",
               ["month_start", "rate_reported", "engaged_visitors", "censored_flag"],
               t11_rows)

    # ---- TILE 12: subscription expansion rate (KEY real signal) ----
    t12_rows: list[list[Any]] = []
    for r in q03:
        t12_rows.append([r["month_start"],
                         safe_div(r["expansions_qualifying"], r["qualifying_subs_for_expansion_rate"]),
                         r["expansions_qualifying"], r["qualifying_subs_for_expansion_rate"], 0])
    write_long(TABLES / "tile_12_expansion_rate.csv",
               ["month_start", "rate_reported", "expansions_qualifying",
                "qualifying_subs_for_expansion_rate", "censored_flag"],
               t12_rows)

    # ---- TILE 13: avg 1-yr LTV value of expansion ----
    t13_rows: list[list[Any]] = []
    for r in q03:
        t13_rows.append([r["month_start"],
                         safe_div(r["expansion_value_total"], r["expansions_all"]),
                         r["expansions_all"], 0])
    write_long(TABLES / "tile_13_avg_expansion_value.csv",
               ["month_start", "avg_expansion_value_usd", "expansions_all_n", "censored_flag"],
               t13_rows)

    # ---- TILE 14: placeholder (= tile 1) ----
    t14_rows: list[list[Any]] = list(t1_rows)
    write_long(TABLES / "tile_14_placeholder.csv",
               ["month_start", "rate_reported", "rate_corrected", "subscribing_sessions",
                "censored_flag"],
               t14_rows)

    # ---- KPI SUMMARY (wide) ----
    summary_header = [
        "month_start",
        "tile_01_revenue_per_session_reported", "tile_01_revenue_per_session_corrected",
        "tile_01_subscribing_sessions",
        "tile_02_avg_revenue_per_transaction", "tile_02_transactions",
        "tile_03_revenue_per_engaged_session", "tile_03_engaged_sessions",
        "tile_04_purchase_cvr_reported", "tile_04_purchase_cvr_corrected", "tile_04_conversions",
        "tile_05_signups_per_session_reported", "tile_05_signups_per_session_corrected", "tile_05_signed_up_visitors",
        "tile_06_mqls_per_session_reported", "tile_06_mqls_per_session_corrected",
        "tile_06_mql_visitors_3component_sum",
        "tile_06_mql_pricing", "tile_06_mql_enterprise", "tile_06_mql_demo",
        "tile_07_pct_dl_first_7d", "tile_07_subscribers_in_cohort", "tile_07_censored_flag",
        "tile_08_songs_per_sub_0_30d", "tile_08_subscribers_in_cohort", "tile_08_censored_flag",
        "tile_09_pct_dl_30_60d", "tile_09_subs_60_plus", "tile_09_censored_flag",
        "tile_10_sessions_per_engaged_30_60", "tile_10_engaged_subs_30_60", "tile_10_censored_flag",
        "tile_11_engaged_signup_cvr", "tile_11_engaged_visitors",
        "tile_12_expansion_rate", "tile_12_expansions_qualifying",
        "tile_12_qualifying_subs_for_expansion_rate",
        "tile_13_avg_expansion_value_usd", "tile_13_expansions_all_n",
        "tile_14_revenue_per_session_reported", "tile_14_revenue_per_session_corrected",
        "tile_14_subscribing_sessions",
    ]
    all_months = sorted(set(months_q01) | set(months_q02) | set(months_q03))
    summary_rows: list[list[Any]] = []
    for m in all_months:
        r1 = by_q01.get(m, {})
        r2 = by_q02.get(m, {})
        r3 = by_q03.get(m, {})

        if r1:
            mqls = ((r1.get("visitors_mql_pricing") or 0) + (r1.get("visitors_mql_enterprise") or 0)
                    + (r1.get("visitors_mql_demo") or 0))
            t1_revenue = (r1.get("license_revenue") or 0) + (r1.get("subscribing_sessions") or 0) * 200 + mqls * 300
            t1_rep = safe_div(t1_revenue, r1.get("sessions_total"))
            t1_cor = safe_div(t1_revenue, real_sessions.get(m, r1.get("sessions_total")))
            t2_rev = (r1.get("license_revenue") or 0) + (r1.get("subscribing_sessions") or 0) * 200
            t2_den = (r1.get("subscribing_sessions") or 0) + (r1.get("license_sessions") or 0)
            t2 = safe_div(t2_rev, t2_den)
            t3_num = (r1.get("license_revenue_engaged") or 0) + (r1.get("subscribing_sessions") or 0) * 200
            t3 = safe_div(t3_num, r1.get("sessions_engaged"))
            t4_num = (r1.get("subscribing_sessions") or 0) + (r1.get("license_sessions") or 0)
            t4_rep = safe_div(t4_num, r1.get("sessions_total"))
            t4_cor = safe_div(t4_num, real_sessions.get(m, r1.get("sessions_total")))
            t5_rep = safe_div(r1.get("visitors_signed_up"), r1.get("sessions_total"))
            t5_cor = safe_div(r1.get("visitors_signed_up"), real_sessions.get(m, r1.get("sessions_total")))
            t6_rep = safe_div(mqls, r1.get("sessions_total"))
            t6_cor = safe_div(mqls, real_sessions.get(m, r1.get("sessions_total")))
            t11 = safe_div(r1.get("engaged_visitors_signed_up"), r1.get("visitors_engaged"))
        else:
            t1_rep = t1_cor = t2 = t3 = t4_rep = t4_cor = t5_rep = t5_cor = t6_rep = t6_cor = t11 = None
            t2_den = t4_num = mqls = 0

        if r2:
            t7 = safe_div(r2.get("subs_dl_first_7d"), r2.get("subscribers_in_cohort"))
            t8 = safe_div(r2.get("songs_dl_first_30d_total"), r2.get("subscribers_in_cohort"))
            t9 = safe_div(r2.get("engaged_subs_30_60_qualifying"), r2.get("subs_60_plus"))
            t10 = safe_div(r2.get("sessions_in_30_60_window_engaged"), r2.get("engaged_subs_30_60_total"))
        else:
            t7 = t8 = t9 = t10 = None

        if r3:
            t12 = safe_div(r3.get("expansions_qualifying"), r3.get("qualifying_subs_for_expansion_rate"))
            t13 = safe_div(r3.get("expansion_value_total"), r3.get("expansions_all"))
        else:
            t12 = t13 = None

        summary_rows.append([
            m,
            t1_rep, t1_cor, r1.get("subscribing_sessions") if r1 else None,
            t2, t2_den if r1 else None,
            t3, r1.get("sessions_engaged") if r1 else None,
            t4_rep, t4_cor, t4_num if r1 else None,
            t5_rep, t5_cor, r1.get("visitors_signed_up") if r1 else None,
            t6_rep, t6_cor, mqls if r1 else None,
            r1.get("visitors_mql_pricing") if r1 else None,
            r1.get("visitors_mql_enterprise") if r1 else None,
            r1.get("visitors_mql_demo") if r1 else None,
            t7, r2.get("subscribers_in_cohort") if r2 else None, censor_flag(m, date(2026, 4, 1)),
            t8, r2.get("subscribers_in_cohort") if r2 else None, censor_flag(m, date(2026, 3, 1)),
            t9, r2.get("subs_60_plus") if r2 else None, censor_flag(m, date(2026, 3, 1)),
            t10, r2.get("engaged_subs_30_60_total") if r2 else None, censor_flag(m, date(2026, 3, 1)),
            t11, r1.get("visitors_engaged") if r1 else None,
            t12, r3.get("expansions_qualifying") if r3 else None,
            r3.get("qualifying_subs_for_expansion_rate") if r3 else None,
            t13, r3.get("expansions_all") if r3 else None,
            t1_rep, t1_cor, r1.get("subscribing_sessions") if r1 else None,
        ])
    write_long(TABLES / "kpi_summary.csv", summary_header, summary_rows)

    # ---- REGIME WINDOWS ----
    write_long(TABLES / "regime_windows.csv",
               ["window_id", "label", "start_date", "end_date", "kind"],
               [
                   ["W1", "Domain consolidation artifact (DE/NL/CA Direct)",
                    DOMAIN_CUTOVER_START, DOMAIN_CUTOVER_END, "session_denominator_artifact"],
                   ["W2", "APAC Direct artifact",
                    APR_SPIKE_START, APR_SPIKE_END, "session_denominator_artifact"],
               ])


if __name__ == "__main__":
    main()
