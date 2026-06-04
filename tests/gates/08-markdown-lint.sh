#!/usr/bin/env bash
# G8 — markdown style (advisory). Self-degrades to a warning and always exits 0.
# Rule config lives in .markdownlint.jsonc; runner options in .markdownlint-cli2.jsonc.
set -uo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

runner=""
if command -v markdownlint-cli2 >/dev/null 2>&1; then
  runner="markdownlint-cli2"
elif command -v bunx >/dev/null 2>&1; then
  runner="bunx markdownlint-cli2"
elif command -v npx >/dev/null 2>&1; then
  runner="npx --no-install markdownlint-cli2"
fi

if [ -z "$runner" ]; then
  echo "G8 markdown-lint: SKIP (markdownlint-cli2 not installed) [advisory]"
  exit 0
fi

if $runner "**/*.md" >/dev/null 2>&1; then
  echo "G8 markdown-lint: ok"
else
  echo "G8 markdown-lint: WARN (style issues — run '$runner \"**/*.md\"' to see them) [advisory]"
fi
exit 0
