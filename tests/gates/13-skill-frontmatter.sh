#!/usr/bin/env bash
# G13 — skill front-matter lint. (CRITICAL)
#
# A skill that the agent invokes must declare the fields Claude Code needs to run it deterministically
# (roadmap P13b). This gate parses the YAML front-matter of every `.claude/skills/*/SKILL.md` and:
#
#   FAIL  — if any REQUIRED-for-execution field is absent: `name`, `description`, `model`,
#           `allowed-tools`. Without these the skill can't be discovered, modelled, or permission-scoped.
#   WARN  — if `argument-hint` is absent (advisory only, never a FAIL): it improves the invocation UX
#           but the skill still runs without it.
#
# It uses the shared `gates_frontmatter` extractor (lib.sh) so it reads only the front-matter block,
# not the body. Offline, dependency-light (awk + grep). Never calls the network.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }
warn() { echo "  WARN: $1"; }

SKILLS_DIR=".claude/skills"
REQUIRED="name description model allowed-tools"

# A front-matter key is present if a line in the front-matter block begins with `key:` (optionally
# indented). We check the extracted front-matter only, so a mention of the word in the body never
# counts as the field being declared.
has_key() { # $1 = front-matter text  $2 = key
  printf '%s\n' "$1" | grep -qE "^[[:space:]]*$2:"
}

checked=0
while IFS= read -r skill; do
  [ -f "$skill" ] || continue
  checked=$((checked + 1))
  fm="$(gates_frontmatter "$skill")"
  if [ -z "$fm" ]; then
    note "$skill has no YAML front-matter (--- … --- block)"
    continue
  fi
  for key in $REQUIRED; do
    has_key "$fm" "$key" || note "$skill front-matter is missing required field \"$key\""
  done
  has_key "$fm" "argument-hint" || warn "$skill front-matter has no \"argument-hint\" (advisory — improves invocation UX)"
done < <(find "$SKILLS_DIR" -maxdepth 2 -name 'SKILL.md')

[ "$checked" -ge 1 ] || note "found no SKILL.md files to lint under $SKILLS_DIR"

if [ "$fail" -ne 0 ]; then
  echo "G13 skill-frontmatter: FAIL"
  exit 1
fi
echo "G13 skill-frontmatter: ok ($checked skills carry the required front-matter fields)"
