"""
XmR Process Behavior Chart -- Display Impressions (Daily, Sliding 90-Day Baseline)
Two-panel chart: X chart (individuals) + mR chart (moving range)
with signal overlays by rule type.

Design: Helvetica Neue, muted cohesive palette, Tufte-minimal frame,
direct limit annotations, merged Rule 2 spans, year boundary markers.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.ticker as mticker
import matplotlib.patches as mpatches
import matplotlib.patheffects as pe
from matplotlib.lines import Line2D
from datetime import date
from pathlib import Path

# ---------------------------------------------------------------------------
# Load data
# ---------------------------------------------------------------------------
DATA_DIR = Path(__file__).parent
df = pd.read_csv(DATA_DIR / "display_impressions.csv", parse_dates=["DATE"])

bool_cols = [
    "SIGNAL_RULE_1", "SIGNAL_RULE_2", "SIGNAL_RULE_3",
    "SIGNAL_RULE_4", "MR_SIGNAL", "ANY_SIGNAL",
]
for col in bool_cols:
    if col not in df.columns:
        df[col] = False
    elif df[col].dtype == object:
        df[col] = df[col].str.lower().map({"true": True, "false": False}).fillna(False)
    else:
        df[col] = df[col].astype(bool)

# ---------------------------------------------------------------------------
# Design system
# ---------------------------------------------------------------------------
FONT_FAMILY = "Helvetica Neue"
plt.rcParams.update({
    "font.family": FONT_FAMILY,
    "font.size": 10,
    "axes.unicode_minus": False,
})

# Palette -- muted, cohesive, semantically encoded
BG_COLOR       = "#FFFFFF"
PANEL_BG       = "#F8FAFC"
GRID_COLOR     = "#E2E8F0"
TEXT_PRIMARY    = "#1E293B"
TEXT_SECONDARY  = "#64748B"
TEXT_TERTIARY   = "#94A3B8"

DATA_LINE      = "#334155"
DATA_POINT     = "#475569"
CENTER_LINE    = "#94A3B8"
LIMIT_LINE     = "#F43F5E"
LIMIT_ZONE     = "#FFF1F2"
SIGMA2_LINE    = "#F59E0B"
SIGMA2_ZONE    = "#FFFBEB"
YEAR_MARKER    = "#CBD5E1"

MR_LINE        = "#6366F1"
MR_POINT       = "#818CF8"
URL_LINE       = "#F43F5E"

SIGNAL_COLORS = {
    "rule_1": "#DC2626",  # red -- highest urgency (beyond limits)
    "rule_2": "#A78BFA",  # soft violet -- background context (run of 8)
    "rule_3": "#D97706",  # amber -- medium urgency (2-of-3 > 2σ)
    "rule_4": "#059669",  # emerald -- trend
    "mr":     "#4F46E5",  # indigo -- mR signal
}

SIGNAL_MARKERS = {
    "rule_1": {"marker": "o", "size": 80, "zorder": 8},
    "rule_3": {"marker": "D", "size": 52, "zorder": 7},
    "rule_4": {"marker": "^", "size": 58, "zorder": 7},
    "mr":     {"marker": "o", "size": 55, "zorder": 7},
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def fmt_k(x, pos):
    """Format axis ticks: 10K, 150K, etc."""
    if abs(x) >= 1_000:
        return f"{x / 1_000:.0f}K"
    return f"{x:.0f}"


def merge_contiguous_spans(dates, half_width):
    """Merge adjacent True-flagged dates into contiguous (start, end) spans."""
    if dates.empty:
        return []
    spans = []
    sorted_dates = dates.sort_values().reset_index(drop=True)
    start = sorted_dates.iloc[0] - half_width
    end = sorted_dates.iloc[0] + half_width
    for i in range(1, len(sorted_dates)):
        candidate_start = sorted_dates.iloc[i] - half_width
        candidate_end = sorted_dates.iloc[i] + half_width
        if candidate_start <= end:
            end = candidate_end
        else:
            spans.append((start, end))
            start = candidate_start
            end = candidate_end
    spans.append((start, end))
    return spans


def annotate_limit(ax, y_series, label, color, side="right"):
    """Place a direct label at the right edge of a limit line."""
    y_val = y_series.iloc[-1]
    x_val = df["DATE"].iloc[-1]
    ax.annotate(
        label,
        xy=(x_val, y_val),
        xytext=(8, 0),
        textcoords="offset points",
        fontsize=7.5,
        fontweight="medium",
        color=color,
        va="center",
        ha="left",
        path_effects=[pe.withStroke(linewidth=2.5, foreground=PANEL_BG)],
    )


# ---------------------------------------------------------------------------
# Figure layout
# ---------------------------------------------------------------------------
fig = plt.figure(figsize=(20, 11), facecolor=BG_COLOR)
gs = fig.add_gridspec(
    3, 1,
    height_ratios=[3.2, 1, 0.4],
    hspace=0.30,
    left=0.06, right=0.92, top=0.92, bottom=0.06,
)
ax_x = fig.add_subplot(gs[0])
ax_mr = fig.add_subplot(gs[1], sharex=ax_x)
ax_leg = fig.add_subplot(gs[2])
ax_leg.axis("off")

# ---------------------------------------------------------------------------
# Axes styling -- Tufte minimal frame
# ---------------------------------------------------------------------------
for ax in (ax_x, ax_mr):
    ax.set_facecolor(PANEL_BG)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(GRID_COLOR)
    ax.spines["left"].set_linewidth(0.8)
    ax.spines["bottom"].set_color(GRID_COLOR)
    ax.spines["bottom"].set_linewidth(0.8)
    # Horizontal grid only -- light, behind everything
    ax.yaxis.grid(True, color=GRID_COLOR, linewidth=0.4, alpha=0.7, zorder=0)
    ax.xaxis.grid(False)
    ax.tick_params(
        axis="both", which="both",
        colors=TEXT_SECONDARY, labelsize=8.5,
        length=3, width=0.6, direction="out",
    )
    ax.tick_params(axis="x", which="minor", length=0)

# ---------------------------------------------------------------------------
# Year boundary markers
# ---------------------------------------------------------------------------
year_starts = pd.to_datetime([
    f"{y}-01-01" for y in range(
        df["DATE"].dt.year.min(),
        df["DATE"].dt.year.max() + 2
    )
])
for ys in year_starts:
    if df["DATE"].min() < ys < df["DATE"].max():
        for ax in (ax_x, ax_mr):
            ax.axvline(ys, color=YEAR_MARKER, linewidth=0.8, linestyle="-", zorder=1, alpha=0.6)
        # Year label at top of X chart
        ax_x.annotate(
            str(ys.year),
            xy=(ys, 1.0), xycoords=("data", "axes fraction"),
            xytext=(4, -4), textcoords="offset points",
            fontsize=7.5, color=TEXT_TERTIARY, fontweight="medium",
            va="top", ha="left",
        )

# ===========================================================================
# PANEL 1: X Chart (Individuals)
# ===========================================================================

# --- Zone shading (layered, subtle) ---
ax_x.fill_between(df["DATE"], df["LNPL"], df["TWO_SIGMA_LOWER"],
                   color=LIMIT_ZONE, alpha=0.8, zorder=1, linewidth=0)
ax_x.fill_between(df["DATE"], df["TWO_SIGMA_LOWER"], df["TWO_SIGMA_UPPER"],
                   color=SIGMA2_ZONE, alpha=0.5, zorder=1, linewidth=0)
ax_x.fill_between(df["DATE"], df["TWO_SIGMA_UPPER"], df["UNPL"],
                   color=LIMIT_ZONE, alpha=0.8, zorder=1, linewidth=0)

# --- Control limit lines ---
ax_x.plot(df["DATE"], df["UNPL"], color=LIMIT_LINE, lw=0.9, ls="--",
          alpha=0.5, zorder=2, dash_capstyle="round")
ax_x.plot(df["DATE"], df["LNPL"], color=LIMIT_LINE, lw=0.9, ls="--",
          alpha=0.5, zorder=2, dash_capstyle="round")
ax_x.plot(df["DATE"], df["TWO_SIGMA_UPPER"], color=SIGMA2_LINE, lw=0.7, ls=(0, (3, 4)),
          alpha=0.35, zorder=2)
ax_x.plot(df["DATE"], df["TWO_SIGMA_LOWER"], color=SIGMA2_LINE, lw=0.7, ls=(0, (3, 4)),
          alpha=0.35, zorder=2)
ax_x.plot(df["DATE"], df["X_BAR"], color=CENTER_LINE, lw=1.0,
          alpha=0.7, zorder=2, solid_capstyle="round")

# Direct limit annotations (right edge)
annotate_limit(ax_x, df["UNPL"], "UNPL", LIMIT_LINE)
annotate_limit(ax_x, df["LNPL"], "LNPL", LIMIT_LINE)
annotate_limit(ax_x, df["X_BAR"], "X\u0304", CENTER_LINE)

# --- Rule 2 background (merged contiguous spans) ---
r2_spans = merge_contiguous_spans(
    df.loc[df["SIGNAL_RULE_2"], "DATE"],
    pd.Timedelta(hours=12),
)
for start, end in r2_spans:
    ax_x.axvspan(start, end, color=SIGNAL_COLORS["rule_2"], alpha=0.08, zorder=1, linewidth=0)

# --- Data line + consistent point markers ---
ax_x.plot(df["DATE"], df["VALUE"], color=DATA_LINE, lw=1.4, zorder=4,
          solid_capstyle="round", solid_joinstyle="round")
# Base dots on every point (small, subtle)
ax_x.scatter(df["DATE"], df["VALUE"], color=DATA_POINT,
             s=10, zorder=5, alpha=0.4, edgecolors="none")

# --- Signal markers (layered by priority: R4 < R3 < R1) ---
# Rule 4: trend
r4 = df[df["SIGNAL_RULE_4"] & ~df["SIGNAL_RULE_1"] & ~df["SIGNAL_RULE_3"]]
if not r4.empty:
    ax_x.scatter(r4["DATE"], r4["VALUE"],
                 color=SIGNAL_COLORS["rule_4"],
                 s=SIGNAL_MARKERS["rule_4"]["size"],
                 marker=SIGNAL_MARKERS["rule_4"]["marker"],
                 zorder=SIGNAL_MARKERS["rule_4"]["zorder"],
                 edgecolors="white", linewidths=0.6, alpha=0.9)

# Rule 3: 2-of-3 > 2σ (excluding R1 overlap)
r3 = df[df["SIGNAL_RULE_3"] & ~df["SIGNAL_RULE_1"]]
if not r3.empty:
    ax_x.scatter(r3["DATE"], r3["VALUE"],
                 color=SIGNAL_COLORS["rule_3"],
                 s=SIGNAL_MARKERS["rule_3"]["size"],
                 marker=SIGNAL_MARKERS["rule_3"]["marker"],
                 zorder=SIGNAL_MARKERS["rule_3"]["zorder"],
                 edgecolors="white", linewidths=0.6, alpha=0.9)

# Rule 1: beyond limits (top layer)
r1 = df[df["SIGNAL_RULE_1"]]
if not r1.empty:
    ax_x.scatter(r1["DATE"], r1["VALUE"],
                 color=SIGNAL_COLORS["rule_1"],
                 s=SIGNAL_MARKERS["rule_1"]["size"],
                 marker=SIGNAL_MARKERS["rule_1"]["marker"],
                 zorder=SIGNAL_MARKERS["rule_1"]["zorder"],
                 edgecolors="white", linewidths=0.8, alpha=0.95)

# --- Title + subtitle ---
fig.text(
    0.06, 0.96,
    "XmR Process Behavior Chart",
    fontsize=15, fontweight="bold", color=TEXT_PRIMARY,
)
fig.text(
    0.06, 0.935,
    "Display Impressions (Daily)  \u2022  Sliding 90-Day Baseline  \u2022  Wheeler Signal Rules",
    fontsize=9, color=TEXT_SECONDARY, style="italic",
)

ax_x.set_ylabel("Display Impressions", fontsize=9.5, color=TEXT_SECONDARY, labelpad=8)
ax_x.yaxis.set_major_formatter(mticker.FuncFormatter(fmt_k))
plt.setp(ax_x.get_xticklabels(), visible=False)

# ===========================================================================
# PANEL 2: mR Chart (Moving Range)
# ===========================================================================

# mR URL zone shading
ax_mr.fill_between(df["DATE"], 0, df["URL"],
                   color=PANEL_BG, alpha=1, zorder=1, linewidth=0)

ax_mr.plot(df["DATE"], df["MR"], color=MR_LINE, lw=1.1, zorder=3,
           solid_capstyle="round", solid_joinstyle="round")
ax_mr.scatter(df["DATE"], df["MR"], color=MR_POINT,
              s=8, zorder=4, alpha=0.35, edgecolors="none")
ax_mr.plot(df["DATE"], df["MR_BAR"], color=CENTER_LINE, lw=0.9,
           alpha=0.65, zorder=2)
ax_mr.plot(df["DATE"], df["URL"], color=URL_LINE, lw=0.8, ls="--",
           alpha=0.45, zorder=2, dash_capstyle="round")

# Direct annotations
annotate_limit(ax_mr, df["URL"], "URL", URL_LINE)
annotate_limit(ax_mr, df["MR_BAR"], "m\u0304R", CENTER_LINE)

# mR signal markers
mr_sig = df[df["MR_SIGNAL"]]
if not mr_sig.empty:
    ax_mr.scatter(mr_sig["DATE"], mr_sig["MR"],
                  color=SIGNAL_COLORS["mr"],
                  s=SIGNAL_MARKERS["mr"]["size"],
                  marker=SIGNAL_MARKERS["mr"]["marker"],
                  zorder=SIGNAL_MARKERS["mr"]["zorder"],
                  edgecolors="white", linewidths=0.7, alpha=0.9)

ax_mr.set_ylabel("Moving Range", fontsize=9, color=TEXT_SECONDARY, labelpad=8)
ax_mr.yaxis.set_major_formatter(mticker.FuncFormatter(fmt_k))
ax_mr.set_ylim(bottom=0)

# X-axis date formatting
ax_mr.xaxis.set_major_locator(mdates.WeekdayLocator(byweekday=mdates.MO, interval=2))
ax_mr.xaxis.set_major_formatter(mdates.DateFormatter("%b %d"))
ax_mr.xaxis.set_minor_locator(mdates.WeekdayLocator(byweekday=mdates.MO))
plt.setp(ax_mr.xaxis.get_majorticklabels(), rotation=45, ha="right", fontsize=8)

# Pad the x-axis so annotations don't clip
x_pad = pd.Timedelta(days=14)
ax_mr.set_xlim(df["DATE"].min() - x_pad, df["DATE"].max() + x_pad * 3)

# Data freshness note
last_date = df["DATE"].max().strftime("%b %d, %Y")
fig.text(
    0.92, 0.935,
    f"Through {last_date}",
    fontsize=7.5, color=TEXT_TERTIARY, ha="right", style="italic",
)

# ===========================================================================
# Legend -- outside chart, grouped: Signals | Reference
# ===========================================================================
signal_handles = [
    Line2D([], [], color=SIGNAL_COLORS["rule_1"], marker="o", linestyle="None",
           markersize=7, markeredgecolor="white", markeredgewidth=0.5,
           label="Rule 1: Beyond 3\u03c3"),
    mpatches.Patch(facecolor=SIGNAL_COLORS["rule_2"], alpha=0.25, edgecolor="none",
                   label="Rule 2: Run of 8"),
    Line2D([], [], color=SIGNAL_COLORS["rule_3"], marker="D", linestyle="None",
           markersize=5.5, markeredgecolor="white", markeredgewidth=0.5,
           label="Rule 3: 2-of-3 > 2\u03c3"),
    Line2D([], [], color=SIGNAL_COLORS["rule_4"], marker="^", linestyle="None",
           markersize=6, markeredgecolor="white", markeredgewidth=0.5,
           label="Rule 4: Trend of 6"),
    Line2D([], [], color=SIGNAL_COLORS["mr"], marker="o", linestyle="None",
           markersize=5.5, markeredgecolor="white", markeredgewidth=0.5,
           label="mR: Range Signal"),
]
ref_handles = [
    Line2D([], [], color=LIMIT_LINE, ls="--", lw=0.9, alpha=0.6, label="UNPL / LNPL"),
    Line2D([], [], color=SIGMA2_LINE, ls=(0, (3, 4)), lw=0.7, alpha=0.5, label="2\u03c3 Zone"),
    Line2D([], [], color=CENTER_LINE, lw=1.0, alpha=0.7, label="X\u0304 / m\u0304R"),
]

# Spacer separates signal group from reference group visually
spacer = Line2D([], [], color="none", marker="None", linestyle="None", label="  \u2502  ")
all_handles = signal_handles + [spacer] + ref_handles

leg = ax_leg.legend(
    handles=all_handles,
    loc="center",
    ncol=9,
    fontsize=8.5,
    frameon=True,
    fancybox=False,
    edgecolor=GRID_COLOR,
    facecolor=BG_COLOR,
    framealpha=1.0,
    columnspacing=1.8,
    handletextpad=0.6,
    handlelength=1.8,
    borderpad=0.8,
)
leg.get_frame().set_linewidth(0.6)

# ---------------------------------------------------------------------------
# Save to charts/<today>/
# ---------------------------------------------------------------------------
CHART_DIR = DATA_DIR.parent / "charts" / date.today().isoformat()
CHART_DIR.mkdir(parents=True, exist_ok=True)
out_path = CHART_DIR / "display_impressions.png"
fig.savefig(out_path, dpi=200, bbox_inches="tight", facecolor=BG_COLOR)
plt.close(fig)
print(f"Chart saved to {out_path}")
