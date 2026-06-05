# `.claude/teams/` — author-only spawnable teams

Never shipped; never loaded into an end-user session. This layer holds reusable, spawnable **agent
teams** for developing the registry. A team is a folder with a shared brief plus a roster of
auto-discovered agent definitions in `.claude/agents/`.

## Map

- **`registry-dev/`** — the engineering team that **implements** the brainstorm roadmap
  (`docs/plan/`) behind the gate suite. Its nine roles are spawnable agents named
  `registry-dev-*` in `.claude/agents/`. Entry point: `registry-dev-manager`.
  - `TEAM-BRIEF.md` — shared context every teammate reads first (mission, non-negotiables, lanes,
    phase sequencing, working agreement, Definition of Done).
  - `BACKLOG.md` — the assignable work breakdown (phase → lane → item), filled from the roadmap.
  - `README.md` — roster, prerequisites, the launch kickoff prompt, workflow, DoD summary.

## How it relates

This is the **implementation** half of the two-team apparatus. The **ideation** half lives in
`docs/brainstorm/` and produces the roadmap this team consumes. See [`../../docs/teams.md`](../../docs/teams.md).

## Prerequisites

Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` (read at
startup — restart Claude Code after enabling). The `registry-dev-*` role files are auto-discovered as
agent types, so any teammate can be spawned directly; the Delivery Lead is the entry point.
