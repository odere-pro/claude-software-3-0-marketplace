#!/usr/bin/env bash
# G17 — CI commit-author backstop gate. (CRITICAL)
#
# Commits in this repo must be human-authored (global policy: includeCoAuthoredBy:false in
# .claude/settings.json; CONTRIBUTING.md "Commits"). The PreToolUse hook .claude/hooks/
# guard-commit-author.sh blocks an AI-authored `git commit` at edit time; THIS gate is the CI
# backstop that re-checks committed history, so a commit made outside the hook (another machine, a
# bypassed hook) still gets caught (roadmap P14, thesis 7).
#
# It scans every commit reachable from HEAD and FAILs if any commit's author/committer name or email,
# or its message, carries a Claude/Anthropic signal — mirroring the three signals the hook blocks:
#   - a Claude/Anthropic author or committer identity (name or email),
#   - a `Co-authored-by: …claude/anthropic…` trailer,
#   - a "Generated with … Claude Code" / "🤖 Generated" line.
#
# Local git only — NO network (roadmap D3/D4). In CI the checkout uses `fetch-depth: 0` (D15) so the
# FULL history is present to scan; this gate and that ci.yml change ship atomically (D-atomicity).
# SKIPs (exit 0) if `git` is unavailable or this is not a git work tree, per the gate convention.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

if ! command -v git >/dev/null 2>&1; then
  echo "G17 commit-author: SKIP (git not installed)"
  exit 0
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "G17 commit-author: SKIP (not a git work tree)"
  exit 0
fi

fail=0
note() { echo "  FAIL: $1"; fail=1; }

# Case-insensitive AI-attribution signal shared across the identity and message checks.
ai_re='claude|anthropic'

scanned=0
# Identity check: author name|author email|committer name|committer email, NUL-free, one record/commit.
# %x1f = unit separator between fields, %x1e = record separator between commits.
while IFS=$'\x1f' read -r -d $'\x1e' h an ae cn ce; do
  [ -n "$h" ] || continue
  scanned=$((scanned + 1))
  for field in "$an" "$ae" "$cn" "$ce"; do
    if printf '%s' "$field" | grep -qiE "$ai_re"; then
      note "commit ${h:0:12}: AI-attributed identity \"$field\" — commits must be human-authored (roadmap P14)"
      break
    fi
  done
done < <(git log --format='%H%x1f%an%x1f%ae%x1f%cn%x1f%ce%x1e' HEAD)

# Message check: a Co-Authored-By trailer or a "Generated with Claude Code" line naming claude/anthropic.
while IFS= read -r h; do
  [ -n "$h" ] || continue
  body="$(git log -1 --format='%B' "$h")"
  if printf '%s' "$body" | grep -qiE 'co-authored-by:[^\n]*('"$ai_re"')'; then
    note "commit ${h:0:12}: message carries a Claude/Anthropic Co-Authored-By trailer (roadmap P14)"
  fi
  if printf '%s' "$body" | grep -qiE 'generated with .*claude code|🤖 generated'; then
    note "commit ${h:0:12}: message carries a 'Generated with Claude Code' line (roadmap P14)"
  fi
done < <(git log --format='%H' HEAD)

if [ "$scanned" -eq 0 ]; then
  echo "G17 commit-author: SKIP (no commits reachable from HEAD)"
  exit 0
fi

if [ "$fail" -ne 0 ]; then
  echo "G17 commit-author: FAIL"
  exit 1
fi
echo "G17 commit-author: ok ($scanned commit(s) human-authored)"
