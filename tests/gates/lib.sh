#!/usr/bin/env bash
# Shared helpers for the marketplace gate suite.
# Sourced by each gate; never executed directly.

# Absolute repo root, derived from this file's location.
gates_repo_root() {
  CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
}

# Print the YAML frontmatter (between the first two `---` fences) of file $1.
gates_frontmatter() {
  awk 'BEGIN{s=0}
       /^---[[:space:]]*$/{s++; if(s==2) exit; next}
       s==1{print}' "$1"
}

# The marketplace manifest, relative to the repo root.
# shellcheck disable=SC2034
GATES_MARKETPLACE=".claude-plugin/marketplace.json"

# Navigational layers that must each carry a CLAUDE.md (consumed by 07-claude-md-coverage.sh).
# shellcheck disable=SC2034
GATES_DOCUMENTED_DIRS=".claude-plugin .github .claude tests/gates"
