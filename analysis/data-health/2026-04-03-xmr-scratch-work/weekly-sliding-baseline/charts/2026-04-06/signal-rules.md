# XmR Signal Detection Rules

## R1 — Beyond Natural Process Limits

A single data point exceeds the Upper Natural Process Limit (UNPL) or falls below the Lower Natural Process Limit (LNPL), calculated as X̄ ± 2.66 × m̄R.

**What it means:** Something happened this period that the process has not historically produced. This is the strongest individual signal — the equivalent of a ~3σ event. In operational terms, it usually points to a discrete external cause: a campaign launch, a site outage, a seasonal extreme, or a tracking change. The question is not *whether* something changed, but *what*.

## R2 — Run of 8

Eight or more consecutive data points fall on the same side of the center line (X̄).

**What it means:** The process has shifted. Even though no single point may look extreme, the sustained bias above or below center is statistically improbable under a stable process. Operationally, this signals a gradual structural change — a market shift, an algorithm update, a slow leak in a funnel — where the "new normal" has diverged from the baseline the limits were built on.

## R3 — 2-of-3 Beyond 2σ

Two out of three consecutive data points fall beyond the 2σ zone (1.77 × m̄R from center).

**What it means:** The process is clustering near its limits without necessarily breaching them. This is an early warning — the system is running hot (or cold) and a full R1 breach may follow. Operationally, it often appears during transitions: a metric that is in the process of shifting but hasn't fully broken through yet.

## R4 — Trend of 6

Six or more consecutive data points are steadily increasing or steadily decreasing.

**What it means:** A sustained directional drift. Unlike R2 (which detects level shifts), R4 detects slope — the metric is consistently moving in one direction. Operationally, this catches gradual degradation (e.g., slowly declining conversion rates) or compounding growth that might not trigger R1 or R2 until it's progressed further.

## mR — Moving Range Signal

The week-to-week moving range exceeds the Upper Range Limit (URL = 3.267 × m̄R).

**What it means:** The *volatility* between adjacent periods is abnormal, regardless of whether the values themselves are within limits. Operationally, this flags instability — erratic behavior that may indicate data quality issues, inconsistent external inputs, or a system oscillating between states. A metric can be "in control" on the X chart but flagging on the mR chart if its week-to-week swings are unusually large.
