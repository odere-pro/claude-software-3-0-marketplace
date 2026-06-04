#!/usr/bin/env bash
# marketplace-guard.sh — PreToolUse hook (Write|Edit|MultiEdit matcher).
# Fast local guardrail for edits to .claude-plugin/marketplace.json. The authoritative full check is
# tests/gates/02-marketplace-shape.sh; this gives immediate feedback before a bad edit lands.
#
# Blocks (exit 2) when an edit to marketplace.json would:
#   - (Write) produce invalid JSON, or set a forbidden `version`/`sha`/`commit`, or change the
#     top-level name away from "odere-pro", or embed a secret-shaped token;
#   - (Edit/MultiEdit) introduce a `"version"`/`"sha"`/`"commit"` key or a secret-shaped token.
# Zero-cost (exit 0) for any other tool or file.
set -euo pipefail

INPUT="$(cat)"

read_field() { # $1 = python expression over `d` (the parsed hook payload)
  printf '%s' "$INPUT" | python3 -c "import sys,json
try:
    d = json.load(sys.stdin)
except Exception:
    print(''); sys.exit(0)
i = d.get('tool_input', {}) or {}
print($1)" 2>/dev/null || printf ''
}

TOOL="$(read_field "d.get('tool_name','')")"
case "$TOOL" in
  Write | Edit | MultiEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH="$(read_field "i.get('file_path', i.get('path',''))")"
case "$FILE_PATH" in
  */.claude-plugin/marketplace.json) ;;
  *) exit 0 ;;
esac

SECRET_RE='(sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{12,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'

block() {
  echo "[marketplace-guard] BLOCKED: $1" >&2
  echo "[marketplace-guard] marketplace.json must stay a clean registry index:" >&2
  echo "[marketplace-guard]   - valid JSON, top-level name \"odere-pro\"" >&2
  echo "[marketplace-guard]   - entries omit version (plugin.json is the version of record) and sha/commit" >&2
  echo "[marketplace-guard]   - no secret-shaped tokens. See .claude/rules/marketplace-dev.md." >&2
  exit 2
}

if [ "$TOOL" = "Write" ]; then
  CONTENT="$(read_field "i.get('content','')")"
  [ -n "$CONTENT" ] || exit 0
  printf '%s' "$CONTENT" | python3 -c "import sys,json; json.load(sys.stdin)" >/dev/null 2>&1 \
    || block "the new content is not valid JSON"
  name="$(printf '%s' "$CONTENT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null || printf '')"
  [ "$name" = "odere-pro" ] || block "top-level name must be \"odere-pro\" (got \"$name\")"
  forbidden="$(printf '%s' "$CONTENT" | python3 -c "import sys,json
d=json.load(sys.stdin)
bad=[]
for p in d.get('plugins',[]):
    for k in ('version','sha','commit'):
        if k in p: bad.append(k)
    for k in ('sha','commit'):
        if k in (p.get('source') or {}): bad.append('source.'+k)
print(' '.join(sorted(set(bad))))" 2>/dev/null || printf '')"
  [ -z "$forbidden" ] || block "entries set forbidden key(s): $forbidden"
  badrepo="$(printf '%s' "$CONTENT" | python3 -c "import sys,json,re
d=json.load(sys.stdin)
bad=[(p.get('source') or {}).get('repo','') for p in d.get('plugins',[])
     if not re.match(r'^odere-pro/[A-Za-z0-9._-]+\$', (p.get('source') or {}).get('repo',''))]
print(' '.join(r or '(missing)' for r in bad))" 2>/dev/null || printf '')"
  [ -z "$badrepo" ] || block "entry source.repo must be odere-pro/<repo>: $badrepo"
  if printf '%s' "$CONTENT" | grep -qE "$SECRET_RE"; then block "content contains a secret-shaped token"; fi
  exit 0
fi

# Edit / MultiEdit: inspect the inserted text heuristically.
NEW="$(read_field "i.get('new_string', json.dumps(i.get('edits','')))")"
[ -n "$NEW" ] || exit 0
if printf '%s' "$NEW" | grep -qE '"(version|sha|commit)"[[:space:]]*:'; then
  block "the edit introduces a forbidden \"version\"/\"sha\"/\"commit\" key"
fi
# A "repo": "..." inserted by the edit must be odere-pro-owned.
while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  case "$repo" in
    odere-pro/?*) ;;
    *) block "the edit sets source.repo \"$repo\" — must be odere-pro/<repo>" ;;
  esac
done < <(printf '%s' "$NEW" | grep -oE '"repo"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')
if printf '%s' "$NEW" | grep -qE "$SECRET_RE"; then block "the edit introduces a secret-shaped token"; fi
exit 0
