"""
XmR Process Behavior Chart -- New Subscribers (Weekly, Sliding 20-Week Baseline)
Two-panel chart: X chart (individuals) + mR chart (moving range).
"""

import pandas as pd
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
df = pd.read_csv(DATA_DIR / "new_subscribers.csv", parse_dates=["WEEK_START"])

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
FONT = "Helvetica Neue"
plt.rcParams.update({
    "font.family": FONT,
    "font.size": 10,
    "axes.unicode_minus": False,
})

BG           = "#FFFFFF"
PANEL_BG     = "#F8F9FA"
GRID_COLOR   = "#DEE2E6"
GRID_LIGHT   = "#F1F3F5"
TEXT_1       = "#212529"
TEXT_2       = "#495057"
TEXT_3       = "#868E96"

DATA_LINE    = "#1C1C1E"
DATA_POINT   = "#343A40"
CENTER_LINE  = "#ADB5BD"

LIMIT_LINE   = "#E8425A"
LIMIT_ZONE   = "#FFF0F1"
SIGMA2_LINE  = "#E8850C"
SIGMA2_ZONE  = "#FFF8E1"

YEAR_LINE    = "#CED4DA"

MR_LINE      = "#5856D6"
MR_POINT     = "#7A79E0"
URL_LINE     = "#E8425A"

SIGNAL = {
    "R1":  "#E8425A",
    "R2":  "#B197FC",
    "R3":  "#F08C00",
    "R4":  "#12B886",
    "mR":  "#5856D6",
}

MARKERS = {
    "R1": {"m": "o", "s": 80, "z": 8},
    "R3": {"m": "D", "s": 55, "z": 7},
    "R4": {"m": "s", "s": 50, "z": 7},
    "mR": {"m": "o", "s": 55, "z": 7},
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def fmt_k(x, pos):
    if abs(x) >= 1_000:
        return f"{x / 1_000:.0f}K"
    return f"{x:.0f}"


def merge_spans(dates, hw):
    if dates.empty:
        return []
    spans, sd = [], dates.sort_values().reset_index(drop=True)
    s, e = sd.iloc[0] - hw, sd.iloc[0] + hw
    for i in range(1, len(sd)):
        cs, ce = sd.iloc[i] - hw, sd.iloc[i] + hw
        if cs <= e:
            e = ce
        else:
            spans.append((s, e)); s, e = cs, ce
    spans.append((s, e))
    return spans


def annot_limit(ax, y_series, date_col, label, color):
    ax.annotate(
        label,
        xy=(df[date_col].iloc[-1], y_series.iloc[-1]),
        xytext=(6, 0), textcoords="offset points",
        fontsize=7, fontweight="bold", color=color, va="center", ha="left",
        path_effects=[pe.withStroke(linewidth=3, foreground=PANEL_BG)],
    )


class MonthYearFormatter(mticker.Formatter):
    """Show 'Jan\\n2025' for January, just 'Feb', 'Mar', etc. otherwise."""
    def __call__(self, x, pos=None):
        dt = mdates.num2date(x)
        if dt.month == 1:
            return f"{dt.strftime('%b')}\n{dt.year}"
        return dt.strftime("%b")


def setup_month_axis(ax):
    ax.xaxis.set_major_locator(mdates.MonthLocator())
    ax.xaxis.set_major_formatter(MonthYearFormatter())
    ax.xaxis.set_minor_locator(mdates.WeekdayLocator(byweekday=mdates.MO))
    plt.setp(ax.xaxis.get_majorticklabels(), rotation=0, ha="center", fontsize=7)


# ---------------------------------------------------------------------------
# Figure layout -- X chart + mR chart + legend
# ---------------------------------------------------------------------------
fig = plt.figure(figsize=(26, 10), facecolor=BG)
gs = fig.add_gridspec(
    3, 1,
    height_ratios=[3.5, 1.1, 0.22],
    hspace=0.12,
    left=0.05, right=0.93, top=0.92, bottom=0.06,
)
ax_x = fig.add_subplot(gs[0])
ax_mr = fig.add_subplot(gs[1], sharex=ax_x)
ax_leg = fig.add_subplot(gs[2])
ax_leg.axis("off")

# ---------------------------------------------------------------------------
# Axes styling
# ---------------------------------------------------------------------------
for ax in (ax_x, ax_mr):
    ax.set_facecolor(PANEL_BG)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_color(GRID_COLOR)
    ax.spines["left"].set_linewidth(0.7)
    ax.spines["bottom"].set_color(GRID_COLOR)
    ax.spines["bottom"].set_linewidth(0.7)
    ax.yaxis.grid(True, color=GRID_COLOR, linewidth=0.35, zorder=0)
    ax.xaxis.grid(True, color=GRID_LIGHT, linewidth=0.25, zorder=0)
    ax.tick_params(axis="both", which="both", colors=TEXT_2, labelsize=8,
                   length=3, width=0.5, direction="out")
    ax.tick_params(axis="x", which="minor", length=0)

setup_month_axis(ax_x)
setup_month_axis(ax_mr)

# Year boundary markers
years = pd.to_datetime([
    f"{y}-01-01" for y in range(
        df["WEEK_START"].dt.year.min(),
        df["WEEK_START"].dt.year.max() + 2,
    )
])
for ys in years:
    if df["WEEK_START"].min() < ys < df["WEEK_START"].max():
        for ax in (ax_x, ax_mr):
            ax.axvline(ys, color=YEAR_LINE, lw=1.0, ls="-", zorder=1)
        ax_x.annotate(
            str(ys.year), xy=(ys, 1.0), xycoords=("data", "axes fraction"),
            xytext=(5, -6), textcoords="offset points",
            fontsize=8, color=TEXT_3, fontweight="bold", va="top", ha="left",
        )

x_pad = pd.Timedelta(days=14)
ax_x.set_xlim(df["WEEK_START"].min() - x_pad, df["WEEK_START"].max() + x_pad * 3)

# ===========================================================================
# PANEL 1: X Chart
# ===========================================================================

ax_x.fill_between(df["WEEK_START"], df["LNPL"], df["TWO_SIGMA_LOWER"],
                   color=LIMIT_ZONE, zorder=1, linewidth=0)
ax_x.fill_between(df["WEEK_START"], df["TWO_SIGMA_LOWER"], df["TWO_SIGMA_UPPER"],
                   color=SIGMA2_ZONE, alpha=0.6, zorder=1, linewidth=0)
ax_x.fill_between(df["WEEK_START"], df["TWO_SIGMA_UPPER"], df["UNPL"],
                   color=LIMIT_ZONE, zorder=1, linewidth=0)

ax_x.plot(df["WEEK_START"], df["UNPL"], color=LIMIT_LINE, lw=0.8, ls="--", alpha=0.5, zorder=2)
ax_x.plot(df["WEEK_START"], df["LNPL"], color=LIMIT_LINE, lw=0.8, ls="--", alpha=0.5, zorder=2)
ax_x.plot(df["WEEK_START"], df["TWO_SIGMA_UPPER"], color=SIGMA2_LINE, lw=0.6, ls=(0, (3, 4)), alpha=0.35, zorder=2)
ax_x.plot(df["WEEK_START"], df["TWO_SIGMA_LOWER"], color=SIGMA2_LINE, lw=0.6, ls=(0, (3, 4)), alpha=0.35, zorder=2)
ax_x.plot(df["WEEK_START"], df["X_BAR"], color=CENTER_LINE, lw=1.0, alpha=0.7, zorder=2)

annot_limit(ax_x, df["UNPL"], "WEEK_START", "UNPL", LIMIT_LINE)
annot_limit(ax_x, df["LNPL"], "WEEK_START", "LNPL", LIMIT_LINE)
annot_limit(ax_x, df["X_BAR"], "WEEK_START", "X\u0304", CENTER_LINE)

for s, e in merge_spans(df.loc[df["SIGNAL_RULE_2"], "WEEK_START"], pd.Timedelta(days=3.5)):
    ax_x.axvspan(s, e, color=SIGNAL["R2"], alpha=0.08, zorder=1, linewidth=0)

ax_x.plot(df["WEEK_START"], df["VALUE"], color=DATA_LINE, lw=1.5, zorder=4,
          solid_capstyle="round", solid_joinstyle="round")
ax_x.scatter(df["WEEK_START"], df["VALUE"], color=DATA_POINT,
             s=12, zorder=5, alpha=0.45, edgecolors="none")

for rule, filt, excl in [
    ("R4", "SIGNAL_RULE_4", ["SIGNAL_RULE_1", "SIGNAL_RULE_3"]),
    ("R3", "SIGNAL_RULE_3", ["SIGNAL_RULE_1"]),
    ("R1", "SIGNAL_RULE_1", []),
]:
    mask = df[filt].copy()
    for ex in excl:
        mask = mask & ~df[ex]
    pts = df[mask]
    if not pts.empty and rule in MARKERS:
        ax_x.scatter(pts["WEEK_START"], pts["VALUE"],
                     color=SIGNAL[rule], s=MARKERS[rule]["s"],
                     marker=MARKERS[rule]["m"], zorder=MARKERS[rule]["z"],
                     edgecolors="white", linewidths=0.7, alpha=0.92)

# Title block
fig.text(0.05, 0.97, "NEW SUBSCRIBERS",
         fontsize=22, fontweight="bold", color=TEXT_1, fontfamily=FONT)
fig.text(0.05, 0.945,
         "XmR Process Behavior Chart  \u2022  Weekly  \u2022  Sliding 20-Week Baseline",
         fontsize=10, color=TEXT_2, fontfamily=FONT)
last_week = df["WEEK_START"].max().strftime("%b %d, %Y")
fig.text(0.93, 0.97, f"Through week of {last_week}",
         fontsize=8.5, color=TEXT_3, ha="right", fontfamily=FONT)
fig.text(0.93, 0.954, "Wheeler Signal Rules",
         fontsize=8.5, color=TEXT_3, ha="right", style="italic", fontfamily=FONT)

ax_x.set_ylabel("Weekly New Subscribers", fontsize=9.5, color=TEXT_2, labelpad=8)
ax_x.yaxis.set_major_formatter(mticker.FuncFormatter(fmt_k))

# ===========================================================================
# PANEL 2: mR Chart
# ===========================================================================

ax_mr.plot(df["WEEK_START"], df["MR"], color=MR_LINE, lw=1.0, zorder=3,
           solid_capstyle="round", solid_joinstyle="round")
ax_mr.scatter(df["WEEK_START"], df["MR"], color=MR_POINT,
              s=8, zorder=4, alpha=0.35, edgecolors="none")
ax_mr.plot(df["WEEK_START"], df["MR_BAR"], color=CENTER_LINE, lw=0.8, alpha=0.6, zorder=2)
ax_mr.plot(df["WEEK_START"], df["URL"], color=URL_LINE, lw=0.7, ls="--", alpha=0.4, zorder=2)

annot_limit(ax_mr, df["URL"], "WEEK_START", "URL", URL_LINE)
annot_limit(ax_mr, df["MR_BAR"], "WEEK_START", "m\u0304R", CENTER_LINE)

mr_sig = df[df["MR_SIGNAL"]]
if not mr_sig.empty:
    ax_mr.scatter(mr_sig["WEEK_START"], mr_sig["MR"],
                  color=SIGNAL["mR"], s=MARKERS["mR"]["s"],
                  marker=MARKERS["mR"]["m"], zorder=MARKERS["mR"]["z"],
                  edgecolors="white", linewidths=0.7, alpha=0.9)

ax_mr.set_ylabel("Moving Range", fontsize=9, color=TEXT_2, labelpad=8)
ax_mr.yaxis.set_major_formatter(mticker.FuncFormatter(fmt_k))
ax_mr.set_ylim(bottom=0)

# ===========================================================================
# Legend
# ===========================================================================
handles = [
    Line2D([], [], color=SIGNAL["R1"], marker="o", ls="None", ms=6.5,
           mec="white", mew=0.5, label="R1: Beyond 3\u03c3"),
    mpatches.Patch(fc=SIGNAL["R2"], alpha=0.25, ec="none", label="R2: Run of 8"),
    Line2D([], [], color=SIGNAL["R3"], marker="D", ls="None", ms=5.5,
           mec="white", mew=0.5, label="R3: 2-of-3 > 2\u03c3"),
    Line2D([], [], color=SIGNAL["R4"], marker="s", ls="None", ms=5,
           mec="white", mew=0.5, label="R4: Trend of 6"),
    Line2D([], [], color=SIGNAL["mR"], marker="o", ls="None", ms=5.5,
           mec="white", mew=0.5, label="mR: Range Signal"),
    Line2D([], [], color="none", marker="None", ls="None", label=" "),
    Line2D([], [], color=LIMIT_LINE, ls="--", lw=0.9, alpha=0.6, label="UNPL / LNPL"),
    Line2D([], [], color=SIGMA2_LINE, ls=(0, (3, 4)), lw=0.7, alpha=0.5, label="2\u03c3 Zone"),
    Line2D([], [], color=CENTER_LINE, lw=1.0, alpha=0.7, label="X\u0304 / m\u0304R"),
]
leg = ax_leg.legend(handles=handles, loc="center", ncol=9, fontsize=8,
                    frameon=True, fancybox=False, edgecolor=GRID_COLOR,
                    facecolor=BG, framealpha=1.0, columnspacing=1.6,
                    handletextpad=0.5, handlelength=1.6, borderpad=0.6)
leg.get_frame().set_linewidth(0.5)

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------
CHART_DIR = DATA_DIR.parent / "charts" / date.today().isoformat()
CHART_DIR.mkdir(parents=True, exist_ok=True)
out_path = CHART_DIR / "new_subscribers.png"
fig.savefig(out_path, dpi=300, bbox_inches="tight", facecolor=BG)
plt.close(fig)
print(f"Chart saved to {out_path}")
