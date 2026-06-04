# Contributing

This repo is the **`odere-pro` marketplace registry**. The one source of truth is
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json); everything else is governance,
CI, and an author-only `.claude/` harness.

## Adding a plugin

The easy, accurate path is the agent-driven workflow — in a Claude Code session in this repo:

```text
/vet-plugin <repo>             # read-only preflight: ready? what's blocking?
/add-plugin <repo>             # add: vet → edit manifest + README + CHANGELOG → gates → PR
/update-plugin <name>          # refresh metadata; --repo to repoint, --name to rename
/remove-plugin <name>          # drop an entry
```

It vets the candidate, inserts a well-formed entry, regenerates the README table, updates the
changelog, runs the gates, and opens the PR for you. The full process, the listability contract, and
how to clear each blocker are in [`docs/adding-plugins.md`](docs/adding-plugins.md).

**Requirements for a candidate** (also enforced by `tests/gates/02-marketplace-shape.sh`):

- The plugin lives in its **own** `odere-pro` repo with a valid `.claude-plugin/plugin.json`
  (`name` + `description` + `license`).
- It ships **no** `.claude-plugin/marketplace.json` of its own — a second repo declaring the name
  `odere-pro` would shadow this registry (see [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md)).
- The entry omits `version` (the plugin's own `plugin.json` is the version of record) and `sha`/`commit`.
  The entry `name` may differ from the repo basename.

**Manual fallback:** append one `github`-source block to `.claude-plugin/marketplace.json`, run
`bash .claude/skills/add-plugin/scripts/sync-readme.sh`, add a `CHANGELOG.md` bullet, then:

```bash
bash tests/gates/run-all.sh          # authoritative check (CI runs this)
claude plugin validate .
```

> The registry starts **empty**. While there are zero entries, `claude plugin validate --strict` warns
> "Marketplace has no plugins defined" — expected; the gate suite is the green check. Once the first
> plugin is listed, `--strict` is meaningful again.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/): `<type>: <subject>`, where `type` is
one of `feat fix docs refactor test chore perf ci build`. Keep each commit to one logical change.
Commits are human-authored — no AI attribution trailers (a local hook enforces this).

## Before you open a PR

- `bash tests/gates/run-all.sh` is green and `claude plugin validate . --strict` exits 0.
- README + CHANGELOG are in sync with `marketplace.json`.

## Reporting issues

Security vulnerabilities go through [`SECURITY.md`](SECURITY.md), not public issues. By participating
you agree to the [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
