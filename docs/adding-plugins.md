# Managing odere-pro marketplace plugins

This is the canonical, agent-driven process for **adding, updating, and removing** plugins in the
`odere-pro` registry. It is **author-only** tooling — it edits this repo's `marketplace.json`, README,
and CHANGELOG, and opens a PR. It never edits a plugin's own repository.

## TL;DR

```text
/vet-plugin   claude-aws-architect           # read-only: is it ready? what's blocking?
/add-plugin   claude-aws-architect           # add: vet → manifest + README + CHANGELOG → gates → PR
/update-plugin claude-aws-architect          # refresh metadata from the plugin's plugin.json
/update-plugin claude-aws-architect --repo odere-pro/new-repo   # replace / repoint
/update-plugin claude-aws-architect --name aws-architect        # rename the entry
/remove-plugin claude-aws-architect          # drop the entry
```

`<repo>` defaults the owner to `odere-pro`; pass `owner/repo` to be explicit (owner must be
`odere-pro`). `/add-plugin` and `/update-plugin` accept `--name <name>` to set/override the entry name;
`/remove-plugin` and `/update-plugin` take the entry **name** as it appears in the registry.

## The contract (what makes a candidate listable)

A candidate is ready when **all** of these hold (enforced by
`.claude/skills/add-plugin/scripts/vet-candidate.sh`, the `marketplace-guard` hook, and
`tests/gates/02-marketplace-shape.sh`):

- **Owner is `odere-pro`.** The registry is odere-pro-only.
- **It has a valid `.claude-plugin/plugin.json`** with `name`, `description`, and `license`.
- **It ships at least one component directory** — `commands/`, `agents/`, `skills/`, or `hooks/`. A
  plugin with a `plugin.json` but no components is an empty shell. The vet probes these directories
  directly (a constant-cost `contents/<dir>` check, stopping at the first one found — never a
  recursive tree walk), so it stays within the add-time API budget.
- **It ships no `.claude-plugin/marketplace.json` of its own.** A second repo declaring the marketplace
  name `odere-pro` silently shadows this registry — the collision that broke installs before. The
  plugin must be plugin-only.
- **It isn't already listed** here.
- **The listing meets the quality floors** (G2 enforces these on every entry): `description` is
  non-empty, at least 20 characters, and is not just a repeat of the entry `name`; `keywords` lists at
  least one term; and `homepage` (when present) starts with `https://`. These keep each listing
  useful for discovery rather than a bare stub. The generic-keyword denylist
  (e.g. `claude-code`, `plugin`) is **advisory** — `plugin-onboarder` drops generic noise during
  curation, but a generic keyword does not by itself block a listing.

The entry written into `marketplace.json` is always a `github` source with **no `version`** (the
plugin's own `plugin.json` is the version of record) and **no `sha`/`commit`** (installs track the
default branch). The entry `name` may differ from the repo basename — e.g. `plugin-cookbook` lives in
`odere-pro/claude-plugin-cookbook`.

## Pre-submission checklist (candidate repo)

Before `/add-plugin`, confirm the candidate repo satisfies the contract. The vet runs all of this
automatically, but you can self-check first:

- [ ] The repo is **`odere-pro`-owned** and is a plugin (ships `.claude-plugin/plugin.json`).
- [ ] `plugin.json` has a non-empty **`name`**, **`description`**, and an SPDX **`license`** in the
      allowlist (`MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0`).
- [ ] The repo ships **no `.claude-plugin/marketplace.json`** of its own (it would shadow this registry).
- [ ] The repo ships **at least one component directory** (`commands/`, `agents/`, `skills/`, or `hooks/`).
- [ ] `description` is ≥ 20 characters and is not just the `name`; `keywords` lists ≥ 1 term;
      `homepage` (if set) starts with `https://`.

Validate the candidate's `plugin.json` shape locally with one `jq` line (no schema file is hosted
here — the SPDX allowlist and field rules live in `vet-candidate.sh` + `02-marketplace-shape.sh`, so
there is nothing to version-drift):

```bash
gh api repos/<owner>/<repo>/contents/.claude-plugin/plugin.json --jq '.content' | base64 -d \
  | jq -e 'has("name") and has("description") and has("license")
           and (.name|length>0) and (.description|length>=20) and (.license|length>0)' \
  && echo "plugin.json has the required fields" || echo "plugin.json is missing a required field"
```

## How it works (the pieces)

| Piece | Role |
| ----- | ---- |
| `/add-plugin`, `/vet-plugin`, `/update-plugin`, `/remove-plugin` | the skills you invoke (`.claude/skills/`) |
| `plugin-onboarder` | worker agent: fetches + vets the repo, curates description/keywords (`.claude/agents/`) |
| `vet-candidate.sh` | read-only preflight → JSON verdict (`ok` + `blockers[]` + entry fields); `--skip-listed-check` for updates |
| `add-entry.sh` | re-vets, then inserts the entry with `jq` (idempotent, no duplicates) |
| `update-entry.sh` | re-vets, then replaces an existing entry in place (refresh / repoint / rename) |
| `remove-entry.sh` | deletes an entry by name with `jq` |
| `sync-readme.sh` | regenerates the README Plugins table from the manifest |
| gate `02-marketplace-shape` | CI enforcement of the contract above (allows an empty registry) |
| gate `09-readme-in-sync` | README table can't drift from the manifest |

## Clearing the common blockers

- **"still ships `.claude-plugin/marketplace.json`"** — remove it in the candidate's own repo first
  (plus any CI gate that requires it), the same change made for `claude-oop-excellence` and
  `claude-calibration`: branch off `main`, `git rm .claude-plugin/marketplace.json`, keep `plugin.json`,
  PR. Then re-run `/add-plugin`.
- **"owner is …; lists odere-pro repos only"** — only `odere-pro`-owned repos can be listed.
- **"ships no plugin component directory"** — add at least one of `commands/`, `agents/`, `skills/`,
  or `hooks/` to the candidate repo (a plugin needs at least one component to do anything), then
  re-run the vet.
- **"already listed"** — it's already in the marketplace; nothing to do.

## Updating or replacing a plugin

`/update-plugin <name>` operates on an **already-listed** entry and re-vets the target repo with
`--skip-listed-check` (so "already listed" isn't a blocker), then replaces the entry in place:

- **Refresh** — `/update-plugin <name>` re-pulls `description` / `keywords` / `homepage` / `license`
  from the plugin's current `plugin.json` (use after the plugin changes its manifest).
- **Replace / repoint** — `/update-plugin <name> --repo odere-pro/<new-repo>` points the same entry at a
  different odere-pro repo (the new repo is vetted like any candidate).
- **Rename** — `/update-plugin <name> --name <new-name>` renames the entry (refuses a name that collides
  with another entry).

It only ever changes an existing entry; to add a brand-new one use `/add-plugin`.

## Removing a plugin

`/remove-plugin <name>` deletes the entry by name, regenerates the README (showing the placeholder if it
was the last plugin), updates CHANGELOG, runs the gates, and opens a PR. Removing the last entry leaves
`plugins: []`, which is allowed.

## Empty registry

The marketplace starts with **no plugins**; they're added one at a time (after testing) via
`/add-plugin`. While the `plugins` array is empty, `bash tests/gates/run-all.sh` is green, but
`claude plugin validate --strict` warns "Marketplace has no plugins defined" — that's expected. The
gate suite is the authoritative check; `--strict` validation becomes meaningful once the first plugin
is listed.

## Manual fallback

If you'd rather edit by hand: append one `github`-source block to the `plugins` array in
`.claude-plugin/marketplace.json` (no `version`/`sha`), run
`bash .claude/skills/add-plugin/scripts/sync-readme.sh`, add a `CHANGELOG.md` bullet, then
`bash tests/gates/run-all.sh` (and `claude plugin validate .`). See
[`CONTRIBUTING.md`](../CONTRIBUTING.md).
