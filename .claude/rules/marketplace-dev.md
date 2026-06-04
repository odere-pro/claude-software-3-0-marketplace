---
name: marketplace-dev
description: >-
  House rules for editing the odere-pro marketplace registry. Author-only — lives under .claude/ and
  is never shipped. Path-scoped so it loads only when you touch the manifest.
paths:
  - ".claude-plugin/**"
---

# Marketplace-registry house rules

This repo is a **registry only**: the single source of truth is
`.claude-plugin/marketplace.json`. There is no `plugin.json` and no plugin components.

## The manifest contract (enforced by `tests/gates/02-marketplace-shape.sh`)

- Top-level `name` is exactly **`odere-pro`**. Claude Code keys marketplaces by name — a second repo
  declaring `odere-pro` would silently shadow this one, so the name is load-bearing and pinned.
- `owner.name` + `owner.email` are present.
- Every `plugins[]` entry:
  - is a **`github` source**: `"source": { "source": "github", "repo": "odere-pro/<name>" }`, where
    `repo` equals `odere-pro/` + the entry's `name`;
  - carries `name`, `description`, `license` (and ideally `homepage`, `keywords`);
  - **omits `version`** — the plugin's own `plugin.json` is the version of record;
  - **omits `sha`/`commit`** — installs track the plugin repo's default branch.

## When you add or change an entry

1. The plugin must live in its own `odere-pro` repo and **must not** ship its own `marketplace.json`.
2. Keep `README.md` (the Plugins table) and `CHANGELOG.md` (`[Unreleased]`) in sync with the manifest.
3. Run `bash tests/gates/run-all.sh` and `claude plugin validate . --strict` before committing.

## Don't

- Don't add a `plugin.json` or any component dirs (`skills/`, `agents/`, `hooks/`, `commands/`,
  `.mcp.json` as a *shipped* plugin) — this repo is not a plugin.
- Don't hand-format the manifest inconsistently — the `json-format.sh` PostToolUse hook keeps it
  two-space indented.
