#!/usr/bin/env bash
# add-entry.sh — vet a candidate, then insert its entry into marketplace.json. (writes the manifest)
#
# Usage: add-entry.sh <repo|owner/repo> [--name X] [--description "..."] [--keywords a,b,c]
# Runs vet-candidate.sh first and aborts (non-zero) on any blocker. On success, appends a well-formed
# entry to .claude-plugin/marketplace.json via `jq --indent 2`. Idempotent: refuses a duplicate name.
# Overrides (--name/--description/--keywords) let the caller substitute curated metadata.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"

[ "$#" -ge 1 ] || { echo "usage: add-entry.sh <repo|owner/repo> [--name X] [--description ..] [--keywords a,b]" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

REPO_ARG="$1"; shift
o_name=""; o_desc=""; o_keywords=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)        o_name="${2:-}"; shift 2 ;;
    --description) o_desc="${2:-}"; shift 2 ;;
    --keywords)    o_keywords="${2:-}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

here="$(dirname -- "$0")"
root="$(mk_repo_root)"
manifest="$root/$MK_MANIFEST"

# Vet first. Capture the verdict; abort with its blockers if not ok.
verdict="$(bash "$here/vet-candidate.sh" "$REPO_ARG")" || {
  echo "BLOCKED — cannot add $REPO_ARG:" >&2
  printf '%s' "$verdict" | jq -r '.blockers[]? | "  - " + .message + (if .fix then " (fix: " + .fix + ")" else "" end)' >&2
  exit 1
}

repo="$(printf '%s' "$verdict" | jq -r '.repo')"
name="$(printf '%s' "$verdict" | jq -r '.name')"
desc="$(printf '%s' "$verdict" | jq -r '.description')"
home="$(printf '%s' "$verdict" | jq -r '.homepage')"
lic="$(printf '%s' "$verdict" | jq -r '.license')"
keywords_json="$(printf '%s' "$verdict" | jq -c '.keywords')"

# Apply overrides.
[ -n "$o_name" ] && name="$o_name"
[ -n "$o_desc" ] && desc="$o_desc"
if [ -n "$o_keywords" ]; then
  keywords_json="$(printf '%s' "$o_keywords" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$";"")) | map(select(length>0))')"
fi

# Build the entry and append it (idempotent on name).
tmp="$(mktemp)"
jq --indent 2 \
  --arg name "$name" --arg repo "$repo" --arg description "$desc" \
  --arg homepage "$home" --arg license "$lic" --argjson keywords "$keywords_json" \
  '
  if (.plugins // []) | any(.name == $name) then
    error("\"" + $name + "\" is already listed")
  else
    .plugins += [ {
      name: $name,
      source: { source: "github", repo: $repo },
      description: $description,
      homepage: $homepage,
      license: $license,
      keywords: $keywords
    } ]
  end
  ' "$manifest" >"$tmp"

mv "$tmp" "$manifest"

# Deterministic changelog bullet (roadmap P8): record the listing under [Unreleased] → Added so the
# changelog tracks the manifest without a hand-written step. 11-changelog-in-sync.sh gates this.
mk_changelog_bullet "Added" "List \`$name\` (\`$repo\`)."

echo "added \"$name\" ($repo) to $MK_MANIFEST (changelog updated)" >&2
echo "$name"
