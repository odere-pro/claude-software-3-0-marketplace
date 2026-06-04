#!/usr/bin/env bash
# G7 — every navigational layer carries a CLAUDE.md. (CRITICAL)
# The repo follows a nested-CLAUDE.md convention: each folder gives just enough context for an agent
# to navigate its layer, with detail deepening as you descend. This gate enforces presence for the
# documented layers (root + GATES_DOCUMENTED_DIRS). A directory that does not exist is skipped.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0

[ -f "CLAUDE.md" ] || { echo "  FAIL: missing root CLAUDE.md"; fail=1; }

for d in $GATES_DOCUMENTED_DIRS; do
  [ -d "$d" ] || continue
  if [ ! -f "$d/CLAUDE.md" ]; then
    echo "  FAIL: $d/ exists but has no CLAUDE.md"
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then echo "G7 claude-md-coverage: FAIL"; exit 1; fi
echo "G7 claude-md-coverage: ok"
