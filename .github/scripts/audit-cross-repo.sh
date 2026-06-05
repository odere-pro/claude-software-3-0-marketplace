#!/usr/bin/env bash
# audit-cross-repo.sh — consolidated cross-repo provenance audit (scheduled, ADVISORY). (no writes)
#
# Roadmap P4 (Phase 3, thesis 2/5). Re-derives, live, for every plugin listed in marketplace.json:
#   1. the listed repo exists and its .claude-plugin/plugin.json is fetchable + valid JSON,
#   2. source.repo matches the odere-pro/<repo> pattern,
#   3. the listed repo ships NO marketplace.json of its own (would re-create the name collision).
# It does NOT assert entry.name === plugin.json.name — the entry name may legitimately differ via
# `--name` (D13).
#
# It REUSES the vet-candidate.sh probes (DRY, D1 — no fork): each listed source.repo is run through
# `vet-candidate.sh --skip-listed-check`, whose coded blockers already cover PLUGIN_JSON_UNREADABLE,
# PLUGIN_JSON_INVALID, SHIPS_MARKETPLACE_JSON and OWNER_NOT_ALLOWED. The source.repo-pattern check is
# done manifest-side here.
#
# ADVISORY / SKIP-NOT-FAIL (D3): this is notify-only. It NEVER hard-FAILs.
#   * No plugins listed (N=0)            -> no-op, exit 0.
#   * Tooling missing / gh-auth failure  -> SKIP, exit 0, no issue.
#   * Connectivity control probe fails   -> SKIP, exit 0, no issue (a transient non-200/network error
#                                           must not be mistaken for real drift, D3).
#   * Connectivity OK but a listed repo
#     fails a contract probe             -> reportable DRIFT (printed; the caller opens/updates an
#                                           issue, D17/Q1).
# The script exits 0 in every advisory path; it prints a machine-readable drift report to stdout for
# the workflow's notify step. Human notes go to stderr.
#
# Auth: uses whatever gh auth the environment provides (the workflow exports the default GITHUB_TOKEN
# as GH_TOKEN — reads public plugin repos, no extra secret, D17). Not a tests/gates gate: it makes
# network calls and must never enter the push suite run-all.sh (D3/D4).
set -euo pipefail

# Locate the vet-candidate.sh probe core (shared add-plugin scripts) and the manifest.
SELF_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH='' cd -- "$SELF_DIR/../.." && pwd)" # .github/scripts/ -> repo root
VET="$ROOT/.claude/skills/add-plugin/scripts/vet-candidate.sh"
MANIFEST="$ROOT/.claude-plugin/marketplace.json"
OWNER="odere-pro"

skip() { echo "AUDIT: SKIP — $1" >&2; echo '{"status":"skip","reason":"'"$1"'","drift":[]}'; exit 0; }

command -v jq >/dev/null 2>&1 || skip "jq not available"
command -v gh >/dev/null 2>&1 || skip "gh (GitHub CLI) not available"
[ -f "$MANIFEST" ] || skip "manifest not found at $MANIFEST"
[ -x "$VET" ] || [ -f "$VET" ] || skip "vet-candidate.sh probe core not found at $VET"

# N=0 no-op: registry empty -> nothing to audit.
count="$(jq -r '(.plugins // []) | length' "$MANIFEST" 2>/dev/null || echo 0)"
if [ "$count" -eq 0 ]; then
  echo "AUDIT: registry is empty — nothing to audit (N=0 no-op)" >&2
  echo '{"status":"empty","reason":"registry empty (N=0)","drift":[]}'
  exit 0
fi

# Connectivity control probe (D3): if GitHub itself is unreachable / gh is unauthenticated, every
# subsequent probe would falsely look like drift. A failing control probe means SKIP, never report.
if ! gh api rate_limit >/dev/null 2>&1; then
  skip "gh control probe failed (network down or gh unauthenticated) — not treating as drift"
fi

# Connectivity is good. Audit each listed entry.
drift='[]'

while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  name="$(printf '%s' "$entry" | jq -r '.name // ""')"
  src="$(printf '%s' "$entry" | jq -r '.source.repo // .source // ""')"

  problems='[]'

  # (2) source.repo must match the odere-pro/<repo> pattern (manifest-side, D13: name NOT compared).
  if ! printf '%s' "$src" | grep -Eq "^${OWNER}/[A-Za-z0-9._-]+$"; then
    problems="$(printf '%s' "$problems" | jq --arg m "source.repo \"$src\" does not match ${OWNER}/<repo>" '. + [{code:"SOURCE_REPO_PATTERN", message:$m}]')"
    # Cannot probe a malformed source — record and move on.
    drift="$(printf '%s' "$drift" | jq --arg n "$name" --arg s "$src" --argjson p "$problems" '. + [{name:$n, repo:$s, problems:$p}]')"
    continue
  fi

  # (1)+(3) Re-derive via the shared vet probes (repo/plugin.json fetchable + valid JSON; ships no
  # marketplace.json; owner). vet exit 2 = tooling/usage error -> SKIP the whole run (D3, not drift).
  set +e
  verdict="$(bash "$VET" --skip-listed-check "$src" 2>/dev/null)"
  rc=$?
  set -e
  if [ "$rc" -eq 2 ]; then
    skip "vet tooling error on $src (exit 2) — not treating as drift"
  fi

  # Keep only the contract blockers relevant to a provenance audit (D13 excludes name/component
  # advisories that are add-time quality floors, not provenance drift).
  relevant="$(printf '%s' "$verdict" | jq -c '
    [ (.blockers // [])[]
      | select(.code == "PLUGIN_JSON_UNREADABLE"
            or .code == "PLUGIN_JSON_INVALID"
            or .code == "SHIPS_MARKETPLACE_JSON"
            or .code == "OWNER_NOT_ALLOWED")
      | {code: .code, message: .message} ]' 2>/dev/null || echo '[]')"

  problems="$(printf '%s' "$problems" | jq --argjson r "$relevant" '. + $r')"

  if [ "$(printf '%s' "$problems" | jq 'length')" -gt 0 ]; then
    drift="$(printf '%s' "$drift" | jq --arg n "$name" --arg s "$src" --argjson p "$problems" '. + [{name:$n, repo:$s, problems:$p}]')"
  fi
done < <(jq -c '(.plugins // [])[]' "$MANIFEST")

if [ "$(printf '%s' "$drift" | jq 'length')" -eq 0 ]; then
  echo "AUDIT: ok — all $count listed plugin(s) re-derived clean" >&2
  echo '{"status":"ok","reason":"no drift","drift":[]}'
  exit 0
fi

echo "AUDIT: DRIFT detected in $(printf '%s' "$drift" | jq 'length') listed plugin(s)" >&2
jq -cn --argjson d "$drift" '{status:"drift", reason:"provenance drift detected", drift:$d}'
exit 0
