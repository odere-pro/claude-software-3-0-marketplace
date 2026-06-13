# odere-pro Claude Code marketplace

[![CI](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code marketplace](https://img.shields.io/badge/Claude%20Code-marketplace-8A2BE2)](https://docs.claude.com/en/docs/claude-code/plugins)

The single [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for
[`odere-pro`](https://github.com/odere-pro). Each plugin lives in its **own** repository and is
aggregated here, so you add this marketplace once and install any plugin individually.

The marketplace `name` is **`odere-pro`** — installs are always `<plugin>@odere-pro`, regardless of
this repo's name.

## Why trust this registry

Every plugin listing passes a **19-gate automated suite** (`bash tests/gates/run-all.sh`) on every
push and PR: the manifest is linted for structural correctness (G2), secret-scanned (G4), checked for
supply-chain hygiene — SHA-pinned actions (G15) and least-privilege workflow permissions (G16) — and
each plugin's `plugin.json` is vetted for a valid SPDX license (G2) and at least one domain-specific
keyword. The repo also runs [CodeQL](https://codeql.github.com/) and
[OpenSSF Scorecard](https://securityscorecards.dev/) in CI.

Installing this marketplace adds it to your Claude Code session once; from then on individual plugins
install by name:

- **In a Claude Code session** (recommended): `/plugin marketplace add odere-pro/claude-software-3-0-marketplace`
- **From the shell**: `claude plugin marketplace add odere-pro/claude-software-3-0-marketplace`

Browse the full listing with live search at
**[odere-pro.github.io/claude-software-3-0-marketplace](https://odere-pro.github.io/claude-software-3-0-marketplace/)**.

## Add the marketplace

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
```

## Install plugins

Once the marketplace is added, install any plugin individually:

```text
/plugin install <plugin>@odere-pro
```

From the shell, the same steps are `claude plugin marketplace add …` and
`claude plugin install <plugin>@odere-pro`. Plugins install **per-user (per machine), not
per-project** — once installed, a plugin is available in every repo you open. A session restart may be
needed for its commands, agents, and hooks to load.

## Test a plugin

To try a plugin against a specific project, open that project and drive the plugin's commands there
(the install is global, so there's nothing to reinstall):

```bash
gh repo clone <owner>/<repo> -- -b <branch>   # the project to test against
cd <repo>
claude                                          # start a session in this repo
```

Then run the plugin's entry-point commands — each plugin documents its own in its repo README. For
example, `claude-wiki-pages` exposes `/claude-wiki-pages:onboarding` (guided setup),
`/claude-wiki-pages:wiki` (the orchestrator), and `/claude-wiki-pages:doctor` (health check).

Inspect or manage an installed plugin from the shell:

```bash
claude plugin list                 # what's installed / enabled
claude plugin details <plugin>     # component inventory + projected token cost
claude plugin update <plugin>      # pull the latest from the plugin repo's default branch
claude plugin uninstall <plugin>   # remove it
```

Per-plugin install + quick-start guides live in [`docs/plugins/`](docs/plugins/) — e.g.
[claude-oop-excellence](docs/plugins/claude-oop-excellence.md).

## Plugins

<!-- The table below is generated from .claude-plugin/marketplace.json by
     .claude/skills/add-plugin/scripts/sync-readme.sh. Don't edit it by hand. -->
<!-- BEGIN PLUGINS -->
| Plugin | Repo | What it does | License | Keywords |
| --- | --- | --- | --- | --- |
| `claude-oop-excellence` | [odere-pro/claude-oop-excellence](https://github.com/odere-pro/claude-oop-excellence) | Audits and refactors codebases for object-oriented design quality: parallel RISK + PATTERN analysis tracks, a 102-entity glossary (45 issues, 57 patterns), and gated fix/implement commands — language-agnostic. | MIT | `oop`, `object-oriented-design`, `solid`, `encapsulation`, `design-patterns`, `antipatterns`, `code-quality`, `refactoring`, `audit`, `risk-scan`, `language-agnostic` |
| `claude-wiki-pages` | [odere-pro/claude-wiki-pages-plugin](https://github.com/odere-pro/claude-wiki-pages-plugin) | Turns an Obsidian vault into a provenance-tracked LLM knowledge base on Karpathy's LLM Wiki pattern: a four-layer stack of 23 skills, 7 agents, and 15 schema-enforcing hooks ingests sources into typed, citation-verified pages — with offline Ollama support and git-checkpointed self-healing. | Apache-2.0 | `obsidian`, `knowledge-base`, `knowledge-management`, `llm-wiki`, `rag`, `multi-agent`, `agentic`, `markdown`, `provenance`, `local-models`, `ollama`, `karpathy` |
| `claude-calibration` | [odere-pro/claude-calibration](https://github.com/odere-pro/claude-calibration) | Continuous evaluate-plan-calibrate-re-evaluate loop over Claude Code setups (CLAUDE.md, rules, skills, hooks, MCP, plugins) with scoring rubrics and enforcement scaffolding for recurring findings. | MIT | `calibration`, `evaluation`, `config-audit`, `harness`, `orchestration`, `claude-code-setup` |
<!-- END PLUGINS -->

The table above is generated from `.claude-plugin/marketplace.json` by `sync-readme.sh` and is the
source of truth for what is currently listed. To add more plugins, use `/add-plugin <repo>` in a
Claude Code session in this repo (see [docs/adding-plugins.md](docs/adding-plugins.md)).

## How it's wired

This repo is a **dedicated aggregator**: it ships only `.claude-plugin/marketplace.json` and no plugin
of its own. Each entry references its plugin's repository with a `github`
[source](https://docs.claude.com/en/docs/claude-code/plugins):

```json
{
  "name": "claude-oop-excellence",
  "source": { "source": "github", "repo": "odere-pro/claude-oop-excellence" }
}
```

Entries omit `version` — each plugin's own `.claude-plugin/plugin.json` is the version of record — and
omit `sha`/`commit`, so installs track each plugin repo's default branch.

### Managing plugins

The easy path is the agent-driven workflow — in a Claude Code session in this repo:

```text
/vet-plugin <repo>                          # read-only: is the candidate ready? what's blocking?
/add-plugin <repo>                          # vet → edit manifest + README + CHANGELOG → run gates → open a PR
/update-plugin <name>                       # refresh description/keywords/homepage/license from the plugin's plugin.json
/update-plugin <name> --repo odere-pro/<new-repo>   # replace / repoint the entry at a different repo
/update-plugin <name> --name <new-name>     # rename the entry
/remove-plugin <name>                       # drop the entry
```

`/add-plugin` and `/vet-plugin` take a **repo** (`odere-pro/<repo>`); `/update-plugin` and
`/remove-plugin` take the entry **name** as it appears in the registry. Each command edits the
manifest, regenerates the table above, updates `CHANGELOG`, runs the gates, and opens a PR; the add /
update paths also vet the target repo (odere-pro owner, valid `plugin.json`, ships no
`marketplace.json` of its own). Full process, contract, and the manual fallback are in
[`docs/adding-plugins.md`](docs/adding-plugins.md) and [`CONTRIBUTING.md`](CONTRIBUTING.md). A manifest
entry looks like:

```json
{
  "name": "<plugin-name>",
  "source": { "source": "github", "repo": "odere-pro/<repo>" },
  "description": "...",
  "homepage": "https://github.com/odere-pro/<repo>",
  "license": "MIT"
}
```

Entries omit `version` (the plugin's own `plugin.json` is the version of record) and `sha`/`commit`.
The entry name may differ from the repo basename.

## Developing this registry

This repo carries a full GitHub + Claude Code harness: validation gates (`tests/gates/`), CI and
supply-chain workflows (`.github/`), and an author-only `.claude/` harness. Why a registry is built
this way — as an agent-operable index — is in [`SOFTWARE-3-0.md`](SOFTWARE-3-0.md). Governance:
[`CONTRIBUTING.md`](CONTRIBUTING.md) · [`SECURITY.md`](SECURITY.md) · [`SUPPORT.md`](SUPPORT.md) ·
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

[MIT](./LICENSE) © odere-pro
