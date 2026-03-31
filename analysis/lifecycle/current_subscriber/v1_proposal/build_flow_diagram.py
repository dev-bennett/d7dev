"""
Lifecycle Email Flow — Per-Plan Diagram Builder (v4)
Matches new_flow.png structure:
  - Enterprise gate at top (excluded → Sales/AM)
  - New subscriber exit (out of scope → existing onboarding flow)
  - Rolling 30-day session window
  - 5 terminal segments in horizontal band at bottom
Generates one diagram per non-enterprise plan + aggregate.
"""

import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle
from collections import defaultdict
from pathlib import Path

BASE_DIR = Path(__file__).parent

CORE_PLANS = {'business', 'creator', 'pro', 'pro-plus'}
SEGMENTS = ['ACTIVE_DOWNLOADER', 'ACTIVE_BROWSER', 'EARLY_LAPSE', 'DEEP_LAPSE', 'DORMANT']
TARGET_MONTHS = {'2025-09', '2025-10', '2025-11', '2025-12', '2026-01', '2026-02'}

# Load 6-month averages
seg_plan_month = defaultdict(lambda: defaultdict(lambda: defaultdict(float)))
seg_all_month = defaultdict(lambda: defaultdict(float))

with open(BASE_DIR / 's1.csv') as f:
    for row in csv.DictReader(f):
        plan = row['PLAN_TYPE']
        month = row['MONTH_START'][:7]
        if month not in TARGET_MONTHS:
            continue
        seg = row['LIFECYCLE_SEGMENT']
        count = int(row['SUBSCRIBER_COUNT'])

        if plan in CORE_PLANS and seg in SEGMENTS:
            seg_plan_month[plan][seg][month] += count
            seg_all_month[seg][month] += count

# Compute averages
def avg_over_months(month_dict):
    return round(sum(month_dict.get(m, 0) for m in TARGET_MONTHS) / len(TARGET_MONTHS))

plan_sizes = {}
for plan in CORE_PLANS:
    plan_sizes[plan] = {}
    for seg in SEGMENTS:
        plan_sizes[plan][seg] = avg_over_months(seg_plan_month[plan][seg])

all_sizes = {seg: avg_over_months(seg_all_month[seg]) for seg in SEGMENTS}

plan_totals = {plan: sum(avg_over_months(seg_plan_month[plan][seg]) for seg in SEGMENTS)
               for plan in CORE_PLANS}
plan_totals['all'] = sum(plan_totals[p] for p in CORE_PLANS)

# Enterprise and new sub counts are not in the rolling-window query output.
# Use reference values from the original analysis for diagram labels.
ent_avg = 1000   # ~1K enterprise subs handled by Sales/AM
new_avg = 700    # ~700 new subs/month handled by existing onboarding flow
new_counts = {plan: 0 for plan in CORE_PLANS}  # not broken out by plan; use aggregate
new_counts['all'] = new_avg

PLAN_DISPLAY = {
    'all': 'All Plans (excl. Enterprise)',
    'business': 'Business',
    'creator': 'Personal (Creator)',
    'pro': 'Pro',
    'pro-plus': 'Pro Plus',
}

SEGMENT_DISPLAY = {
    'ACTIVE_DOWNLOADER': 'Active\nDownloaders',
    'ACTIVE_BROWSER': 'Active\nBrowsers',
    'EARLY_LAPSE': 'Early Lapse',
    'DEEP_LAPSE': 'Deep Lapse',
    'DORMANT': 'Dormant',
}

SEGMENT_COLORS = {
    'ACTIVE_DOWNLOADER': ('#dbeafe', '#2563eb'),
    'ACTIVE_BROWSER': ('#ede9fe', '#7c3aed'),
    'EARLY_LAPSE': ('#fef3c7', '#d97706'),
    'DEEP_LAPSE': ('#ffedd5', '#ea580c'),
    'DORMANT': ('#fee2e2', '#dc2626'),
}

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

def draw_box(ax, x, y, w, h, text, subtext='', fill='#f3f4f6', border='#6b7280',
             fs=10, subfs=10, border_style='-', lw=2.0):
    box = FancyBboxPatch((x - w/2, y - h/2), w, h,
        boxstyle='round,pad=0.12', facecolor=fill, edgecolor=border,
        linewidth=lw, linestyle=border_style, zorder=10)
    ax.add_patch(box)
    if subtext:
        ax.text(x, y + h*0.15, text, ha='center', va='center', fontsize=fs,
                fontweight='bold', fontfamily='sans-serif', color='#1f2937', zorder=11)
        ax.text(x, y - h*0.22, subtext, ha='center', va='center', fontsize=subfs,
                fontweight='bold', fontfamily='sans-serif', color=border, zorder=11)
    else:
        ax.text(x, y, text, ha='center', va='center', fontsize=fs,
                fontweight='bold', fontfamily='sans-serif', color='#1f2937', zorder=11)


def draw_diamond(ax, x, y, w, h, text, fs=9):
    hw, hh = w/2, h/2
    diamond = plt.Polygon(
        [(x, y + hh), (x + hw, y), (x, y - hh), (x - hw, y)],
        closed=True, facecolor='#eff6ff', edgecolor='#3b82f6',
        linewidth=1.5, zorder=10)
    ax.add_patch(diamond)
    ax.text(x, y, text, ha='center', va='center', fontsize=fs,
            fontfamily='sans-serif', color='#1e3a5f', zorder=11, linespacing=1.2)


def draw_arrow(ax, x1, y1, x2, y2, color='#6b7280', lw=1.5, label=None, label_pos=None):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(arrowstyle='->', lw=lw, color=color, shrinkA=2, shrinkB=2), zorder=5)
    if label and label_pos:
        ax.text(label_pos[0], label_pos[1], label, ha='center', va='center', fontsize=8.5,
                fontfamily='sans-serif', color=color, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.1', facecolor='white', edgecolor='none', alpha=0.9), zorder=6)


# ---------------------------------------------------------------------------
# Main diagram function
# ---------------------------------------------------------------------------

def draw_flow(plan_key, sizes, total, new_count, filename):
    if total == 0:
        return

    def fmt(seg):
        c = sizes.get(seg, 0)
        p = 100.0 * c / total if total > 0 else 0
        if c >= 1000:
            return f'{c/1000:.1f}K ({p:.0f}%)'
        return f'{c:,} ({p:.0f}%)'

    fig, ax = plt.subplots(figsize=(16, 20), dpi=150)
    ax.set_xlim(0, 16)
    ax.set_ylim(0, 22)
    ax.set_aspect('equal')
    ax.axis('off')
    fig.patch.set_facecolor('white')

    CX = 8
    plan_label = PLAN_DISPLAY.get(plan_key, plan_key)

    # Title
    ax.text(CX, 21.8, f'{plan_label} — Lifecycle Email Flow',
            ha='center', va='center', fontsize=18, fontweight='bold',
            fontfamily='sans-serif', color='#1f2937')
    ax.text(CX, 21.3, f'6-month avg segment sizes (Sep 2025 – Feb 2026)',
            ha='center', va='center', fontsize=10, fontstyle='italic',
            fontfamily='sans-serif', color='#6b7280')

    # Gate 1: Is Enterprise?
    y_ent = 20.5
    draw_diamond(ax, CX, y_ent, 3.5, 1.6, 'Is Enterprise?', fs=10)
    draw_arrow(ax, CX - 1.75, y_ent, 2.5, y_ent, color='#059669', lw=1.5,
               label='Yes', label_pos=(4.2, y_ent + 0.3))
    draw_box(ax, 2.0, y_ent, 3.0, 1.0, 'Sales / Account\nManagement', f'~{ent_avg/1000:.0f}K',
             fill='#f3f4f6', border='#6b7280', fs=9, subfs=10, border_style='--', lw=1.5)

    # No → Active Subscribers
    y_active = 18.5
    draw_arrow(ax, CX, y_ent - 0.8, CX, y_active + 0.55, color='#dc2626', lw=2,
               label='No', label_pos=(CX + 0.5, y_ent - 0.4))
    draw_box(ax, CX, y_active, 3.8, 1.0, 'Active Subscribers',
             f'{total/1000:.0f}K' if total >= 1000 else f'{total:,}',
             fill='#e0e7ff', border='#4f46e5', fs=11, subfs=12)

    # Gate 2: Subscribed this month?
    y_new = 16.7
    draw_arrow(ax, CX, y_active - 0.5, CX, y_new + 0.8, color='#4f46e5', lw=2)
    draw_diamond(ax, CX, y_new, 4.0, 1.6, 'Subscribed this\nmonth?', fs=9)

    draw_arrow(ax, CX - 2.0, y_new, 3.0, y_new, color='#059669', lw=1.5,
               label='Yes', label_pos=(4.5, y_new + 0.3))
    new_pct = round(100 * new_count / total) if total > 0 else 0
    draw_box(ax, 2.5, y_new, 3.2, 1.0, 'New Subscriber\nOnboarding Flow',
             f'{new_count:,} ({new_pct}%)',
             fill='#f3f4f6', border='#9ca3af', fs=9, subfs=9, border_style='--', lw=1.5)

    # No → session check
    y_session = 14.7
    draw_arrow(ax, CX + 2.0, y_new, CX + 3, y_new, color='#dc2626', lw=2,
               label='No', label_pos=(CX + 2.8, y_new + 0.3))
    draw_arrow(ax, CX + 3, y_new, CX + 3, y_session + 1.0, color='#dc2626', lw=2)
    draw_arrow(ax, CX + 3, y_session + 1.0, CX, y_session + 0.8, color='#dc2626', lw=2)

    # Gate 3: Has session in last 30 days?
    draw_diamond(ax, CX, y_session, 4.5, 1.6, 'Has session in last\n30 days?', fs=9)

    # Yes → download check
    y_dl = 12.5
    draw_arrow(ax, CX - 2.25, y_session, CX - 4, y_dl + 0.8, color='#2563eb', lw=2,
               label='Yes', label_pos=(CX - 3.8, y_session - 0.2))
    draw_diamond(ax, CX - 4, y_dl, 4.5, 1.6, 'Downloaded at least\n1 song/sfx?', fs=9)

    y_bottom = 9.2
    draw_arrow(ax, CX - 6.25, y_dl, CX - 7.5, y_dl, color='#2563eb', lw=1.5,
               label='Yes', label_pos=(CX - 7.0, y_dl + 0.3))
    draw_arrow(ax, CX - 7.5, y_dl, CX - 7.5, y_bottom + 0.5, color='#2563eb', lw=1.5)
    draw_arrow(ax, CX - 4, y_dl - 0.8, CX - 4, y_bottom + 0.5, color='#7c3aed', lw=1.5,
               label='No', label_pos=(CX - 3.4, y_dl - 1.1))

    # No session → lapse check
    y_lapse = 12.5
    draw_arrow(ax, CX + 2.25, y_session, CX + 4.5, y_lapse + 0.8, color='#dc2626', lw=2,
               label='No', label_pos=(CX + 4.0, y_session - 0.2))
    draw_diamond(ax, CX + 4.5, y_lapse, 4.5, 1.6, 'How long since\nlast session?', fs=9)

    draw_arrow(ax, CX + 2.25, y_lapse, CX + 1.0, y_bottom + 0.5, color='#d97706', lw=1.5,
               label='30 Days', label_pos=(CX + 1.2, y_lapse - 0.5))
    draw_arrow(ax, CX + 4.5, y_lapse - 0.8, CX + 4.5, y_bottom + 0.5, color='#ea580c', lw=1.5,
               label='31-180', label_pos=(CX + 5.2, y_lapse - 1.1))
    draw_arrow(ax, CX + 6.75, y_lapse, CX + 8.0, y_bottom + 0.5, color='#dc2626', lw=1.5,
               label='+180 Days', label_pos=(CX + 8.0, y_lapse - 0.5))

    # Bottom band with 5 segments
    band_y = y_bottom - 1.5
    band_h = 2.5
    band = Rectangle((0.3, band_y - band_h/2), 15.4, band_h,
        facecolor='#f3f4f6', edgecolor='#d1d5db', linewidth=1.0, zorder=1)
    ax.add_patch(band)

    seg_positions = {
        'ACTIVE_DOWNLOADER': CX - 7.5,
        'ACTIVE_BROWSER':    CX - 4,
        'EARLY_LAPSE':       CX + 1.0,
        'DEEP_LAPSE':        CX + 4.5,
        'DORMANT':           CX + 8.0,
    }

    for seg in SEGMENTS:
        sx = seg_positions[seg]
        fill, border = SEGMENT_COLORS[seg]
        draw_box(ax, sx, band_y, 2.6, 1.8, SEGMENT_DISPLAY[seg], fmt(seg),
                 fill=fill, border=border, fs=9, subfs=9)

    plt.tight_layout(pad=0.5)
    fig.savefig(BASE_DIR / filename, dpi=150, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    fig.savefig(BASE_DIR / filename.replace('.png', '.svg'),
                bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close(fig)
    print(f'  Generated: {filename}')


# ---------------------------------------------------------------------------
# Generate
# ---------------------------------------------------------------------------

print('Generating lifecycle flow diagrams (v4)...')

# Aggregate
draw_flow('all', all_sizes, plan_totals['all'], new_counts['all'], 'lifecycle_flow_all.png')

# Per plan
for plan in sorted(CORE_PLANS):
    safe = plan.replace('-', '_')
    draw_flow(plan, plan_sizes[plan], plan_totals[plan], new_counts[plan],
              f'lifecycle_flow_{safe}.png')

print('Done.')
