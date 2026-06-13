# claude-calibration — install & quick start

[`odere-pro/claude-calibration`](https://github.com/odere-pro/claude-calibration) · MIT

Audits and improves your Claude Code setup through a repeatable **evaluate → plan → approve → apply →
re-evaluate** loop. Given a goal (or a guessed one), it spawns worker agents that score CLAUDE.md,
rules, settings, skills, subagents, hooks, MCP, and plugins against a curated rubric, builds a
prioritized plan, gates it on your approval, applies the approved rows, and re-audits to measure
impact. When the same finding recurs, the planner scaffolds an *enforcing* feature (a hook, rule, or
wrapper skill) instead of a one-off fix, so the problem stops coming back.

## Install

In a Claude Code session:

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
/plugin install claude-calibration@odere-pro
```

Or from the shell:

```bash
claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
claude plugin install claude-calibration@odere-pro
claude plugin list                          # confirm installed/enabled
```

Plugins install per-user (per machine), not per-project — once installed it's available in every repo
you open. A session restart may be needed for its skills, agents, and hooks to load. See the root
[README](../../README.md) for the generic install / `claude plugin …` lifecycle details.

**Prerequisites:** `git` and `bash` (used for baseline/drift tracking and the bundle scripts). The
plugin ships **PreToolUse write-guard hooks** (they keep the calibrator's edits inside its allow-list
and hold the audit flows read-only) and a **SessionStart hook** that installs its bundled Workflow
scripts into `.claude/workflows/` (never overwriting your edits). It needs **no MCP server** and makes
no external API calls. Run state persists under `.claude/calibration/` so it survives `/clear` — add
that path to `.gitignore` unless you want run folders committed.

## Quick start

Pick a starting point by intent:

```text
/calibration                                   # discovery: prints the menu of every flow
/claude-calibration:calibration-onboarding     # first time? detects your config, names one next step (read-only)
/claude-calibration:calibration-doctor         # ~5s structural health check (read-only)
/claude-calibration:calibration-audit          # read-only baseline evaluation — no plan, no edits (good CI gate)
```

When you're ready to actually change things, run the full loop — it has an **approval gate** before
anything is written:

```text
/calibrate                                     # full loop with a guessed intent
/calibrate "reduce always-on context cost without losing capability"   # with an explicit goal
```

Useful follow-ups:

```text
/claude-calibration:calibration-diff           # what changed since the last run?
/claude-calibration:calibration-track          # deterministic improvement vs baseline
/calibrate harden                              # tighten standards + auto-approve
/calibrate cost                                # standing context-cost snapshot only
/claude-calibration:calibrate-skills           # audit one feature standalone (-rules, -hooks, -mcp, …)
```

A typical first session: `/calibration` (or `/calibration-onboarding`) → `/calibration-audit` for a
read-only baseline → `/calibrate "<goal>"` to apply improvements behind the approval gate.

## What it ships

| Kind | Items |
| ---- | ----- |
| Skills (entry points) | `/calibrate` (orchestrator), `/calibration` (dispatcher/menu), read-only flows `calibration-audit` / `calibration-diff` / `calibration-track` / `calibration-flow` / `calibration-doctor` / `calibration-onboarding`, and 9 per-feature bundles `calibrate-<feature>` (`skills`, `subagents`, `claude-md`, `rules`, `settings`, `hooks`, `mcp`, `plugins`, `general`) |
| Agents | `calibration-planner`, `calibration-evaluator`, `calibration-feature-evaluator`, `calibration-calibrator`, `calibration-flow-evaluator` (worker subagents — invoked by the skills, never directly) |
| Hooks | PreToolUse write-guards (`calibrator-write-guard.sh`, `audit-write-guard.sh`) + SessionStart workflow installer |

This plugin is **skills-only** (no `commands/`). Full mode matrix and arguments are in the plugin's own
repo: <https://github.com/odere-pro/claude-calibration> (see its `docs/usage.md`).
