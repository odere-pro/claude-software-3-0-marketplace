# odere-pro Claude Code marketplace

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

Append one block to the `plugins` array in `.claude-plugin/marketplace.json` and push:

```json
{
  "name": "<plugin-name>",
  "source": { "source": "github", "repo": "odere-pro/<repo>" },
  "description": "...",
  "homepage": "https://github.com/odere-pro/<repo>",
  "license": "MIT"
}
```

## License

[MIT](./LICENSE) © odere-pro
