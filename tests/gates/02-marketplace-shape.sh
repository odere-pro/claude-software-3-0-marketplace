#!/usr/bin/env bash
# G2 — the marketplace manifest has the required registry shape. (CRITICAL)
#
# Encodes the odere-pro aggregator invariants:
#   - top-level name is exactly "odere-pro" (the marketplace name of record; keying it by name is
#     what makes the name-collision class of bug possible, so we pin it here),
#   - owner.name + owner.email present,
#   - every plugin entry is a `github` source whose repo is owned by odere-pro (the repo basename may
#     differ from the entry name — e.g. plugin-cookbook lives in claude-plugin-cookbook),
#   - entry names are unique,
#   - every entry carries name + description + license,
#   - NO entry sets `version` (each plugin's own plugin.json is the version of record),
#   - NO entry or source sets `sha`/`commit` (installs track each plugin repo's default branch).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

MK="$GATES_MARKETPLACE"
[ -f "$MK" ] || { echo "  FAIL: missing $MK"; echo "G2 marketplace-shape: FAIL"; exit 1; }
jq empty "$MK" >/dev/null 2>&1 || { echo "  FAIL: $MK is not valid JSON"; echo "G2 marketplace-shape: FAIL"; exit 1; }

problems="$(jq -r '
  ( [ (if .name == "odere-pro" then empty else "top-level name must be \"odere-pro\" (got \(.name | tojson))" end),
      (if (.owner.name // "") != "" then empty else "owner.name missing" end),
      (if (.owner.email // "") != "" then empty else "owner.email missing" end),
      (if (.plugins | type) == "array" then empty else "plugins must be an array (it may be empty — the registry can start with no plugins)" end),
      ( ([.plugins[]?.name] | group_by(.) | map(select(length > 1)[0]) | unique[]?) as $dup
        | "duplicate plugin name \"\($dup)\" (entry names must be unique)" )
    ]
  + [ (.plugins // []) | to_entries[] | .key as $i | .value as $p |
        ( (if (($p.name // "") != "") then empty else "plugins[\($i)].name missing" end),
          (if ($p.source.source // "") == "github" then empty else "plugins[\($i)].source.source must be \"github\"" end),
          (if (($p.source.repo // "") != "") then empty else "plugins[\($i)].source.repo missing" end),
          (if (($p.source.repo // "") | test("^odere-pro/[A-Za-z0-9._-]+$")) then empty else "plugins[\($i)].source.repo (\($p.source.repo // "")) must be an odere-pro/<repo> github repo" end),
          (if (($p.description // "") != "") then empty else "plugins[\($i)].description missing" end),
          (if (($p.license // "") != "") then empty else "plugins[\($i)].license missing" end),
          (if ($p | has("version")) then "plugins[\($i)] must NOT set version (plugin.json is the version of record)" else empty end),
          (if ($p | has("sha")) then "plugins[\($i)] must NOT set sha (installs track the default branch)" else empty end),
          (if ($p | has("commit")) then "plugins[\($i)] must NOT set commit (installs track the default branch)" else empty end),
          (if ($p.source | has("sha")) then "plugins[\($i)].source must NOT set sha" else empty end),
          (if ($p.source | has("commit")) then "plugins[\($i)].source must NOT set commit" else empty end)
        )
    ]
  ) | .[]
' "$MK")"

if [ -n "$problems" ]; then
  echo "  FAIL: marketplace.json shape violations:"
  printf '%s\n' "$problems" | sed 's/^/    - /'
  echo "G2 marketplace-shape: FAIL"
  exit 1
fi
echo "G2 marketplace-shape: ok"
