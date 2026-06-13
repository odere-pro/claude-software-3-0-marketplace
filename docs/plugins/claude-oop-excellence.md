# claude-oop-excellence — install & quick start

[`odere-pro/claude-oop-excellence`](https://github.com/odere-pro/claude-oop-excellence) · MIT

Audits and refactors a codebase for object-oriented design quality in **any language**: one read-only
front door (`/audit`) runs two analysis tracks in parallel — RISK (issues) and PATTERN (patterns
present + pattern-fit opportunities) — and merges them into a single report whose **Recommended
Actions** hand off to gated, test-verified fix/implement commands. Detection is principle-based
(SOLID, Law of Demeter, DRY, encapsulation…), driven by a canonical 102-entity glossary.

## Install

In a Claude Code session:

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
/plugin install claude-oop-excellence@odere-pro
```

Or from the shell:

```bash
claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
claude plugin install claude-oop-excellence@odere-pro
claude plugin list                          # confirm installed/enabled
```

Plugins install per-user (per machine), not per-project — once installed it's available in every repo
you open. A session restart may be needed for its commands, agents, and skills to load. See the root
[README](../../README.md) for the generic install / `claude plugin …` lifecycle details.

**Prerequisites: none.** The plugin ships **no hooks and no MCP server**, makes **no toolchain
assumptions**, and runs your project's *own* detected test/lint commands (`npm test`, `pytest`,
`go test`, `cargo test`, `mvn`, …) to verify any change. Removing it leaves no background state behind.

## Quick start

Open the project you want to analyze, then:

```text
/onboarding        # read-only orientation: the mental model and the analyze → act flow
/audit             # whole project: RISK + PATTERN tracks in parallel → one unified report
```

`/audit` is **read-only — it never changes code.** Scope it down when you want a narrower pass:

```text
/audit changed     # only files changed vs the base branch
/audit god-class   # a single glossary entity (id), e.g. god-class
```

The report ends with a **Recommended Actions** section that prints the *exact* gated commands to run
next, scoped to what it found. Nothing is modified until you run one of those yourself:

```text
/fix-risks <selection> [scope]            # apply the smallest corrective refactor (RISK findings)
/implement-patterns <selection> [scope]   # introduce a design pattern via a safe parallel-change sequence
```

Add `--plan-only` to either command to preview the changes without writing them. Both commands verify
the result with the project's own tests before finishing.

A typical first session: `/onboarding` → `/audit` → read the report → run the printed
`/fix-risks …` or `/implement-patterns …` (with `--plan-only` first if you want to preview).

## What it ships

| Kind | Items |
| ---- | ----- |
| Commands | `/fix-risks`, `/implement-patterns` (gated, user-invoked) |
| Skills | `audit` (analysis front door), `onboarding`, `glossary` (lookup), `improve`, `pattern-implement` |
| Agents | `oop-orchestrator` + glossary-driven workers: `entity-detector`, `pattern-scanner`, `pattern-suggester`, `entity-fixer`, `pattern-implementer` |

Full reference and the glossary live in the plugin's own repo:
<https://github.com/odere-pro/claude-oop-excellence>.
