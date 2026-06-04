# `.claude-plugin/` — the registry manifest (deepest detail)

This directory holds `marketplace.json`, the **single source of truth** for the `odere-pro`
marketplace. It is the only thing this repo ships. There is intentionally **no `plugin.json`** here —
this is a registry, not a plugin.

## `marketplace.json` shape

```json
{
  "$schema": "https://json.schemastore.org/claude-code-marketplace.json",
  "name": "odere-pro",
  "owner": { "name": "odere-pro", "email": "odere.pro@gmail.com" },
  "description": "…",
  "plugins": [
    {
      "name": "claude-oop-excellence",
      "source": { "source": "github", "repo": "odere-pro/claude-oop-excellence" },
      "description": "…",
      "homepage": "https://github.com/odere-pro/claude-oop-excellence",
      "license": "MIT",
      "keywords": ["…"]
    }
  ]
}
```

## Invariants (every one is gated by `tests/gates/02-marketplace-shape.sh`)

- **`name` is exactly `odere-pro`.** Claude Code keys marketplaces by name. If any *other* repo also
  declares a marketplace named `odere-pro`, only one registers and the other is silently shadowed —
  the install failure that motivated consolidating everything here. So the name is load-bearing and
  must never drift, and listed plugins' own repos must ship **no** `marketplace.json`.
- **Each entry is a `github` source** whose `repo` is `odere-pro/<entry-name>` (the entry `name` and
  the repo basename match).
- **Each entry carries** `name`, `description`, `license` (plus `homepage`, `keywords` by convention).
- **No `version`** on any entry — the plugin's own `plugin.json` is the version of record.
- **No `sha`/`commit`** — installs track the plugin repo's default branch.

## Editing

A PreToolUse hook (`.claude/hooks/marketplace-guard.sh`) blocks edits that break JSON, rename the
marketplace, add a forbidden key, or embed a secret; a PostToolUse hook keeps it two-space indented.
The path-scoped rule `.claude/rules/marketplace-dev.md` restates the contract. After editing, sync
`README.md` + `CHANGELOG.md` and run `bash tests/gates/run-all.sh`.
