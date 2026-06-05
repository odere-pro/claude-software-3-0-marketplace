#!/usr/bin/env bash
# G15 — actions-pinned gate. (CRITICAL)
#
# Every external GitHub Action referenced by a workflow (`uses: owner/repo@ref`) must be pinned by a
# full 40-character commit SHA, never a mutable tag/branch ref (`@v6`, `@main`). A SHA pin is the
# OpenSSF "Pinned-Dependencies" signal: a tag can be re-pointed at malicious code after review, a SHA
# cannot. A trailing `# vX.Y.Z` comment is encouraged (Dependabot maintains it) but the SHA is what
# this gate enforces (roadmap P12a, thesis 7).
#
# Allowed exception: a `./`-local reusable-workflow reference (`uses: ./.github/workflows/foo.yml`)
# names a file in THIS repo at the checked-out commit — there is nothing external to pin. The matcher
# is precise: only a leading `./` path is exempt; `actions/checkout@v6` is not.
#
# Static YAML scan over `.github/workflows/*.yml`. Offline, dependency-light (grep + a SHA regex).
# Never calls the network.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

WF_DIR=".github/workflows"
if [ ! -d "$WF_DIR" ]; then
  echo "G15 actions-pinned: ok (no $WF_DIR)"
  exit 0
fi

# A full commit SHA is exactly 40 lowercase hex characters.
sha_re='^[0-9a-f]{40}$'

checked=0
while IFS= read -r wf; do
  [ -f "$wf" ] || continue
  # Extract the value after `uses:` on each step line (strip a leading `- `, the `uses:` key,
  # surrounding quotes, and any trailing ` # comment`). Linear scan, no YAML parser needed.
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    checked=$((checked + 1))

    # `./`-local reusable workflow: nothing external to pin — allowed.
    case "$ref" in
      ./*) continue ;;
    esac

    # Everything else must be `owner/repo@<40-hex-sha>` (possibly with a `/subpath`).
    case "$ref" in
      *@*)
        pin="${ref##*@}"
        if ! printf '%s' "$pin" | grep -Eq "$sha_re"; then
          note "$wf: \"uses: $ref\" is not pinned by a 40-char commit SHA (got @$pin) — pin to a full SHA (roadmap P12a)"
        fi
        ;;
      *)
        note "$wf: \"uses: $ref\" has no @ref — pin to a full 40-char commit SHA, or use a ./local workflow"
        ;;
    esac
  done < <(
    grep -nE '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*' "$wf" \
      | sed -E 's/^[0-9]+:[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]*#.*$//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]*$//'
  )
done < <(find "$WF_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \))

if [ "$checked" -eq 0 ]; then
  note "found no \`uses:\` references to check — the workflow extractor or the workflow shape changed"
fi

if [ "$fail" -ne 0 ]; then
  echo "G15 actions-pinned: FAIL"
  exit 1
fi
echo "G15 actions-pinned: ok ($checked action reference(s) pinned)"
