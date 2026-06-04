---
name: update-plugin
description: >-
  Author-only maintenance skill for the odere-pro marketplace repo. Updates a listed plugin's entry:
  refreshes its description/keywords/homepage/license from the source repo's plugin.json, and can
  repoint it to a different odere-pro repo (--repo) or rename it (--name). Regenerates the README,
  updates CHANGELOG, runs gates, opens a PR. Invoke explicitly as /update-plugin <name>. Edits files.
disable-model-invocation: true
model: sonnet
argument-hint: "<name> [--repo <owner/repo>] [--name <new-name>]"
allowed-tools: Read, Grep, Glob, Agent, Edit(.claude-plugin/marketplace.json), Edit(README.md), Edit(CHANGELOG.md), Bash(bash .claude/skills/add-plugin/scripts/vet-candidate.sh:*), Bash(bash .claude/skills/add-plugin/scripts/update-entry.sh:*), Bash(bash .claude/skills/add-plugin/scripts/sync-readme.sh:*), Bash(bash tests/gates/run-all.sh), Bash(claude plugin validate:*), Bash(git checkout:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(gh pr create:*)
---

# /update-plugin

Update a listed plugin's entry, all the way to a PR. Covers **refresh** (re-pull metadata from the
plugin's `plugin.json`), **replace/repoint** (`--repo <owner/repo>`), and **rename** (`--name`).

`$ARGUMENTS`: the existing entry `name`, plus optional `--repo <owner/repo>` and `--name <new-name>`.

## Steps

1. **Confirm it's listed.** The entry `<name>` must exist in `.claude-plugin/marketplace.json`; if not,
   tell the user to use `/add-plugin` and stop.
2. **Re-vet + curate.** Delegate to the `plugin-onboarder` subagent in **update mode** for the target
   repo (the `--repo` override, or the entry's current `source.repo`): it runs
   `vet-candidate.sh --skip-listed-check <repo>` and, if clean, returns a refreshed `description` /
   `keywords` proposal. If blocked (e.g. the target now ships its own `marketplace.json`, or the owner
   isn't `odere-pro`), print the blockers and **stop**.
3. **Apply.** Run
   `bash .claude/skills/add-plugin/scripts/update-entry.sh <name> [--repo …] [--name …] [--description "…"] [--keywords a,b]`
   with the curated values. It re-vets and replaces the entry in place.
4. **Sync docs.** Run `bash .claude/skills/add-plugin/scripts/sync-readme.sh` and add a `CHANGELOG.md`
   bullet under `## [Unreleased]` (e.g. `- Update \`<name>\` …`).
5. **Verify.** Run `bash tests/gates/run-all.sh` and `claude plugin validate .` — both green.
6. **PR.** Branch `feat/update-<name>`, `git add` the manifest + README + CHANGELOG, commit
   `feat: update <name> in the odere-pro marketplace` (human-authored), push `-u`, `gh pr create`.
   Report the PR URL.

## Boundaries

- The entry must already exist (this never adds). odere-pro repos only; never edits the plugin's repo.
- Touches only `.claude-plugin/marketplace.json`, `README.md`, `CHANGELOG.md`; never sets
  `version`/`sha`/`commit`.
