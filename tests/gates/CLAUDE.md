# `tests/gates/` — the validation gate suite

Author-only. Small, standalone shell scripts that keep the registry well-formed. `ci.yml` runs the
whole suite on every push/PR; run it locally with `bash tests/gates/run-all.sh`.

## How it runs

`run-all.sh` auto-discovers every `NN-*.sh` in this directory (two-digit prefix), runs each, and
fails the suite if any exits non-zero. **To add a gate, just drop in a new `NN-name.sh`** — no
registry to update. Each gate sources `lib.sh` (`gates_repo_root`, `gates_frontmatter`, the
documented-dirs list) and `cd`s to the repo root.

## The gates

| Gate | Protects | Severity |
| ---- | -------- | -------- |
| `00-harness-integrity` | the harness's own shape: every gate is named `[0-9][0-9]-*.sh` so none silently skips (D8); the surface budget (10 agents, 4 skills, 3 hooks) holds; the repo root ships no plugin payload; and the secret regex + forbidden-key set stay byte-identical between gate and hook (parity, not cross-tree `source` — D1/D11) | CRITICAL |
| `01-json-parses` | every tracked `*.json` is valid JSON | CRITICAL |
| `02-marketplace-shape` | the `marketplace.json` registry contract (name `odere-pro`; `odere-pro/<repo>` github sources; unique entry names; no `version`/`sha`/`commit`) | CRITICAL |
| `03-no-absolute-paths` | no leaked `/Users/…` `/home/…` machine paths | CRITICAL |
| `04-secret-scan` | no token-shaped secrets (OpenAI/GitHub/AWS/Slack/PEM) | CRITICAL |
| `05-doc-links` | no dangling intra-repo `.md` links | CRITICAL |
| `06-shellcheck` | gate + hook + skill scripts lint clean (`-S error`); SKIPs if shellcheck absent | CRITICAL |
| `07-claude-md-coverage` | every navigational layer has a `CLAUDE.md` | CRITICAL |
| `08-markdown-lint` | markdown style; self-degrades to WARN/SKIP without `markdownlint-cli2` | advisory |
| `09-readme-in-sync` | README Plugins table matches `marketplace.json` (runs `sync-readme.sh --check`) | CRITICAL |
| `10-vet-verdict-schema` | `vet-candidate.sh` emits coded `{code,message,fix}` blockers (roadmap P7); offline shape-contract guard — SKIPs only if `jq` absent | CRITICAL |

## Conventions

- `set -euo pipefail`; print indented `FAIL:` detail lines, then a final `GN name: FAIL` and `exit 1`.
- A gate that can't run a tool (e.g. shellcheck missing) **SKIPs** (exit 0), it does not fail.
- Keep gates fast and dependency-light (`jq`, `grep`, `find`, `awk`, `python3`).
