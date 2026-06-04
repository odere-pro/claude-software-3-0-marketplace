#!/usr/bin/env bash
# G1 — every tracked *.json file parses as valid JSON. (CRITICAL)
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  if ! jq empty "$f" >/dev/null 2>&1; then
    echo "  FAIL: invalid JSON: $f"
    fail=1
  fi
done < <(find . -type f -name '*.json' -not -path './.git/*' -not -path './node_modules/*' | sort)

if [ "$fail" -ne 0 ]; then echo "G1 json-parses: FAIL"; exit 1; fi
echo "G1 json-parses: ok"
