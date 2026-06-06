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
#            NO_COMPONENTS REPO_ARCHIVED REPO_PRIVATE LICENSE_FILE_MISMATCH
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

# Repo-posture probe: fetch repo metadata (1 gh api call) to check archived/private status and the
# GitHub-detected license SPDX id. Covers REPO_ARCHIVED + REPO_PRIVATE + LICENSE_FILE_MISMATCH.
# Runs for odere-pro repos only (if OWNER_NOT_ALLOWED already fired, we skip to avoid noise).
repo_meta=""
repo_gh_spdx=""
if [ "$owner" = "$MK_OWNER" ]; then
  if repo_meta="$(gh api "repos/$REPO" 2>/dev/null)"; then
    if [ "$(printf '%s' "$repo_meta" | jq -r '.archived // false')" = "true" ]; then
      add_blocker "REPO_ARCHIVED" \
        "$REPO is archived — listing a read-only archived repo is not permitted" \
        "un-archive the repo on GitHub (Settings → Danger Zone → Unarchive), then re-run the vet"
    fi
    if [ "$(printf '%s' "$repo_meta" | jq -r '.private // false')" = "true" ]; then
      add_blocker "REPO_PRIVATE" \
        "$REPO is private — the registry only lists public repos" \
        "set the repo visibility to Public on GitHub (Settings → Danger Zone → Change visibility), then re-run the vet"
    fi
    repo_gh_spdx="$(printf '%s' "$repo_meta" | jq -r '.license.spdx_id // ""')"
  fi
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

# Component probe (roadmap D-component-check): a plugin must ship at least one component directory
# (commands/agents/skills/hooks). A repo with a valid plugin.json but no components is an empty shell.
# CONSTANT-COST (D12): we probe each dir name via the `contents/<dir>` API and STOP at the first hit —
# at most 4 `gh api` calls, never a recursive tree walk. Rides the existing add-time gh-api budget.
# Only run when plugin.json is readable (if it isn't, PLUGIN_JSON_UNREADABLE already covers it).
if [ -n "$pj" ]; then
  has_component=false
  for dir in commands agents skills hooks; do
    if gh api "repos/$REPO/contents/$dir" >/dev/null 2>&1; then
      has_component=true
      break
    fi
  done
  if ! $has_component; then
    add_blocker "NO_COMPONENTS" \
      "$REPO ships no plugin component directory (commands/, agents/, skills/, or hooks/) — a plugin with no components is an empty shell" \
      "add at least one component directory (commands/, agents/, skills/, or hooks/) to the candidate repo, then re-run the vet"
  fi
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
  else
    # LICENSE_FILE_MISMATCH (positive path): GitHub has positively identified a *different* SPDX id.
    if [ -n "$repo_gh_spdx" ] && [ "$repo_gh_spdx" != "NOASSERTION" ] && [ "$repo_gh_spdx" != "$c_lic" ]; then
      add_blocker "LICENSE_FILE_MISMATCH" \
        "$REPO plugin.json declares \"$c_lic\" but GitHub detects a \"$repo_gh_spdx\" LICENSE file — the file content and the declared SPDX id must match" \
        "update the LICENSE file in $REPO to match SPDX id \"$c_lic\", or change plugin.json \"license\" to \"$repo_gh_spdx\" (if it is in the allowlist)"

    # LICENSE_FILE_MISMATCH (NOASSERTION path): GitHub returned NOASSERTION (could not parse the
    # LICENSE file format). We resolve this by fetching the raw LICENSE text and verifying it
    # contains the canonical per-SPDX-id marker for the declared license.
    # Trigger: NOASSERTION + declared id is in SPDX_ALLOWLIST (checked by the enclosing `elif`).
    # Budget: one extra gh api call on the NOASSERTION+allowlisted branch only — constant-cost,
    # add-time only, never inside run-all.sh (D3/D4/D12).
    elif [ "$repo_gh_spdx" = "NOASSERTION" ]; then
      # Fetch the repo's LICENSE file content via the /license endpoint (base64 in .content).
      lic_txt=""
      if lic_txt_b64="$(gh api "repos/$REPO/license" --jq '.content' 2>/dev/null)"; then
        lic_txt="$(printf '%s' "$lic_txt_b64" | base64 -d 2>/dev/null || true)"
      fi

      if [ -z "$lic_txt" ]; then
        # Fetch failed (network/data gap). Emit a human note only; do NOT block.
        # Mirrors the D3 SKIP-not-FAIL philosophy: a fetch failure is not drift.
        printf '[vet] could not fetch LICENSE for content verification; NOASSERTION not resolvable for %s\n' "$REPO" >&2
      else
        # Canonical text-marker lookup (vet-local; no shared file needed — this is the only call site).
        # Decision rule: if the text does NOT contain the declared id's marker → emit LICENSE_FILE_MISMATCH.
        # If ambiguous (e.g. BSD-2 vs BSD-3 stem present but distinguishing clause absent) → NO block
        # (favor false-negative over false-positive).
        #
        # Marker table (one unambiguous canonical phrase per SPDX id):
        #   MIT        — "Permission is hereby granted, free of charge, to any person obtaining a copy"
        #   Apache-2.0 — "Apache License" AND "Version 2.0"
        #   BSD-2-Clause / BSD-3-Clause — "Redistribution and use in source and binary forms"
        #                 (+ BSD-3 additionally: "Neither the name of")
        #   ISC        — "Permission to use, copy, modify, and/or distribute this software"
        #   0BSD       — same ISC stem + absence of the BSD redistribution clause; ambiguous → NO block
        #   MPL-2.0    — "Mozilla Public License Version 2.0"
        lic_txt_lower="$(printf '%s' "$lic_txt" | tr '[:upper:]' '[:lower:]')"
        marker_ok=true
        case "$c_lic" in
          MIT)
            printf '%s' "$lic_txt_lower" | grep -qF "permission is hereby granted, free of charge, to any person obtaining a copy" \
              || marker_ok=false
            ;;
          Apache-2.0)
            printf '%s' "$lic_txt_lower" | grep -qF "apache license" && \
            printf '%s' "$lic_txt_lower" | grep -qF "version 2.0" \
              || marker_ok=false
            ;;
          BSD-2-Clause)
            if ! printf '%s' "$lic_txt_lower" | grep -qF "redistribution and use in source and binary forms"; then
              marker_ok=false
            fi
            # If BSD-3 distinguishing clause is present, treat as ambiguous (wrong variant) — NO block.
            # We can only block if clearly NOT BSD-2 text at all.
            ;;
          BSD-3-Clause)
            if ! printf '%s' "$lic_txt_lower" | grep -qF "redistribution and use in source and binary forms"; then
              marker_ok=false
            elif ! printf '%s' "$lic_txt_lower" | grep -qiF "neither the name of"; then
              # BSD-3 marker absent but BSD-2 stem present → ambiguous, NO block.
              marker_ok=true
            fi
            ;;
          ISC)
            printf '%s' "$lic_txt_lower" | grep -qF "permission to use, copy, modify, and/or distribute this software" \
              || marker_ok=false
            ;;
          0BSD)
            # 0BSD strips the redistribution clause; its marker is the ISC stem.
            # If the redistribution clause IS present, it is likely BSD-2, but 0BSD is ambiguous → NO block.
            marker_ok=true
            ;;
          MPL-2.0)
            printf '%s' "$lic_txt_lower" | grep -qF "mozilla public license version 2.0" \
              || marker_ok=false
            ;;
          *)
            # Unknown id in allowlist (should not occur): NO block (safe default).
            marker_ok=true
            ;;
        esac

        if ! $marker_ok; then
          add_blocker "LICENSE_FILE_MISMATCH" \
            "GitHub could not classify $REPO's LICENSE (NOASSERTION); the file text does not contain the canonical marker for the declared SPDX id \"$c_lic\"" \
            "make the LICENSE file the verbatim canonical text for \"$c_lic\", or change plugin.json \"license\" to the id matching the actual file"
        fi
      fi
    fi
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
