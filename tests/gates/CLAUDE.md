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
| `00-harness-integrity` | the harness's own shape: every gate is named `[0-9][0-9]-*.sh` so none silently skips (D8); the surface budget (10 agents, 4 skills, 3 hooks) holds; the repo root ships no plugin payload; the secret regex + forbidden-key set + generic-keyword denylist (`KEYWORD_DENYLIST`) stay byte-identical between gate and hook (parity, not cross-tree `source` — D1/D11/W2.1); and the manage-plugins core helpers (`mk_normalize_repo`/`MK_OWNER`/`MK_MANIFEST`) are defined only in the shared `add-plugin/scripts/lib.sh`, never forked (roadmap P13d, folded here per D11) | CRITICAL |
| `01-json-parses` | every tracked `*.json` is valid JSON | CRITICAL |
| `02-marketplace-shape` | the `marketplace.json` registry contract: name `odere-pro`; `$schema` pinned; `odere-pro/<repo>` github sources; unique entry names; no `version`/`sha`/`commit`; top-level `description` non-empty and >= 40 chars; every entry has >= 1 keyword NOT in the generic-keyword denylist (W2.1 — promoted from advisory to FAIL; denylist parity-gated against the hook) | CRITICAL |
| `03-no-absolute-paths` | no leaked `/Users/…` `/home/…` machine paths | CRITICAL |
| `04-secret-scan` | no token-shaped secrets (OpenAI/GitHub/AWS/Slack/PEM) | CRITICAL |
| `05-doc-links` | no dangling intra-repo `.md` links | CRITICAL |
| `06-shellcheck` | gate + hook + skill scripts lint clean (`-S error`); SKIPs if shellcheck absent | CRITICAL |
| `07-claude-md-coverage` | every navigational layer has a `CLAUDE.md` | CRITICAL |
| `08-markdown-lint` | markdown style; self-degrades to WARN/SKIP without `markdownlint-cli2` | advisory |
| `09-readme-in-sync` | README Plugins table matches `marketplace.json` (runs `sync-readme.sh --check`) | CRITICAL |
| `10-vet-verdict-schema` | `vet-candidate.sh` emits coded `{code,message,fix}` blockers (roadmap P7); offline shape-contract guard — SKIPs only if `jq` absent | CRITICAL |
| `11-changelog-in-sync` | every plugin listed in `marketplace.json` is named in `CHANGELOG.md` (roadmap P8; distinct from G9 — a weaker, accreting-prose invariant, not a byte check); the add/update/remove scripts emit the bullet via `mk_changelog_bullet` | CRITICAL |
| `12-skill-failure-handling` | every skill `SKILL.md` carries a `## Failure handling` section; the three write skills document the staged-AND-dirty rollback (`git restore --staged …` + `git restore …`) (roadmap P13a) | CRITICAL |
| `13-skill-frontmatter` | each skill `SKILL.md` declares the required front-matter (`name`/`description`/`model`/`allowed-tools`); missing `argument-hint` is a WARN, not a FAIL (roadmap P13b) | CRITICAL |
| `14-skill-script-paths` | every `bash .claude/skills/.../scripts/<x>.sh` reference in a `SKILL.md` or agent resolves to a real file (roadmap P13c) | CRITICAL |
| `15-actions-pinned` | every external `uses:` in `.github/workflows/*.yml` is pinned by a full 40-char commit SHA (OpenSSF Pinned-Dependencies); `./`-local reusable workflows are exempt (roadmap P12a); static, offline | CRITICAL |
| `16-workflow-permissions` | no workflow declares `permissions: write-all`, and `contents: write` is forbidden unless allowlisted (empty today); narrow scopes like `security-events`/`id-token` `write` are fine (roadmap P12b); static, offline | CRITICAL |
| `17-commit-author` | no commit reachable from HEAD carries a Claude/Anthropic author/committer identity or AI-attribution trailer — CI backstop mirroring `guard-commit-author.sh` (roadmap P14); needs full history (`ci.yml` uses `fetch-depth: 0`, D15); local git only, SKIPs without git/commits | CRITICAL |
| `18-pages-in-sync` | `site/` is byte-identical to what `sync-site.sh` would generate today (byte-equality on index.html/sitemap.xml/robots.txt); no remote-fetch primitives in the generator or output HTML; **real XSS-payload escape check**: runs the generator against a synthetic manifest with injection vectors in every rendered field and asserts the HTML output contains no live `onerror=` attribute, no `"><script>` attribute-breakout, no `<script>` tags injected via license/description, and no `</script` in the JSON-LD section beyond the legitimate closing tag; SEO files present and non-empty; JSON-LD block parses as valid JSON; passes at N=0 (empty plugins). SKIPs if generator/site/ absent or jq missing | CRITICAL |
| `19-timing-report` | `run-all.sh` carries the advisory per-gate + total timing instrumentation (`suite_start`/`gate_start`/`gate_elapsed`/`total:` pattern); prints WARN (exits 0) if the instrumentation is accidentally stripped — never blocks the suite | advisory |

## Timing report

`run-all.sh` records elapsed seconds for every gate (using bash `$SECONDS`, zero extra dependencies)
and prints a `total:` line in the summary. All timing output is advisory: it never changes the exit
code. The numeric budget for the timing format is:

- Per-gate line: `  [NNNs] <gate-filename>` (right-justified 3-digit seconds field).
- Failing gate line: `  [NNNs] <gate-filename>  <-- FAILED` (same format + annotation).
- Summary line: `gates passed: N   failed: N   total: Ns`.

G19 (`19-timing-report.sh`) enforces the presence of the four instrumentation patterns
(`suite_start=$SECONDS`, `gate_start=$SECONDS`, `gate_elapsed=`, `total:`) so they cannot be
silently removed. G19 is advisory (always exits 0).

## Conventions

- `set -euo pipefail`; print indented `FAIL:` detail lines, then a final `GN name: FAIL` and `exit 1`.
- A gate that can't run a tool (e.g. shellcheck missing) **SKIPs** (exit 0), it does not fail.
- Keep gates fast and dependency-light (`jq`, `grep`, `find`, `awk`, `python3`).
