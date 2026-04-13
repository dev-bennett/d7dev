#!/bin/bash
# SessionStart hook — surfaces hook errors from prior sessions.
source "$(dirname "$0")/_lib.sh"
init_hook "health-check"

# Check for errors from previous sessions
if [ -f "$ERROR_LOG" ] && [ -s "$ERROR_LOG" ]; then
  ERROR_COUNT=$(wc -l < "$ERROR_LOG" | tr -d ' ')
  RECENT=$(tail -5 "$ERROR_LOG")
  # Rotate: move to .prev so warnings don't repeat
  mv "$ERROR_LOG" "${ERROR_LOG}.prev" 2>/dev/null || true
  echo "Hook errors detected (${ERROR_COUNT} total). Most recent:" >&2
  echo "$RECENT" >&2
  echo "Run .claude/hooks/test-all.sh to diagnose. Full log: ${ERROR_LOG}.prev" >&2
  exit 1
fi

exit 0
