#!/usr/bin/env bash
# G16 — workflow-permissions gate. (CRITICAL)
#
# A workflow's GITHUB_TOKEN must follow least privilege (OpenSSF "Token-Permissions" signal):
#
#   1. NO `permissions: write-all` — the blanket grant gives a compromised step write to the whole
#      repo. Forbidden at every scope (top-level or job-level).
#   2. NO `contents: write` unless the workflow is on the allowlist below — write to repo contents is
#      the lever a supply-chain attack pulls (push a tag, rewrite a release). Today nothing in this
#      repo needs it (the gate suite is read-only; Scorecard/CodeQL upload via `security-events`/
#      `id-token`, not `contents`), so the allowlist is empty and any `contents: write` FAILs. A
#      future workflow that genuinely needs it is an explicit, reviewed allowlist entry — not a
#      silent default (roadmap P12b, thesis 7).
#
# `security-events: write` and `id-token: write` are legitimate, narrow scopes (SAST SARIF upload,
# Scorecard publish) and are NOT flagged — only the blanket `write-all` and the high-blast-radius
# `contents: write` are.
#
# Static YAML scan over `.github/workflows/*.yml`. Offline, dependency-light (grep). Never networks.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

WF_DIR=".github/workflows"
if [ ! -d "$WF_DIR" ]; then
  echo "G16 workflow-permissions: ok (no $WF_DIR)"
  exit 0
fi

# Workflows explicitly permitted to declare `contents: write` (basename, no extension). Empty today.
# To allow one, add its basename here AND say why in .github/CLAUDE.md — a reviewed change, not a default.
CONTENTS_WRITE_ALLOWLIST=""

checked=0
while IFS= read -r wf; do
  [ -f "$wf" ] || continue
  checked=$((checked + 1))
  base="$(basename "$wf")"
  base="${base%.yml}"; base="${base%.yaml}"

  # 1. blanket write-all at any scope: `permissions: write-all` (allow surrounding whitespace/quotes).
  if grep -nEq '^[[:space:]]*permissions:[[:space:]]*["'"'"']?write-all["'"'"']?[[:space:]]*$' "$wf"; then
    note "$wf: declares \`permissions: write-all\` — use least-privilege explicit scopes (roadmap P12b)"
  fi

  # 2. `contents: write` as a permission scope line (inside a permissions: block).
  #    Match a `contents: write` key/value line; only the allowlisted workflows may carry it.
  if grep -nEq '^[[:space:]]+contents:[[:space:]]*["'"'"']?write["'"'"']?[[:space:]]*$' "$wf"; then
    if ! printf '%s' " $CONTENTS_WRITE_ALLOWLIST " | grep -qF " $base "; then
      note "$wf: declares \`contents: write\` but is not on the allowlist — drop it or add \"$base\" to CONTENTS_WRITE_ALLOWLIST with a documented reason (roadmap P12b)"
    fi
  fi
done < <(find "$WF_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \))

if [ "$checked" -eq 0 ]; then
  note "found no workflow files to check — the workflow scan changed shape"
fi

if [ "$fail" -ne 0 ]; then
  echo "G16 workflow-permissions: FAIL"
  exit 1
fi
echo "G16 workflow-permissions: ok ($checked workflow(s) within least-privilege bounds)"
