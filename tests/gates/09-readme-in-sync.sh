#!/usr/bin/env bash
# G9 — the README Plugins table matches marketplace.json. (CRITICAL)
# The table between the <!-- BEGIN PLUGINS --> / <!-- END PLUGINS --> markers is generated from the
# manifest by .claude/skills/add-plugin/scripts/sync-readme.sh. This gate runs that script in
# --check mode so the docs can never drift from the registry.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

sync=".claude/skills/add-plugin/scripts/sync-readme.sh"
if [ ! -f "$sync" ]; then
  echo "G9 readme-in-sync: SKIP ($sync not present)"
  exit 0
fi

if bash "$sync" --check >/dev/null 2>&1; then
  echo "G9 readme-in-sync: ok"
else
  echo "  FAIL: README Plugins table is out of sync with $GATES_MARKETPLACE"
  echo "  fix: bash $sync"
  echo "G9 readme-in-sync: FAIL"
  exit 1
fi
