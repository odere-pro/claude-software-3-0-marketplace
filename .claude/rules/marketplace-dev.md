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
  - is a **`github` source**: `"source": { "source": "github", "repo": "odere-pro/<repo>" }`, where the
    owner is **`odere-pro`** (registry is odere-pro-only). The entry `name` may differ from the repo
    basename (e.g. `plugin-cookbook` lives in `claude-plugin-cookbook`);
  - carries `name`, `description`, `license` (and ideally `homepage`, `keywords`);
  - **omits `version`** — the plugin's own `plugin.json` is the version of record;
  - **omits `sha`/`commit`** — installs track the plugin repo's default branch.

## When you add or change an entry

Prefer the agent-driven workflow: `/add-plugin <repo>` (and `/vet-plugin <repo>` to preflight). It vets
the candidate, edits the manifest, regenerates the README table, updates CHANGELOG, runs the gates, and
opens a PR. See [`docs/adding-plugins.md`](../../docs/adding-plugins.md). If editing by hand:

1. The plugin must live in its own `odere-pro` repo and **must not** ship its own `marketplace.json`.
2. Regenerate the README table with `bash .claude/skills/add-plugin/scripts/sync-readme.sh` and add a
   `CHANGELOG.md` (`[Unreleased]`) bullet.
3. Run `bash tests/gates/run-all.sh` and `claude plugin validate . --strict` before committing.

## Don't

- Don't add a `plugin.json` or any component dirs (`skills/`, `agents/`, `hooks/`, `commands/`,
  `.mcp.json` as a *shipped* plugin) — this repo is not a plugin.
- Don't hand-format the manifest inconsistently — the `json-format.sh` PostToolUse hook keeps it
  two-space indented.
