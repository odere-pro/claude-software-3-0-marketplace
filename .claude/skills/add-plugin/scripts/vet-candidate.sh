#!/usr/bin/env bash
# vet-candidate.sh — read-only preflight for a candidate plugin repo. (no writes)
#
# Usage: vet-candidate.sh [--skip-listed-check] <repo|owner/repo>
# Fetches the candidate's .claude-plugin/plugin.json over `gh api`, checks the marketplace contract,
# and prints a JSON verdict on stdout:
#   { "ok": bool, "repo": "owner/repo", "name": "..", "description": "..", "homepage": "..",
#     "license": "..", "keywords": [..],
#     "blockers": [ { "code": "<ENUM>", "message": "...", "fix": "..." }, ... ] }
# Each blocker is a coded object: `code` is a stable enum (see VET_CODES below), `message` is the
# human-readable problem, `fix` is the paired remediation. The verdict shape is gated by
# tests/gates/10-vet-verdict-schema.sh.
# --skip-listed-check: don't flag "already listed" (used by /update-plugin, which expects the entry to
# exist). Exit 0 if ok, 1 if there are blockers, 2 on usage/tooling error. Human notes go to stderr.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

skip_listed=false
repo_arg=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-listed-check) skip_listed=true; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) repo_arg="$1"; shift ;;
  esac
done

[ -n "$repo_arg" ] || { echo "usage: vet-candidate.sh [--skip-listed-check] <repo|owner/repo>" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

REPO="$(mk_normalize_repo "$repo_arg")"
owner="${REPO%%/*}"
name_from_repo="${REPO##*/}"

# Coded blocker enum. Every blocker is { code, message, fix }; `code` is one of these stable tokens.
# The verdict-shape gate (tests/gates/10-vet-verdict-schema.sh) asserts each blocker carries all three.
# VET_CODES: OWNER_NOT_ALLOWED PLUGIN_JSON_UNREADABLE PLUGIN_JSON_INVALID SHIPS_MARKETPLACE_JSON
#            MISSING_NAME MISSING_DESCRIPTION MISSING_LICENSE LICENSE_NOT_ALLOWED ALREADY_LISTED
#
# SPDX license allowlist (roadmap P10 / D14): permissive + file-level weak copyleft only. Shared
# by-value with tests/gates/02-marketplace-shape.sh (the G2 license check); the two sites are kept
# byte-identical by the parity check in tests/gates/00-harness-integrity.sh (D1: no cross-tree
# `source`). Expanding the set is an explicit "open an issue" change (docs/adding-plugins.md).
SPDX_ALLOWLIST="MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0"
blockers=()
add_blocker() { # $1=code  $2=message  $3=fix  → appends a compact JSON object
  blockers+=("$(jq -cn --arg code "$1" --arg message "$2" --arg fix "$3" \
    '{code:$code, message:$message, fix:$fix}')")
}

# Owner must be odere-pro (registry is odere-pro-only).
if [ "$owner" != "$MK_OWNER" ]; then
  add_blocker "OWNER_NOT_ALLOWED" \
    "owner is \"$owner\"; this registry lists $MK_OWNER repos only" \
    "transfer or re-fork the plugin under the $MK_OWNER org, then re-run the vet"
fi

# Fetch the candidate plugin.json (base64 from the contents API).
pj=""
if pj_b64="$(gh api "repos/$REPO/contents/.claude-plugin/plugin.json" --jq '.content' 2>/dev/null)"; then
  pj="$(printf '%s' "$pj_b64" | base64 -d 2>/dev/null || true)"
fi

if [ -z "$pj" ]; then
  add_blocker "PLUGIN_JSON_UNREADABLE" \
    "could not read .claude-plugin/plugin.json from $REPO (repo missing, private, or not a plugin)" \
    "confirm the repo exists, is accessible to your gh auth, and ships .claude-plugin/plugin.json"
elif ! printf '%s' "$pj" | jq empty >/dev/null 2>&1; then
  add_blocker "PLUGIN_JSON_INVALID" \
    "$REPO .claude-plugin/plugin.json is not valid JSON" \
    "fix the JSON syntax in the candidate's .claude-plugin/plugin.json, then re-run the vet"
  pj=""
fi

# Candidate must NOT ship its own marketplace.json (would re-create the odere-pro name collision).
if gh api "repos/$REPO/contents/.claude-plugin/marketplace.json" >/dev/null 2>&1; then
  add_blocker "SHIPS_MARKETPLACE_JSON" \
    "$REPO still ships .claude-plugin/marketplace.json — remove it first (see docs/adding-plugins.md)" \
    "git rm .claude-plugin/marketplace.json in the candidate repo (keep plugin.json), then re-run the vet"
fi

# Extract fields from the candidate plugin.json (empty string if absent).
get() { [ -n "$pj" ] && printf '%s' "$pj" | jq -r "$1 // empty" 2>/dev/null || printf ''; }
c_name="$(get '.name')"
c_desc="$(get '.description')"
c_home="$(get '.homepage')"
c_lic="$(get '.license')"
c_keywords_json="$([ -n "$pj" ] && printf '%s' "$pj" | jq -c '(.keywords // [])' 2>/dev/null || printf '[]')"
[ -n "$c_keywords_json" ] || c_keywords_json="[]"

# The entry name defaults to the candidate's plugin.json name (may differ from the repo basename).
entry_name="${c_name:-$name_from_repo}"
[ -n "$c_home" ] || c_home="https://github.com/$REPO"

if [ -n "$pj" ]; then
  [ -n "$c_name" ] || add_blocker "MISSING_NAME" \
    "$REPO plugin.json has no \"name\"" \
    "add a \"name\" field to the candidate's .claude-plugin/plugin.json"
  [ -n "$c_desc" ] || add_blocker "MISSING_DESCRIPTION" \
    "$REPO plugin.json has no \"description\"" \
    "add a concise \"description\" field to the candidate's .claude-plugin/plugin.json"
  if [ -z "$c_lic" ]; then
    add_blocker "MISSING_LICENSE" \
      "$REPO plugin.json has no \"license\"" \
      "add an SPDX \"license\" field to the candidate's .claude-plugin/plugin.json (one of: $SPDX_ALLOWLIST)"
  elif ! printf '%s' " $SPDX_ALLOWLIST " | grep -qF " $c_lic "; then
    add_blocker "LICENSE_NOT_ALLOWED" \
      "$REPO plugin.json license \"$c_lic\" is not in the registry's SPDX allowlist ($SPDX_ALLOWLIST)" \
      "set \"license\" to one of: $SPDX_ALLOWLIST; if a valid newer SPDX id should be allowed, open an issue to expand the allowlist (docs/adding-plugins.md)"
  fi
fi

# Already listed here? (skipped for /update-plugin, which operates on an existing entry.)
root="$(mk_repo_root)"
if ! $skip_listed && [ -f "$root/$MK_MANIFEST" ]; then
  if jq -e --arg n "$entry_name" '.plugins[]? | select(.name == $n)' "$root/$MK_MANIFEST" >/dev/null 2>&1; then
    add_blocker "ALREADY_LISTED" \
      "\"$entry_name\" is already listed in the marketplace" \
      "use /update-plugin \"$entry_name\" to refresh/repoint instead of /add-plugin"
  fi
fi

ok=true
[ "${#blockers[@]}" -eq 0 ] || ok=false

# Assemble the coded blockers into a JSON array (each element is already a compact JSON object).
if [ "${#blockers[@]}" -eq 0 ]; then
  blockers_json="[]"
else
  blockers_json="$(printf '%s\n' "${blockers[@]}" | jq -s '.')"
fi

# Emit the JSON verdict.
printf '%s' "$c_keywords_json" | jq \
  --argjson ok "$ok" \
  --arg repo "$REPO" \
  --arg name "$entry_name" \
  --arg description "$c_desc" \
  --arg homepage "$c_home" \
  --arg license "$c_lic" \
  --argjson blockers "$blockers_json" \
  '{ ok: $ok, repo: $repo, name: $name, description: $description, homepage: $homepage,
     license: $license, keywords: ., blockers: $blockers }'

$ok && exit 0 || exit 1
