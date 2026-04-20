#!/bin/bash
# Stop hook — runs when a session ends or Claude finishes a turn.
# Produces a lightweight session summary (dangling state, writes, warnings)
# and cleans up per-session /tmp state.
#
# Writes to stderr so the user sees the summary in their terminal.
# Does not block. Always exits 0.
source "$(dirname "$0")/_lib.sh"
init_hook "session-closeout"
read_input || true

# Only run on genuine Stop events (not subagent turn-end etc.) — guard by checking
# the state dir exists. If no state was built up, nothing to report.
[ -d "$STATE_DIR" ] || finish 0

SUMMARY_LINES=()

# --- Dangling charts (written but never verified via execution) ---
CHARTS_PENDING="$(state_file charts_pending)"
if [ -f "$CHARTS_PENDING" ] && [ -s "$CHARTS_PENDING" ]; then
  COUNT=$(wc -l < "$CHARTS_PENDING" | tr -d ' ')
  SUMMARY_LINES+=("  - ${COUNT} chart script(s) written but not verified:")
  while IFS= read -r line; do
    [ -n "$line" ] && SUMMARY_LINES+=("      ${line}")
  done < "$CHARTS_PENDING"
fi

# --- Managed writes vs preflight ---
COUNTER_FILE="$(state_file managed_write_count)"
if [ -f "$COUNTER_FILE" ]; then
  WRITES=$(wc -l < "$COUNTER_FILE" | tr -d ' ')
  if [ "$WRITES" -ge 3 ] && ! has_marker "$MARKER_PREFLIGHT_DONE"; then
    SUMMARY_LINES+=("  - ${WRITES} managed writes this session without running /preflight.")
  fi
fi

# --- Edit retry hotspots (files edited 5+ times) ---
EDIT_LOG="$(state_file edit_log)"
if [ -f "$EDIT_LOG" ]; then
  # Strip the "#hash" suffix to get per-file counts. Top 3.
  HOTSPOTS=$(awk -F'#' '{print $1}' "$EDIT_LOG" | sort | uniq -c | sort -rn | awk '$1>=5 {print "      "$1" edits: "$2}' | head -3)
  if [ -n "$HOTSPOTS" ]; then
    SUMMARY_LINES+=("  - Edit hotspots (>=5 edits):")
    while IFS= read -r line; do
      SUMMARY_LINES+=("$line")
    done <<< "$HOTSPOTS"
  fi
fi

# --- Uncommitted changes in the project root ---
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
if command -v git >/dev/null 2>&1 && [ -d "${PROJECT_DIR}/.git" ]; then
  DIRTY=$(cd "$PROJECT_DIR" && git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  if [ "$DIRTY" -gt 0 ]; then
    SUMMARY_LINES+=("  - ${DIRTY} uncommitted file(s) in the repo. Run /review before committing.")
  fi
fi

# --- Emit summary if anything to report ---
if [ "${#SUMMARY_LINES[@]}" -gt 0 ]; then
  echo "" >&2
  echo "Session closeout — d7dev hooks:" >&2
  for line in "${SUMMARY_LINES[@]}"; do
    echo "$line" >&2
  done
  echo "" >&2
fi

# --- Cleanup per-session state ---
# Keep the state dir for one more session? No — it's /tmp, scoped by SESSION_ID
# which is unique per session, so safe to remove on Stop.
if [ -n "${SESSION_ID:-}" ] && [ "$SESSION_ID" != "unknown" ] && [ -d "$STATE_DIR" ]; then
  rm -rf "$STATE_DIR" 2>/dev/null || true
fi

# Also rotate session-log.jsonl if it exceeds 10 MB (simple size cap)
if [ -f "$SESSION_LOG" ]; then
  SIZE=$(wc -c < "$SESSION_LOG" 2>/dev/null | tr -d ' ')
  if [ -n "$SIZE" ] && [ "$SIZE" -gt 10485760 ]; then
    mv "$SESSION_LOG" "${SESSION_LOG}.prev" 2>/dev/null || true
  fi
fi

finish 0 "pass" "$(jq -cn --argjson n "${#SUMMARY_LINES[@]}" '{summary_lines:$n}')"
