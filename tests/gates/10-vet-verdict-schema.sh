#!/usr/bin/env bash
# G10 — vet-candidate verdict-shape gate. (CRITICAL)
#
# vet-candidate.sh emits a JSON verdict whose `blockers[]` are coded objects
# `{ code, message, fix }` (roadmap P7). This gate pins that contract so the verdict can never
# silently regress to raw-string blockers (which would break add-entry.sh / update-entry.sh, whose
# rollback messaging renders `.code`/`.message`/`.fix`).
#
# Dependency-light and OFFLINE (tests/gates/CLAUDE.md): it never calls `gh` or the network. It checks
#   1. the usage-error path — vet-candidate.sh with no argument exits 2 with a usage message, before
#      any `gh api` call (so the gate exercises the script without touching the network);
#   2. the shape contract — a validator jq filter (the invariant vet-candidate.sh produces) ACCEPTS a
#      well-formed verdict and REJECTS malformed ones (a blocker missing `code` or `fix`, or a `code`
#      outside the VET_CODES enum). If the validator ever stops rejecting malformed input, the gate
#      FAILs — that is the regression guard.
#
# SKIPs (exit 0) only if jq is absent (convention). It does not need `gh`.
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

if [ "$fail" -ne 0 ]; then
  echo "G10 vet-verdict-schema: FAIL"
  exit 1
fi
echo "G10 vet-verdict-schema: ok"
