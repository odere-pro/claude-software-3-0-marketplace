#!/usr/bin/env bash
# G11 — CHANGELOG tracks the manifest plugin-set. (CRITICAL)
#
# Distinct from G9 (which byte-checks the generated README table): the changelog is accreting,
# human-curated prose that cannot be byte-reproduced, so this gate checks a weaker but robust
# invariant — **every plugin currently listed in marketplace.json is named in CHANGELOG.md** (roadmap
# P8). The add/update/remove scripts emit a deterministic bullet via mk_changelog_bullet, so a listing
# whose changelog line was dropped (manifest plugin-set changed but the Unreleased section omits it)
# makes this gate FAIL. Removal can never break it (a removed plugin simply leaves the listed set).
#
# At N=0 (empty registry) the listed set is empty, so the gate passes vacuously. Offline,
# dependency-light (jq + grep). Never calls the network. SKIPs only if jq is absent.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

command -v jq >/dev/null 2>&1 || { echo "G11 changelog-in-sync: SKIP (jq not installed)"; exit 0; }

CL="CHANGELOG.md"
[ -f "$CL" ] || { echo "  FAIL: $CL not found"; echo "G11 changelog-in-sync: FAIL"; exit 1; }
[ -f "$GATES_MARKETPLACE" ] || { echo "  FAIL: $GATES_MARKETPLACE not found"; echo "G11 changelog-in-sync: FAIL"; exit 1; }

# The changelog must carry the standard Unreleased section the scripts insert under.
grep -qE '^##[[:space:]]+\[Unreleased\]' "$CL" \
  || { echo "  FAIL: $CL has no \"## [Unreleased]\" section"; echo "G11 changelog-in-sync: FAIL"; exit 1; }

fail=0
note() { echo "  FAIL: $1"; fail=1; }

# Every currently-listed plugin name must appear somewhere in the changelog.
checked=0
while IFS= read -r pname; do
  [ -n "$pname" ] || continue
  checked=$((checked + 1))
  # Match the name as a backtick-quoted token (how the scripts write it), falling back to a plain
  # substring so a hand-written line in another phrasing still counts.
  if ! grep -qF "\`$pname\`" "$CL" && ! grep -qF "$pname" "$CL"; then
    note "plugin \"$pname\" is listed in $GATES_MARKETPLACE but not named in $CL (run the add/update script, or add an Unreleased bullet)"
  fi
done < <(jq -r '.plugins[]?.name // empty' "$GATES_MARKETPLACE")

if [ "$fail" -ne 0 ]; then
  echo "G11 changelog-in-sync: FAIL"
  exit 1
fi
echo "G11 changelog-in-sync: ok ($checked listed plugin(s) named in the changelog)"
