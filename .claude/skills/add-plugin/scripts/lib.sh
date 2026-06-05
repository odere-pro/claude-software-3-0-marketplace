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

# Path to the changelog, relative to the repo root.
# shellcheck disable=SC2034
MK_CHANGELOG="CHANGELOG.md"

# Insert a deterministic bullet into CHANGELOG.md under `## [Unreleased]` → `### <section>`, creating
# the subsection if it is absent. This removes the "remember to hand-write a changelog line" step from
# the agent flow (roadmap P8): the add/update/remove scripts each call this so the changelog tracks the
# manifest deterministically. The 11-changelog-in-sync.sh gate then asserts every listed plugin is
# named in the changelog.
#   $1 = section ("Added" | "Changed" | "Removed")
#   $2 = bullet text WITHOUT the leading "- " (e.g. 'List `foo` (`odere-pro/foo`).')
# No network, idempotent only per logical change (one call = one bullet). Portable awk (BSD/macOS).
mk_changelog_bullet() {
  local section="$1" text="$2"
  local root cl tmp
  root="$(mk_repo_root)"
  cl="$root/$MK_CHANGELOG"
  [ -f "$cl" ] || { echo "changelog $MK_CHANGELOG not found at repo root" >&2; return 1; }
  grep -qE '^##[[:space:]]+\[Unreleased\]' "$cl" || {
    echo "$MK_CHANGELOG has no \"## [Unreleased]\" section" >&2; return 1; }

  tmp="$(mktemp)"
  awk -v section="$section" -v bullet="- $text" '
    BEGIN { in_unrel=0; in_sect=0; done=0 }
    # Track entry into / exit from the [Unreleased] block.
    /^##[[:space:]]+\[Unreleased\]/ { in_unrel=1; print; next }
    # A new top-level "## " heading after Unreleased ends the block. If we never found the target
    # subsection, create it here before leaving Unreleased.
    /^##[[:space:]]/ && in_unrel==1 {
      if (done==0) { print "### " section; print bullet; print ""; done=1 }
      in_unrel=0; in_sect=0; print; next
    }
    # The target "### <section>" subsection inside Unreleased: insert the bullet right after it.
    in_unrel==1 && $0 ~ ("^###[[:space:]]+" section "[[:space:]]*$") {
      print; print bullet; in_sect=1; done=1; next
    }
    { print }
    END {
      # Unreleased ran to EOF without a following "## " heading and without the subsection: append it.
      if (in_unrel==1 && done==0) { print "### " section; print bullet }
    }
  ' "$cl" >"$tmp"
  mv "$tmp" "$cl"
}
