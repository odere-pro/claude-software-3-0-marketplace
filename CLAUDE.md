# claude-software-3-0-marketplace — registry development

> Author/dev project memory. **Not shipped context** — adding this marketplace registers an index;
> nothing in this repo is loaded into an end user's Claude Code session.

This repo is the **`odere-pro` marketplace**: a dedicated, registry-only aggregator. It ships one
source of truth — `.claude-plugin/marketplace.json` — that lists each plugin by a `github` source.
Each plugin lives in its **own** repo and installs individually as `<plugin>@odere-pro`.

## What ships (the registry)

- `.claude-plugin/marketplace.json` — the manifest (name `odere-pro`; one `github`-source entry per
  plugin; no `version`, no `sha`). **The only payload.** Deep detail:
  [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md).
- `README.md`, `LICENSE` — what the marketplace is and how to use it.

This repo has **no `plugin.json` and no plugin components** (`skills/`, `agents/`, `hooks/`,
`commands/`). It is not a plugin.

## What doesn't ship (author-only — governance, CI, harness)

| Path | Role | Detail |
| ---- | ---- | ------ |
| `.claude-plugin/` | the manifest (registry payload) | [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md) |
| `.claude/` | dev harness: settings, hooks, rules, the add-plugin skills + agent, the `registry-dev` team, statusline, MCP | [`.claude/CLAUDE.md`](.claude/CLAUDE.md) |
| `.claude/teams/` | author-only spawnable agent teams (the `registry-dev` engineering team) | [`.claude/teams/CLAUDE.md`](.claude/teams/CLAUDE.md) |
| `.github/` | CI, supply-chain workflows, Dependabot, CODEOWNERS | [`.github/CLAUDE.md`](.github/CLAUDE.md) |
| `tests/gates/` | the validation gate suite | [`tests/gates/CLAUDE.md`](tests/gates/CLAUDE.md) |
| `docs/` | human-readable references (adding plugins; the dev teams + roadmaps) | [`docs/CLAUDE.md`](docs/CLAUDE.md) |
| root docs | `SOFTWARE-3-0.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md` | governance |
| hygiene | `.editorconfig`, `.gitattributes`, `.markdownlint*.jsonc`, `.prettierrc`, `package.json` | repo config |

## Nested CLAUDE.md convention

Every navigational layer carries a `CLAUDE.md` that says *just enough* for its level; detail deepens
as you descend. `tests/gates/07-claude-md-coverage.sh` enforces presence for the documented layers.

## How to manage plugins

Use the agent-driven skills (each vets, edits the manifest + README + CHANGELOG, runs gates, and opens a
PR): `/vet-plugin <repo>` (read-only preflight), `/add-plugin <repo>`, `/update-plugin <name>`
(refresh / `--repo` repoint / `--name` rename), `/remove-plugin <name>`. Full process, contract, and
manual fallback: [`docs/adding-plugins.md`](docs/adding-plugins.md),
[`CONTRIBUTING.md`](CONTRIBUTING.md), and [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md).

## Gate map

`bash tests/gates/run-all.sh` before any PR (CI runs the same). G1 json-parses · G2 marketplace-shape
· G3 no-absolute-paths · G4 secret-scan · G5 doc-links · G6 shellcheck · G7 claude-md-coverage ·
G8 markdown-lint (advisory) · G9 readme-in-sync. See [`tests/gates/CLAUDE.md`](tests/gates/CLAUDE.md).

## Verify before commit

```bash
bash tests/gates/run-all.sh           # full gate suite is green (the authoritative check; CI runs this)
claude plugin validate .              # manifest validates
```

> While the registry is **empty**, `claude plugin validate --strict` warns "Marketplace has no plugins
> defined" (a warning `--strict` promotes to failure). That's expected — the gate suite is the green
> check; `--strict` becomes meaningful once the first plugin is listed via `/add-plugin`.
