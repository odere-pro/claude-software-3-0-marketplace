#!/usr/bin/env bash
# G6 — shellcheck every shell script (gates + harness hooks + skill scripts) at error severity. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "G6 shellcheck: SKIP (shellcheck not installed)"
  exit 0
fi

# `-exec ... {} +` batches matches into one invocation and runs nothing if none are found.
# Portable across BSD (macOS) and GNU find.
if find tests .claude/hooks .claude/skills -type f -name '*.sh' -exec shellcheck -S error -x {} +; then
  echo "G6 shellcheck: ok"
else
  echo "G6 shellcheck: FAIL"
  exit 1
fi
