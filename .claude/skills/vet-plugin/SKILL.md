---
name: vet-plugin
description: >-
  Author-only read-only preflight for the odere-pro marketplace repo. Checks whether a candidate repo
  is ready to list — owner is odere-pro, it has a valid plugin.json with name/description/license, it
  ships no marketplace.json of its own, and it isn't already listed — and reports go/no-go with
  blockers. Makes no edits. Invoke explicitly as /vet-plugin <repo>. Run before /add-plugin.
disable-model-invocation: true
model: sonnet
argument-hint: "<repo|owner/repo>"
allowed-tools: Read, Bash(bash .claude/skills/add-plugin/scripts/vet-candidate.sh:*)
---

# /vet-plugin

Read-only preflight for a candidate plugin. Reports whether it can be listed and, if not, exactly why.
Edits nothing — use `/add-plugin` to actually list it.

`$ARGUMENTS` is the candidate repo (`<repo>` defaults the owner to `odere-pro`, or `owner/repo`).

## Steps

1. Run `bash .claude/skills/add-plugin/scripts/vet-candidate.sh $ARGUMENTS`.
2. Parse the JSON verdict and report:
   - **Ready** (`ok: true`) → show the entry it would produce (name, repo, description, license,
     keywords) and suggest `/add-plugin $ARGUMENTS`.
   - **Blocked** (`ok: false`) → list each `blockers[]` item with the fix. For "still ships
     marketplace.json", point to [`docs/adding-plugins.md`](../../../docs/adding-plugins.md) and the
     oop/calibration-style removal.
