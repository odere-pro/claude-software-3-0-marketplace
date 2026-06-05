# `docs/brainstorm/` — the ideation team apparatus

Author-only; never shipped, never loaded into an end-user session. This layer holds the **agentic-
engineering level-up brainstorm**: a 12-persona, read-only agent team that ideates how to make the
`odere-pro` marketplace more agent-operable, higher-quality, and faster to operate — full-spectrum
across the internal harness and the external product.

## Map

- **`TEAM-BRIEF.md`** — the shared context every teammate reads first: charter, the `SOFTWARE-3-0.md`
  thesis, the current-state baseline (path-cited), non-negotiables, the output contract (the roadmap
  skeleton), the roster, and the three-round protocol.
- **`README.md`** — what's here, prerequisites (the Agent Teams flag), the kickoff prompt, and where
  the output lands.
- **`roles/`** — one structured role prompt per teammate (12 files). Each carries its model and
  thinking effort in its header.

## How it relates

This is the **ideation** half of the two-team apparatus. Its output is a phased roadmap in
`docs/plan/` (a proposal). The **implementation** half — `.claude/teams/registry-dev/` — consumes
that roadmap. See [`../teams.md`](../teams.md).

Read-only / proposal-only: no teammate edits the manifest, the harness, or any shipped file.
