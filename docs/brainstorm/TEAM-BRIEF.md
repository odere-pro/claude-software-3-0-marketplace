# Team Brief — `odere-pro` agentic-engineering level-up brainstorm

> Shared context for every teammate. Read this in full before you produce anything.
> Do not restate it back; cite it. This is a **dev-only** brainstorming apparatus — it never ships.
> Nothing here is loaded into an end user's Claude Code session.

## Contract

| Aspect | Rule |
| --- | --- |
| Mission | Brainstorm how to **level up the agentic engineering** of the `odere-pro` marketplace — **full-spectrum**: the internal author-only harness *and* the external marketplace-as-product — and turn it into a **development-ready plan the `registry-dev` team can implement**. |
| Authority | `SOFTWARE-3-0.md` (the thesis), `CLAUDE.md` + `.claude-plugin/CLAUDE.md` (what ships vs what doesn't), `tests/gates/CLAUDE.md` (the gates), `CONTRIBUTING.md` / `docs/adding-plugins.md` (the workflow). |
| Output | **A development-ready implementation plan** for the `registry-dev` engineering team (`docs/teams.md`), written by `facilitator-pm` at convergence — phased, with items mapped to lanes/owners, acceptance criteria, and a handover checklist. Lands in `docs/plan/`. |
| Mode | READ-ONLY / proposal-only. No teammate edits the manifest, the harness, or any shipped file. |
| Grounding | Every current-state claim cites a repo path. Uncited = labeled `[speculative]`. |
| Halting | A teammate stops its turn after producing its round deliverable and messaging the facilitator. |

## 1. Mission

Make the `odere-pro` marketplace measurably more **agent-operable, higher-quality, and faster to
operate** — without weakening any non-negotiable. The thesis (`SOFTWARE-3-0.md`) is that **an agent
can operate this registry end-to-end with no human in the loop**: every improvement should remove a
human from the critical path, move trust from "someone remembers the rule" to "a gate enforces it,"
or make the contract/docs more machine-actionable. This team works **both halves**:

- **Internal harness** — gates (`tests/gates/`), the manage-plugins skills (`.claude/skills/*`), the
  `plugin-onboarder` agent, the PreToolUse/PostToolUse hooks (`.claude/hooks/*`), CI &
  supply-chain (`.github/`), and the manifest tooling.
- **External product** — the marketplace as something other people *find, trust, install, and
  contribute to*: discoverability, the quality bar for listed plugins, the author submission
  experience, and the consumer first-install experience.

## 2. Product thesis (verbatim — do not re-interpret)

From `SOFTWARE-3-0.md`:

1. **The product is agent-operable, not "contains an AI."** An agent operates it end to end with no
   human in the loop. "If an agent needs a human to read a wiki, guess a coordinate, or hand-edit
   JSON by feel, the registry has failed the test."
2. **One machine-readable contract at the boundary** — the entire product surface is
   `.claude-plugin/marketplace.json` (top-level `name: "odere-pro"`, a `plugins[]` array of
   `github` sources with `description`/`homepage`/`license`/`keywords`, `$schema`-pinned).
3. **A stable, computable install coordinate** — installs are always `<plugin>@odere-pro`; the
   marketplace `name`, not the repo, is the coordinate.
4. **No version, no pin — the source owns truth** — entries omit `version` and `sha`/`commit`.
5. **The name is load-bearing, and singular** — only this repo may declare `odere-pro`; listed
   plugins ship no `marketplace.json` of their own.
6. **Docs the agent can consult mid-task** — every layer carries a `CLAUDE.md`; "if an agent needs
   something the docs don't say, that's a bug."
7. **Gates, not promises** — invariants are enforced mechanically (`tests/gates/`), so trust does
   not degrade under pressure or neglect.

This team reads every idea through the thesis: *does it remove a human from the critical path, raise
a quality bar a gate can hold, or lower the cost/latency of operating the registry?*

## 3. Current-state baseline (ground truth — path-cited)

A registry-only aggregator whose only shipped payload is `.claude-plugin/marketplace.json`
(`CLAUDE.md`, `.claude-plugin/CLAUDE.md`). The registry currently starts **empty**.

- **Manifest & contract** (`.claude-plugin/marketplace.json`, `.claude-plugin/CLAUDE.md`) — name
  `odere-pro`; one `github`-source entry per plugin; no `version`/`sha`.
- **Gate suite** (`tests/gates/`, `tests/gates/CLAUDE.md`): G1 json-parses · G2 marketplace-shape ·
  G3 no-absolute-paths · G4 secret-scan · G5 doc-links · G6 shellcheck · G7 claude-md-coverage ·
  G8 markdown-lint (advisory) · G9 readme-in-sync. `run-all.sh` auto-discovers `NN-*.sh`.
- **Manage-plugins skills** (`.claude/skills/{add,vet,update,remove}-plugin/SKILL.md`) with a shared
  deterministic core in `.claude/skills/add-plugin/scripts/{vet-candidate,add-entry,update-entry,
  remove-entry,sync-readme,lib}.sh`.
- **Worker agent** (`.claude/agents/plugin-onboarder.md`) — read-only; vets a candidate and curates
  description/keywords; never edits the manifest.
- **Interactive guards** (`.claude/hooks/{marketplace-guard,guard-commit-author,json-format}.sh`) —
  what the hooks enforce live, the gates mirror in CI.
- **CI & supply-chain** (`.github/`, `.github/CLAUDE.md`) — workflows, Dependabot, CODEOWNERS.
- **Governance & docs** (`docs/adding-plugins.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`,
  `SOFTWARE-3-0.md`, `CHANGELOG.md`).

## 4. Authority docs to respect

- `SOFTWARE-3-0.md` — the thesis. Every idea must serve agent-operability.
- `CLAUDE.md` + `.claude-plugin/CLAUDE.md` — what ships (the manifest only) vs the author-only harness.
- `tests/gates/CLAUDE.md` — the gate conventions; a new invariant means a new `NN-*.sh`, not folklore.
- `.claude/CLAUDE.md` — the harness map (settings, hooks, skills, agent, rules).
- `CONTRIBUTING.md` / `docs/adding-plugins.md` — the agent-driven add/vet/update/remove workflow.

## 5. Non-negotiables (hard list)

A nicer UX or a faster pipeline never buys an exception to any of these.

- **Agent-operability is the bar.** A feature that needs a human on the critical path is a regression.
- **Gates, not promises.** A new rule ships as a `tests/gates/NN-*.sh` gate (and, where it guards a
  live edit, a mirrored `.claude/hooks/*` guard) — never as prose someone must remember.
- **One machine-readable contract.** `.claude-plugin/marketplace.json` stays the only payload:
  `name: "odere-pro"`, `github` sources, `$schema` pinned.
- **No `version`, no `sha`/`commit`.** The source owns truth; do not reintroduce drift.
- **The name is singular and load-bearing.** Only this repo declares `odere-pro`; installs are
  `<plugin>@odere-pro`.
- **Docs the agent consults mid-task.** Every navigational layer keeps a `CLAUDE.md` (G7).
- **README is generated, never hand-maintained out of sync** (G9 / `sync-readme.sh`).
- **KISS / YAGNI.** A registry is a list. Prefer extending an existing skill / gate / hook / doc over
  a new surface; justify every new surface against the "registry is just a list" minimum.
- **Dev-time vs runtime separation.** The harness, these teams, and all `docs/` apparatus never load
  into an end user's session and never ship.
- **No secrets, no machine paths in tracked files** (G3, G4); secrets come from env, never the repo.

## 6. Citation rule

Every claim about how the marketplace works today cites a repo path (e.g.
`tests/gates/02-marketplace-shape.sh`). A claim with no path is labeled `[speculative]` and cannot
enter a roadmap phase until grounded.

## 7. Output contract — a development-ready plan for `registry-dev`

`facilitator-pm` writes **one implementation plan that hands off to the `registry-dev` team**
(`docs/teams.md`). It is the artifact `registry-dev-manager` picks up, so every phase item must be
**assignable**: mapped to a lane (A manifest+gates · B harness · C CI+supply-chain · D docs+DX),
sized, with acceptance criteria QA can check. Write it to `docs/plan/` in this structure:

```text
# odere-pro: agentic-engineering level-up — development plan (brainstorm output)
## Context              — why this exercise; the roster
## Thesis recap         — the SOFTWARE-3-0 points (§2), each tagged with its owner role
## Current-state baseline — the harness + product surfaces, path-cited, condensed
## Guiding constraints  — the non-negotiables (§5)
## Decisions log        — resolved decisions + rejected alternatives (incl. every Skeptic veto)
## Phases               — each item assignable to a registry-dev lane
  ### Phase 0 — <foundations>   (lowest-risk, highest-leverage; unblocks the rest)
     | Item | Owner lane | Thesis point served | Effort | Touches (paths) | Acceptance (gate/check) |
  ### Phase 1 / 2 / 3 — <themes>
  ### Deferred / Out-of-scope   (the Skeptic's cut list, with reasons)
## Quality & performance targets — measurable bars (coverage, CI time, token/latency budget)
## Open questions       — what the operator must resolve before the gated items start
## Handover checklist   — the steps registry-dev-manager runs to pick this up
```

The plan is a **proposal**. Hand it over via `docs/teams.md`: the brainstorm team writes it, the
engineering team consumes it.

## 8. Roster

No separate Lead: **`facilitator-pm` carries the facilitator/synthesizer hat**, with
**`registry-architect` co-owning architectural coherence** at convergence. Cross-functional by
design — every competency the full-spectrum charter needs is represented.

| Role (slug) | Owns | Model | Effort |
| --- | --- | --- | --- |
| `facilitator-pm` | Goal-fit, acceptance, **facilitation** + roadmap write | opus | ultrathink |
| `registry-architect` | Manifest contract + harness-layer coherence; ADR candidates; co-convergence | opus | ultrathink |
| `agent-operability-lead` | The thesis north star: every idea removes a human from the critical path | opus | ultrathink |
| `gate-contract-engineer` | Gates-as-contract, determinism, local↔CI parity, new invariants | sonnet | think hard |
| `harness-skills-ux` | DX of the add/vet/update/remove skills + `plugin-onboarder` + hooks | sonnet | think hard |
| `supply-chain-security` | Supply-chain trust, secret-scan, Dependabot, provenance/quality of listed plugins | opus | ultrathink |
| `claude-code-platform-expert` | Plugin/marketplace mechanics, settings, Agent Teams, version drift | sonnet | think hard |
| `marketplace-consumer` | End user: `marketplace add` → install `<plugin>@odere-pro`, first-install friction, trust signals | sonnet | standard |
| `plugin-author-advocate` | External submitter: the contract to meet, submission friction | sonnet | think hard |
| `discoverability-growth` | Registry as product: README/SEO surfaces, keywords, curation, findability | sonnet | think hard |
| `quality-performance-lead` | Raise quality (coverage, review) + performance (token/CI cost, latency, agent efficiency) | opus | think hard |
| `skeptic` | Guardian/red-team: KISS/DRY/YAGNI, "a registry is just a list," veto standing | opus | ultrathink |

## 9. Protocol (three rounds)

- **Round 1 — Divergence (isolated).** Produce your deliverables without reading peers.
  Per-idea template:
  `### IDEA-<role>-<n>` → Problem → Proposal → Cited evidence (paths) → Agent-operability note
  (which human does this remove from the critical path?) → Effort (S/M/L) → Suggested phase →
  Dependencies → Acceptance (the gate or check that proves it).
- **Round 2 — Cross-critique.** Read your assigned peers and file objections `OBJ-<from>-<to>-<n>`
  with a path-cited reason. The **Skeptic critiques all roles**; the **`agent-operability-lead`
  grills every headline proposal** for a remaining human on the critical path. Attack discipline,
  feasibility, and thesis-fit — not taste. Suggested pairings: consumer ↔ author-advocate,
  discoverability ↔ platform-expert, gate-engineer ↔ supply-chain, harness-ux ↔ quality-performance,
  architect ↔ agent-operability-lead.
- **Round 3 — Convergence (`facilitator-pm` + `registry-architect`).** The facilitator merges
  surviving ideas into the roadmap with the architect's coherence sign-off. Conflict order:
  1. A non-negotiable (§5) always wins.
  2. A Skeptic veto stands unless the facilitator explicitly overrides it and logs the rejected
     alternative.
  3. Remaining ties: the facilitator decides and records both the decision and the discarded option.

## 10. Glossary / coinage discipline

Prefer the established vocabulary already in `SOFTWARE-3-0.md` and the `CLAUDE.md` layers
(manifest, contract, gate, source, install coordinate, agent-operable, harness). Flag any new term a
role coins for a definition in the plan's prose before it is used as if shared — do not silently
adopt coinages.
