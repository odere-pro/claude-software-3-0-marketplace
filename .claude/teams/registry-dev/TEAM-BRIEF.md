# Team Brief — `registry-dev` engineering team

> Shared context for every teammate. Read this in full before you produce anything.
> Do not restate it back; cite it. This is a **dev-only** apparatus — it lives in `.claude/` and is
> never loaded as end-user session context. It does not ship.

## Contract

| Aspect | Rule |
| --- | --- |
| Mission | **Implement the brainstorm roadmap** (`docs/plan/`) as additive, gate-backed improvements to the `odere-pro` marketplace — internal harness and external product — one assignable item at a time. |
| Authority | `docs/plan/<roadmap>.md` (phases + acceptance), `BACKLOG.md` (the assignable work), `SOFTWARE-3-0.md` (the thesis), `.claude-plugin/CLAUDE.md` (the contract), `tests/gates/CLAUDE.md` (the gates). |
| Output | Merged-green changes: edited harness/docs/CI behind passing gates, with docs updated and an ADR for any settled decision. |
| Mode | READ-ONLY until the Delivery Lead assigns an item; then each teammate edits only its lane's paths. |
| Grounding | Cite repo paths; do not restate the brief or the roadmap back. |
| Halting | A teammate stops its turn after producing its deliverable and messaging the Delivery Lead. |

## 1. Mission

Turn the roadmap into shipped, gate-backed improvements without weakening any non-negotiable. Every
item must arrive as a failing check that the change makes pass: the registry stays agent-operable,
its contract stays singular and machine-readable, and trust stays in gates, not promises.

## 2. The thesis we serve

`SOFTWARE-3-0.md`: the product is agent-operable — an agent operates the registry end-to-end with no
human in the loop. Implementation choices are judged by whether they remove a human from the critical
path, raise a quality bar a gate can hold, or lower the cost/latency of operating the registry.

## 3. Non-negotiables (hard list)

- **Manifest is the only payload**: `name: "odere-pro"`, `github` sources, `$schema` pinned, **no
  `version`/`sha`/`commit`** (`tests/gates/02-marketplace-shape.sh`).
- **Gates, not promises**: a new rule ships as a `tests/gates/NN-*.sh` (and a mirrored
  `.claude/hooks/*` guard where it gates a live edit). Local and CI never disagree
  (`.claude/CLAUDE.md` "Mirror to gates").
- **README is generated** (`tests/gates/09-readme-in-sync.sh` / `sync-readme.sh`) — never hand-edited
  out of sync.
- **CLAUDE.md coverage** (`tests/gates/07-claude-md-coverage.sh`) — every documented layer keeps one.
- **No secrets, no machine paths** in tracked files (G3, G4).
- **DRY**: the four manage-plugins skills share one core (`.claude/skills/add-plugin/scripts/*.sh`);
  do not fork it.
- **KISS / YAGNI**: extend an existing surface before adding one.
- **Dev-time vs runtime separation**: the harness and these teams never ship.

## 4. Lanes

Four lanes run in parallel; the Delivery Lead serializes any shared-file edit.

| Lane | Owner role | Paths |
| --- | --- | --- |
| **A — Manifest & Gates** | `registry-dev-eng-manifest-gates` | `.claude-plugin/marketplace.json`, `tests/gates/` |
| **B — Harness** | `registry-dev-eng-harness` | `.claude/skills/*`, `.claude/agents/plugin-onboarder.md`, `.claude/hooks/*` |
| **C — CI & Supply-chain** | `registry-dev-eng-ci-supplychain` | `.github/` (workflows, Dependabot, CODEOWNERS) |
| **D — Docs & DX** | `registry-dev-eng-docs-dx` | `docs/`, `README.md` (via `sync-readme.sh`), root governance docs, `CLAUDE.md` files |

## 5. Phase sequencing

Drive the roadmap's phases in order: **Phase 0 (foundations) → Phase 1 → Phase 2 → Phase 3**. Phase 0
is upstream of everything; do it first. Do not start a phase whose dependencies (per the roadmap and
`BACKLOG.md`) are unmet. Phase 3 only on the PM's go.

## 6. Working agreement

- **Design before code** for any M-effort or shared-mechanism item: route the engineer through
  `registry-dev-architect` first.
- **Test/gate first**: write the failing gate or check, watch it fail, then make it pass.
- **One item, one branch, one PR.** Do not commit or push unless the human operator asks.
- **Stay in lane**: edit only your lane's paths; the Delivery Lead serializes shared files.
- **Cite, don't restate** the brief or roadmap.
- **Read-only until assigned.**

## 7. Definition of Done (per item)

- The failing gate/check written first now passes.
- `bash tests/gates/run-all.sh` green.
- `claude plugin validate .` clean (and `--strict` once the registry is non-empty).
- Contract intact: name `odere-pro`, no `version`/`sha` (G2).
- CLAUDE.md coverage holds (G7); README in sync (G9, via `sync-readme.sh`).
- Docs updated; an ADR added if the item settles a decision.
- Non-negotiables (§3) verified by `registry-dev-architect` and `registry-dev-qa-adversarial`.
- PM (`registry-dev-pm`) acceptance recorded.

## 8. Roster

| Role (slug) | Title | Model | Lane / focus |
| --- | --- | --- | --- |
| `registry-dev-manager` | Delivery Lead — entry point | opus | Sequencing, assignment, shared-file serialization, integration, final gate |
| `registry-dev-pm` | Product Manager | opus | Acceptance criteria, user-gated questions |
| `registry-dev-architect` | Architect / Tech Lead | opus | Contract + agent-operability coherence, ADRs, design-before-code |
| `registry-dev-eng-manifest-gates` | Engineer | sonnet | Lane A — manifest + gates |
| `registry-dev-eng-harness` | Engineer | sonnet | Lane B — skills, agent, hooks |
| `registry-dev-eng-ci-supplychain` | Engineer | sonnet | Lane C — CI, supply-chain, Dependabot |
| `registry-dev-eng-docs-dx` | Engineer | sonnet | Lane D — docs, CLAUDE.md, README sync, governance |
| `registry-dev-qa-gates` | QA — Functional | sonnet | `run-all.sh`, `claude plugin validate`, new-gate coverage |
| `registry-dev-qa-adversarial` | QA — Adversarial & Security | opus | Supply-chain red-team, secret-scan, agent-operability audit |
