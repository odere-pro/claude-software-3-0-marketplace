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

| Plugin | Repo | What it does |
| --- | --- | --- |
| `claude-oop-excellence` | [odere-pro/claude-oop-excellence](https://github.com/odere-pro/claude-oop-excellence) | Language-agnostic OOP design enforcement: a read-only `/audit` front door runs RISK + PATTERN tracks in parallel into one unified report, with an audit → action handoff to gated, test-verified fixes. |
| `claude-calibration` | [odere-pro/claude-calibration](https://github.com/odere-pro/claude-calibration) | Audit and harden a Claude Code setup via an evaluate → plan → calibrate → re-evaluate loop, promoting recurring findings into enforcement (hooks/rules/wrapper skills). |

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

Append one block to the `plugins` array in `.claude-plugin/marketplace.json`, sync this table and
`CHANGELOG.md`, and run the gates. Full steps and the manifest contract are in
[`CONTRIBUTING.md`](CONTRIBUTING.md):

```json
{
  "name": "<plugin-name>",
  "source": { "source": "github", "repo": "odere-pro/<repo>" },
  "description": "...",
  "homepage": "https://github.com/odere-pro/<repo>",
  "license": "MIT"
}
```

## Developing this registry

This repo carries a full GitHub + Claude Code harness: validation gates (`tests/gates/`), CI and
supply-chain workflows (`.github/`), and an author-only `.claude/` harness. Why a registry is built
this way — as an agent-operable index — is in [`SOFTWARE-3-0.md`](SOFTWARE-3-0.md). Governance:
[`CONTRIBUTING.md`](CONTRIBUTING.md) · [`SECURITY.md`](SECURITY.md) · [`SUPPORT.md`](SUPPORT.md) ·
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## License

[MIT](./LICENSE) © odere-pro
