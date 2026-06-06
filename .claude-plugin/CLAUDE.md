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
- **Each entry is a `github` source** whose `repo` is owned by **`odere-pro`** (matches
  `^odere-pro/[A-Za-z0-9._-]+$`). The entry `name` may differ from the repo basename — e.g.
  `plugin-cookbook` lives in `odere-pro/claude-plugin-cookbook`. Entry names are unique.
- **Each entry carries** `name`, `description`, `license` (plus `homepage`, `keywords` by convention).
- **Listing-quality floors (G2):** `description` is non-empty, ≥ 20 chars, and not a verbatim repeat of
  `name`; `keywords` is non-empty; `homepage` (when set) matches `^https://`. The top-level
  marketplace `description` is also non-empty and **≥ 40 chars** (W2.1). **Each entry must have at
  least one keyword NOT in the generic-keyword denylist** (`claude plugin tool utility helper code ai
  assistant cli`) — this is a hard FAIL, not advisory (W2.1). The denylist is parity-gated between G2
  and the Write-path hook (`marketplace-guard.sh`) via G0 §5.
- **`$schema` is pinned** to `https://json.schemastore.org/claude-code-marketplace.json` (exact
  string-equality, checked by G2 with no network call).
- **No `version`** on any entry — the plugin's own `plugin.json` is the version of record.
- **No `sha`/`commit`** — installs track the plugin repo's default branch.

## Editing

Prefer the agent-driven skills (see [`docs/adding-plugins.md`](../docs/adding-plugins.md)) over hand
edits: `/add-plugin <repo>` to list, `/update-plugin <name>` to refresh / repoint (`--repo`) / rename
(`--name`), `/remove-plugin <name>` to drop, `/vet-plugin <repo>` to preflight. A PreToolUse hook (`.claude/hooks/marketplace-guard.sh`) blocks edits that break JSON, rename the
marketplace, set a non-`odere-pro` repo, add a forbidden key, or embed a secret; a PostToolUse hook
keeps it two-space indented. The path-scoped rule `.claude/rules/marketplace-dev.md` restates the
contract. After editing, regenerate the README table
(`bash .claude/skills/add-plugin/scripts/sync-readme.sh`), update `CHANGELOG.md`, and run
`bash tests/gates/run-all.sh`.
