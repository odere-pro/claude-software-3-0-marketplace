# odere-pro Claude Code marketplace

[![CI](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code marketplace](https://img.shields.io/badge/Claude%20Code-marketplace-8A2BE2)](https://docs.claude.com/en/docs/claude-code/plugins)

The single [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for
[`odere-pro`](https://github.com/odere-pro). Each plugin lives in its **own** repository and is
aggregated here, so you add this marketplace once and install any plugin individually.

The marketplace `name` is **`odere-pro`** — installs are always `<plugin>@odere-pro`, regardless of
this repo's name.

## Add the marketplace

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
```

## Install plugins

```text
/plugin install claude-oop-excellence@odere-pro
/plugin install claude-calibration@odere-pro
```

## Plugins

<!-- The table below is generated from .claude-plugin/marketplace.json by
     .claude/skills/add-plugin/scripts/sync-readme.sh. Don't edit it by hand. -->
<!-- BEGIN PLUGINS -->
| Plugin | Repo | What it does |
| --- | --- | --- |
| `claude-oop-excellence` | [odere-pro/claude-oop-excellence](https://github.com/odere-pro/claude-oop-excellence) | Language-agnostic OOP design enforcement. A single read-only /audit front door runs two tracks in parallel — RISK (issues) and PATTERN (existing-pattern scan + pattern-fit suggestions) — into one unified report; every track / aspect / family / entity is individually selectable. Driven by a canonical glossary of 102 entities (45 issues + 57 design patterns), with glossary-driven workers fanning out per family in parallel and an audit → action handoff to gated, test-verified fix and implement commands. |
| `claude-calibration` | [odere-pro/claude-calibration](https://github.com/odere-pro/claude-calibration) | Audit and harden a Claude Code setup: an evaluate → plan → calibrate → re-evaluate loop over CLAUDE.md, rules, settings, skills, subagents, hooks, MCP, and plugins, where recurring findings are promoted into enforcement (hooks/rules/wrapper skills). |
<!-- END PLUGINS -->

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

### Adding a plugin

The easy path is the agent-driven workflow — in a Claude Code session in this repo:

```text
/vet-plugin <repo>     # read-only: is the candidate ready? what's blocking?
/add-plugin <repo>     # vet → edit manifest + README + CHANGELOG → run gates → open a PR
```

It vets the candidate (odere-pro owner, valid `plugin.json`, ships no `marketplace.json` of its own),
inserts the entry, regenerates the table above, and opens a PR. Full process, contract, and the manual
fallback are in [`docs/adding-plugins.md`](docs/adding-plugins.md) and
[`CONTRIBUTING.md`](CONTRIBUTING.md). A manifest entry looks like:

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
