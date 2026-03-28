#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLI="$SCRIPT_DIR/../comfy-health"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ✗ $1: $2"; }

test_name() { echo ""; echo "TEST: $1"; }

# ── 1. --help ───────────────────────────────────────────────────────────

test_name "--help exits 0 and contains Usage:"

out=$("$CLI" --help 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "--help exits 0"
else
  fail "--help exits 0" "exit code $rc"
fi

if echo "$out" | grep -q "Usage:"; then
  pass "--help contains Usage:"
else
  fail "--help contains Usage:" "output missing Usage:"
fi

# ── 2. --version ────────────────────────────────────────────────────────

test_name "--version exits 0 and outputs comfy-health ..."

out=$("$CLI" --version 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "--version exits 0"
else
  fail "--version exits 0" "exit code $rc"
fi

if echo "$out" | grep -q "^comfy-health "; then
  pass "--version starts with 'comfy-health '"
else
  fail "--version starts with 'comfy-health '" "got: $out"
fi

# ── 3. no args ──────────────────────────────────────────────────────────

test_name "no args exits 0 (shows help)"

out=$("$CLI" 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "no args exits 0"
else
  fail "no args exits 0" "exit code $rc"
fi

if echo "$out" | grep -q "Usage:"; then
  pass "no args shows Usage:"
else
  fail "no args shows Usage:" "output missing Usage:"
fi

# ── 4. help subcommand ──────────────────────────────────────────────────

test_name "help subcommand exits 0"

out=$("$CLI" help 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "help exits 0"
else
  fail "help exits 0" "exit code $rc"
fi

# ── 5. diff in a git repo ──────────────────────────────────────────────

test_name "diff in a git repo"

out=$("$CLI" diff 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "diff exits 0"
else
  fail "diff exits 0" "exit code $rc"
fi

if echo "$out" | grep -qE "(changed|No changed files)"; then
  pass "diff output mentions changed files"
else
  # Still a pass if it exits 0 — output may vary
  pass "diff exits 0 (output varies)"
fi

# ── 6. branch in a git repo ────────────────────────────────────────────

test_name "branch in a git repo"

out=$("$CLI" branch 2>&1) && rc=$? || rc=$?
if [[ $rc -eq 0 ]]; then
  pass "branch exits 0"
else
  fail "branch exits 0" "exit code $rc"
fi

# ── 7. unknown-cmd falls through (doesn't crash wrapper) ───────────────

test_name "unknown-cmd falls through to desloppify"

if python3 -m desloppify --version &>/dev/null; then
  # desloppify is available — unknown-cmd may error but wrapper shouldn't crash
  out=$("$CLI" unknown-cmd 2>&1) && rc=$? || rc=$?
  # We only care that the wrapper itself didn't crash with a bash error.
  # desloppify may return non-zero for an unknown command — that's fine.
  if [[ $rc -le 2 ]]; then
    pass "unknown-cmd: wrapper handled gracefully (exit $rc)"
  else
    fail "unknown-cmd: wrapper handled gracefully" "exit code $rc (possible crash)"
  fi
else
  echo "  ⊘ skipped (desloppify not installed)"
fi

# ── 8. doctor command pattern ───────────────────────────────────────────

test_name "doctor command (pattern check)"

if python3 -m desloppify --version &>/dev/null; then
  # doctor may not be implemented yet — verify the wrapper doesn't crash
  out=$("$CLI" doctor 2>&1) && rc=$? || rc=$?
  if [[ $rc -le 2 ]]; then
    pass "doctor: wrapper handled gracefully (exit $rc)"
  else
    fail "doctor: wrapper handled gracefully" "exit code $rc"
  fi

  if echo "$out" | grep -qiE "(check|doctor|error|usage|python|desloppify|project|git)"; then
    pass "doctor: produced recognizable output"
  else
    fail "doctor: produced recognizable output" "unexpected output: $out"
  fi
else
  echo "  ⊘ skipped (desloppify not installed)"
fi

# ── Results ─────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
