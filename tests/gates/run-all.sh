#!/usr/bin/env bash
# Run every gate in this directory. A gate that exits non-zero fails the suite.
# Advisory gates (e.g. markdown style) self-degrade to warnings and always exit 0.
#
# Timing: each gate's elapsed seconds and the suite total are printed as an
# advisory summary (stderr-safe stdout lines). The timing NEVER changes the exit
# code — a slow gate is still a passing gate.
#
# Usage: bash tests/gates/run-all.sh
set -u

DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

passed=0
failed=0
failed_list=""
suite_start=$SECONDS

for gate in "$DIR"/[0-9][0-9]-*.sh; do
  [ -e "$gate" ] || continue
  name="$(basename "$gate")"
  gate_start=$SECONDS
  if bash "$gate"; then
    gate_elapsed=$((SECONDS - gate_start))
    passed=$((passed + 1))
    printf "  [%3ds] %s\n" "$gate_elapsed" "$name"
  else
    gate_elapsed=$((SECONDS - gate_start))
    failed=$((failed + 1))
    failed_list="${failed_list} ${name}"
    printf "  [%3ds] %s  <-- FAILED\n" "$gate_elapsed" "$name"
  fi
done

suite_elapsed=$((SECONDS - suite_start))

echo "--------------------------------------------------"
echo "gates passed: ${passed}   failed: ${failed}   total: ${suite_elapsed}s"
if [ "${failed}" -ne 0 ]; then
  echo "FAILED:${failed_list}"
  exit 1
fi
echo "ALL GATES PASS"
