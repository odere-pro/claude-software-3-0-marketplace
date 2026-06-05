#!/usr/bin/env bash
# G14 — skill-script path-existence gate. (CRITICAL)
#
# Every `bash <path>/scripts/<x>.sh` invocation referenced in a skill SKILL.md or the worker agent
# must resolve to a file that actually exists. A skill that tells the agent to run a script that was
# renamed or deleted is a silent break in the agent-operable flow (the agent only finds out at
# runtime). This gate makes a stale script reference a CI failure (roadmap P13c).
#
# Scope: `.claude/skills/*/SKILL.md` and `.claude/agents/*.md`. It extracts every
# `.claude/skills/add-plugin/scripts/<x>.sh` token and asserts the file exists at the repo root.
# Offline, dependency-light (grep + test). Never calls the network.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

# Files that may reference the manage-plugins scripts: every skill SKILL.md and worker/agent .md.
# A `while read` over `find` output (portable to BSD/macOS bash 3.2 — no `mapfile`).
checked=0
while IFS= read -r doc; do
  [ -f "$doc" ] || continue
  # Pull every `.claude/skills/.../scripts/<name>.sh` path token referenced in the doc.
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    checked=$((checked + 1))
    if [ ! -f "$ref" ]; then
      note "$doc references \"$ref\" — no such script at the repo root"
    fi
  done < <(grep -oE '\.claude/skills/[A-Za-z0-9._/-]+/scripts/[A-Za-z0-9._-]+\.sh' "$doc" | sort -u)
done < <(find .claude/skills -maxdepth 2 -name 'SKILL.md'; find .claude/agents -maxdepth 1 -name '*.md')

if [ "$checked" -eq 0 ]; then
  note "found no skill-script references to check — the extractor or the docs changed shape"
fi

if [ "$fail" -ne 0 ]; then
  echo "G14 skill-script-paths: FAIL"
  exit 1
fi
echo "G14 skill-script-paths: ok ($checked references resolved)"
