# odere-pro Claude Code marketplace

[![CI](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code marketplace](https://img.shields.io/badge/Claude%20Code-marketplace-8A2BE2)](https://docs.claude.com/en/docs/claude-code/plugins)

The single [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for
[`odere-pro`](https://github.com/odere-pro). Each plugin lives in its **own** repository and is
aggregated here — add this marketplace once, then install any plugin individually. The marketplace
`name` is **`odere-pro`**, so installs are always `<plugin>@odere-pro`, regardless of this repo's name.

> 🔎 Browse the catalog with live search at
> **[odere-pro.github.io/claude-software-3-0-marketplace](https://odere-pro.github.io/claude-software-3-0-marketplace/)**.

## Quick start

**1. Add the marketplace** (once per machine) — in a Claude Code session:

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
```

**2. Install a plugin** from the [catalog below](#plugins). Submit each as its **own** command — one
slash command per line, and let the `marketplace add` finish first:

```text
/plugin install <plugin>@odere-pro
```

**3. Start using it** — a session restart may be needed to load the plugin's commands, agents, and
hooks. Then follow its [install + quick-start guide](#plugins).

From the shell, the same steps are `claude plugin marketplace add …` and
`claude plugin install <plugin>@odere-pro`. Plugins install **per-user (per machine), not
per-project** — once installed, a plugin is available in every repo you open.

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

**Start using →** each plugin ships an install + quick-start guide, so you can go from "added the
marketplace" to "ran the plugin" without leaving this repo:
[claude-oop-excellence](docs/plugins/claude-oop-excellence.md) ·
[claude-wiki-pages](docs/plugins/claude-wiki-pages.md) ·
[claude-calibration](docs/plugins/claude-calibration.md).

The table is generated from [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — the
source of truth for what's listed.

## Managing installed plugins

Inspect or manage anything you've installed, from the shell:

```bash
claude plugin list                 # what's installed / enabled
claude plugin details <plugin>     # component inventory + projected token cost
claude plugin update <plugin>      # pull the latest from the plugin's repo default branch
claude plugin uninstall <plugin>   # remove it
```

To try a plugin against a specific project, open that project and run the plugin's entry-point
commands there — the install is global, so there's nothing to reinstall:

```bash
gh repo clone <owner>/<repo> -- -b <branch>   # the project to test against
cd <repo> && claude                           # start a session in this repo
```

Each plugin's commands are documented in its [guide](#plugins) and its own repo README.

## Troubleshooting installs

Most install snags are **local Claude Code state**, not the registry — the manifest is gate-verified
on every push. The common ones and their fixes:

- **`URL rejected: Malformed input…` when adding the marketplace** — two commands were submitted on
  one line, so `marketplace add` swallowed the next as part of the repo argument. Run each command on
  its own line, marketplace first.

- **`Failed to load marketplace "odere-pro": cache-miss`** — the local catalog cache is stale. Rebuild
  it from the shell:

  ```bash
  claude plugin marketplace remove odere-pro
  claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
  claude plugin install <plugin>@odere-pro
  ```

- **`already installed`, or the plugin loads from a local path** — a prior local/dev install (e.g.
  `--plugin-dir`, or the plugin's repo added as its own marketplace) shadows the marketplace copy.
  Uninstall, then reinstall so it resolves into the per-user cache:

  ```bash
  claude plugin uninstall <plugin>@odere-pro
  claude plugin install <plugin>@odere-pro
  ```

- **Install everything through the one `odere-pro` marketplace** (`<plugin>@odere-pro`). Don't also
  register an individual plugin's repo as a separate marketplace — same-name entries collide.

## Why trust this registry

Every listing passes a **20-gate automated suite** (`bash tests/gates/run-all.sh`) on every push and
PR: the manifest is structurally linted (G2) and secret-scanned (G4); supply-chain hygiene is enforced
— SHA-pinned actions (G15) and least-privilege workflow permissions (G16); and each plugin's
`plugin.json` is vetted for a valid SPDX license (G2) and at least one domain-specific keyword. CI also
runs [CodeQL](https://codeql.github.com/) and [OpenSSF Scorecard](https://securityscorecards.dev/).

## For maintainers

This repo is a **dedicated aggregator**: it ships only
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) and no plugin of its own. Each
entry references a plugin's repository as a `github` source and omits `version`/`sha`/`commit`, so
installs track the plugin repo's default branch:

```json
{
  "name": "claude-oop-excellence",
  "source": { "source": "github", "repo": "odere-pro/claude-oop-excellence" }
}
```

Manage the registry with the agent-driven skills, in a session in this repo — `/vet-plugin <repo>`
(read-only preflight), `/add-plugin <repo>`, `/update-plugin <name>` (refresh / `--repo` repoint /
`--name` rename), `/remove-plugin <name>`. Each vets the target, edits the manifest, regenerates the
table above, updates the [`CHANGELOG`](CHANGELOG.md), runs the gates, and opens a PR. Full process,
contract, and the manual fallback: [`docs/adding-plugins.md`](docs/adding-plugins.md) ·
[`CONTRIBUTING.md`](CONTRIBUTING.md) · [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md).

Why a registry is built this way — as an agent-operable index — is in
[`SOFTWARE-3-0.md`](SOFTWARE-3-0.md). Governance: [`SECURITY.md`](SECURITY.md) ·
[`SUPPORT.md`](SUPPORT.md) · [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) ·
[`CHANGELOG.md`](CHANGELOG.md).

## License

[MIT](./LICENSE) © odere-pro
