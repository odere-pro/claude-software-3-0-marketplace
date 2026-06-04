# Adding a plugin to the odere-pro marketplace

This is the canonical, agent-driven process for listing a plugin in the `odere-pro` registry. It is
**author-only** tooling — it edits this repo's `marketplace.json`, README, and CHANGELOG, and opens a
PR. It never edits the candidate's own repository.

## TL;DR

```text
/vet-plugin claude-aws-architect      # read-only: is it ready? what's blocking?
/add-plugin claude-aws-architect      # vet → edit manifest + README + CHANGELOG → gates → PR
```

`<repo>` defaults the owner to `odere-pro`; pass `owner/repo` to be explicit (owner must be
`odere-pro`). Add `--name <name>` to override the entry name.

## The contract (what makes a candidate listable)

A candidate is ready when **all** of these hold (enforced by
`.claude/skills/add-plugin/scripts/vet-candidate.sh`, the `marketplace-guard` hook, and
`tests/gates/02-marketplace-shape.sh`):

- **Owner is `odere-pro`.** The registry is odere-pro-only.
- **It has a valid `.claude-plugin/plugin.json`** with `name`, `description`, and `license`.
- **It ships no `.claude-plugin/marketplace.json` of its own.** A second repo declaring the marketplace
  name `odere-pro` silently shadows this registry — the collision that broke installs before. The
  plugin must be plugin-only.
- **It isn't already listed** here.

The entry written into `marketplace.json` is always a `github` source with **no `version`** (the
plugin's own `plugin.json` is the version of record) and **no `sha`/`commit`** (installs track the
default branch). The entry `name` may differ from the repo basename — e.g. `plugin-cookbook` lives in
`odere-pro/claude-plugin-cookbook`.

## How it works (the pieces)

| Piece | Role |
| ----- | ---- |
| `/add-plugin`, `/vet-plugin` | the skills you invoke (`.claude/skills/`) |
| `plugin-onboarder` | worker agent: fetches + vets the repo, curates description/keywords (`.claude/agents/`) |
| `vet-candidate.sh` | read-only preflight → JSON verdict (`ok` + `blockers[]` + entry fields) |
| `add-entry.sh` | re-vets, then inserts the entry with `jq` (idempotent, no duplicates) |
| `sync-readme.sh` | regenerates the README Plugins table from the manifest |
| gate `02-marketplace-shape` | CI enforcement of the contract above |
| gate `09-readme-in-sync` | README table can't drift from the manifest |

## Clearing the common blockers

- **"still ships `.claude-plugin/marketplace.json`"** — remove it in the candidate's own repo first
  (plus any CI gate that requires it), the same change made for `claude-oop-excellence` and
  `claude-calibration`: branch off `main`, `git rm .claude-plugin/marketplace.json`, keep `plugin.json`,
  PR. Then re-run `/add-plugin`.
- **"owner is …; lists odere-pro repos only"** — only `odere-pro`-owned repos can be listed.
- **"already listed"** — it's already in the marketplace; nothing to do.

## Manual fallback

If you'd rather edit by hand: append one `github`-source block to the `plugins` array in
`.claude-plugin/marketplace.json` (no `version`/`sha`), run
`bash .claude/skills/add-plugin/scripts/sync-readme.sh`, add a `CHANGELOG.md` bullet, then
`bash tests/gates/run-all.sh` and `claude plugin validate . --strict`. See
[`CONTRIBUTING.md`](../CONTRIBUTING.md).
