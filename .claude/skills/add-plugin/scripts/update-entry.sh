#!/usr/bin/env bash
# update-entry.sh — refresh (or repoint/rename) an existing marketplace entry. (writes the manifest)
#
# Usage: update-entry.sh <name> [--repo R] [--name NEW] [--description "..."] [--keywords a,b,c]
# Refreshes the entry's metadata from its source repo's plugin.json. With --repo it repoints to a
# different odere-pro repo (replace); with --name it renames the entry. Re-vets the target repo (owner,
# valid plugin.json, ships no marketplace.json) before writing. Run sync-readme.sh afterwards.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

[ "$#" -ge 1 ] || { echo "usage: update-entry.sh <name> [--repo R] [--name NEW] [--description ..] [--keywords a,b]" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

name="$1"; shift
o_repo=""; o_name=""; o_desc=""; o_keywords=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)        o_repo="${2:-}"; shift 2 ;;
    --name)        o_name="${2:-}"; shift 2 ;;
    --description) o_desc="${2:-}"; shift 2 ;;
    --keywords)    o_keywords="${2:-}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

here="$(dirname -- "$0")"
root="$(mk_repo_root)"
manifest="$root/$MK_MANIFEST"

# The entry must already be listed.
cur_repo="$(jq -r --arg n "$name" '.plugins[]? | select(.name == $n) | .source.repo' "$manifest")"
if [ -z "$cur_repo" ]; then
  echo "\"$name\" is not listed — use /add-plugin to add it" >&2
  exit 1
fi

target_repo="${o_repo:-$cur_repo}"

# Re-vet the target repo (skip the already-listed check — we're updating an existing entry).
verdict="$(bash "$here/vet-candidate.sh" --skip-listed-check "$target_repo")" || {
  echo "BLOCKED — cannot update \"$name\":" >&2
  printf '%s' "$verdict" | jq -r '.blockers[]? | "  - " + .' >&2 2>/dev/null || true
  exit 1
}

repo="$(printf '%s' "$verdict" | jq -r '.repo')"
desc="$(printf '%s' "$verdict" | jq -r '.description')"
home="$(printf '%s' "$verdict" | jq -r '.homepage')"
lic="$(printf '%s' "$verdict" | jq -r '.license')"
keywords_json="$(printf '%s' "$verdict" | jq -c '.keywords')"

# Apply overrides.
new_name="${o_name:-$name}"
[ -n "$o_desc" ] && desc="$o_desc"
if [ -n "$o_keywords" ]; then
  keywords_json="$(printf '%s' "$o_keywords" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))')"
fi

# A rename must not collide with a different existing entry.
if [ "$new_name" != "$name" ] && jq -e --arg n "$new_name" '.plugins[]? | select(.name == $n)' "$manifest" >/dev/null 2>&1; then
  echo "cannot rename to \"$new_name\" — that name is already listed" >&2
  exit 1
fi

tmp="$(mktemp)"
jq --indent 2 \
  --arg old "$name" --arg name "$new_name" --arg repo "$repo" --arg description "$desc" \
  --arg homepage "$home" --arg license "$lic" --argjson keywords "$keywords_json" \
  '.plugins = (.plugins | map(
     if .name == $old then
       { name: $name,
         source: { source: "github", repo: $repo },
         description: $description,
         homepage: $homepage,
         license: $license,
         keywords: $keywords }
     else . end))' "$manifest" >"$tmp"

mv "$tmp" "$manifest"
echo "updated \"$name\" -> \"$new_name\" ($repo) in $MK_MANIFEST" >&2
echo "$new_name"
