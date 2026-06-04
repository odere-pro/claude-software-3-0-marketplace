#!/usr/bin/env bash
# json-format.sh — PostToolUse hook (Write|Edit matcher).
# Pretty-prints an edited *.json file with two-space indentation, but only if it is already valid
# JSON. No-op when jq is unavailable, the file is not JSON, or parsing fails — never destructive.
set -euo pipefail

INPUT="$(cat)"
FILE_PATH="$(printf '%s' "$INPUT" | python3 -c "import sys,json
try: d=json.load(sys.stdin)
except Exception: print(''); sys.exit(0)
i=d.get('tool_input',{}) or {}
print(i.get('file_path', i.get('path','')))" 2>/dev/null || printf '')"

case "$FILE_PATH" in
  *.json) ;;
  *) exit 0 ;;
esac
[ -f "$FILE_PATH" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
jq empty "$FILE_PATH" >/dev/null 2>&1 || exit 0

tmp="$(mktemp)"
if jq --indent 2 '.' "$FILE_PATH" >"$tmp" 2>/dev/null; then
  # Append a trailing newline jq already provides; only replace if content actually changed.
  if ! cmp -s "$tmp" "$FILE_PATH"; then mv "$tmp" "$FILE_PATH"; else rm -f "$tmp"; fi
else
  rm -f "$tmp"
fi
exit 0
