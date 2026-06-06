#!/usr/bin/env bash
# G10 — vet-candidate verdict-shape gate. (CRITICAL)
#
# vet-candidate.sh emits a JSON verdict whose `blockers[]` are coded objects
# `{ code, message, fix }` (roadmap P7). This gate pins that contract so the verdict can never
# silently regress to raw-string blockers (which would break add-entry.sh / update-entry.sh, whose
# rollback messaging renders `.code`/`.message`/`.fix`).
#
# Dependency-light and OFFLINE (tests/gates/CLAUDE.md): it never calls the real network. It checks:
#   1. the usage-error path — vet-candidate.sh with no argument exits 2 with a usage message, before
#      any `gh api` call (so the gate exercises the script without touching the network);
#   2. the shape contract — a validator jq filter (the invariant vet-candidate.sh produces) ACCEPTS a
#      well-formed verdict and REJECTS malformed ones (a blocker missing `code` or `fix`, or a `code`
#      outside the VET_CODES enum). If the validator ever stops rejecting malformed input, the gate
#      FAILs — that is the regression guard;
#   3. the NOASSERTION LICENSE text-marker path — four stub-based controls (PATH-injected fake `gh`)
#      verify the NOASSERTION branch: mismatch fires, honest match passes, fetch-fail is graceful.
#      The stub is a local script; no network call is made (D3/D4).
#
# SKIPs (exit 0) only if jq is absent (convention). It does not need real `gh`.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

command -v jq >/dev/null 2>&1 || { echo "G10 vet-verdict-schema: SKIP (jq not installed)"; exit 0; }

VET="tests/../.claude/skills/add-plugin/scripts/vet-candidate.sh"
[ -f "$VET" ] || { echo "  FAIL: $VET not found"; echo "G10 vet-verdict-schema: FAIL"; exit 1; }

fail=0
note() { echo "  FAIL: $1"; fail=1; }

# The VET_CODES enum, kept in sync with vet-candidate.sh's documented enum (lines 39-41 there).
# A blocker `code` outside this set is a contract violation.
VET_CODES='["OWNER_NOT_ALLOWED","PLUGIN_JSON_UNREADABLE","PLUGIN_JSON_INVALID","SHIPS_MARKETPLACE_JSON","MISSING_NAME","MISSING_DESCRIPTION","MISSING_LICENSE","LICENSE_NOT_ALLOWED","ALREADY_LISTED","NO_COMPONENTS","REPO_ARCHIVED","REPO_PRIVATE","LICENSE_FILE_MISMATCH"]'

# The shape validator: a verdict is well-formed iff `blockers` is an array and EVERY blocker is an
# object carrying non-empty string `code` (in the enum), `message`, and `fix`. Emits "OK" or the
# first problem. This is the contract vet-candidate.sh must keep producing.
validate() { # stdin = a verdict JSON; exit 0 if valid, else exit 1 + prints the first problem
  local result
  # Print "OK" or the first problem string. A jq parse error (non-JSON) is itself a rejection.
  result="$(jq -r --argjson codes "$VET_CODES" '
    if (.blockers | type) != "array" then "blockers is not an array"
    else
      ( [ .blockers[]
          | if (type) != "object" then "a blocker is not an object"
            elif ((.code // "") | type) != "string" or ((.code // "") == "") then "a blocker is missing a string code"
            elif (.code as $c | $codes | index($c) | not) then "a blocker code is not in the VET_CODES enum"
            elif ((.message // "") | type) != "string" or ((.message // "") == "") then "a blocker is missing a string message"
            elif ((.fix // "") | type) != "string" or ((.fix // "") == "") then "a blocker is missing a string fix"
            else empty end ]
        | if length > 0 then .[0] else "OK" end )
    end
  ' 2>/dev/null)" || { echo "not valid JSON"; return 1; }
  if [ "$result" = "OK" ]; then return 0; fi
  echo "$result"; return 1
}

# ── 1. usage-error path: no arg → exit 2, no network ────────────────────────────────────────────
set +e
usage_out="$(bash "$VET" 2>&1)"
usage_rc=$?
set -e
[ "$usage_rc" -eq 2 ] || note "vet-candidate.sh with no argument should exit 2 (got $usage_rc)"
printf '%s' "$usage_out" | grep -qi 'usage' || note "vet-candidate.sh usage-error path did not print a usage message"

# ── 2. shape contract: validator ACCEPTS well-formed, REJECTS malformed ─────────────────────────
good='{"ok":false,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[{"code":"MISSING_NAME","message":"m","fix":"f"},{"code":"LICENSE_NOT_ALLOWED","message":"m2","fix":"f2"}]}'
ok_empty='{"ok":true,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[]}'
# Positive fixtures for the repo-posture codes (Phase-1 additions): each must be accepted.
good_archived='{"ok":false,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[{"code":"REPO_ARCHIVED","message":"m","fix":"f"}]}'
good_private='{"ok":false,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[{"code":"REPO_PRIVATE","message":"m","fix":"f"}]}'
good_lfm='{"ok":false,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[{"code":"LICENSE_FILE_MISMATCH","message":"m","fix":"f"}]}'
good_nc='{"ok":false,"repo":"odere-pro/x","name":"x","description":"d","homepage":"https://h","license":"MIT","keywords":["k"],"blockers":[{"code":"NO_COMPONENTS","message":"m","fix":"f"}]}'
bad_no_code='{"blockers":[{"message":"m","fix":"f"}]}'
bad_no_fix='{"blockers":[{"code":"MISSING_NAME","message":"m"}]}'
bad_bad_code='{"blockers":[{"code":"NOT_A_REAL_CODE","message":"m","fix":"f"}]}'
bad_string='{"blockers":["a raw string blocker"]}'

printf '%s' "$good"         | validate >/dev/null 2>&1 || note "validator rejected a well-formed coded verdict"
printf '%s' "$ok_empty"     | validate >/dev/null 2>&1 || note "validator rejected a valid empty-blockers verdict"
# Repo-posture codes (Phase-1): each must be accepted by the validator.
printf '%s' "$good_archived" | validate >/dev/null 2>&1 || note "validator rejected a REPO_ARCHIVED blocker"
printf '%s' "$good_private"  | validate >/dev/null 2>&1 || note "validator rejected a REPO_PRIVATE blocker"
printf '%s' "$good_lfm"      | validate >/dev/null 2>&1 || note "validator rejected a LICENSE_FILE_MISMATCH blocker"
printf '%s' "$good_nc"       | validate >/dev/null 2>&1 || note "validator rejected a NO_COMPONENTS blocker"
# Each malformed verdict MUST be rejected; if the validator accepts it, the contract guard is broken.
for bad in "bad_no_code" "bad_no_fix" "bad_bad_code" "bad_string"; do
  if printf '%s' "${!bad}" | validate >/dev/null 2>&1; then
    note "validator ACCEPTED a malformed verdict ($bad) — the verdict-shape guard is not enforcing {code,message,fix}"
  fi
done

# ── 3. NOASSERTION LICENSE text-marker stub tests ───────────────────────────────────────────────
# These tests exercise the new NOASSERTION branch in vet-candidate.sh (see lines added under the
# existing `else` block). We stub `gh` via PATH injection so no network call is made (D3/D4).
# Four controls:
#   A. NEGATIVE: NOASSERTION + declared MIT + LICENSE body is GPL-3.0 → must block (LICENSE_FILE_MISMATCH).
#   B. POSITIVE: NOASSERTION + declared MIT + LICENSE body contains MIT marker → must NOT block.
#   C. REAL-CASE: NOASSERTION + declared Apache-2.0 + LICENSE body is Apache-2.0 → must NOT block.
#      (This is the claude-wiki-pages-plugin scenario that prompted this fix.)
#   D. FETCH-FAIL: `repos/<repo>/license` returns empty → must NOT block (graceful skip).
#
# Each control sets up a temp dir with a fake `gh` script that echoes the right stub payloads,
# then runs vet-candidate.sh and inspects the verdict for LICENSE_FILE_MISMATCH.

_mit_marker_b64() {
  printf 'MIT License\n\nPermission is hereby granted, free of charge, to any person obtaining a copy\nof this software...\n' | base64
}
_apache_marker_b64() {
  printf 'Apache License\nVersion 2.0, January 2004\n\nAPACHE LICENSE\nVERSION 2.0\n' | base64
}
_gpl3_body_b64() {
  printf 'GNU GENERAL PUBLIC LICENSE Version 3, 29 June 2007\n\nCopyright (C) 2007 Free Software Foundation, Inc.\n' | base64
}

# Helper: build a stub `gh` binary in a temp dir.
# Usage: _make_stub_gh <tmpdir> <license_content_b64|"EMPTY">
# The stub echoes different JSON depending on the gh api path called:
#   repos/<repo>         -> repo metadata with license.spdx_id = NOASSERTION
#   repos/<repo>/contents/.claude-plugin/plugin.json -> base64 of a minimal plugin.json
#   repos/<repo>/contents/.claude-plugin/marketplace.json -> exit 1 (not found)
#   repos/<repo>/contents/<dir> -> exit 1 (no component dirs)
#   repos/<repo>/license -> { "content": "<license_content_b64>" } or exits 1 if EMPTY
_make_stub_gh() {
  local tmpdir="$1" lic_b64="$2" declared_lic="$3"
  # Build plugin.json content base64.
  local pj_json pj_b64
  pj_json="$(printf '{"name":"stub-plugin","description":"A stub plugin for testing.","license":"%s","keywords":["stub"]}' "$declared_lic")"
  pj_b64="$(printf '%s' "$pj_json" | base64)"
  # Build the stub script.
  # NOTE: vet-candidate.sh calls `gh api <endpoint> --jq '.content'` for content fetches.
  # Real `gh api --jq` applies jq and emits only the extracted value (the raw b64 string).
  # Our stub must detect `--jq .content` and output only the b64 value, not the JSON wrapper.
  cat >"$tmpdir/gh" <<STUB_EOF
#!/usr/bin/env bash
# Stub gh for NOASSERTION test.
ENDPOINT=""
USE_JQ_CONTENT=false
for arg in "\$@"; do
  case "\$arg" in
    repos/*) ENDPOINT="\$arg" ;;
    .content) USE_JQ_CONTENT=true ;;
  esac
done
# emit_content: if --jq .content was requested, output the raw b64 value; else output JSON wrapper.
emit_content() {
  local b64val="\$1"
  if \$USE_JQ_CONTENT; then
    printf '%s\n' "\$b64val"
  else
    printf '{"content":"%s\n"}' "\$b64val"
  fi
}
case "\$ENDPOINT" in
  # Marketplace.json check — not found.
  */contents/.claude-plugin/marketplace.json) exit 1 ;;
  # plugin.json fetch.
  */contents/.claude-plugin/plugin.json)
    emit_content "$pj_b64"; exit 0 ;;
  # Component probe — no components.
  */contents/commands|*/contents/agents|*/contents/skills|*/contents/hooks) exit 1 ;;
  # License file fetch.
  */license)
    if [ "$lic_b64" = "EMPTY" ]; then exit 1; fi
    emit_content "$lic_b64"; exit 0 ;;
  # Fallback: repo metadata — archived=false, private=false, spdx_id=NOASSERTION.
  *)
    printf '{"archived":false,"private":false,"license":{"spdx_id":"NOASSERTION"}}'; exit 0 ;;
esac
STUB_EOF
  chmod +x "$tmpdir/gh"
}

_run_vet_with_stub() {
  local tmpdir="$1"
  local verdict
  set +e
  verdict="$(PATH="$tmpdir:$PATH" bash "$VET" "odere-pro/stub-plugin" 2>/dev/null)"
  set -e
  printf '%s' "$verdict"
}

_has_lfm() {
  # Returns 0 if the verdict JSON contains a LICENSE_FILE_MISMATCH blocker.
  printf '%s' "$1" | jq -e '[.blockers[]? | select(.code == "LICENSE_FILE_MISMATCH")] | length > 0' >/dev/null 2>&1
}

# Guard: only run stub tests if we can call the vet script (already confirmed it exists above).
# Also confirm bash can run it (set -euo pipefail + source lib.sh — needs to be invocable).
if [ -n "${BASH_VERSION:-}" ] || command -v bash >/dev/null 2>&1; then
  tmpA="$(mktemp -d)"
  tmpB="$(mktemp -d)"
  tmpC="$(mktemp -d)"
  tmpD="$(mktemp -d)"

  # Control A: NOASSERTION + declared MIT + body is GPL-3.0 → must fire LICENSE_FILE_MISMATCH.
  _make_stub_gh "$tmpA" "$(_gpl3_body_b64)" "MIT"
  verdictA="$(_run_vet_with_stub "$tmpA")"
  if _has_lfm "$verdictA"; then
    : # expected — the mismatch was caught
  else
    note "NOASSERTION+MIT+GPL-body should emit LICENSE_FILE_MISMATCH but did NOT"
  fi

  # Control B: NOASSERTION + declared MIT + body contains MIT marker → must NOT fire.
  _make_stub_gh "$tmpB" "$(_mit_marker_b64)" "MIT"
  verdictB="$(_run_vet_with_stub "$tmpB")"
  if _has_lfm "$verdictB"; then
    note "NOASSERTION+MIT+MIT-body should NOT emit LICENSE_FILE_MISMATCH but DID"
  fi

  # Control C: NOASSERTION + declared Apache-2.0 + body is Apache-2.0 → must NOT fire.
  # (the claude-wiki-pages-plugin real case)
  _make_stub_gh "$tmpC" "$(_apache_marker_b64)" "Apache-2.0"
  verdictC="$(_run_vet_with_stub "$tmpC")"
  if _has_lfm "$verdictC"; then
    note "NOASSERTION+Apache-2.0+Apache-body should NOT emit LICENSE_FILE_MISMATCH but DID (wiki-pages regression)"
  fi

  # Control D: NOASSERTION + declared MIT + license endpoint returns empty → must NOT fire (graceful).
  _make_stub_gh "$tmpD" "EMPTY" "MIT"
  verdictD="$(_run_vet_with_stub "$tmpD")"
  if _has_lfm "$verdictD"; then
    note "NOASSERTION+fetch-fail should NOT emit LICENSE_FILE_MISMATCH but DID"
  fi

  rm -rf "$tmpA" "$tmpB" "$tmpC" "$tmpD"
fi

if [ "$fail" -ne 0 ]; then
  echo "G10 vet-verdict-schema: FAIL"
  exit 1
fi
echo "G10 vet-verdict-schema: ok"
