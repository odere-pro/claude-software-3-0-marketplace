# `odere-pro` agentic-engineering brainstorm — agent-team apparatus

A **dev-only** setup for running a team of agents that brainstorms how to **level up the agentic
engineering** of the `odere-pro` marketplace — full-spectrum across the internal author-only harness
(gates, skills, the `plugin-onboarder` agent, hooks, CI/supply-chain) and the external
marketplace-as-product (discoverability, plugin quality bar, author + consumer experience). It is
**not** part of the shipped registry (which is only `.claude-plugin/marketplace.json`) and is never
loaded as end-user session context — it sits alongside `docs/plan/`.

It is the **ideation** counterpart to the engineering team in `.claude/teams/registry-dev/` (which
*implements* the roadmap). See [`../teams.md`](../teams.md) for how the two teams relate.

## What's here

```text
docs/brainstorm/
  CLAUDE.md              # navigational briefing for this layer
  TEAM-BRIEF.md          # shared context every teammate reads first (charter, thesis, non-negotiables, roster, protocol)
  README.md              # this file
  roles/                 # one structured prompt per role (12 files)
    facilitator-pm.md              # PM + facilitator (frames rounds, writes the roadmap)
    registry-architect.md          # contract + harness coherence; co-owns convergence
    agent-operability-lead.md      # the SOFTWARE-3-0 north star
    gate-contract-engineer.md
    harness-skills-ux.md
    supply-chain-security.md
    claude-code-platform-expert.md
    marketplace-consumer.md
    plugin-author-advocate.md
    discoverability-growth.md
    quality-performance-lead.md
    skeptic.md                     # guardian: KISS/DRY/YAGNI, "a registry is just a list"
```

## Roster (12 personas)

A cross-functional panel spanning the whole spectrum — internal harness engineering, the
agent-operability thesis, supply-chain security, the Claude Code platform, plus the external
consumer, author, and discoverability lenses — with a quality/performance lead and a skeptic to keep
proposals lean and buildable. There is **no separate Lead**: `facilitator-pm` carries the
facilitator/synthesizer hat and `registry-architect` co-owns coherence at convergence. Full table
with model and effort in [`TEAM-BRIEF.md`](TEAM-BRIEF.md) §8.

## Prerequisites

- Claude Code with Agent Teams. Verify: `claude --version`.
- Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`.
  **The flag is read at startup — restart Claude Code after enabling it.**

## How to run (live Agent Teams)

In a session opened at the repo root, paste the kickoff prompt. The ready-to-paste copy lives in the
git-ignored scratch file `tmp/brainstorm-kickoff.md`; it reads:

> Create a 12-teammate agent team for the `odere-pro` agentic-engineering level-up brainstorm. Every
> teammate first reads `docs/brainstorm/TEAM-BRIEF.md`, then adopts one role from
> `docs/brainstorm/roles/` (one teammate per file). Spawn each with the model named in its role
> header (opus or sonnet). `facilitator-pm` is the facilitator: it frames Round 1, runs the
> three-round protocol in Brief §9 (divergence → cross-critique → convergence), and writes the
> phased, full-spectrum roadmap to `docs/plan/` in the structure of Brief §7, with
> `registry-architect`'s coherence sign-off. Keep everything read-only on the repo and grounded with
> repo-path citations.

`facilitator-pm` orchestrates the rounds, resolves conflicts (Brief §9), and writes the roadmap.

## The three-round protocol (summary)

1. **Divergence** — each role produces ideas in isolation (`IDEA-<role>-<n>` template).
2. **Cross-critique** — roles file `OBJ-<from>-<to>-<n>` objections; the Skeptic critiques all and
   `agent-operability-lead` grills every headline proposal for a remaining human on the critical path.
3. **Convergence** — `facilitator-pm` merges into the roadmap (`registry-architect` sign-off);
   non-negotiables win, Skeptic vetoes stand unless the facilitator overrides and logs the rejected
   alternative.

## Output

One phased, full-spectrum roadmap in `docs/plan/` (a proposal). It becomes the input to the
`registry-dev` engineering team via [`../teams.md`](../teams.md) and
`.claude/teams/registry-dev/BACKLOG.md`.
