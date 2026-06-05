---
name: remove-plugin
description: >-
  Author-only maintenance skill for the odere-pro marketplace repo. Removes a listed plugin from the
  registry end to end: deletes its entry from .claude-plugin/marketplace.json, regenerates the README
  table, updates CHANGELOG, runs the gate suite, then opens a PR. Invoke explicitly as
  /remove-plugin <name>. Edits files.
disable-model-invocation: true
model: sonnet
argument-hint: "<name>"
allowed-tools: Read, Grep, Glob, Edit(.claude-plugin/marketplace.json), Edit(README.md), Edit(CHANGELOG.md), Bash(bash .claude/skills/add-plugin/scripts/remove-entry.sh:*), Bash(bash .claude/skills/add-plugin/scripts/sync-readme.sh:*), Bash(bash tests/gates/run-all.sh), Bash(claude plugin validate:*), Bash(git checkout:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(gh pr create:*)
---

# /remove-plugin

Remove a listed plugin from the marketplace, all the way to a PR. `$ARGUMENTS` is the entry `name`
(as it appears in `.claude-plugin/marketplace.json` / the README table).

## Steps

1. **Remove the entry.** Run `bash .claude/skills/add-plugin/scripts/remove-entry.sh <name>`. If the
   name isn't listed, the script errors — report that and stop (nothing to remove).
2. **Sync docs.** Run `bash .claude/skills/add-plugin/scripts/sync-readme.sh` (regenerates the table;
   shows the placeholder if that was the last plugin), and add a `CHANGELOG.md` bullet under
   `## [Unreleased]` (e.g. `- Remove \`<name>\` from the marketplace.`).
3. **Verify.** Run `bash tests/gates/run-all.sh` — it must be green. (`02-marketplace-shape` accepts an
   empty registry, so removing the last entry is fine.)
4. **PR.** Branch `chore/remove-<name>`, `git add` the manifest + README + CHANGELOG, commit
   `chore: remove <name> from the odere-pro marketplace` (human-authored — no AI attribution), push
   `-u`, `gh pr create` with a short body. Report the PR URL.

## Boundaries

- Touches only `.claude-plugin/marketplace.json`, `README.md`, `CHANGELOG.md`; never the plugin's own
  repo.
- Removal is by entry `name`; to change a plugin instead of dropping it, use `/update-plugin`.

## Failure handling

If any step fails (the name isn't listed, a gate goes red, or the PR push fails), **stop and roll
back** so the working tree is left exactly as it started — never half applied. Undo both the staged
and the working-tree state of the three files this skill touches:

```bash
git restore --staged .claude-plugin/marketplace.json README.md CHANGELOG.md
git restore .claude-plugin/marketplace.json README.md CHANGELOG.md
```

`git restore --staged …` first unstages anything `git add`ed in step 4; the second `git restore …`
discards the working-tree edits from steps 1–2. Then report what failed and what you reverted. Do not
commit or push a partial change.
