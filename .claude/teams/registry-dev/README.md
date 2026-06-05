# `odere-pro` development team — agent-team apparatus

A dev-only, cross-functional agent team that **implements** the brainstorm roadmap (`docs/plan/`). It
is the implementation counterpart to the brainstorm team in `docs/brainstorm/` (which produces the
roadmap). Like that apparatus, it is **not** part of the shipped registry — it lives in `.claude/`
and is never loaded as end-user session context. See [`../../../docs/teams.md`](../../../docs/teams.md).

## What's here

```text
.claude/teams/registry-dev/
  CLAUDE.md → see ../CLAUDE.md   # the teams layer briefing
  TEAM-BRIEF.md    # shared context every teammate reads first (mission, non-negotiables, lanes, DoD)
  BACKLOG.md       # the assignable work breakdown: phase → lane → item, filled from the roadmap
  README.md        # this file

.claude/agents/    # the nine spawnable role definitions
  registry-dev-manager.md            # Delivery Lead — start here
  registry-dev-pm.md                 # Product Manager
  registry-dev-architect.md          # Architect / Tech Lead
  registry-dev-eng-manifest-gates.md # Lane A — Manifest & Gates
  registry-dev-eng-harness.md        # Lane B — Skills, agent, hooks
  registry-dev-eng-ci-supplychain.md # Lane C — CI & Supply-chain
  registry-dev-eng-docs-dx.md        # Lane D — Docs & DX
  registry-dev-qa-gates.md           # QA — Functional
  registry-dev-qa-adversarial.md     # QA — Adversarial & Security
```

## Roster (9 teammates)

3 leads (Delivery Lead, PM, Architect) + 4 lane engineers (manifest+gates · harness · CI+supply-chain
· docs+DX) + 2 QA (functional · adversarial). Full table with model and lane in
[`TEAM-BRIEF.md`](TEAM-BRIEF.md) §8.

## Prerequisites

- Claude Code with Agent Teams. `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`
  (read at startup — restart Claude Code if you change it).
- The `registry-dev-*` role files in `.claude/agents/` are auto-discovered as agent types.

## How to launch

The **Delivery Lead is the entry point**. Paste to a session opened at the repo root:

> Act as `registry-dev-manager`. Read `.claude/teams/registry-dev/TEAM-BRIEF.md` and
> `.claude/teams/registry-dev/BACKLOG.md` and the roadmap in `docs/plan/`. Stand up the full team
> (PM, Architect, four lane engineers, two QA), confirm the roadmap's open questions with me before
> any gated item, then run **Phase 0**: fan out the independent items across lanes in parallel, route
> each through the handoff chain (Architect design review → engineer test-first → QA-functional →
> QA-adversarial where applicable → PM acceptance), and integrate only when
> `bash tests/gates/run-all.sh` is green and `claude plugin validate .` is clean. Report status and stop.

For a single workstream, spawn that lane directly — e.g. *"Act as `registry-dev-eng-manifest-gates`
and take item A1 from the backlog"* — but still route it through QA and the PM per the Brief.

## Workflow (parallel by lane, sequential by phase)

1. The Delivery Lead reads the roadmap + backlog and plans the cycle.
2. The PM attaches an acceptance spec; the Architect approves the design for any M-effort or
   shared-mechanism item **before** code.
3. The four lanes implement their items **in parallel** (gate/check first).
4. QA-functional runs `bash tests/gates/run-all.sh` + `claude plugin validate .`; QA-adversarial
   red-teams the non-negotiables (secret-scan, supply-chain, contract drift, agent-operability).
5. The PM accepts; the Delivery Lead integrates and runs the final gate.

Phase order (Brief §5): **Phase 0 → 1 → 2 → 3** (Phase 3 only on the PM's go).

## Definition of done

See Brief §7. In short: failing gate/check written first now passes; `bash tests/gates/run-all.sh`
green; `claude plugin validate .` clean; contract intact (no `version`/`sha`); CLAUDE.md coverage and
README-in-sync hold; docs updated; ADR for any settled decision; PM acceptance.

## Notes

- Read-only on the repo until the Delivery Lead assigns an item; teammates then edit only their lane's
  paths.
- It mirrors the repo's brainstorm pattern (`docs/brainstorm/`) but is located in `.claude/` as a
  reusable, spawnable team. It does not ship and is not loaded as end-user context.
