#!/usr/bin/env bash
# G0 — harness integrity meta-gate. (CRITICAL)
#
# One consolidated self-check (roadmap D11) folding four invariants plus the cross-tree
# contract-constant parity check (roadmap P3 / D1: no cross-tree `source`):
#
#   1. suite-integrity   — every gate `*.sh` (except lib.sh / run-all.sh) is named `[0-9][0-9]-*.sh`,
#                          so run-all.sh's discovery glob can never silently skip a misnamed gate (D8).
#   2. gate-coverage     — the discovery glob actually matches the gate files on disk (no zero-match).
#   3. surface-budget    — the harness keeps its fixed surface: exactly the 10 allow-listed agents,
#                          4 skills, 3 hooks. A new surface is a regression to justify, not a default.
#   4. ship-surface      — the repo root ships NO plugin payload (plugin.json / skills/ / agents/ /
#                          hooks/ / commands/). This repo is a registry, not a plugin.
#   5. constant-parity   — the secret regex and the forbidden-key set are byte-identical between their
#                          gate site and their hook site. They are duplicated by design (the two trees
#                          must not `source` across each other, D1); this gate FAILs if they diverge.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname -- "$0")/lib.sh"
cd "$(gates_repo_root)"

fail=0
note() { echo "  FAIL: $1"; fail=1; }

GATES_DIR="tests/gates"
HOOK=".claude/hooks/marketplace-guard.sh"
SECRET_GATE="$GATES_DIR/04-secret-scan.sh"
SHAPE_GATE="$GATES_DIR/02-marketplace-shape.sh"

# ── 1. suite-integrity ────────────────────────────────────────────────────────────────────────
for f in "$GATES_DIR"/*.sh; do
  base="$(basename "$f")"
  case "$base" in
    lib.sh | run-all.sh) continue ;;
  esac
  case "$base" in
    [0-9][0-9]-*.sh) ;;
    *) note "gate \"$base\" is misnamed — must match [0-9][0-9]-*.sh or run-all.sh would silently skip it" ;;
  esac
done

# ── 2. gate-coverage ──────────────────────────────────────────────────────────────────────────
shopt -s nullglob
discovered=("$GATES_DIR"/[0-9][0-9]-*.sh)
shopt -u nullglob
[ "${#discovered[@]}" -ge 1 ] || note "gate-discovery glob [0-9][0-9]-*.sh matched no gates"

# ── 3. surface-budget (allow-list) ──────────────────────────────────────────────────────────────
EXPECTED_AGENTS="plugin-onboarder
registry-dev-architect
registry-dev-eng-ci-supplychain
registry-dev-eng-docs-dx
registry-dev-eng-harness
registry-dev-eng-manifest-gates
registry-dev-manager
registry-dev-pm
registry-dev-qa-adversarial
registry-dev-qa-gates"
actual_agents="$(find .claude/agents -maxdepth 1 -name '*.md' -exec basename {} .md \; | sort)"
if [ "$actual_agents" != "$(printf '%s' "$EXPECTED_AGENTS" | sort)" ]; then
  note "agent surface drifted from the 10-agent allow-list (1 worker + 9 registry-dev-*):"
  diff <(printf '%s\n' "$EXPECTED_AGENTS" | sort) <(printf '%s\n' "$actual_agents") | sed 's/^/      /' || true
fi

n_skills="$(find .claude/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')"
[ "$n_skills" = "4" ] || note "skill surface is $n_skills, expected 4 (add/vet/update/remove-plugin)"

n_hooks="$(find .claude/hooks -maxdepth 1 -name '*.sh' | wc -l | tr -d ' ')"
[ "$n_hooks" = "3" ] || note "hook surface is $n_hooks, expected 3 (marketplace-guard, guard-commit-author, json-format)"

# ── 4. ship-surface ─────────────────────────────────────────────────────────────────────────────
for p in plugin.json skills agents hooks commands; do
  [ -e "$p" ] && note "repo root ships \"$p\" — this is a registry, not a plugin (no payload at root)"
done
# plugin.json is also forbidden inside .claude-plugin/ (only marketplace.json belongs there).
[ -e ".claude-plugin/plugin.json" ] && note ".claude-plugin/plugin.json present — this repo is not a plugin"

# ── 5. constant-parity (D1: shared via parity, never cross-tree source) ──────────────────────────
# Secret regex: the single-quoted RE literal on the assignment line at each site.
gate_secret="$(grep -E "^secret_re=" "$SECRET_GATE" | sed -E "s/^secret_re='(.*)'\$/\1/" || true)"
hook_secret="$(grep -E "^SECRET_RE=" "$HOOK" | sed -E "s/^SECRET_RE='(.*)'\$/\1/" || true)"
if [ -z "$gate_secret" ] || [ -z "$hook_secret" ]; then
  note "could not extract the secret regex from $SECRET_GATE and/or $HOOK (assignment shape changed?)"
elif [ "$gate_secret" != "$hook_secret" ]; then
  note "secret regex diverged between $SECRET_GATE and $HOOK (must be byte-identical — D1)"
fi

# Forbidden-key set: both sites must reject exactly version + sha + commit.
# Gate (G2) names each via `has("<key>")` in its problems array. The hook enforces them in two
# Write-path python tuples — `('version','sha','commit')` on the entry and `('sha','commit')` on
# source. Match those exact enforcement tuples so a comment mentioning a key cannot mask its removal.
hook_entry_tuple="$(grep -oE "\('version','sha','commit'\)" "$HOOK" | head -1 || true)"
hook_source_tuple="$(grep -oE "\('sha','commit'\)" "$HOOK" | head -1 || true)"
[ "$hook_entry_tuple" = "('version','sha','commit')" ] \
  || note "hook ($HOOK) entry forbidden-key tuple is not ('version','sha','commit') — parity with G2 broken"
[ "$hook_source_tuple" = "('sha','commit')" ] \
  || note "hook ($HOOK) source forbidden-key tuple is not ('sha','commit') — parity with G2 broken"
for key in version sha commit; do
  grep -q "has(\"$key\")" "$SHAPE_GATE" || note "G2 ($SHAPE_GATE) no longer rejects forbidden key \"$key\""
done

if [ "$fail" -ne 0 ]; then
  echo "G0 harness-integrity: FAIL"
  exit 1
fi
echo "G0 harness-integrity: ok"
