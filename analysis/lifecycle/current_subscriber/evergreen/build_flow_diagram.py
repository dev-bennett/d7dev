"""
Evergreen Lifecycle Email Flow — Diagram
Shows the continuous enrollment/exit cycle:
  - Segment classification (daily)
  - State change detection → enrollment trigger
  - Deduplication, cooldown, and suppression checks
  - Flow execution with goal-based exit
  - 5 flows with priority hierarchy
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch
from pathlib import Path

BASE_DIR = Path(__file__).parent

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

def draw_box(ax, x, y, w, h, text, subtext='', fill='#f3f4f6', border='#6b7280',
             fs=9, subfs=8, lw=2.0, border_style='-', text_color='#1f2937'):
    box = FancyBboxPatch((x - w/2, y - h/2), w, h,
        boxstyle='round,pad=0.1', facecolor=fill, edgecolor=border,
        linewidth=lw, linestyle=border_style, zorder=10)
    ax.add_patch(box)
    if subtext:
        ax.text(x, y + h*0.15, text, ha='center', va='center', fontsize=fs,
                fontweight='bold', fontfamily='sans-serif', color=text_color, zorder=11)
        ax.text(x, y - h*0.2, subtext, ha='center', va='center', fontsize=subfs,
                fontfamily='sans-serif', color='#6b7280', zorder=11)
    else:
        ax.text(x, y, text, ha='center', va='center', fontsize=fs,
                fontweight='bold', fontfamily='sans-serif', color=text_color, zorder=11)


def draw_diamond(ax, x, y, w, h, text, fs=8):
    hw, hh = w/2, h/2
    diamond = plt.Polygon(
        [(x, y + hh), (x + hw, y), (x, y - hh), (x - hw, y)],
        closed=True, facecolor='#eff6ff', edgecolor='#3b82f6',
        linewidth=1.5, zorder=10)
    ax.add_patch(diamond)
    ax.text(x, y, text, ha='center', va='center', fontsize=fs,
            fontfamily='sans-serif', color='#1e3a5f', zorder=11, linespacing=1.2)


def draw_arrow(ax, x1, y1, x2, y2, color='#6b7280', lw=1.5, label=None, label_pos=None, style='-'):
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
        arrowprops=dict(arrowstyle='->', lw=lw, color=color, shrinkA=2, shrinkB=2,
                        linestyle=style), zorder=5)
    if label and label_pos:
        ax.text(label_pos[0], label_pos[1], label, ha='center', va='center', fontsize=7.5,
                fontfamily='sans-serif', color=color, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.08', facecolor='white', edgecolor='none', alpha=0.9),
                zorder=6)


def draw_process(ax, x, y, w, h, text, fill='#f3f4f6', border='#9ca3af', fs=8):
    """Draw a process/action box (rectangular, no rounding)."""
    box = FancyBboxPatch((x - w/2, y - h/2), w, h,
        boxstyle='round,pad=0.06', facecolor=fill, edgecolor=border,
        linewidth=1.5, zorder=10)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fs,
            fontfamily='sans-serif', color='#1f2937', zorder=11, linespacing=1.2)


# ---------------------------------------------------------------------------
# Build figure
# ---------------------------------------------------------------------------

fig, ax = plt.subplots(figsize=(20, 24), dpi=150)
ax.set_xlim(0, 20)
ax.set_ylim(0, 26)
ax.set_aspect('equal')
ax.axis('off')
fig.patch.set_facecolor('white')

# ── Title ──
ax.text(10, 25.3, 'Evergreen Lifecycle Email Flow', ha='center', va='center',
        fontsize=20, fontweight='bold', fontfamily='sans-serif', color='#1f2937')
ax.text(10, 24.7, 'Continuous state-aware enrollment with deduplication and suppression',
        ha='center', va='center', fontsize=11, fontstyle='italic',
        fontfamily='sans-serif', color='#6b7280')

CX = 10  # center x

# =====================================================================
# TOP: Daily Evaluation Pipeline
# =====================================================================

y = 23.5
draw_process(ax, CX, y, 4.5, 0.9, 'Daily Segment\nClassification Query',
             fill='#e0e7ff', border='#4f46e5', fs=10)

draw_arrow(ax, CX, y - 0.45, CX, y - 1.3, color='#4f46e5', lw=2)

y = 21.8
draw_diamond(ax, CX, y, 4.5, 1.6, 'Segment changed\nsince last evaluation?', fs=9)

# No → no action
draw_arrow(ax, CX + 2.25, y, CX + 5, y, color='#9ca3af', lw=1.5,
           label='No', label_pos=(CX + 3.8, y + 0.3))
draw_box(ax, CX + 6.5, y, 2.5, 0.8, 'No action', fill='#f9fafb', border='#d1d5db',
         fs=9, lw=1.0)

# Yes → check gates
draw_arrow(ax, CX, y - 0.8, CX, y - 1.7, color='#059669', lw=2,
           label='Yes', label_pos=(CX + 0.5, y - 1.2))

# =====================================================================
# GATE CHECKS (sequential)
# =====================================================================

y = 19.3
draw_diamond(ax, CX, y, 4.5, 1.6, 'On suppression\nlist?', fs=9)

draw_arrow(ax, CX + 2.25, y, CX + 5, y, color='#dc2626', lw=1.5,
           label='Yes', label_pos=(CX + 3.8, y + 0.3))
draw_box(ax, CX + 6.5, y, 2.5, 0.8, 'Suppressed\n(no enrollment)', fill='#fee2e2',
         border='#dc2626', fs=8, lw=1.0)

draw_arrow(ax, CX, y - 0.8, CX, y - 1.7, color='#059669', lw=2,
           label='No', label_pos=(CX + 0.5, y - 1.2))

y = 16.8
draw_diamond(ax, CX, y, 4.5, 1.6, 'In cooldown for\nthis flow?', fs=9)

draw_arrow(ax, CX + 2.25, y, CX + 5, y, color='#d97706', lw=1.5,
           label='Yes', label_pos=(CX + 3.8, y + 0.3))
draw_box(ax, CX + 6.5, y, 2.5, 0.8, 'Blocked\n(cooldown active)', fill='#fef3c7',
         border='#d97706', fs=8, lw=1.0)

draw_arrow(ax, CX, y - 0.8, CX, y - 1.7, color='#059669', lw=2,
           label='No', label_pos=(CX + 0.5, y - 1.2))

y = 14.3
draw_diamond(ax, CX, y, 5.0, 1.6, 'Already in a higher-\npriority flow?', fs=9)

draw_arrow(ax, CX + 2.5, y, CX + 5.2, y, color='#d97706', lw=1.5,
           label='Yes', label_pos=(CX + 4.0, y + 0.3))
draw_box(ax, CX + 6.5, y, 2.5, 0.8, 'Deduped\n(stay in current)', fill='#fef3c7',
         border='#d97706', fs=8, lw=1.0)

draw_arrow(ax, CX, y - 0.8, CX, y - 1.7, color='#059669', lw=2,
           label='No', label_pos=(CX + 0.5, y - 1.2))

# =====================================================================
# ENROLLMENT
# =====================================================================

y = 11.8
draw_process(ax, CX, y, 5.0, 1.0, 'Enroll in segment flow\n(exit current flow if any)',
             fill='#d1fae5', border='#059669', fs=10)

draw_arrow(ax, CX, y - 0.5, CX, y - 1.5, color='#059669', lw=2)

# =====================================================================
# FLOW EXECUTION — 5 flows side by side
# =====================================================================

y_flows = 9.3
flow_data = [
    ('P1: Early Lapse\nRe-engagement', '3 emails / 21d\n~3,400/mo', '#fef3c7', '#d97706'),
    ('P2: Deep Lapse\nWin-back', '2 emails / 30d\n~1,220/mo', '#ffedd5', '#ea580c'),
    ('P3: Dormant\nSunset', '2 emails / 14d\n~660/mo', '#fee2e2', '#dc2626'),
    ('P4: Active Browser\nDownload Nudge', '2 emails / 14d\n~500/mo', '#ede9fe', '#7c3aed'),
    ('P5: Active DL\nReinforcement', '1 email / 30d\n~2,600/mo', '#dbeafe', '#2563eb'),
]

flow_xs = [2.5, 6.0, 10.0, 14.0, 17.5]
for fx, (name, sub, fill, border) in zip(flow_xs, flow_data):
    draw_box(ax, fx, y_flows, 3.0, 1.8, name, sub,
             fill=fill, border=border, fs=8, subfs=7, lw=1.5)

# Arrows from enrollment to each flow
for fx in flow_xs:
    draw_arrow(ax, CX, y - 1.5, fx, y_flows + 0.9, color='#6b7280', lw=0.8, style='--')

# =====================================================================
# EXIT CONDITIONS
# =====================================================================

y = 7.0
draw_diamond(ax, CX, y, 5.0, 1.8, 'Exit condition met?\n(goal / escalation /\nseries complete)', fs=9)

# Connect flows down to exit check
for fx in flow_xs:
    draw_arrow(ax, fx, y_flows - 0.9, CX, y + 0.9, color='#6b7280', lw=0.8, style='--')

# Three exit paths
# Goal met → cooldown + re-enter pool
draw_arrow(ax, CX - 2.5, y, 3.5, y - 1.5, color='#059669', lw=1.5,
           label='Goal met', label_pos=(4.5, y - 0.5))
draw_box(ax, 3.5, y - 2.3, 3.0, 1.0,
         'Set cooldown timer\nRe-enter evaluation pool',
         fill='#d1fae5', border='#059669', fs=8, lw=1.5)

# Escalation → re-evaluate for next flow
draw_arrow(ax, CX, y - 0.9, CX, y - 2.0, color='#d97706', lw=1.5,
           label='Escalated', label_pos=(CX + 1.0, y - 1.5))
draw_box(ax, CX, y - 2.7, 3.5, 1.0,
         'Re-evaluate segment\nEnroll in next-priority flow',
         fill='#fef3c7', border='#d97706', fs=8, lw=1.5)

# Series complete (Dormant) → suppress
draw_arrow(ax, CX + 2.5, y, 16.5, y - 1.5, color='#dc2626', lw=1.5,
           label='Sunset complete', label_pos=(15.0, y - 0.5))
draw_box(ax, 16.5, y - 2.3, 3.0, 1.0,
         'Add to suppression list\n(until active session)',
         fill='#fee2e2', border='#dc2626', fs=8, lw=1.5)

# =====================================================================
# FEEDBACK LOOP — arrow from exit back to top
# =====================================================================
# Draw a curved arrow from the "re-enter pool" box back up to the evaluation
ax.annotate('', xy=(1.0, 23.5), xytext=(1.0, y - 2.3),
    arrowprops=dict(arrowstyle='->', lw=2, color='#4f46e5',
                    connectionstyle='arc3,rad=0.0', linestyle='--'),
    zorder=3)
ax.text(0.5, 15.0, 'Next daily\nevaluation', ha='center', va='center', fontsize=8,
        fontfamily='sans-serif', color='#4f46e5', fontstyle='italic', rotation=90)

# =====================================================================
# Priority Legend
# =====================================================================
legend_y = 2.5
ax.text(2, legend_y + 0.5, 'Flow Priority (highest → lowest):', fontsize=9,
        fontweight='bold', fontfamily='sans-serif', color='#374151')
priorities = [
    ('P1', 'Early Lapse Re-engagement', '#d97706'),
    ('P2', 'Deep Lapse Win-back', '#ea580c'),
    ('P3', 'Dormant Sunset', '#dc2626'),
    ('P4', 'Active Browser Download Nudge', '#7c3aed'),
    ('P5', 'Active Downloader Reinforcement', '#2563eb'),
]
for i, (p, name, color) in enumerate(priorities):
    ax.text(2 + (i * 3.5), legend_y, f'{p}: {name}', fontsize=7.5,
            fontfamily='sans-serif', color=color, fontweight='bold')

# Gate legend
ax.text(2, legend_y - 0.7, 'Gate checks (sequential):', fontsize=9,
        fontweight='bold', fontfamily='sans-serif', color='#374151')
gates = ['1. Suppression list', '2. Cooldown timer', '3. Deduplication (priority)']
for i, g in enumerate(gates):
    ax.text(2 + (i * 4.5), legend_y - 1.2, g, fontsize=8,
            fontfamily='sans-serif', color='#6b7280')

plt.tight_layout(pad=0.5)
out_path = BASE_DIR / 'evergreen_flow.png'
fig.savefig(out_path, dpi=150, bbox_inches='tight', facecolor='white', edgecolor='none')
fig.savefig(out_path.with_suffix('.svg'), bbox_inches='tight', facecolor='white', edgecolor='none')
plt.close(fig)
print(f'Generated: {out_path.name} + .svg')
