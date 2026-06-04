#!/usr/bin/env bash
# vet-candidate.sh — read-only preflight for a candidate plugin repo. (no writes)
#
# Usage: vet-candidate.sh <repo|owner/repo>
# Fetches the candidate's .claude-plugin/plugin.json over `gh api`, checks the marketplace contract,
# and prints a JSON verdict on stdout:
#   { "ok": bool, "repo": "owner/repo", "blockers": [..], "name": "..", "description": "..",
#     "homepage": "..", "license": "..", "keywords": [..] }
# Exit 0 if ok, 1 if there are blockers, 2 on usage/tooling error. Human notes go to stderr.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

[ "$#" -ge 1 ] || { echo "usage: vet-candidate.sh <repo|owner/repo>" >&2; exit 2; }
command -v gh >/dev/null 2>&1 || { echo "gh (GitHub CLI) is required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

REPO="$(mk_normalize_repo "$1")"
owner="${REPO%%/*}"
name_from_repo="${REPO##*/}"

blockers=()

# Owner must be odere-pro (registry is odere-pro-only).
if [ "$owner" != "$MK_OWNER" ]; then
  blockers+=("owner is \"$owner\"; this registry lists $MK_OWNER repos only")
fi

# Fetch the candidate plugin.json (base64 from the contents API).
pj=""
if pj_b64="$(gh api "repos/$REPO/contents/.claude-plugin/plugin.json" --jq '.content' 2>/dev/null)"; then
  pj="$(printf '%s' "$pj_b64" | base64 -d 2>/dev/null || true)"
fi

if [ -z "$pj" ]; then
  blockers+=("could not read .claude-plugin/plugin.json from $REPO (repo missing, private, or not a plugin)")
elif ! printf '%s' "$pj" | jq empty >/dev/null 2>&1; then
  blockers+=("$REPO .claude-plugin/plugin.json is not valid JSON")
  pj=""
fi

# Candidate must NOT ship its own marketplace.json (would re-create the odere-pro name collision).
if gh api "repos/$REPO/contents/.claude-plugin/marketplace.json" >/dev/null 2>&1; then
  blockers+=("$REPO still ships .claude-plugin/marketplace.json — remove it first (see docs/adding-plugins.md)")
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
  [ -n "$c_name" ] || blockers+=("$REPO plugin.json has no \"name\"")
  [ -n "$c_desc" ] || blockers+=("$REPO plugin.json has no \"description\"")
  [ -n "$c_lic" ]  || blockers+=("$REPO plugin.json has no \"license\"")
fi

# Already listed here?
root="$(mk_repo_root)"
if [ -f "$root/$MK_MANIFEST" ]; then
  if jq -e --arg n "$entry_name" '.plugins[]? | select(.name == $n)' "$root/$MK_MANIFEST" >/dev/null 2>&1; then
    blockers+=("\"$entry_name\" is already listed in the marketplace")
  fi
fi

ok=true
[ "${#blockers[@]}" -eq 0 ] || ok=false

# Emit the JSON verdict.
printf '%s' "$c_keywords_json" | jq \
  --argjson ok "$ok" \
  --arg repo "$REPO" \
  --arg name "$entry_name" \
  --arg description "$c_desc" \
  --arg homepage "$c_home" \
  --arg license "$c_lic" \
  --args \
  '{ ok: $ok, repo: $repo, name: $name, description: $description, homepage: $homepage,
     license: $license, keywords: ., blockers: $ARGS.positional }' \
  ${blockers[@]+"${blockers[@]}"}

$ok && exit 0 || exit 1
