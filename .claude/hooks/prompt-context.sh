#!/bin/bash
# UserPromptSubmit hook — injects fresh date, checkpoint age, and memory staleness
# into every prompt. Prevents stale-date bugs and memory decay.
#
# Output format: JSON to stdout with hookSpecificOutput.additionalContext, which
# Claude Code injects into the prompt context (per hooks protocol).
source "$(dirname "$0")/_lib.sh"
init_hook "prompt-context"
read_input || true

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TODAY=$(date '+%Y-%m-%d')

CTX=""

# Today's date — always inject so Claude doesn't invent one.
CTX="Today's date is ${TODAY}."

# Checkpoint age (if the cross-session handoff checkpoint exists)
CHECKPOINT="${PROJECT_DIR}/.claude/hooks/checkpoint.md"
if [ -f "$CHECKPOINT" ]; then
  # Age in days (portable across macOS/Linux)
  if command -v stat >/dev/null 2>&1; then
    MTIME=$(stat -f '%m' "$CHECKPOINT" 2>/dev/null || stat -c '%Y' "$CHECKPOINT" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE_DAYS=$(( (NOW - MTIME) / 86400 ))
    if [ "$AGE_DAYS" -le 1 ]; then
      CTX="${CTX} A cross-session checkpoint at .claude/hooks/checkpoint.md was updated within the last day — check it before resuming."
    elif [ "$AGE_DAYS" -le 7 ]; then
      CTX="${CTX} A cross-session checkpoint at .claude/hooks/checkpoint.md exists (${AGE_DAYS}d old) — review if resuming prior work."
    fi
  fi
fi

# Memory staleness
MEM_INDEX="/Users/dev/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/MEMORY.md"
if [ -f "$MEM_INDEX" ]; then
  MEM_MTIME=$(stat -f '%m' "$MEM_INDEX" 2>/dev/null || stat -c '%Y' "$MEM_INDEX" 2>/dev/null || echo 0)
  MEM_AGE=$(( ( $(date +%s) - MEM_MTIME ) / 86400 ))
  if [ "$MEM_AGE" -gt 14 ]; then
    CTX="${CTX} MEMORY.md has not been updated in ${MEM_AGE} days — consider reviewing for stale entries."
  fi
fi

# Emit as hookSpecificOutput so Claude Code injects it into prompt context
jq -cn --arg ctx "$CTX" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'

finish 0 "pass" "$(jq -cn --arg ctx "$CTX" '{injected_len:($ctx|length)}')"
