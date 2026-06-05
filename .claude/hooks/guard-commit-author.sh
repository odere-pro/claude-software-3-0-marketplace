#!/usr/bin/env bash
# guard-commit-author.sh — PreToolUse hook (Bash matcher).
# Blocks a `git commit` that sets a Claude/Anthropic --author, or carries a Co-Authored-By: Claude
# trailer or a "Generated with Claude Code" line. Commits stay human-authored (global policy:
# attribution is disabled). Exit 0 = allow, exit 2 = block (stderr surfaces to Claude).
set -euo pipefail

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit(0)
print((d.get('tool_input',{}) or {}).get('command',''))" 2>/dev/null || printf '')"

# Only inspect git commit invocations.
printf '%s' "$COMMAND" | grep -qE '\bgit\b.*\bcommit\b' || exit 0

block() {
  echo "[guard-commit-author] BLOCKED: $1" >&2
  echo "[guard-commit-author] Commits must be human-authored. Drop the --author override and any" >&2
  echo "[guard-commit-author] 'Co-Authored-By: Claude' / 'Generated with Claude Code' line, then re-run." >&2
  # Cite the policy + its config source so the fix path is explicit (roadmap P13e).
  echo "[guard-commit-author] policy: human-authored commits (includeCoAuthoredBy:false in" >&2
  echo "[guard-commit-author]   .claude/settings.json; see CONTRIBUTING.md \"Commits\")." >&2
  echo "[guard-commit-author] remediation: re-run the commit without the attribution override/trailer." >&2
  exit 2
}

if printf '%s' "$COMMAND" | grep -qiE '\-\-author[=[:space:]]+[^[:space:]]*(claude|anthropic)'; then
  block "git commit sets a Claude/Anthropic --author"
fi
if printf '%s' "$COMMAND" | grep -qiE 'Co-authored-by:[^\n]*(claude|anthropic)'; then
  block "git commit message carries a Claude/Anthropic Co-Authored-By trailer"
fi
if printf '%s' "$COMMAND" | grep -qiE 'Generated with .*Claude Code|🤖 Generated'; then
  block "git commit message carries a 'Generated with Claude Code' line"
fi
exit 0
