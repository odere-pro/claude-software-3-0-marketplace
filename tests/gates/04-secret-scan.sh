#!/usr/bin/env bash
# G4 — no concrete secret-shaped tokens in tracked files. (CRITICAL)
# Targets real credential formats (OpenAI, GitHub PAT, AWS, Slack, private keys), not the literal
# pattern strings this gate itself carries (those live below the marker and are excluded).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

# Concrete token formats.
secret_re='(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

# Exclude .git, deps, and this gate suite (the regex above is not a secret).
hits="$(grep -rnE "$secret_re" . \
  --include='*.md' --include='*.json' --include='*.jsonc' --include='*.sh' --include='*.yml' --include='*.yaml' \
  2>/dev/null | grep -v '/.git/' | grep -v '/node_modules/' | grep -v '/tests/gates/' || true)"

if [ -n "$hits" ]; then
  echo "  FAIL: possible secret(s) found:"
  printf '%s\n' "$hits" | sed 's/^/    /'
  echo "G4 secret-scan: FAIL"
  exit 1
fi
echo "G4 secret-scan: ok"
