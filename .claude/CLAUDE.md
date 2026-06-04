# `.claude/` — the author-only harness

Never shipped; this configures Claude Code for whoever develops the registry. The goal is a tight,
high-signal harness for a repo whose only payload is one JSON file.

## Map

- **`settings.json`** — the harness wiring:
  - `includeCoAuthoredBy: false` + empty `attribution` → human-authored commits/PRs (global policy).
  - `permissions.allow` → read-only/maintenance Bash (git read verbs, `jq`, `find`, `grep`, `cat`,
    the gate runner, `claude plugin validate`, bun lint/format) so routine work doesn't prompt.
  - `skillOverrides` → disable skill families irrelevant to a docs/JSON registry (frontend, backend,
    postgres/db, and the instinct-learning set).
  - `hooks` → see below.
- **`hooks/`**
  - `marketplace-guard.sh` (PreToolUse `Write|Edit|MultiEdit`) — blocks bad `marketplace.json` edits
    (invalid JSON, renamed marketplace, forbidden `version`/`sha`/`commit`, secret tokens).
  - `guard-commit-author.sh` (PreToolUse `Bash`) — blocks a `git commit` with Claude/Anthropic author
    or an AI attribution trailer.
  - `json-format.sh` (PostToolUse `Write|Edit`) — pretty-prints edited valid `*.json`; no-op otherwise.
  - All read the hook payload from stdin (JSON) via `python3`; exit `2` blocks, `0` allows.
- **`rules/marketplace-dev.md`** — path-scoped (`.claude-plugin/**`) restatement of the manifest
  contract; loads only when the manifest is touched.
- **`agentline.json`** — statusline (model · branch · PR · context% · tokens · cost) for the
  [agentline](https://github.com/odere-pro/claude-agentline) statusline.

## MCP

`.mcp.json` (repo root, committed) declares `context7` (docs lookup) and `github` servers. Secrets
are **not** in the file — they come from env (`CONTEXT7_API_KEY`, `GITHUB_PERSONAL_ACCESS_TOKEN`).
Per-machine plugin/MCP enablement lives in the git-ignored `.claude/settings.local.json`.

## Mirror to gates

What the hooks enforce interactively, `tests/gates/` enforces in CI — edit them together so local and
CI never disagree.
