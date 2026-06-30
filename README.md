# odere-pro Claude Code marketplace

[![CI](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml/badge.svg)](https://github.com/odere-pro/claude-software-3-0-marketplace/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code marketplace](https://img.shields.io/badge/Claude%20Code-marketplace-8A2BE2)](https://docs.claude.com/en/docs/claude-code/plugins)

This is the registry for the [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins and
tools I ([`odere-pro`](https://github.com/odere-pro)) build to improve my own agentic setup. Each
tool lives in its own repository and is listed here — **add this marketplace once, then install any
plugin individually.** The marketplace `name` is **`odere-pro`**, so installs are always
`<plugin>@odere-pro`, whatever this repo is called.

> 🔎 Browse the catalog with live search at
> **[odere-pro.github.io/claude-software-3-0-marketplace](https://odere-pro.github.io/claude-software-3-0-marketplace/)**.

## Requirements

- **[Claude Code](https://docs.claude.com/en/docs/claude-code/setup) with a working `/plugin`
  command.** `/plugin` is generally available — if you don't see it, [update Claude
  Code](https://docs.claude.com/en/docs/claude-code/setup).
- **`git`** and **`bash`** on your `PATH`.
- A few plugins also need **Node.js / Bun** or **`jq`** — each plugin's [guide](#plugins) lists its
  own prerequisites.

New to any of these? See the [FAQ](#faq) for one-line install pointers.

## Install

Two ways to install, depending on whether you want a tool everywhere or scoped to one project. Both
work from the in-session `/plugin` command **or** the `claude plugin` shell CLI.

### Global (per-user — the default)

Available in every repo you open; recorded in `~/.claude/settings.json`.

In a Claude Code session — submit each as its **own** command (let `marketplace add` finish first):

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
/plugin install <plugin>@odere-pro
```

Or from the shell:

```bash
claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
claude plugin install <plugin>@odere-pro
```

A session restart may be needed to load the plugin's commands, agents, and hooks. Then follow its
[quick-start guide](#plugins).

### Project-local (scoped to one repo, shared with your team)

Commit the marketplace and the plugins you want into a project's `.claude/settings.json`. Anyone who
clones the repo and trusts the folder gets the same tools — nothing global to install:

```json
{
  "extraKnownMarketplaces": {
    "odere-pro": {
      "source": { "source": "github", "repo": "odere-pro/claude-software-3-0-marketplace" }
    }
  },
  "enabledPlugins": {
    "<plugin>@odere-pro": true
  }
}
```

Or do it in one command from the shell — `--scope project` installs the plugin into
`./.claude/settings.json` and auto-registers the marketplace at project scope:

```bash
claude plugin install <plugin>@odere-pro --scope project
```

That one-command form is what the [catalog below](#plugins) lists per plugin (install + update).

## Manage installed plugins

Update, remove, or inspect anything you've installed — from a session or the shell:

```text
/plugin marketplace update odere-pro     # refresh the catalog listing
/plugin uninstall <plugin>@odere-pro     # remove a plugin
/plugin list                             # what's installed / enabled
```

```bash
claude plugin update <plugin>@odere-pro     # pull the latest from the plugin's default branch
claude plugin uninstall <plugin>@odere-pro  # remove it
claude plugin list                          # what's installed / enabled
claude plugin details <plugin>@odere-pro    # component inventory + projected token cost
```

## Plugins

<!-- The table below is generated from .claude-plugin/marketplace.json by
     .claude/skills/add-plugin/scripts/sync-readme.sh. Don't edit it by hand. -->
<!-- BEGIN PLUGINS -->
| Plugin | Description | Install / update (current project) |
| --- | --- | --- |
| [`claude-oop-excellence`](https://github.com/odere-pro/claude-oop-excellence) | Audits and refactors codebases for object-oriented design quality. | `claude plugin install claude-oop-excellence@odere-pro --scope project`<br>`claude plugin update claude-oop-excellence@odere-pro --scope project` |
| [`claude-wiki-pages`](https://github.com/odere-pro/claude-wiki-pages-plugin) | Turns an Obsidian vault into a provenance-tracked LLM knowledge base on Karpathy's LLM Wiki pattern. | `claude plugin install claude-wiki-pages@odere-pro --scope project`<br>`claude plugin update claude-wiki-pages@odere-pro --scope project` |
| [`claude-calibration`](https://github.com/odere-pro/claude-calibration) | Continuous evaluate-plan-calibrate-re-evaluate loop over Claude Code setups. | `claude plugin install claude-calibration@odere-pro --scope project`<br>`claude plugin update claude-calibration@odere-pro --scope project` |
| [`authentic-writing`](https://github.com/odere-pro/authentic-writing) | Router-first writing engine. | `claude plugin install authentic-writing@odere-pro --scope project`<br>`claude plugin update authentic-writing@odere-pro --scope project` |
<!-- END PLUGINS -->

**Start using →** each plugin ships an install + quick-start guide, so you can go from "added the
marketplace" to "ran the plugin" without leaving this repo:
[claude-oop-excellence](docs/plugins/claude-oop-excellence.md) ·
[claude-wiki-pages](docs/plugins/claude-wiki-pages.md) ·
[claude-calibration](docs/plugins/claude-calibration.md).

The table is generated from [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) — the
source of truth for what's listed.

## FAQ

**I don't have Claude Code / the `/plugin` command.** Install or update Claude Code from the
[official setup guide](https://docs.claude.com/en/docs/claude-code/setup); `/plugin` ships in current
versions.

**How do I install Git?** Get it from [git-scm.com/downloads](https://git-scm.com/downloads) (macOS:
`xcode-select --install` also provides it; most Linux distros ship it via their package manager).

**How do I install Node.js?** Download the LTS build from
[nodejs.org](https://nodejs.org/en/download); that includes `npm`.

**How do I manage Node versions (NVM)?** Use [nvm](https://github.com/nvm-sh/nvm#installing-and-updating)
(macOS/Linux) — `nvm install --lts` then `nvm use --lts`. On Windows, use
[nvm-windows](https://github.com/coreybutler/nvm-windows).

**`URL rejected: Malformed input…` when adding the marketplace.** Two commands were submitted on one
line, so `marketplace add` swallowed the next as part of the repo argument. Run each command on its
own line, `marketplace add` first.

**`already installed`, or the plugin loads from a local path.** A prior local/dev install (e.g.
`--plugin-dir`, or the plugin's repo added as its own marketplace) shadows the marketplace copy.
Uninstall, then reinstall so it resolves cleanly:

```bash
claude plugin uninstall <plugin>@odere-pro
claude plugin install <plugin>@odere-pro
```

Install everything through the one `odere-pro` marketplace (`<plugin>@odere-pro`) — don't also
register an individual plugin's repo as a separate marketplace, or same-name entries collide.

**I want to contribute or add a plugin.** See [`CONTRIBUTING.md`](CONTRIBUTING.md) and
[`docs/adding-plugins.md`](docs/adding-plugins.md).

## License

[MIT](./LICENSE) © odere-pro
