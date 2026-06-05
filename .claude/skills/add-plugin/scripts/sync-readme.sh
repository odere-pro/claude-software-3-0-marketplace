#!/usr/bin/env bash
# sync-readme.sh — regenerate the README Plugins table from marketplace.json. (writes README.md)
#
# Replaces the rows between the markers:
#   <!-- BEGIN PLUGINS -->
#   ...generated table...
#   <!-- END PLUGINS -->
# with one row per manifest entry. Deterministic — this is exactly what 09-readme-in-sync.sh checks.
# With --check it writes nothing and exits 1 if README is out of sync (used by the gate).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

check=false
[ "${1:-}" = "--check" ] && check=true

root="$(mk_repo_root)"
manifest="$root/$MK_MANIFEST"
readme="$root/README.md"
begin="<!-- BEGIN PLUGINS -->"
end="<!-- END PLUGINS -->"

grep -qF "$begin" "$readme" && grep -qF "$end" "$readme" || {
  echo "README.md is missing the $begin / $end markers" >&2; exit 2;
}

# Build the generated block (markers + header + one row per entry) into a temp file. We splice from a
# file rather than an awk -v variable so BSD awk (macOS) doesn't choke on embedded newlines.
blockfile="$(mktemp)"
{
  printf '%s\n' "$begin"
  if [ "$(jq '.plugins | length' "$manifest")" -eq 0 ]; then
    printf '_No plugins listed yet — add one with `/add-plugin <repo>` (see [docs/adding-plugins.md](docs/adding-plugins.md))._\n'
  else
    printf '| Plugin | Repo | What it does | License | Keywords |\n'
    printf '| --- | --- | --- | --- | --- |\n'
    # License and Keywords columns are rendered straight from the manifest (roadmap P13h): License is
    # the entry `.license`; Keywords joins `.keywords` with ", ". Both stay in sync with the manifest
    # because this generator is the single source for the table (G9 checks byte-equality).
    jq -r '
      .plugins[]
      | "| `\(.name)` | [\(.source.repo)](https://github.com/\(.source.repo)) | "
        + "\(.description | gsub("\n"; " ")) | \(.license // "—") | "
        + "\((.keywords // []) | map("`" + . + "`") | join(", ") | if . == "" then "—" else . end) |"
    ' "$manifest"
  fi
  printf '%s\n' "$end"
} >"$blockfile"

# Splice: replace everything from the BEGIN marker line through the END marker line with the block.
tmp="$(mktemp)"
awk -v begin="$begin" -v end="$end" -v bf="$blockfile" '
  index($0, begin) { while ((getline line < bf) > 0) print line; close(bf); skip=1; next }
  index($0, end)   { skip=0; next }
  skip != 1        { print }
' "$readme" >"$tmp"
rm -f "$blockfile"

if $check; then
  if cmp -s "$tmp" "$readme"; then
    rm -f "$tmp"; echo "README plugins table in sync"; exit 0
  else
    rm -f "$tmp"; echo "README plugins table is OUT OF SYNC — run sync-readme.sh" >&2; exit 1
  fi
fi

if cmp -s "$tmp" "$readme"; then rm -f "$tmp"; echo "README already in sync" >&2; else mv "$tmp" "$readme"; echo "README plugins table regenerated" >&2; fi
