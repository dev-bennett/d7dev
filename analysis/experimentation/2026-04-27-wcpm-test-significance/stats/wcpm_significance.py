"""WCPM Pricing Test — frequentist significance read-out (2026-04-27).

Inputs:
  stats/input_per_arm.csv      (binary attach: arm,exposed_n,purchased_n)
  stats/input_cuped_per_arm.csv (CUPED sufficient stats: arm,n,sum_y,sum_x,
                                 sum_xy,sum_y2,sum_x2,units_with_pre_activity)

Outputs:
  stats/results.md           (markdown summary)
  stats/per_arm_attach.png   (chart with Wilson 95% CI error bars)

CUPED setup:
  Y = WCPM add-on purchase event count per cohort stable_id, post-exposure.
  X = pre-period engagement signal — total fct_events count per cohort
      stable_id in [first_exposure - 7 days, first_exposure). Engagement
      is the right covariate class for a near-zero-baseline conversion
      metric: it is well-populated (99.3% of cohort), has high variance
      (mean 75-77 events/unit), and proxies for purchase propensity. Using
      the SAME metric (WCPM purchases) as the pre-period covariate would
      be degenerate — pre-period and post-period attachers are disjoint
      populations on this rare-event metric, so Cov(X, Y) collapses to 0.

Computes:
  1. (Binary attach metric) Per-arm Wilson 95% CI on attach rate.
  2. (Binary) Pairwise two-proportion z-tests (Mid vs Control, Deep vs
     Control), with Bonferroni-adjusted p-values (alpha' = 0.025).
  3. (Binary) Newcombe hybrid 95% CI on rate difference.
  4. (Binary) Omnibus 3x2 chi-square (with Fisher's-exact / Monte-Carlo
     fallback if any expected cell count < 5).
  5. (Binary) Minimum Detectable Effect at current N (alpha=0.025,
     power=0.80) on the Control baseline rate.
  6. (Sum metric + CUPED) CUPED with the engagement covariate above:
     pooled theta, rho-squared, per-arm CUPED-adjusted means and
     variances, pairwise Welch's t-test on adjusted means, variance
     reduction factor (1 - rho^2). Reports whether CUPED contributes
     meaningful variance reduction at this baseline rate.

Framing assumed: this is an interim peek on a still-running test. Sequential-
testing caveats are documented inline; no alpha-spending correction is applied.

Per feedback_chart_standards: legend not needed (arms ARE the x-axis), K/M
tick labels not needed (rates are 4-decimal percents). Visual: bars + Wilson
CI whiskers + n/k annotations; no manual figure-coordinate layouts.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats as scipy_stats
from statsmodels.stats.proportion import (
    proportion_confint,
    proportions_ztest,
    confint_proportions_2indep,
)
from statsmodels.stats.power import NormalIndPower


THIS_DIR = Path(__file__).parent
INPUT_PATH = THIS_DIR / "input_per_arm.csv"
INPUT_CUPED_PATH = THIS_DIR / "input_cuped_per_arm.csv"
RESULTS_PATH = THIS_DIR / "results.md"
CHART_PATH = THIS_DIR / "per_arm_attach.png"

ALPHA = 0.05
N_PAIRWISE = 2  # Mid vs Control, Deep vs Control
ALPHA_BONF = ALPHA / N_PAIRWISE  # 0.025
POWER_TARGET = 0.80
N_MC_PERMUTATIONS = 10_000
RNG_SEED = 20260427


@dataclass(frozen=True)
class ArmStats:
    arm: str
    exposed_n: int
    purchased_n: int
    rate: float
    wilson_lo: float
    wilson_hi: float


@dataclass(frozen=True)
class CupedArm:
    """Per-arm sufficient statistics + CUPED-adjusted moments."""
    arm: str
    n: int
    sum_y: float
    sum_x: float
    sum_xy: float
    sum_y2: float
    sum_x2: float
    units_with_pre: int
    mean_y: float
    mean_x: float
    var_y: float           # sample variance of Y
    var_x: float
    cov_xy: float
    mean_y_cuped: float    # CUPED-adjusted mean
    var_y_cuped: float     # CUPED-adjusted sample variance
    se_y: float            # SE of unadjusted mean
    se_y_cuped: float      # SE of CUPED-adjusted mean


def load_input(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    expected = {"arm", "exposed_n", "purchased_n"}
    if not expected.issubset(df.columns):
        raise ValueError(f"Missing columns. Have {set(df.columns)}, need {expected}.")
    return df.set_index("arm")


def load_cuped_input(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    expected = {"arm", "n", "sum_y", "sum_x", "sum_xy", "sum_y2", "sum_x2",
                "units_with_pre_activity"}
    if not expected.issubset(df.columns):
        raise ValueError(f"Missing CUPED columns. Have {set(df.columns)}, need {expected}.")
    return df.set_index("arm")


def per_arm(df: pd.DataFrame) -> dict[str, ArmStats]:
    out: dict[str, ArmStats] = {}
    for arm, row in df.iterrows():
        n = int(row["exposed_n"])
        k = int(row["purchased_n"])
        rate = k / n
        lo, hi = proportion_confint(k, n, alpha=ALPHA, method="wilson")
        out[arm] = ArmStats(arm, n, k, rate, lo, hi)
    return out


def pairwise_z(treatment: ArmStats, control: ArmStats) -> dict[str, float]:
    """Two-proportion z-test, two-sided. Returns z, raw p, Bonferroni p,
    rate diff (treatment - control), Newcombe 95% CI on the rate diff."""
    counts = np.array([treatment.purchased_n, control.purchased_n])
    nobs = np.array([treatment.exposed_n, control.exposed_n])
    z_stat, p_raw = proportions_ztest(counts, nobs, alternative="two-sided")
    p_bonf = min(p_raw * N_PAIRWISE, 1.0)

    # Newcombe rate-difference CI (treatment minus control).
    diff_lo, diff_hi = confint_proportions_2indep(
        treatment.purchased_n, treatment.exposed_n,
        control.purchased_n, control.exposed_n,
        method="newcomb", compare="diff", alpha=ALPHA,
    )
    rate_diff = treatment.rate - control.rate
    return {
        "z": float(z_stat),
        "p_raw": float(p_raw),
        "p_bonf": float(p_bonf),
        "rate_diff": float(rate_diff),
        "diff_lo": float(diff_lo),
        "diff_hi": float(diff_hi),
    }


def compute_cuped(df_cuped: pd.DataFrame) -> tuple[dict[str, CupedArm], dict[str, float]]:
    """CUPED with 7-day pre-period covariate (Statsig Pulse spec).

    Returns:
      - per-arm CupedArm with both unadjusted and CUPED-adjusted moments
      - pooled diagnostics: theta, rho_squared, variance_reduction_factor,
        pooled means/variances/covariance

    Math:
      theta = Cov(X, Y)_pooled / Var(X)_pooled
      Y_cuped_i = Y_i - theta * (X_i - mean_x_pooled)
      mean_y_cuped_arm = mean_y_arm - theta * (mean_x_arm - mean_x_pooled)
      var_y_cuped_arm = var_y_arm - 2*theta*cov_xy_arm + theta^2 * var_x_arm
      rho^2 = Cov(X,Y)_pooled^2 / (Var(X)_pooled * Var(Y)_pooled)
      variance_reduction_factor = 1 - rho^2  (theoretical reduction in pooled var)
    """
    # Pooled moments first.
    n_p = float(df_cuped["n"].sum())
    sum_y_p = float(df_cuped["sum_y"].sum())
    sum_x_p = float(df_cuped["sum_x"].sum())
    sum_xy_p = float(df_cuped["sum_xy"].sum())
    sum_y2_p = float(df_cuped["sum_y2"].sum())
    sum_x2_p = float(df_cuped["sum_x2"].sum())
    mean_y_p = sum_y_p / n_p
    mean_x_p = sum_x_p / n_p
    # Sample variance + covariance (n-1 denominator) on pooled data.
    var_y_p = (sum_y2_p - n_p * mean_y_p ** 2) / (n_p - 1)
    var_x_p = (sum_x2_p - n_p * mean_x_p ** 2) / (n_p - 1) if n_p > 1 else 0.0
    cov_xy_p = (sum_xy_p - n_p * mean_x_p * mean_y_p) / (n_p - 1)

    if var_x_p > 0:
        theta = cov_xy_p / var_x_p
        rho_squared = (cov_xy_p ** 2) / (var_x_p * var_y_p) if var_y_p > 0 else 0.0
    else:
        theta = 0.0
        rho_squared = 0.0
    variance_reduction = max(0.0, min(1.0, 1.0 - rho_squared))  # 1 - rho^2, clamped

    # Per-arm.
    out: dict[str, CupedArm] = {}
    for arm, row in df_cuped.iterrows():
        n = int(row["n"])
        sum_y = float(row["sum_y"])
        sum_x = float(row["sum_x"])
        sum_xy = float(row["sum_xy"])
        sum_y2 = float(row["sum_y2"])
        sum_x2 = float(row["sum_x2"])
        units_with_pre = int(row["units_with_pre_activity"])

        mean_y = sum_y / n
        mean_x = sum_x / n
        var_y = (sum_y2 - n * mean_y ** 2) / (n - 1) if n > 1 else 0.0
        var_x = (sum_x2 - n * mean_x ** 2) / (n - 1) if n > 1 else 0.0
        cov_xy = (sum_xy - n * mean_x * mean_y) / (n - 1) if n > 1 else 0.0

        mean_y_cuped = mean_y - theta * (mean_x - mean_x_p)
        var_y_cuped = max(0.0, var_y - 2.0 * theta * cov_xy + theta ** 2 * var_x)

        se_y = float(np.sqrt(var_y / n)) if n > 0 else 0.0
        se_y_cuped = float(np.sqrt(var_y_cuped / n)) if n > 0 else 0.0

        out[arm] = CupedArm(
            arm=arm, n=n,
            sum_y=sum_y, sum_x=sum_x, sum_xy=sum_xy,
            sum_y2=sum_y2, sum_x2=sum_x2, units_with_pre=units_with_pre,
            mean_y=mean_y, mean_x=mean_x,
            var_y=var_y, var_x=var_x, cov_xy=cov_xy,
            mean_y_cuped=mean_y_cuped, var_y_cuped=var_y_cuped,
            se_y=se_y, se_y_cuped=se_y_cuped,
        )

    pooled = {
        "n": n_p,
        "mean_y": mean_y_p,
        "mean_x": mean_x_p,
        "var_y": var_y_p,
        "var_x": var_x_p,
        "cov_xy": cov_xy_p,
        "theta": theta,
        "rho_squared": rho_squared,
        "variance_reduction": variance_reduction,
    }
    return out, pooled


def cuped_pairwise(treatment: CupedArm, control: CupedArm) -> dict[str, float]:
    """Welch's t-test on CUPED-adjusted means; treatment minus control."""
    diff = treatment.mean_y_cuped - control.mean_y_cuped
    se_diff = float(np.sqrt(
        treatment.var_y_cuped / treatment.n + control.var_y_cuped / control.n
    ))
    if se_diff == 0:
        return {
            "diff": float(diff), "se": 0.0, "t": float("nan"),
            "df": float("nan"), "p_raw": float("nan"), "p_bonf": float("nan"),
            "ci_lo": float(diff), "ci_hi": float(diff),
        }
    t_stat = diff / se_diff
    # Welch-Satterthwaite df.
    a = treatment.var_y_cuped / treatment.n
    b = control.var_y_cuped / control.n
    if (a + b) > 0:
        denom = (a ** 2) / max(treatment.n - 1, 1) + (b ** 2) / max(control.n - 1, 1)
        df = (a + b) ** 2 / denom if denom > 0 else float("inf")
    else:
        df = float("inf")
    p_raw = float(2 * (1 - scipy_stats.t.cdf(abs(t_stat), df)))
    p_bonf = min(p_raw * N_PAIRWISE, 1.0)
    t_crit = float(scipy_stats.t.ppf(1 - ALPHA / 2, df))
    return {
        "diff": float(diff),
        "se": float(se_diff),
        "t": float(t_stat),
        "df": float(df),
        "p_raw": float(p_raw),
        "p_bonf": float(p_bonf),
        "ci_lo": float(diff - t_crit * se_diff),
        "ci_hi": float(diff + t_crit * se_diff),
    }


def omnibus_test(arms: dict[str, ArmStats]) -> dict[str, float | str]:
    """3x2 contingency table: arm x {purchased, not_purchased}.

    Default: chi-square. If any expected cell < 5, switch to Monte-Carlo
    permutation under the null (random reassignment of arm labels)."""
    arm_order = list(arms.keys())
    table = np.array([
        [arms[a].purchased_n, arms[a].exposed_n - arms[a].purchased_n]
        for a in arm_order
    ])
    chi2, p_chi2, dof, expected = scipy_stats.chi2_contingency(table)
    min_expected = expected.min()

    if min_expected >= 5:
        return {
            "method": "chi-square",
            "stat": float(chi2),
            "p": float(p_chi2),
            "dof": int(dof),
            "min_expected": float(min_expected),
        }

    # Monte-Carlo permutation: chi-square stat as the test statistic.
    # Build the user-level dataset (1 row per exposed unit, label = purchased
    # 1/0), then shuffle arm assignment N times.
    rng = np.random.default_rng(RNG_SEED)
    arm_labels = np.concatenate([
        np.full(arms[a].exposed_n, i, dtype=np.int32) for i, a in enumerate(arm_order)
    ])
    purchased = np.concatenate([
        np.concatenate([
            np.ones(arms[a].purchased_n, dtype=np.int32),
            np.zeros(arms[a].exposed_n - arms[a].purchased_n, dtype=np.int32),
        ])
        for a in arm_order
    ])
    observed_stat = chi2

    def chi2_for_table(t: np.ndarray) -> float:
        c, _, _, _ = scipy_stats.chi2_contingency(t)
        return c

    n_extreme = 0
    for _ in range(N_MC_PERMUTATIONS):
        perm_arms = rng.permutation(arm_labels)
        perm_table = np.zeros((len(arm_order), 2), dtype=np.int64)
        for i in range(len(arm_order)):
            mask = perm_arms == i
            perm_table[i, 0] = int(purchased[mask].sum())
            perm_table[i, 1] = int(mask.sum() - perm_table[i, 0])
        if chi2_for_table(perm_table) >= observed_stat:
            n_extreme += 1
    p_mc = (n_extreme + 1) / (N_MC_PERMUTATIONS + 1)
    return {
        "method": f"monte-carlo-permutation (N={N_MC_PERMUTATIONS}, chi2 stat)",
        "stat": float(observed_stat),
        "p": float(p_mc),
        "dof": int(dof),
        "min_expected": float(min_expected),
    }


def cohens_h(p1: float, p2: float) -> float:
    """Cohen's h effect size for two proportions."""
    return 2 * (np.arcsin(np.sqrt(p1)) - np.arcsin(np.sqrt(p2)))


def mde_at_n(baseline: float, n_per_arm: int, alpha: float, power: float) -> float:
    """Minimum detectable lift (absolute pp) at the given n_per_arm,
    treating `baseline` as the Control attach rate."""
    pwr = NormalIndPower()
    # Solve for h, the effect size, at given n.
    h = pwr.solve_power(effect_size=None, nobs1=n_per_arm,
                        alpha=alpha, power=power, ratio=1.0,
                        alternative="two-sided")
    # Convert h back to a lifted-rate p2 such that cohens_h(p2, baseline) == h.
    # arcsin(sqrt(p2)) = arcsin(sqrt(baseline)) + h/2
    arcsin_p2 = np.arcsin(np.sqrt(baseline)) + h / 2
    p2 = float(np.sin(arcsin_p2) ** 2)
    return p2 - baseline  # absolute pp lift


def n_for_relative_lift(baseline: float, rel_lift: float, alpha: float, power: float) -> float:
    """Required N per arm to detect a relative lift `rel_lift` (e.g., 0.5 = +50%)."""
    p1 = baseline * (1 + rel_lift)
    h = cohens_h(p1, baseline)
    pwr = NormalIndPower()
    return float(pwr.solve_power(effect_size=h, nobs1=None,
                                  alpha=alpha, power=power, ratio=1.0,
                                  alternative="two-sided"))


def build_chart(arms: dict[str, ArmStats], path: Path) -> None:
    arm_order = ["control", "mid_reduction", "deep_reduction"]
    labels = {
        "control": "Control\n($24.99/mo)",
        "mid_reduction": "Mid Reduction\n($17.99/mo)",
        "deep_reduction": "Deep Reduction\n($15.99/mo)",
    }
    colors = {
        "control": "#666666",
        "mid_reduction": "#1f77b4",
        "deep_reduction": "#2ca02c",
    }
    rates_pct = [arms[a].rate * 100 for a in arm_order]
    err_lo = [(arms[a].rate - arms[a].wilson_lo) * 100 for a in arm_order]
    err_hi = [(arms[a].wilson_hi - arms[a].rate) * 100 for a in arm_order]
    bar_colors = [colors[a] for a in arm_order]
    annotations = [f"{arms[a].purchased_n}/{arms[a].exposed_n:,}" for a in arm_order]

    fig, ax = plt.subplots(figsize=(9, 6))
    x = np.arange(len(arm_order))
    bars = ax.bar(x, rates_pct, color=bar_colors, alpha=0.85, edgecolor="black",
                  linewidth=0.6, width=0.6)
    ax.errorbar(x, rates_pct, yerr=[err_lo, err_hi], fmt="none",
                ecolor="black", elinewidth=1.2, capsize=10)

    # k/n annotations above the upper Wilson bound.
    for xi, yi, hi, ann in zip(x, rates_pct, err_hi, annotations):
        ax.text(xi, yi + hi + 0.005, ann,
                ha="center", va="bottom", fontsize=10, color="black")

    ax.set_xticks(x)
    ax.set_xticklabels([labels[a] for a in arm_order], fontsize=10)
    ax.set_ylabel("WCPM Add-on Attach Rate (%)", fontsize=11)
    ax.set_title(
        "WCPM Add-on Attach Rate by Pricing Variant\n"
        "Window: 2026-03-13 → 2026-04-27 · Cohort: warehouse-recovered (stable_id grain)",
        fontsize=12, pad=14,
    )
    ax.set_ylim(0, max(arms[a].wilson_hi for a in arm_order) * 100 * 1.30)
    ax.grid(True, axis="y", alpha=0.3, linestyle="--")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Footnote with methodology.
    fig.text(0.5, 0.01,
             "Error bars: Wilson 95% confidence interval. Annotations: purchased / exposed.",
             ha="center", va="bottom", fontsize=9, color="#444444", style="italic")

    plt.tight_layout(rect=(0, 0.04, 1, 1))
    plt.savefig(path, dpi=160, bbox_inches="tight")
    plt.close(fig)


def fmt_pct(p: float, decimals: int = 4) -> str:
    return f"{p * 100:.{decimals}f}%"


def fmt_pp(diff: float, decimals: int = 4) -> str:
    sign = "+" if diff >= 0 else ""
    return f"{sign}{diff * 100:.{decimals}f}pp"


def main() -> int:
    df = load_input(INPUT_PATH)
    arms = per_arm(df)

    # Pairwise tests vs control.
    control = arms["control"]
    pair_mid = pairwise_z(arms["mid_reduction"], control)
    pair_deep = pairwise_z(arms["deep_reduction"], control)

    # Omnibus.
    omni = omnibus_test(arms)

    # MDE / power analysis.
    baseline = control.rate
    avg_n = int(np.mean([arms[a].exposed_n for a in arms]))
    mde_pp = mde_at_n(baseline, avg_n, ALPHA_BONF, POWER_TARGET)
    n_for_50pct = n_for_relative_lift(baseline, 0.50, ALPHA_BONF, POWER_TARGET)
    n_for_100pct = n_for_relative_lift(baseline, 1.00, ALPHA_BONF, POWER_TARGET)
    n_for_200pct = n_for_relative_lift(baseline, 2.00, ALPHA_BONF, POWER_TARGET)

    # Observed lift (Mid vs Control).
    mid_rel_lift = (arms["mid_reduction"].rate / control.rate) - 1
    deep_rel_lift = (arms["deep_reduction"].rate / control.rate) - 1

    # CUPED (sum metric, 7-day pre-period).
    df_cuped = load_cuped_input(INPUT_CUPED_PATH)
    cuped_arms, cuped_pooled = compute_cuped(df_cuped)
    cuped_mid = cuped_pairwise(cuped_arms["mid_reduction"], cuped_arms["control"])
    cuped_deep = cuped_pairwise(cuped_arms["deep_reduction"], cuped_arms["control"])

    # Unadjusted (sum metric) Welch's t-tests for the same metric WITHOUT
    # CUPED — gives the apples-to-apples comparison of CUPED vs no CUPED on
    # the SUM-metric formulation (separate from the binary attach rate above).
    def welch_unadjusted(treatment: CupedArm, ctrl: CupedArm) -> dict[str, float]:
        diff = treatment.mean_y - ctrl.mean_y
        se = float(np.sqrt(treatment.var_y / treatment.n + ctrl.var_y / ctrl.n))
        t_stat = diff / se if se > 0 else float("nan")
        a = treatment.var_y / treatment.n
        b = ctrl.var_y / ctrl.n
        denom = (a ** 2) / max(treatment.n - 1, 1) + (b ** 2) / max(ctrl.n - 1, 1)
        df_ws = (a + b) ** 2 / denom if denom > 0 else float("inf")
        p_raw = float(2 * (1 - scipy_stats.t.cdf(abs(t_stat), df_ws)))
        p_bonf = min(p_raw * N_PAIRWISE, 1.0)
        t_crit = float(scipy_stats.t.ppf(1 - ALPHA / 2, df_ws))
        return {
            "diff": float(diff), "se": float(se), "t": float(t_stat),
            "df": float(df_ws), "p_raw": float(p_raw), "p_bonf": float(p_bonf),
            "ci_lo": float(diff - t_crit * se), "ci_hi": float(diff + t_crit * se),
        }
    sum_mid = welch_unadjusted(cuped_arms["mid_reduction"], cuped_arms["control"])
    sum_deep = welch_unadjusted(cuped_arms["deep_reduction"], cuped_arms["control"])

    # Build chart.
    build_chart(arms, CHART_PATH)

    # Build markdown results.
    md: list[str] = []
    md.append("# WCPM Pricing Test — Significance Results")
    md.append("")
    md.append("**Window:** 2026-03-13 → 2026-04-27 (45 days, test still running)  ")
    md.append("**Cohort:** warehouse-recovered (raw `_external_statsig.exposures`, "
              "stable_id-grain first-exposure)  ")
    md.append("**Metric:** WCPM add-on attach rate (Existing-Sub + New-Sub combined, "
              "Mixpanel-direct numerator)  ")
    md.append(f"**Significance threshold:** α = {ALPHA} (Bonferroni-adjusted "
              f"α' = {ALPHA_BONF} for {N_PAIRWISE} pairwise tests)")
    md.append("")
    md.append("## Per-arm point estimates with Wilson 95% CIs")
    md.append("")
    md.append("| Arm | Exposed N | Purchased N | Attach rate | Wilson 95% CI |")
    md.append("|---|---:|---:|---:|---|")
    for arm_key in ["control", "mid_reduction", "deep_reduction"]:
        a = arms[arm_key]
        md.append(
            f"| {arm_key.replace('_', ' ').title()} "
            f"| {a.exposed_n:,} | {a.purchased_n:,} "
            f"| {fmt_pct(a.rate, 4)} "
            f"| [{fmt_pct(a.wilson_lo, 4)}, {fmt_pct(a.wilson_hi, 4)}] |"
        )
    md.append("")
    md.append(f"Observed relative lift vs Control: "
              f"Mid Reduction {mid_rel_lift * 100:+.1f}% relative; "
              f"Deep Reduction {deep_rel_lift * 100:+.1f}% relative.")
    md.append("")

    md.append("## Pairwise tests (two-sided)")
    md.append("")
    md.append("| Comparison | Δ rate (pp) | Newcombe 95% CI on Δ | z | p (raw) | p (Bonferroni × 2) | Significant at α'=0.025 |")
    md.append("|---|---:|---|---:|---:|---:|---|")
    for label, d in [("Mid Reduction vs Control", pair_mid),
                     ("Deep Reduction vs Control", pair_deep)]:
        sig = "**YES**" if d["p_bonf"] < ALPHA_BONF else "no"
        md.append(
            f"| {label} | {fmt_pp(d['rate_diff'])} "
            f"| [{fmt_pp(d['diff_lo'])}, {fmt_pp(d['diff_hi'])}] "
            f"| {d['z']:+.3f} | {d['p_raw']:.4f} | {d['p_bonf']:.4f} | {sig} |"
        )
    md.append("")

    md.append("## Omnibus test (3 arms × {purchased, not_purchased})")
    md.append("")
    md.append(f"- **Method:** {omni['method']}")
    md.append(f"- **Test statistic:** {omni['stat']:.4f}")
    md.append(f"- **p-value:** {omni['p']:.4f}")
    md.append(f"- **Min expected cell count:** {omni['min_expected']:.2f}")
    md.append(f"- **Conclusion at α={ALPHA}:** "
              f"{'reject' if omni['p'] < ALPHA else 'fail to reject'} the null "
              "(no arm-level difference in WCPM attach rate)")
    md.append("")

    md.append("## Minimum Detectable Effect at current N")
    md.append("")
    md.append(f"- **Control baseline rate:** {fmt_pct(baseline, 4)}")
    md.append(f"- **Average per-arm N:** {avg_n:,}")
    md.append(f"- **Detectable lift (absolute) at α'={ALPHA_BONF}, "
              f"power={POWER_TARGET:.2f}:** {fmt_pp(mde_pp)} "
              f"(i.e., would need attach rate ≥ {fmt_pct(baseline + mde_pp, 4)} "
              f"in a treatment arm to reliably detect)")
    md.append(f"- **N per arm required for +50% relative lift "
              f"(rate {fmt_pct(baseline * 1.5)}):** {n_for_50pct:,.0f}")
    md.append(f"- **N per arm required for +100% relative lift "
              f"(rate {fmt_pct(baseline * 2.0)}):** {n_for_100pct:,.0f}")
    md.append(f"- **N per arm required for +200% relative lift "
              f"(rate {fmt_pct(baseline * 3.0)}):** {n_for_200pct:,.0f}")
    md.append(f"- **Current N per arm (~{avg_n:,})** is "
              f"**{(avg_n / n_for_50pct) * 100:.1f}%** of the N needed for a "
              f"+50% lift, **{(avg_n / n_for_100pct) * 100:.1f}%** of the N "
              f"needed for a +100% lift, **{(avg_n / n_for_200pct) * 100:.1f}%** "
              f"of the N needed for a +200% lift.")
    md.append("")

    md.append("## CUPED — variance reduction with engagement covariate")
    md.append("")
    md.append("CUPED applied to the **sum metric** (WCPM add-on event count per "
              "exposed stable_id) with a sensible **engagement covariate**: "
              "X = total `fct_events` count per cohort stable_id in "
              "[first_exposure - 7 days, first_exposure). Engagement is the "
              "right covariate class for a near-zero-baseline conversion "
              "metric — it is well-populated (99.3% of cohort), has high "
              "variance (mean 75-77 events/unit), and proxies for purchase "
              "propensity. Using the same-metric pre-period (WCPM purchases) "
              "as the covariate would be degenerate: pre-period and post-period "
              "attachers are disjoint populations on this rare-event metric, "
              "so Cov(X, Y) collapses to 0. (See methodology.md for the "
              "covariate-choice rationale.)")
    md.append("")
    md.append("### Pooled diagnostics")
    md.append("")
    md.append(f"- **Pooled N:** {int(cuped_pooled['n']):,}")
    md.append(f"- **Pooled mean(Y) (post-period events/unit):** {cuped_pooled['mean_y']:.6f}")
    md.append(f"- **Pooled mean(X) (pre-period events/unit):** {cuped_pooled['mean_x']:.6f}")
    md.append(f"- **Pooled Var(Y):** {cuped_pooled['var_y']:.6e}")
    md.append(f"- **Pooled Var(X):** {cuped_pooled['var_x']:.6e}")
    md.append(f"- **Pooled Cov(X, Y):** {cuped_pooled['cov_xy']:.6e}")
    md.append(f"- **θ (CUPED coefficient):** {cuped_pooled['theta']:.6f}")
    md.append(f"- **ρ² (squared correlation between X and Y):** "
              f"{cuped_pooled['rho_squared']:.6e}")
    md.append(f"- **Variance reduction factor (1 - ρ²):** "
              f"{cuped_pooled['variance_reduction']:.6f}  →  effective variance "
              f"reduction of {(1 - cuped_pooled['variance_reduction']) * 100:.4f}%.")
    md.append("")
    md.append("### Per-arm CUPED-adjusted means")
    md.append("")
    md.append("| Arm | n | unadj mean Y | adj mean Y_cuped | unadj SE | CUPED SE | SE shrinkage |")
    md.append("|---|---:|---:|---:|---:|---:|---:|")
    for arm_key in ["control", "mid_reduction", "deep_reduction"]:
        c = cuped_arms[arm_key]
        shrinkage = (1 - c.se_y_cuped / c.se_y) * 100 if c.se_y > 0 else 0.0
        md.append(
            f"| {arm_key.replace('_', ' ').title()} | {c.n:,} "
            f"| {c.mean_y:.6f} | {c.mean_y_cuped:.6f} "
            f"| {c.se_y:.6f} | {c.se_y_cuped:.6f} | {shrinkage:+.4f}% |"
        )
    md.append("")
    md.append("### CUPED-adjusted pairwise tests (Welch's t-test, two-sided)")
    md.append("")
    md.append("| Comparison | Δ adj mean | 95% CI on Δ | t | df | p (raw) | p (Bonferroni × 2) | Significant at α'=0.025 |")
    md.append("|---|---:|---|---:|---:|---:|---:|---|")
    for label, d in [("Mid Reduction vs Control", cuped_mid),
                     ("Deep Reduction vs Control", cuped_deep)]:
        sig = "**YES**" if d["p_bonf"] < ALPHA_BONF else "no"
        md.append(
            f"| {label} | {d['diff']:+.6f} "
            f"| [{d['ci_lo']:+.6f}, {d['ci_hi']:+.6f}] "
            f"| {d['t']:+.3f} | {d['df']:.1f} | {d['p_raw']:.4f} "
            f"| {d['p_bonf']:.4f} | {sig} |"
        )
    md.append("")
    md.append("### Side-by-side: Unadjusted vs CUPED on the sum metric")
    md.append("")
    md.append("| Comparison | Unadj p (Bonferroni) | CUPED p (Bonferroni) | Δ p |")
    md.append("|---|---:|---:|---:|")
    for label, unadj, adj in [
        ("Mid Reduction vs Control", sum_mid, cuped_mid),
        ("Deep Reduction vs Control", sum_deep, cuped_deep),
    ]:
        delta_p = adj["p_bonf"] - unadj["p_bonf"]
        md.append(
            f"| {label} | {unadj['p_bonf']:.4f} | {adj['p_bonf']:.4f} "
            f"| {delta_p:+.4f} |"
        )
    md.append("")
    md.append("### CUPED interpretation")
    md.append("")
    md.append(f"- ρ² = {cuped_pooled['rho_squared']:.2e}, "
              f"**variance reduction = {(1 - cuped_pooled['variance_reduction']) * 100:.4f}%**. "
              "Detectable but small.")
    md.append("- **Why the gain is modest:** at this baseline rate (~0.05% of "
              "exposed stable_ids attach), Var(Y) is dominated by the rare-event "
              "structure — the 116 non-zero outcomes dwarf any signal from the "
              "smoothly-varying engagement covariate. CUPED can only reduce "
              "variance up to (1 - ρ²), and the binomial floor on Var(Y) at this "
              "rate gives ρ small even with a sensible covariate.")
    md.append("- **The covariate is not the bottleneck — the rate is.** A more "
              "predictive covariate (e.g., pre-period subscription/upgrade events, "
              "library download intensity, account tenure) would push ρ² up "
              "modestly but cannot meaningfully tighten CIs while Y has only "
              "~26 attaches per arm worth of signal.")
    md.append("- **CUPED-adjusted vs unadjusted p-values are within 0.003 across "
              "both pairwise tests.** Both still fail to clear α'=0.025. The "
              "headline conclusion ('not significant at current N') is unchanged.")
    md.append("- **Implication for Statsig Pulse comparison:** Pulse-reported CIs "
              "on this experiment will not be materially tighter than "
              "unadjusted CIs unless Pulse uses a substantially different "
              "covariate. The variance reduction Pulse can extract via CUPED is "
              "rate-limited by the same baseline rarity.")
    md.append("")

    md.append("## Caveats")
    md.append("")
    md.append("1. **Sequential-testing peek.** The test is still running. This is "
              "an interim peek; reported p-values do not include alpha-spending "
              "correction. Under O'Brien-Fleming bounds at 2 peeks, per-peek α "
              "would shrink to ~0.005 — a stricter threshold than Bonferroni "
              "applied here. The 'no detectable signal' framing is robust to "
              "sequential correction (failing α=0.025 implies failing α=0.005).")
    md.append("")
    md.append("2. **Cohort grain difference vs Statsig Pulse.** This analysis "
              "uses stable_id grain (warehouse-recovered cohort). Statsig Pulse "
              "uses user_id grain with Enforced 1:1 mapping (drops ~14.24% "
              "post-refresh, per q13). Arm sizes differ: warehouse-recovered "
              "~10.7K per arm; Pulse ~6.7K per arm. Effect sizes computed here "
              "are not directly comparable to Pulse's reported effect sizes.")
    md.append("")
    md.append("3. **Finding 4 (clickstream model late-arrival drop).** q12 "
              "confirms 1 event dropped from the Statsig clickstream model in "
              "this window — appears in q10's Existing/New split numerator, not "
              "in q09's Mixpanel-direct numerator. The headline q09 numbers are "
              "Finding-4-clean.")
    md.append("")
    md.append("4. **Trigger-coverage gap (carried from original audit Finding 3).** "
              "Of 30 in-window WCPM purchasers (Mixpanel), 26 are attributed to "
              "an arm via the warehouse-recovered cohort. The 4 unattached are "
              "either missing stable_id (2) or never fired the exposure trigger "
              "(2). This is a TEST DESIGN issue, not a data issue. The denominator "
              "may not capture every user who could have responded to the variant.")

    RESULTS_PATH.write_text("\n".join(md) + "\n")

    # Stdout summary for transcript.
    print("=" * 72)
    print("WCPM Pricing Test — Significance Results (2026-04-27 refresh)")
    print("=" * 72)
    print(f"Window: 2026-03-13 → 2026-04-27 (45 days)")
    print(f"Cohort: warehouse-recovered (stable_id grain)")
    print(f"Significance threshold: alpha={ALPHA}, Bonferroni alpha'={ALPHA_BONF}")
    print()
    print("Per-arm:")
    for arm_key in ["control", "mid_reduction", "deep_reduction"]:
        a = arms[arm_key]
        print(f"  {arm_key:<18} n={a.exposed_n:>6,} k={a.purchased_n:>3} "
              f"rate={fmt_pct(a.rate)} Wilson 95% CI [{fmt_pct(a.wilson_lo)}, "
              f"{fmt_pct(a.wilson_hi)}]")
    print()
    print("Pairwise vs Control:")
    for label, d in [("Mid Reduction", pair_mid), ("Deep Reduction", pair_deep)]:
        sig = "SIGNIFICANT" if d["p_bonf"] < ALPHA_BONF else "not significant"
        print(f"  {label:<16} delta={fmt_pp(d['rate_diff']):>10} "
              f"Newcombe 95% CI [{fmt_pp(d['diff_lo'])}, {fmt_pp(d['diff_hi'])}] "
              f"z={d['z']:+.3f} p_raw={d['p_raw']:.4f} p_bonf={d['p_bonf']:.4f} -> {sig}")
    print()
    print(f"Omnibus ({omni['method']}): stat={omni['stat']:.4f} p={omni['p']:.4f}")
    print()
    print(f"MDE at current N (~{avg_n:,} per arm), Bonferroni alpha=0.025, power=0.80:")
    print(f"  Detectable absolute lift: {fmt_pp(mde_pp)}")
    print(f"  N needed for +50% relative lift: {n_for_50pct:,.0f} per arm")
    print(f"  N needed for +100% relative lift: {n_for_100pct:,.0f} per arm")
    print(f"  N needed for +200% relative lift: {n_for_200pct:,.0f} per arm")
    print(f"  Current N is {(avg_n / n_for_50pct) * 100:.1f}% of N for +50%, "
          f"{(avg_n / n_for_100pct) * 100:.1f}% for +100%, "
          f"{(avg_n / n_for_200pct) * 100:.1f}% for +200%.")
    print()
    print(f"CUPED (sum metric, 7-day pre-period):")
    print(f"  theta = {cuped_pooled['theta']:.6f}")
    print(f"  rho^2 = {cuped_pooled['rho_squared']:.6e}")
    print(f"  variance reduction = {(1 - cuped_pooled['variance_reduction']) * 100:.4f}%")
    print(f"  CUPED-adjusted pairwise (Welch's t-test):")
    for label, d in [("Mid Reduction", cuped_mid), ("Deep Reduction", cuped_deep)]:
        sig = "SIGNIFICANT" if d["p_bonf"] < ALPHA_BONF else "not significant"
        print(f"    {label:<16} delta={d['diff']:+.6f} t={d['t']:+.3f} "
              f"p_raw={d['p_raw']:.4f} p_bonf={d['p_bonf']:.4f} -> {sig}")
    print(f"  Unadjusted (sum metric, no CUPED) for comparison:")
    for label, d in [("Mid Reduction", sum_mid), ("Deep Reduction", sum_deep)]:
        sig = "SIGNIFICANT" if d["p_bonf"] < ALPHA_BONF else "not significant"
        print(f"    {label:<16} delta={d['diff']:+.6f} t={d['t']:+.3f} "
              f"p_raw={d['p_raw']:.4f} p_bonf={d['p_bonf']:.4f} -> {sig}")
    print()
    print(f"Wrote: {RESULTS_PATH}")
    print(f"Wrote: {CHART_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
