# M2 — Subscriber Acquisition -74% Channel Decomposition

@../CLAUDE.md

§5 algebraic identity decomposition (shift-share) of the 24-month subscribing-session decline by `last_channel_non_direct`.

## Files

- `queries.sql` — m2_q01 per-channel monthly sessions/subscribes/license/signups
- `M2_channel_monthly.csv` — raw query result (24 months × 7 channels = 168 rows)
- `M2_shift_share_2024_05_to_2026_02.csv` — within-CVR / within-volume / interaction split, May 2024 → Feb 2026 (clean window, avoids artifact)
- `findings.md` — verdict and roll-up

## Window choice

Headline window is **May 2024 → Feb 2026** (clean baseline to clean baseline). The Mar–Apr 2026 Direct channel includes 165K + 66K artifact sessions (per `../../q07.csv`) that would distort the channel mix; pre-March is clean.
