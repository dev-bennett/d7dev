#!/bin/bash
# PreToolUse hook for Write|Edit — CLAUDE.md chain enforcement + preflight nudge.
source "$(dirname "$0")/_lib.sh"
init_hook "session-gate"
read_input
ensure_state_dir

# Skip if no file path
[[ -z "$FILE_PATH" ]] && exit 0

# --- Check 1: CLAUDE.md chain (managed directories only) ---
IS_MANAGED=false
case "$FILE_PATH" in
  */analysis/*|*/etl/*|*/lookml/*|*/knowledge/*|*/initiatives/*) IS_MANAGED=true ;;
esac

IS_CLAUDE_MD=false
[[ "$(basename "$FILE_PATH")" == "CLAUDE.md" ]] && IS_CLAUDE_MD=true

if $IS_MANAGED && ! $IS_CLAUDE_MD; then
  DIR=$(dirname "$FILE_PATH")
  if [[ ! -f "$DIR/CLAUDE.md" ]]; then
    echo "BLOCKED: Directory $DIR has no CLAUDE.md. Create it first (must include @../CLAUDE.md reference)." >&2
    exit 2
  fi
fi

# --- Check 2: Preflight nudge (after 3+ managed writes without /preflight) ---
if $IS_MANAGED && ! $IS_CLAUDE_MD; then
  COUNTER_FILE="$(state_file managed_write_count)"
  append_line "$COUNTER_FILE" "1"
  COUNT=$(wc -l < "$COUNTER_FILE" | tr -d ' ')

  if [ "$COUNT" -ge 3 ] && ! has_marker "preflight_done"; then
    echo "WARNING: ${COUNT} files written to managed directories without running /preflight. Run /preflight to verify environment and check for prior work." >&2
    exit 1
  fi
fi

exit 0
