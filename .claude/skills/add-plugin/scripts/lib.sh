#!/usr/bin/env bash
# Shared helpers for the add-plugin skill scripts. Sourced; never executed directly.
# No network, no side effects on import.

# The only owner this registry lists. The gate, the hook, and these scripts all pin it.
# shellcheck disable=SC2034
MK_OWNER="odere-pro"

# Absolute repo root, derived from this file's location (.claude/skills/add-plugin/scripts/lib.sh).
mk_repo_root() {
  CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd
}

# Path to the marketplace manifest, relative to the repo root.
# shellcheck disable=SC2034
MK_MANIFEST=".claude-plugin/marketplace.json"

# Normalize a user-supplied repo argument to "odere-pro/<repo>".
#   "claude-aws-architect"          -> "odere-pro/claude-aws-architect"
#   "odere-pro/claude-aws-architect"-> "odere-pro/claude-aws-architect"
#   "other/foo"                     -> "other/foo" (caller validates the owner)
mk_normalize_repo() {
  local arg="$1"
  case "$arg" in
    */*) printf '%s' "$arg" ;;
    *) printf '%s/%s' "$MK_OWNER" "$arg" ;;
  esac
}
