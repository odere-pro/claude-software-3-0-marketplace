# odere-pro Claude Code marketplace

[![CI](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code marketplace](https://img.shields.io/badge/Claude%20Code-marketplace-8A2BE2)](https://docs.claude.com/en/docs/claude-code/plugins)

The single [Claude Code](https://docs.claude.com/en/docs/claude-code) plugin marketplace for
[`odere-pro`](https://github.com/odere-pro). Each plugin lives in its **own** repository and is
aggregated here, so you add this marketplace once and install any plugin individually.

The marketplace `name` is **`odere-pro`** — installs are always `<plugin>@odere-pro`, regardless of
this repo's name.

> **Status:** the registry is starting **empty** — plugins are added one at a time (after testing) via
> the [`/add-plugin`](#managing-plugins) workflow. The list below is the source of truth.

## Add the marketplace

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
```

## Install plugins

No plugins are listed yet (see the table below). Once a plugin is listed, install it with:

```text
/plugin install <plugin>@odere-pro
```

## Plugins

<!-- The table below is generated from .claude-plugin/marketplace.json by
     .claude/skills/add-plugin/scripts/sync-readme.sh. Don't edit it by hand. -->
<!-- BEGIN PLUGINS -->
_No plugins listed yet — add one with `/add-plugin <repo>` (see [docs/adding-plugins.md](docs/adding-plugins.md))._
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
