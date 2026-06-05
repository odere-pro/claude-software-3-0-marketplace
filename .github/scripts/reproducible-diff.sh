#!/usr/bin/env bash
# reproducible-diff.sh — PR-scoped "green ⇒ machine-generated" check for the manifest. (roadmap P15)
#
# This is NOT auto-merge (D7/D18): merge governance stays with CODEOWNERS. It is a normal CI check that
# makes "the structural shape of marketplace.json could only have been produced by the add/update
# scripts" mechanically verifiable. It runs on a pull_request via .github/workflows/ci.yml and is kept
# OUT of tests/gates/ (so it never enters the always-on push suite run-all.sh, and so it does not trip
# 00-harness-integrity.sh's gate-naming rule).
#
# What it verifies (network-free, deterministic):
#   1. canonical formatting — re-serializing the manifest with `jq --indent 2 '.'` (the exact formatter
#      both the scripts and .claude/hooks/json-format.sh use) reproduces the on-disk bytes. A hand-edit
#      that left non-canonical whitespace/key-order fails here.
#   2. structural reproduction — for every entry, the STRUCTURAL fields the scripts derive
#      deterministically match the machine-generated form:
#        - source.source == "github"
#        - source.repo   == odere-pro/<repo>   (the only owner; add-entry.sh normalizes to this)
#        - homepage, when present, == https://github.com/<source.repo> (vet-candidate.sh's default)
#        - no forbidden keys (version / sha / commit) on the entry or its source
#      The LLM-CURATED fields `description` and `keywords` are EXCLUDED — they are authored by the
#      plugin-onboarder agent, not reproducible byte-for-byte, so the check never touches them.
#
# At N=0 (empty registry) the entry loop is empty; only the canonical-formatting check runs, and it
# passes for the committed manifest. Offline. SKIPs only if jq is absent.
set -euo pipefail

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)"
cd "$ROOT"
MANIFEST=".claude-plugin/marketplace.json"
OWNER="odere-pro"

command -v jq >/dev/null 2>&1 || { echo "reproducible-diff: SKIP (jq not installed)"; exit 0; }
[ -f "$MANIFEST" ] || { echo "  FAIL: $MANIFEST not found"; echo "reproducible-diff: FAIL"; exit 1; }

fail=0
note() { echo "  FAIL: $1"; fail=1; }

# ── 1. canonical formatting (accounts for json-format.sh: jq --indent 2 '.') ──────────────────────
canon="$(mktemp)"
if ! jq --indent 2 '.' "$MANIFEST" >"$canon" 2>/dev/null; then
  note "$MANIFEST is not valid JSON"
  rm -f "$canon"; echo "reproducible-diff: FAIL"; exit 1
fi
if ! cmp -s "$canon" "$MANIFEST"; then
  note "$MANIFEST is not in canonical \`jq --indent 2\` form — re-run the scripts (or the json-format hook) so the bytes are machine-generated"
fi
rm -f "$canon"

# ── 2. structural reproduction per entry (excludes description/keywords) ──────────────────────────
n="$(jq '.plugins | length' "$MANIFEST")"
i=0
while [ "$i" -lt "$n" ]; do
  src_source="$(jq -r ".plugins[$i].source.source // empty" "$MANIFEST")"
  repo="$(jq -r ".plugins[$i].source.repo // empty" "$MANIFEST")"
  name="$(jq -r ".plugins[$i].name // empty" "$MANIFEST")"
  home="$(jq -r ".plugins[$i].homepage // empty" "$MANIFEST")"
  forbidden="$(jq -r ".plugins[$i] | [paths(scalars)] | map(.[-1]) | map(select(. == \"version\" or . == \"sha\" or . == \"commit\")) | join(\",\")" "$MANIFEST")"

  [ "$src_source" = "github" ] \
    || note "entry \"$name\": source.source is \"$src_source\", scripts emit \"github\""
  case "$repo" in
    "$OWNER"/?*) ;;
    *) note "entry \"$name\": source.repo \"$repo\" is not $OWNER/<repo> (the form add-entry.sh normalizes to)" ;;
  esac
  if [ -n "$home" ] && [ "$home" != "https://github.com/$repo" ]; then
    note "entry \"$name\": homepage \"$home\" is not the script default https://github.com/$repo (if intentionally curated, this field is allowed to differ — adjust this check)"
  fi
  [ -z "$forbidden" ] \
    || note "entry \"$name\": carries forbidden structural key(s): $forbidden (the scripts never emit version/sha/commit)"

  i=$((i + 1))
done

if [ "$fail" -ne 0 ]; then
  echo "reproducible-diff: FAIL — the manifest's structural fields are not in machine-generated form."
  echo "  This check is advisory of provenance, not a merge gate; CODEOWNERS still governs merge (D7)."
  exit 1
fi
echo "reproducible-diff: ok ($n entry/entries; structural fields reproduce, description/keywords excluded)"
