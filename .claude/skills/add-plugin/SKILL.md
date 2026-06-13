---
name: add-plugin
description: >-
  Author-only maintenance skill for the odere-pro marketplace repo. Adds an odere-pro plugin to the
  registry end to end: vets the candidate repo, inserts a well-formed entry into
  .claude-plugin/marketplace.json, regenerates the README table, updates CHANGELOG, runs the gate
  suite, then opens a PR. Invoke explicitly as /add-plugin <repo> [--name <name>]. Edits files.
disable-model-invocation: true
model: sonnet
argument-hint: "<repo|owner/repo> [--name <name>] [--description \"…\"] [--keywords a,b,c]"
allowed-tools: Read, Grep, Glob, Agent, Edit(.claude-plugin/marketplace.json), Edit(README.md), Edit(CHANGELOG.md), Bash(bash .claude/skills/add-plugin/scripts/vet-candidate.sh:*), Bash(bash .claude/skills/add-plugin/scripts/add-entry.sh:*), Bash(bash .claude/skills/add-plugin/scripts/sync-readme.sh:*), Bash(bash .claude/skills/add-plugin/scripts/sync-site.sh:*), Bash(bash tests/gates/run-all.sh), Bash(claude plugin validate:*), Bash(git checkout:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(gh pr create:*)
---

# /add-plugin

Add an `odere-pro` plugin to this marketplace, all the way to a PR. The deterministic file surgery is
done by the bundled scripts under `${CLAUDE_SKILL_DIR}/scripts/`; this skill orchestrates and handles
judgment (curated description / keywords). The full process and contract are in
[`docs/adding-plugins.md`](../../../docs/adding-plugins.md).

`$ARGUMENTS` is the candidate repo (`<repo>` defaults the owner to `odere-pro`, or pass `owner/repo`),
plus optional `--name <name>` to override the entry name.

## Steps

1. **Vet + curate.** Delegate to the `plugin-onboarder` subagent with the repo argument. It runs
   `vet-candidate.sh`, and if clean, returns a structured proposal: `repo`, `name`, a
   marketplace-quality `description`, `homepage`, `license`, `keywords`, and any `blockers`.
   If `--description` or `--keywords` were supplied by the caller, they override the subagent's
   curated values when passed to `add-entry.sh` in step 3.
2. **Stop on blockers.** If the proposal is not `ok`, print each blocker and the fix and **stop** — make
   no edits. The most common blocker: the candidate still ships its own `.claude-plugin/marketplace.json`
   (the `odere-pro` name collision). Tell the user to remove it in that repo first (the same change made
   for claude-oop-excellence / claude-calibration), then re-run. See `docs/adding-plugins.md`.
3. **Insert the entry.** Run
   `bash ${CLAUDE_SKILL_DIR}/scripts/add-entry.sh <repo> [--name …] [--description "…"] [--keywords a,b]`,
   passing the curated description/keywords. The script re-vets, refuses duplicates, and writes the
   entry with `jq --indent 2`.
4. **Sync docs.** Run `bash ${CLAUDE_SKILL_DIR}/scripts/sync-readme.sh` to regenerate the README
   Plugins table **and** `bash ${CLAUDE_SKILL_DIR}/scripts/sync-site.sh` to regenerate the Pages
   `site/` (gate `18-pages-in-sync` fails if `site/` drifts from the manifest), then add a
   `CHANGELOG.md` bullet under `## [Unreleased]` (e.g. `- List \`<name>\`.`).
5. **Verify.** Run `bash tests/gates/run-all.sh` and `claude plugin validate . --strict`. Both must be
   green before continuing.
6. **PR.** Create a branch `feat/add-<name>`, `git add` the manifest + README + CHANGELOG + `site/`, commit
   `feat: list <name> in the odere-pro marketplace` (human-authored — no AI attribution), push `-u`,
   and `gh pr create` with a short body. Report the PR URL.

## Boundaries

- odere-pro repos only; never edits a candidate's own repository (block-with-instructions).
- Touches only `.claude-plugin/marketplace.json`, `README.md`, `CHANGELOG.md`, and the generated `site/`.
- Never sets `version`/`sha`/`commit` on an entry; the scripts and the `marketplace-guard` hook enforce it.

## Failure handling

If any step fails (a blocker surfaces, a gate goes red, `claude plugin validate` errors, or the PR
push fails), **stop and roll back** so the working tree is left exactly as it started — never half
applied. Undo both the staged and the working-tree state of the paths this skill touches:

```bash
git restore --staged .claude-plugin/marketplace.json README.md CHANGELOG.md site/
git restore .claude-plugin/marketplace.json README.md CHANGELOG.md site/
```

`git restore --staged …` first unstages anything `git add`ed in step 6; the second `git restore …`
discards the working-tree edits from steps 3–4. Then report what failed and what you reverted. Do not
commit or push a partial change.
