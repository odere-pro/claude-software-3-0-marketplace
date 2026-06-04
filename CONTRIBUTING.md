# Contributing

This repo is the **`odere-pro` marketplace registry**. The one source of truth is
[`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json); everything else is governance,
CI, and an author-only `.claude/` harness.

## Adding a plugin

1. The plugin must live in its **own** `odere-pro` repository and ship a valid
   `.claude-plugin/plugin.json`. It must **not** ship its own `marketplace.json` — this registry is the
   single marketplace named `odere-pro`, and a second repo declaring that name would shadow this one
   (see [`.claude-plugin/CLAUDE.md`](.claude-plugin/CLAUDE.md)).
2. Append **one** block to the `plugins` array in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<plugin-name>",
     "source": { "source": "github", "repo": "odere-pro/<plugin-name>" },
     "description": "What it does — lifted from the plugin's plugin.json.",
     "homepage": "https://github.com/odere-pro/<plugin-name>",
     "license": "MIT",
     "keywords": ["..."]
   }
   ```

   - `source.repo` must equal `odere-pro/<name>`. **Omit `version`** (the plugin's own `plugin.json` is
     the version of record) and **omit `sha`/`commit`** (installs track the default branch).
3. Add a matching row to the **Plugins** table in `README.md` and a bullet under `[Unreleased]` in
   `CHANGELOG.md`.
4. Run the gate suite — it must be green:

   ```bash
   bash tests/gates/run-all.sh
   claude plugin validate . --strict
   ```

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
