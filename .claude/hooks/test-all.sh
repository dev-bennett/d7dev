#!/bin/bash
# Test harness for all d7dev hooks. Run manually to verify hooks work.
# Usage: .claude/hooks/test-all.sh
set -u

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$HOOKS_DIR/../.." && pwd)"
PASS=0
FAIL=0
TEST_SESSION="test-$$"
STATE_DIR="/tmp/d7dev-hooks/${TEST_SESSION}"

cleanup() { rm -rf "$STATE_DIR" 2>/dev/null; }
trap cleanup EXIT

run_test() {
  local desc="$1" hook="$2" input="$3" expect_exit="$4"
  local actual_exit stderr_file

  stderr_file=$(mktemp)
  set +e
  echo "$input" | "$HOOKS_DIR/$hook" >/dev/null 2>"$stderr_file"
  actual_exit=$?
  set -e

  if [ "$actual_exit" -eq "$expect_exit" ]; then
    echo "  PASS: $desc (exit $actual_exit)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc — expected exit $expect_exit, got $actual_exit"
    [ -s "$stderr_file" ] && echo "        stderr: $(cat "$stderr_file")"
    FAIL=$((FAIL + 1))
  fi
  rm -f "$stderr_file"
}

json() {
  # Build test JSON. Args: session_id tool_name [file_path|command|skill]
  local sid="$1" tool="$2" extra="$3" extra_key
  case "$tool" in
    Write|Edit) extra_key="file_path" ;;
    Bash)       extra_key="command" ;;
    Skill)      extra_key="skill" ;;
    *)          extra_key="file_path" ;;
  esac
  echo "{\"session_id\":\"$sid\",\"tool_name\":\"$tool\",\"tool_input\":{\"$extra_key\":\"$extra\"}}"
}

echo "=== d7dev Hook Test Suite ==="
echo ""

# --- session-gate.sh ---
echo "session-gate.sh:"
cleanup

run_test "Block write to dir without CLAUDE.md" \
  "session-gate.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/nonexistent-dir-xxxxx/test.sql")" \
  2

run_test "Allow writing CLAUDE.md itself" \
  "session-gate.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/new-dir/CLAUDE.md")" \
  0

run_test "Allow write to non-managed dir" \
  "session-gate.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/scripts/foo.py")" \
  0

run_test "Allow write to dir with CLAUDE.md" \
  "session-gate.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/data-health/2026-04-03-xmr-scratch-work/weekly-sliding-baseline/visitors/test.py")" \
  0

# Preflight nudge: write 3 managed files without preflight
cleanup
for i in 1 2 3; do
  echo "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/data-health/2026-04-03-xmr-scratch-work/weekly-sliding-baseline/visitors/test${i}.py")" | "$HOOKS_DIR/session-gate.sh" >/dev/null 2>/dev/null || true
done
run_test "Warn after 3+ managed writes without /preflight" \
  "session-gate.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/data-health/2026-04-03-xmr-scratch-work/weekly-sliding-baseline/visitors/test4.py")" \
  1

echo ""

# --- retry-guard.sh ---
echo "retry-guard.sh:"
cleanup

run_test "Allow first edit" \
  "retry-guard.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/foo/bar.py")" \
  0

# Edit same file 5 times
cleanup
for i in 1 2 3 4; do
  echo "$(json "$TEST_SESSION" Edit "${PROJECT_DIR}/analysis/foo/bar.py")" | "$HOOKS_DIR/retry-guard.sh" >/dev/null 2>/dev/null || true
done
run_test "Warn at 5th edit of same file" \
  "retry-guard.sh" \
  "$(json "$TEST_SESSION" Edit "${PROJECT_DIR}/analysis/foo/bar.py")" \
  1

# Edit same file 8 times
for i in 6 7; do
  echo "$(json "$TEST_SESSION" Edit "${PROJECT_DIR}/analysis/foo/bar.py")" | "$HOOKS_DIR/retry-guard.sh" >/dev/null 2>/dev/null || true
done
run_test "Block at 8th edit of same file" \
  "retry-guard.sh" \
  "$(json "$TEST_SESSION" Edit "${PROJECT_DIR}/analysis/foo/bar.py")" \
  2

# CLAUDE.md exempt
cleanup
for i in $(seq 1 10); do
  echo "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/foo/CLAUDE.md")" | "$HOOKS_DIR/retry-guard.sh" >/dev/null 2>/dev/null || true
done
run_test "CLAUDE.md exempt from edit limits (10 edits)" \
  "retry-guard.sh" \
  "$(json "$TEST_SESSION" Write "${PROJECT_DIR}/analysis/foo/CLAUDE.md")" \
  0

echo ""

# --- bash-guard.sh ---
echo "bash-guard.sh:"
cleanup

run_test "Block git add ." \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "git add .")" \
  2

run_test "Block git add -A" \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "git add -A")" \
  2

run_test "Allow git add specific file" \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "git add analysis/foo/bar.sql")" \
  0

run_test "Warn git commit without /review" \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "git commit -m test")" \
  1

# Command repetition: 4x same command
cleanup
for i in 1 2 3; do
  echo "$(json "$TEST_SESSION" Bash "python3 some_script.py")" | "$HOOKS_DIR/bash-guard.sh" >/dev/null 2>/dev/null || true
done
run_test "Warn at 4th repetition of same command" \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "python3 some_script.py")" \
  1

# Whitelisted commands don't count
cleanup
for i in $(seq 1 10); do
  echo "$(json "$TEST_SESSION" Bash "git status")" | "$HOOKS_DIR/bash-guard.sh" >/dev/null 2>/dev/null || true
done
run_test "git status exempt from repetition (10x)" \
  "bash-guard.sh" \
  "$(json "$TEST_SESSION" Bash "git status")" \
  0

echo ""

# --- workflow-tracker.sh ---
echo "workflow-tracker.sh:"
cleanup

echo "$(json "$TEST_SESSION" Skill "preflight")" | "$HOOKS_DIR/workflow-tracker.sh" >/dev/null 2>/dev/null
if [ -f "$STATE_DIR/preflight_done" ]; then
  echo "  PASS: preflight skill sets marker"
  PASS=$((PASS + 1))
else
  echo "  FAIL: preflight skill did not set marker"
  FAIL=$((FAIL + 1))
fi

echo "$(json "$TEST_SESSION" Skill "review")" | "$HOOKS_DIR/workflow-tracker.sh" >/dev/null 2>/dev/null
if [ -f "$STATE_DIR/review_done" ]; then
  echo "  PASS: review skill sets marker"
  PASS=$((PASS + 1))
else
  echo "  FAIL: review skill did not set marker"
  FAIL=$((FAIL + 1))
fi

run_test "Always exits 0" \
  "workflow-tracker.sh" \
  "$(json "$TEST_SESSION" Write "/some/random/file.txt")" \
  0

echo ""

# --- health-check.sh ---
echo "health-check.sh:"
# No errors
rm -f "$HOOKS_DIR/errors.log" 2>/dev/null
run_test "No errors — clean pass" \
  "health-check.sh" \
  '{}' \
  0

# With errors
echo "[2026-04-06 12:00:00] test-hook: simulated failure" > "$HOOKS_DIR/errors.log"
run_test "Errors present — warn" \
  "health-check.sh" \
  '{}' \
  1
rm -f "$HOOKS_DIR/errors.log" "$HOOKS_DIR/errors.log.prev" 2>/dev/null

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
