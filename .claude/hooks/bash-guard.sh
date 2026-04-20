#!/bin/bash
# PreToolUse hook for Bash — git discipline, chart verification at commit, command repetition.
source "$(dirname "$0")/_lib.sh"
init_hook "bash-guard"
read_input
ensure_state_dir

[[ -z "$COMMAND" ]] && finish 0

# --- Check 1: Block git add . / git add -A ---
if echo "$COMMAND" | grep -qE 'git\s+add\s+(-A|--all|\.)(\s|$)'; then
  echo "BLOCKED: git workflow rule prohibits 'git add .' and 'git add -A'. Stage specific files by name." >&2
  finish 2 "block" '{"reason":"git_add_all"}'
fi

# --- Check 2: Review nudge before commit ---
if echo "$COMMAND" | grep -qE 'git\s+commit'; then
  if ! has_marker "$MARKER_REVIEW_DONE"; then
    echo "WARNING: Committing without running /review. The review command checks Python, SQL, LookML, and analysis quality." >&2
    # Don't exit yet — check charts too, combine warnings
  fi

  # --- Check 3: Unverified chart scripts at commit ---
  CHARTS_PENDING="$(state_file charts_pending)"
  if [ -f "$CHARTS_PENDING" ] && [ -s "$CHARTS_PENDING" ]; then
    PENDING_LIST=$(cat "$CHARTS_PENDING" | tr '\n' ', ' | sed 's/, $//')
    echo "WARNING: Chart scripts written but not verified: ${PENDING_LIST}. Run them and check the visual output before committing." >&2
    finish 1 "warn" '{"reason":"charts_unverified"}'
  fi

  # If review warning was triggered, exit 1 now
  if ! has_marker "$MARKER_REVIEW_DONE"; then
    finish 1 "warn" '{"reason":"missing_review"}'
  fi
fi

# --- Check 4: Bash command repetition ---
# Whitelist: diagnostic/read-only commands that are legitimately repeated
FIRST_WORD=$(echo "$COMMAND" | awk '{print $1}')
case "$FIRST_WORD" in
  git)
    SECOND_WORD=$(echo "$COMMAND" | awk '{print $2}')
    case "$SECOND_WORD" in
      status|log|diff|branch|show) finish 0 ;;
    esac
    ;;
  ls|cat|head|tail|wc|find|tree|date|pwd|echo|which|type) finish 0 ;;
esac

# Fingerprint: first 120 chars, whitespace collapsed
FINGERPRINT=$(echo "$COMMAND" | head -1 | tr -s '[:space:]' ' ' | cut -c1-120)
BASH_LOG="$(state_file bash_log)"
append_line "$BASH_LOG" "$FINGERPRINT"
REPEAT_COUNT=$(count_occurrences "$BASH_LOG" "$FINGERPRINT")

if [ "$REPEAT_COUNT" -ge 7 ]; then
  echo "WARNING: Same command pattern run ${REPEAT_COUNT} times. The approach is likely wrong. Step back and rethink." >&2
  finish 1 "warn" "$(jq -cn --argjson n "$REPEAT_COUNT" '{reason:"command_repetition", count:$n}')"
fi

if [ "$REPEAT_COUNT" -ge 4 ]; then
  echo "WARNING: Same command pattern run ${REPEAT_COUNT} times. Guardrail: investigate, then fix." >&2
  finish 1 "warn" "$(jq -cn --argjson n "$REPEAT_COUNT" '{reason:"command_repetition", count:$n}')"
fi

finish 0
