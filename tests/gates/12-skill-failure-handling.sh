#!/usr/bin/env bash
# G12 — skill failure-handling / rollback coverage. (CRITICAL)
#
# Every manage-plugins skill SKILL.md must document a `## Failure handling` section so the agent knows
# how to recover when a step fails mid-flow (roadmap P13a). For the three skills that EDIT files
# (add / update / remove), that section must spell out the rollback explicitly using
# `git restore --staged …` followed by `git restore …` — so a half-applied change (staged and/or
# dirty in the working tree) is fully undone, never left for a human to clean up (Brief §1: keep the
# human off the critical path). The read-only `vet-plugin` skill still carries the section (it states
# there is nothing to roll back) so the contract is uniform across all four.
#
# Offline, dependency-light (grep). Never calls the network.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

SKILLS_DIR=".claude/skills"
# The skills that write files and therefore need an explicit rollback recipe.
WRITE_SKILLS="add-plugin update-plugin remove-plugin"

checked=0
while IFS= read -r skill; do
  [ -f "$skill" ] || continue
  checked=$((checked + 1))
  # 1. Every skill carries the section heading.
  if ! grep -qE '^##[[:space:]]+Failure handling[[:space:]]*$' "$skill"; then
    note "$skill is missing a \"## Failure handling\" section"
    continue
  fi
done < <(find "$SKILLS_DIR" -maxdepth 2 -name 'SKILL.md')

[ "$checked" -ge 1 ] || note "found no SKILL.md files to check under $SKILLS_DIR"

# 2. The write skills must document the staged-AND-dirty rollback explicitly.
for s in $WRITE_SKILLS; do
  f="$SKILLS_DIR/$s/SKILL.md"
  [ -f "$f" ] || { note "$f not found (expected a write skill)"; continue; }
  grep -q 'git restore --staged' "$f" \
    || note "$f rollback must use \`git restore --staged …\` to unstage a half-applied change (P13a)"
  # A plain `git restore <path>` (working-tree restore) must also be present — i.e. a `git restore`
  # occurrence that is not the `--staged` one. Strip the staged form, then look for a bare restore.
  if ! grep 'git restore' "$f" | grep -vq 'git restore --staged'; then
    note "$f rollback must also use \`git restore …\` to discard the working-tree change (P13a)"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "G12 skill-failure-handling: FAIL"
  exit 1
fi
echo "G12 skill-failure-handling: ok ($checked skills carry a Failure handling section)"
