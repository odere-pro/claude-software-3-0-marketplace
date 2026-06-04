#!/usr/bin/env bash
# Run every gate in this directory. A gate that exits non-zero fails the suite.
# Advisory gates (e.g. markdown style) self-degrade to warnings and always exit 0.
#
# Usage: bash tests/gates/run-all.sh
set -u

DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

passed=0
failed=0
failed_list=""

for gate in "$DIR"/[0-9][0-9]-*.sh; do
  [ -e "$gate" ] || continue
  name="$(basename "$gate")"
  if bash "$gate"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    failed_list="${failed_list} ${name}"
  fi
done

echo "--------------------------------------------------"
echo "gates passed: ${passed}   failed: ${failed}"
if [ "${failed}" -ne 0 ]; then
  echo "FAILED:${failed_list}"
  exit 1
fi
echo "ALL GATES PASS"
