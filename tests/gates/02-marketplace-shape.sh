#!/usr/bin/env bash
# G2 — the marketplace manifest has the required registry shape. (CRITICAL)
#
# Encodes the odere-pro aggregator invariants:
#   - top-level name is exactly "odere-pro" (the marketplace name of record; keying it by name is
#     what makes the name-collision class of bug possible, so we pin it here),
#   - $schema is present and exactly the pinned schemastore URL (pure string-equality, no network),
#   - owner.name + owner.email present,
#   - every plugin entry is a `github` source whose repo is owned by odere-pro (the repo basename may
#     differ from the entry name — e.g. plugin-cookbook lives in claude-plugin-cookbook),
#   - entry names are unique,
#   - every entry carries name + description + license,
#   - every entry's `license` is one of the SPDX allowlist identifiers (roadmap P10 / D14),
#   - NO entry sets `version` (each plugin's own plugin.json is the version of record),
#   - NO entry or source sets `sha`/`commit` (installs track each plugin repo's default branch).
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

# SPDX license allowlist (roadmap P10 / D14): permissive + file-level weak copyleft only.
# Shared by-value with .claude/skills/add-plugin/scripts/vet-candidate.sh (the add-time blocker);
# the two sites are kept byte-identical by the parity check in 00-harness-integrity.sh (D1: no
# cross-tree `source`). Expanding this set is an explicit "open an issue" change (docs/adding-plugins.md).
SPDX_ALLOWLIST="MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0"

MK="$GATES_MARKETPLACE"
[ -f "$MK" ] || { echo "  FAIL: missing $MK"; echo "G2 marketplace-shape: FAIL"; exit 1; }
jq empty "$MK" >/dev/null 2>&1 || { echo "  FAIL: $MK is not valid JSON"; echo "G2 marketplace-shape: FAIL"; exit 1; }

problems="$(jq -r --argjson allow "$(printf '%s' "$SPDX_ALLOWLIST" | jq -R 'split(" ")')" '
  ( [ (if .name == "odere-pro" then empty else "top-level name must be \"odere-pro\" (got \(.name | tojson))" end),
      (if (."$schema" // "") == "https://json.schemastore.org/claude-code-marketplace.json"
         then empty
         else "$schema must be exactly \"https://json.schemastore.org/claude-code-marketplace.json\" (got \((."$schema" // "") | tojson))" end),
      (if (.owner.name // "") != "" then empty else "owner.name missing" end),
      (if (.owner.email // "") != "" then empty else "owner.email missing" end),
      (if (.plugins | type) == "array" then empty else "plugins must be an array (it may be empty — the registry can start with no plugins)" end),
      (if ((.description // "") | length) > 0 then empty else "top-level description is empty (the marketplace needs a one-line description)" end),
      ( ([.plugins[]?.name] | group_by(.) | map(select(length > 1)[0]) | unique[]?) as $dup
        | "duplicate plugin name \"\($dup)\" (entry names must be unique)" )
    ]
  + [ (.plugins // []) | to_entries[] | .key as $i | .value as $p |
        ( (if (($p.name // "") != "") then empty else "plugins[\($i)].name missing" end),
          (if ($p.source.source // "") == "github" then empty else "plugins[\($i)].source.source must be \"github\"" end),
          (if (($p.source.repo // "") != "") then empty else "plugins[\($i)].source.repo missing" end),
          (if (($p.source.repo // "") | test("^odere-pro/[A-Za-z0-9._-]+$")) then empty else "plugins[\($i)].source.repo (\($p.source.repo // "")) must be an odere-pro/<repo> github repo" end),
          (if (($p.description // "") != "") then empty else "plugins[\($i)].description missing" end),
          (if (($p.description // "") | length) >= 20 then empty else "plugins[\($i)].description is too short (>= 20 chars; a listing needs a real one-liner)" end),
          (if (($p.description // "") | ascii_downcase) != (($p.name // "") | ascii_downcase) then empty else "plugins[\($i)].description must not just repeat the name" end),
          (if (($p.keywords // []) | length) > 0 then empty else "plugins[\($i)].keywords is empty (list at least one keyword for discoverability)" end),
          (if (($p.homepage // "") | test("^https://")) then empty else "plugins[\($i)].homepage must start with https:// (got \(($p.homepage // "") | tojson))" end),
          (if (($p.license // "") != "") then empty else "plugins[\($i)].license missing" end),
          (if (($p.license // "") == "") or ($allow | index($p.license)) then empty else "plugins[\($i)].license \(($p.license) | tojson) is not in the SPDX allowlist (MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0); open an issue to expand it, see docs/adding-plugins.md" end),
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
