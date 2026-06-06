---
name: list-plugins
description: >-
  Author-only read-only enumeration skill for the odere-pro marketplace repo. Prints one line per
  listed plugin (name -- install coordinate -- description), or "No plugins listed." when the
  registry is empty. Makes no edits. Invoke explicitly as /list-plugins.
disable-model-invocation: true
model: sonnet
argument-hint: ""
allowed-tools: Read, Bash(jq:*)
---

# /list-plugins

List every plugin currently in the marketplace with a one-line summary. Read-only — edits nothing.

## Steps

1. **Read the manifest.** Run the following `jq` query against `.claude-plugin/marketplace.json`:

   ```bash
   jq -r '
     if (.plugins | length) == 0 then
       "No plugins listed."
     else
       .plugins[] | .name + " -- " + .source.repo + " -- " + .description
     end
   ' .claude-plugin/marketplace.json
   ```

2. **Print the result.** Each plugin appears as one line:

   ```
   <name> -- odere-pro/<repo> -- <description>
   ```

   If the registry is empty the single line `No plugins listed.` is printed.

## Failure handling

This skill is **read-only** — it edits no files, so there is nothing to roll back. If `jq` is
unavailable or `.claude-plugin/marketplace.json` cannot be read, report the error and stop; no
working-tree state is changed. To add, update, or remove plugins use the write skills
(`/add-plugin`, `/update-plugin`, `/remove-plugin`).
