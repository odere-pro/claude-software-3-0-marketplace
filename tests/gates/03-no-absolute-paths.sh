#!/usr/bin/env bash
# G3 — no machine-absolute home paths (/Users/<name>, /home/<name>) in tracked files. (CRITICAL)
# These leak an author's machine layout and break on every other machine.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

# Search everything tracked except the git dir, deps, and this gate suite (which legitimately
# documents the pattern it forbids).
hits="$(grep -rnE '/(Users|home)/[A-Za-z0-9._-]+' . \
  --include='*.md' --include='*.json' --include='*.jsonc' --include='*.sh' --include='*.yml' --include='*.yaml' \
  2>/dev/null | grep -v '/.git/' | grep -v '/node_modules/' | grep -v '/tests/gates/' || true)"

if [ -n "$hits" ]; then
  echo "  FAIL: absolute home path(s) found:"
  printf '%s\n' "$hits" | sed 's/^/    /'
  echo "G3 no-absolute-paths: FAIL"
  exit 1
fi
echo "G3 no-absolute-paths: ok"
