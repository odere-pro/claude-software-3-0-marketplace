#!/usr/bin/env bash
# audit-cross-repo.sh — consolidated cross-repo provenance audit (scheduled, ADVISORY). (no writes)
#
# Roadmap P4 (Phase 3, thesis 2/5). Re-derives, live, for every plugin listed in marketplace.json:
#   1. the listed repo exists and its .claude-plugin/plugin.json is fetchable + valid JSON,
#   2. source.repo matches the odere-pro/<repo> pattern,
#   3. the listed repo ships NO marketplace.json of its own (would re-create the name collision).
#   4. [CHECK A — DRIFT] plugin.json.name is non-empty (coordinate validity: an empty name breaks
#      `<plugin>@odere-pro` install resolution). MISSING_NAME is included here specifically as an
#      install-coordinate check (distinct from the D13 add-time quality floor: at add-time the
#      entry's manifest name may differ from plugin.json.name via `--name`; but a blank plugin.json
#      name at audit time means the install coordinate cannot be resolved at all, which is provenance
#      drift). Source-fetchable is ALREADY covered by PLUGIN_JSON_UNREADABLE — no new code needed.
# It does NOT assert entry.name === plugin.json.name — the entry name may legitimately differ via
# `--name` (D13).
#
# After the per-entry loop:
#   5. [CHECK B — ADVISORY] Registry-repo About/topics advisory: checks the odere-pro marketplace
#      repo itself (odere-pro/claude-software-3-0-marketplace) for recommended discovery topics and
#      a non-empty description. Notify-only; findings go to "advisories", NOT "drift". This check
#      runs unconditionally after the connectivity control probe passes (the registry repo always
#      exists; N=0 does not suppress it — KISS). On any non-200 from this single gh call, the check
#      is silently skipped (advisory only — no false report, D3).
#
# It REUSES the vet-candidate.sh probes (DRY, D1 — no fork): each listed source.repo is run through
# `vet-candidate.sh --skip-listed-check`, whose coded blockers already cover PLUGIN_JSON_UNREADABLE,
# PLUGIN_JSON_INVALID, SHIPS_MARKETPLACE_JSON and OWNER_NOT_ALLOWED. The source.repo-pattern check is
# done manifest-side here.
#
# ADVISORY / SKIP-NOT-FAIL (D3): this is notify-only. It NEVER hard-FAILs.
#   * No plugins listed (N=0)            -> no-op for per-entry checks; About/topics check still runs.
#   * Tooling missing / gh-auth failure  -> SKIP whole run, exit 0, no issue.
#   * Connectivity control probe fails   -> SKIP whole run, exit 0, no issue (a transient non-200/
#                                           network error must not be mistaken for real drift, D3).
#   * Connectivity OK but a listed repo
#     fails a contract probe             -> reportable DRIFT (printed; the caller opens/updates an
#                                           issue, D17/Q1).
#   * About/topics check fails           -> ADVISORY (separate issue channel; never counted as drift).
# The script exits 0 in every advisory path; it prints a machine-readable report to stdout for
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

skip() { echo "AUDIT: SKIP — $1" >&2; echo '{"status":"skip","reason":"'"$1"'","drift":[],"advisories":[]}'; exit 0; }

command -v jq >/dev/null 2>&1 || skip "jq not available"
command -v gh >/dev/null 2>&1 || skip "gh (GitHub CLI) not available"
[ -f "$MANIFEST" ] || skip "manifest not found at $MANIFEST"
[ -x "$VET" ] || [ -f "$VET" ] || skip "vet-candidate.sh probe core not found at $VET"

# N=0 no-op: registry empty -> per-entry loop is skipped; About/topics advisory may still run below.
count="$(jq -r '(.plugins // []) | length' "$MANIFEST" 2>/dev/null || echo 0)"
if [ "$count" -eq 0 ]; then
  echo "AUDIT: registry is empty (N=0) — skipping per-entry checks; About/topics advisory will still run" >&2
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
  # Repo-posture blockers (REPO_ARCHIVED, REPO_PRIVATE, LICENSE_FILE_MISMATCH) are included here
  # because a listed repo that has since gone archived/private or whose license has diverged is
  # genuine post-listing drift, not merely an add-time quality floor.
  # CHECK A — MISSING_NAME is included specifically as an install-coordinate validity check: a blank
  # plugin.json.name breaks `<plugin>@odere-pro` resolution (provenance drift). This is distinct from
  # the D13 add-time quality floor rationale (where name may differ via --name). Source-fetchable is
  # already covered by PLUGIN_JSON_UNREADABLE — no new probe needed.
  relevant="$(printf '%s' "$verdict" | jq -c '
    [ (.blockers // [])[]
      | select(.code == "PLUGIN_JSON_UNREADABLE"
            or .code == "PLUGIN_JSON_INVALID"
            or .code == "SHIPS_MARKETPLACE_JSON"
            or .code == "OWNER_NOT_ALLOWED"
            or .code == "REPO_ARCHIVED"
            or .code == "REPO_PRIVATE"
            or .code == "LICENSE_FILE_MISMATCH"
            or .code == "MISSING_NAME")
      | {code: .code, message: .message} ]' 2>/dev/null || echo '[]')"

  problems="$(printf '%s' "$problems" | jq --argjson r "$relevant" '. + $r')"

  if [ "$(printf '%s' "$problems" | jq 'length')" -gt 0 ]; then
    drift="$(printf '%s' "$drift" | jq --arg n "$name" --arg s "$src" --argjson p "$problems" '. + [{name:$n, repo:$s, problems:$p}]')"
  fi
done < <(jq -c '(.plugins // [])[]' "$MANIFEST")

# CHECK B — About/topics advisory (registry repo itself, not per-entry).
# Runs unconditionally after the connectivity control probe passes (the registry repo always exists).
# Recommended discovery topics — advisory only; expand this list via an issue, not silently.
RECOMMENDED_TOPICS="claude-code marketplace claude-code-plugins"
advisories='[]'

if repo_info="$(gh api "repos/$OWNER/claude-software-3-0-marketplace" \
    --jq '{description: .description, topics: (.topics // [])}' 2>/dev/null)"; then
  repo_description="$(printf '%s' "$repo_info" | jq -r '.description // ""')"
  repo_topics_json="$(printf '%s' "$repo_info" | jq -c '.topics')"

  # Flag if the repo About description is empty.
  if [ -z "$repo_description" ]; then
    advisories="$(printf '%s' "$advisories" | jq \
      '. + [{code:"MISSING_ABOUT", message:"Registry repo odere-pro/claude-software-3-0-marketplace has no About description — set one via Settings for discoverability"}]')"
  fi

  # Flag if any recommended discovery topic is missing.
  missing_topics=""
  for topic in $RECOMMENDED_TOPICS; do
    if ! printf '%s' "$repo_topics_json" | jq -e --arg t "$topic" 'index($t) != null' >/dev/null 2>&1; then
      missing_topics="${missing_topics:+$missing_topics, }$topic"
    fi
  done
  if [ -n "$missing_topics" ]; then
    advisories="$(printf '%s' "$advisories" | jq \
      --arg m "Registry repo odere-pro/claude-software-3-0-marketplace is missing recommended discovery topics: $missing_topics (advisory only — add via Settings → Topics)" \
      '. + [{code:"MISSING_TOPICS", message:$m}]')"
  fi
else
  # Non-200 / network error for this single advisory call: silently skip (D3, advisory only).
  echo "AUDIT: About/topics check skipped (gh api returned non-200 for registry repo)" >&2
fi

# Determine status and emit the final machine-readable report.
# Drift dominates: if both drift and advisories present, status is "drift" and advisories ride along.
# Advisory-only: status is "advisory" when drift is empty but advisories are non-empty.
drift_count="$(printf '%s' "$drift" | jq 'length')"
advisory_count="$(printf '%s' "$advisories" | jq 'length')"

if [ "$drift_count" -gt 0 ]; then
  echo "AUDIT: DRIFT detected in $drift_count listed plugin(s)" >&2
  jq -cn --argjson d "$drift" --argjson a "$advisories" \
    '{status:"drift", reason:"provenance drift detected", drift:$d, advisories:$a}'
elif [ "$advisory_count" -gt 0 ]; then
  echo "AUDIT: advisory — $advisory_count discoverability advisory item(s)" >&2
  jq -cn --argjson a "$advisories" \
    '{status:"advisory", reason:"discoverability advisory", drift:[], advisories:$a}'
elif [ "$count" -eq 0 ]; then
  echo "AUDIT: empty — registry has no listed plugins; no advisories" >&2
  echo '{"status":"empty","reason":"registry empty (N=0)","drift":[],"advisories":[]}'
else
  echo "AUDIT: ok — all $count listed plugin(s) re-derived clean; no advisories" >&2
  echo '{"status":"ok","reason":"no drift","drift":[],"advisories":[]}'
fi
exit 0
