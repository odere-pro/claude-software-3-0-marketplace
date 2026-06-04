#!/usr/bin/env bash
# G5 — no dangling relative *.md links across the repo's docs. (CRITICAL)
# Resolves each `](target.md)` link relative to its file and checks the target exists.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
while IFS= read -r f; do
  dir="$(dirname -- "$f")"
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    target="${target%% *}"      # drop optional `"title"` after a space
    target="${target%%#*}"      # drop #anchor
    case "$target" in
      ""|http://*|https://*|mailto:*|\#*) continue ;;
      *://*) continue ;;
    esac
    case "$target" in *.md) ;; *) continue ;; esac   # only intra-doc .md links
    if [ ! -e "$dir/$target" ]; then
      echo "  FAIL: $f -> $target (target missing)"
      fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//')
done < <(find . -type f -name '*.md' -not -path './.git/*' -not -path './node_modules/*' | sort)

if [ "$fail" -ne 0 ]; then echo "G5 doc-links: FAIL"; exit 1; fi
echo "G5 doc-links: ok"
