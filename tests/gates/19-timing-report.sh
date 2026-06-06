#!/usr/bin/env bash
# G19 — run-all.sh timing-report contract (ADVISORY)
#
# Verifies that run-all.sh contains the advisory per-gate + total timing report
# added by the perf-baseline item (roadmap — tests/gates/CLAUDE.md budget doc).
#
# This gate is ADVISORY: it always exits 0 so a missing feature never breaks CI,
# but it prints a clear WARN when the instrumentation has been accidentally stripped.
#
# Checks:
#   1. run-all.sh captures a suite_start timestamp (SECONDS variable) before the gate loop.
#   2. run-all.sh records per-gate elapsed time inside the discovery loop.
#   3. run-all.sh prints a "total:" elapsed line in the summary block.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

RUN_ALL="tests/gates/run-all.sh"

warn=0
note() { echo "  WARN: $1"; warn=1; }

# 1. Suite-start timestamp capture — must assign suite_start from $SECONDS
grep -qE 'suite_start=\$SECONDS' "$RUN_ALL" \
  || note "$RUN_ALL: missing suite_start=\$SECONDS assignment before the gate loop"

# 2. Per-gate elapsed — must capture SECONDS before each gate and print elapsed in the loop
grep -qE 'gate_start=\$SECONDS' "$RUN_ALL" \
  || note "$RUN_ALL: missing gate_start=\$SECONDS per-gate timestamp capture"

grep -qE 'gate_elapsed=' "$RUN_ALL" \
  || note "$RUN_ALL: missing gate_elapsed= calculation in gate loop"

# 3. Summary total elapsed line
grep -qE 'total:' "$RUN_ALL" \
  || note "$RUN_ALL: missing 'total:' elapsed line in the summary"

if [ "$warn" -ne 0 ]; then
  echo "G19 timing-report: WARN (advisory — timing instrumentation missing or stripped from run-all.sh)"
  exit 0
fi
echo "G19 timing-report: ok"
