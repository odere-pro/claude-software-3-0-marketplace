#!/usr/bin/env bash
# remove-entry.sh — remove a plugin entry from marketplace.json by name. (writes the manifest)
#
# Usage: remove-entry.sh <name>
# Errors (non-zero) if <name> isn't listed. Removing the last entry leaves plugins: [] (allowed —
# the registry can be empty). Run sync-readme.sh afterwards to refresh the README table.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

[ "$#" -ge 1 ] || { echo "usage: remove-entry.sh <name>" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

name="$1"
root="$(mk_repo_root)"
manifest="$root/$MK_MANIFEST"

if ! jq -e --arg n "$name" '.plugins[]? | select(.name == $n)' "$manifest" >/dev/null 2>&1; then
  echo "\"$name\" is not listed in the marketplace — nothing to remove" >&2
  exit 1
fi

tmp="$(mktemp)"
jq --indent 2 --arg n "$name" 'del(.plugins[] | select(.name == $n))' "$manifest" >"$tmp"
mv "$tmp" "$manifest"
echo "removed \"$name\" from $MK_MANIFEST" >&2
echo "$name"
