# Backlog — `registry-dev`

> The assignable work breakdown, filled from the brainstorm roadmap (`tmp/0001-agentic-engineering-level-up.md`;
> the operator keeps the roadmap out of version control in `tmp/`, not `docs/plan/`). `registry-dev-manager`
> keeps this in sync as the source of truth for what is assigned, in flight, and done. Read `TEAM-BRIEF.md` first.

## How to use

1. The brainstorm team writes a phased roadmap (see `docs/teams.md`); for this run it lives at
   `tmp/0001-agentic-engineering-level-up.md`.
2. `registry-dev-manager` copies each roadmap item into the matching phase/lane table below, with its
   dependency status and the gate/check that accepts it.
3. Items are assigned, routed through the handoff chain (Architect design review → engineer
   test-first → QA-functional → QA-adversarial where applicable → PM acceptance), and marked done
   only when the Definition of Done (Brief §7) is met.

## Lanes

A — Manifest & Gates · B — Harness · C — CI & Supply-chain · D — Docs & DX (Brief §4).

## Binding decisions carried from the roadmap (constraints on every item)

- **D1** — No cross-tree `source` edges. Shared contract constants (secret regex, forbidden-key set,
  `odere-pro/<repo>` pattern, SPDX allowlist) are shared via a **parity-gate** (grep both sites for
  byte-equality) **or** a neutral standalone constants file each tree reads — never by `source`-ing
  across `tests/gates/` ↔ `.claude/`.
- **D2** — The hook mirrors **structural** blocks on Write only; per-field quality floors live in the
  gate (G2) only. The hook's Edit/MultiEdit path stays heuristic.
- **D3/D4** — No network call inside any push-suite gate. `$schema` is pure jq string-equality.
- **D5** — No stored trust state in the manifest (`verified`/`passed_at`/`score`/`signature` forbidden).
- **D6** — `marketplace.json` is the only on-disk index; no second index, no non-`$schema` root field.
- **D7/D18** — The registry never writes another repo; no auto-merge. Reproducible-diff *check* (P15) kept.
- **D8** — Gate numbers assigned centrally; keep `00`, `10`–`17` exactly. `00-harness-integrity.sh`
  guards against any future misnamed gate.
- **D11** — Meta-gates consolidated into one file: `00-harness-integrity.sh` (suite-integrity +
  gate-coverage + surface-budget + ship-surface).
- **D12** — Add-time vet enrichments (SPDX P10, component-check) may ride `vet-candidate.sh`'s existing
  `gh api` budget; they do not enter the push suite.
- **D14** — SPDX allowlist = `MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0`; expand via issue.
- **Surface budget (P5):** 10 agents (1 worker + 9 `registry-dev-*`), 4 skills, 3 hooks.

## Status legend

`todo` · `blocked(<dep>)` · `in-progress(<role>)` · `in-review` · `done`

## Phase 0 — Foundations (do first; unblocks the rest)

| ID | Item | Lane | Depends on | Acceptance (gate/check) | Status |
| --- | --- | --- | --- | --- | --- |
| P1 | `$schema` presence+equality in G2 (+ hook Write-path mirror) | A/B | — (serialize G2: P1→P9→P10; hook: P1→P9) | G2 FAILs when `$schema` absent or ≠ pinned URL; guard exits 2 on a Write dropping/changing it; suite green | done |
| P2 | Widen G6 scope to `.claude/skills` | A | — | G6 lints all 6 scripts + a deliberate SC error FAILs; run scope-widen first as Phase-0 baseline | done |
| P3 | DRY secret regex + forbidden-key set via parity-gate or neutral constants file | A/B | — | Parity-gate FAILs if the two sites diverge; **no cross-tree `source`** (D1); G6 green | done |
| P5 | `00-harness-integrity.sh` consolidated meta-gate (suite-integrity + gate-coverage + surface-budget + ship-surface) | A | — | FAILs on a non-`NN-` gate name; FAILs on root `plugin.json`/`skills/`/`agents/`/`hooks/`/`commands/`; surface-budget allow-list enumerates all **10** agents | done |
| P6 | `GATES_DOCUMENTED_DIRS` catch-up | A (+D co-precond) | needs `docs/plan/CLAUDE.md` (Lane D) | Removing `docs/plan/CLAUDE.md` FAILs G7; list = `.claude-plugin .github .claude tests/gates docs docs/brainstorm docs/plan .claude/teams`; flat-iteration limit logged | done |
| P7 | Coded `{code,message,fix}` verdict schema + verdict-shape gate `10-vet-verdict-schema.sh` | B/A | vet-candidate.sh, plugin-onboarder.md (serialize vet: P7→P10; onboarder: P11→P7) | Verdict carries `code` enum + paired `fix`; gate mocks/stubs `gh` or tests usage-error path; SKIPs if `gh` absent | done |
| P9 | Batched G2 listing-quality floors (+ hook Write-path structural mirror) + doc-contract update | A/B/D | after P1 on G2 + hook (same PR co-precond docs) | One G2 block: keywords non-empty, top-level `.description` non-empty, description≠name, length floor (pure jq), `homepage` `^https://`; doc contract updated same PR; generic-keyword denylist advisory only | done |
| P10 | SPDX license allowlist + named-identifier blocker + doc | B/A/D | after P9 on G2; after P7 on vet | G2 FAILs `"license":"NOPE"`, passes `"MIT"`; vet blocker names allowed ids (D14); "open an issue to expand" path documented | done |
| P11 | gh-api-only README fetch (drop WebFetch) | B | onboarder: P11→P7 | WebFetch absent (grep); private-repo flow completes with no prompt; 404→`plugin.json` fallback; prompt-injection note added | done |

### Phase 0 — acceptance record (PM sign-off 2026-06-06)

All 9 Phase-0 items ACCEPTED. Negative-tested by `registry-dev-qa-gates` (each new/changed gate proven
to FAIL when its invariant is violated, then restored) and red-teamed by `registry-dev-qa-adversarial`
(contract / secret / supply-chain / agent-operability). Final `bash tests/gates/run-all.sh` green (11
gates: G0/00–G10/10); `claude plugin validate .` clean (expected empty-registry warning only). No
defects found; nothing committed. Evidence per item:

| ID | Roadmap acceptance criterion | Verdict | Evidence |
| --- | --- | --- | --- |
| P1 | G2 FAILs `$schema` absent or ≠ pinned URL; hook exits 2 on a Write dropping/changing it | PASS | G2 FAILed on both deleted-key and wrong-URL manifests; `marketplace-guard.sh` Write payload dropping `$schema` exited 2 |
| P2 | G6 lints `.claude/skills`; a planted ShellCheck error FAILs | PASS | Planted SC1072/SC1073 in `.claude/skills/add-plugin/scripts/sync-readme.sh` made G6 FAIL (exit 1); restored from HEAD |
| P3 | Parity-gate FAILs if the two sites diverge; no cross-tree `source` (D1) | PASS | G0 FAILed on a secret-regex divergence and on a forbidden-key-tuple divergence; grep confirms no `.sh` sources across `tests/gates/`↔`.claude/` |
| P5 | G0 FAILs on a non-`NN-` gate, on a root payload surface, and enforces the 10-agent budget | PASS | G0 FAILed on `zz-bogus.sh`, on root `plugin.json` + `skills/`, and on an extra agent; all restored |
| P6 | Removing `docs/plan/CLAUDE.md` FAILs G7; list updated | PASS | G7 FAILed with `docs/plan/CLAUDE.md` moved away; `lib.sh` `GATES_DOCUMENTED_DIRS` includes `docs/plan`; restored |
| P7 | Verdict carries `code` enum + paired `fix`; gate offline; usage path exits 2 | PASS | Live `vet-candidate.sh` emits `{code,message,fix}`; usage path exits 2; G0... G10 self-check FAILs when its validator stops enforcing `fix` |
| P9 | One G2 block: keywords non-empty, description non-empty/≠name/length-floor, `homepage ^https://` | PASS | G2 FAILed on empty keywords, description==name, short description, `http://` homepage, and empty top-level description (per-entry stub) |
| P10 | G2 FAILs `"NOPE"`/`"GPL-3.0"`, passes `"MIT"`/`"MPL-2.0"`; allowlist named; expand-via-issue documented | PASS | G2 FAILed on `NOPE` and `GPL-3.0`, passed on `MIT`/`MPL-2.0`; allowlist message names all seven ids and cites `docs/adding-plugins.md` |
| P11 | WebFetch absent from onboarder tools; 404→plugin.json fallback; prompt-injection note | PASS | `plugin-onboarder.md` `tools:` = `Bash, Read, Grep, Glob` (no WebFetch); README-as-untrusted-data note present; gh-api fetch with `plugin.json` fallback documented |

## Phase 1 — operability core

| ID | Item | Lane | Depends on | Acceptance (gate/check) | Status |
| --- | --- | --- | --- | --- | --- |
| P8 | Deterministic CHANGELOG bullet from scripts + distinct sync-gate `11-changelog-in-sync.sh` | A/B | Phase 0 | All three write scripts emit the bullet; gate FAILs when manifest plugin-set changed but Unreleased omits it | done |
| P13a | Skill `## Failure handling` rollback sections + gate `12-skill-failure-handling.sh` | B/A | Phase 0 | Gate FAILs any SKILL.md missing the section; rollback uses `git restore --staged … && git restore …` | done |
| P13b | Skill front-matter lint + agent argument-hint gate `13-skill-frontmatter.sh` | B/A | Phase 0 | Required fields FAIL if absent; `argument-hint` absence is WARN | done |
| P13c | Skill-script path-existence gate `14-skill-script-paths.sh` | A | Phase 0 | Every `bash .../scripts/<x>.sh` reference resolves; FAILs on non-existent path | done |
| P13d | DRY-source gate for the manage-plugins core (folded into `00-harness-integrity.sh` per D11) | A | P5 | No `.sh` outside `add-plugin/scripts/` re-implements core helpers | done |
| P13e | Hook block-message citations + remediation hints | B | Phase 0 | Block output contains the gate/policy citation token; G6 green | done |
| P13f | Pre-submission contract checklist + candidate plugin.json `jq` validation block | D | Phase 0 | Checklist + `jq` one-liner present; G5 green; no hosted schema file | done |
| P13g | Submission onramp + README empty-state example + verify step | D | Phase 0 | G9 green; empty-state emitted by generator; speculative strings labeled | done |
| P13h | README License + Keywords columns (consolidated) | B | Phase 0 | G9 green; one `sync-readme.sh` extension renders both columns | done |
| P15 | Reproducible-diff check (NOT auto-merge) | C | Phase 0 | Re-running scripts reproduces post-format structural bytes + gates green; merge stays with CODEOWNERS (D7) | done |

### Phase 1 — acceptance record (PM sign-off 2026-06-06)

All 10 Phase-1 items ACCEPTED. Each new gate was written test-first and proven to FAIL when its
invariant is violated (negative-tested via safe temp-backup, then restored), and the manifest/hooks/CI
surfaces were red-teamed. Final `bash tests/gates/run-all.sh` green (15 gates: G0/00–G14/14);
`claude plugin validate .` clean (expected empty-registry warning only); all shell clean at
`shellcheck -S error`. Central gate numbers kept exactly (11–14; P13d folded into 00; P15 lives at
`.github/scripts/reproducible-diff.sh`, deliberately outside `run-all.sh`). Nothing committed.

| ID | Roadmap acceptance criterion | Verdict | Evidence |
| --- | --- | --- | --- |
| P8 | Three write scripts emit a deterministic bullet; `11-changelog-in-sync.sh` FAILs when a listed plugin is omitted; rollback handles staged-vs-dirty | PASS | `mk_changelog_bullet` (shared `lib.sh`) wired into add/update/remove-entry.sh; G11 FAILed on an injected listed-but-unlisted plugin; rollback via P13a's `git restore --staged … && git restore …` (CHANGELOG.md in recipe) |
| P13a | Gate FAILs any SKILL.md missing `## Failure handling`; write skills use `git restore --staged … && git restore …` | PASS | G12 FAILed on section deletion and on `--staged` removal; all 4 SKILL.md carry the section; 3 write skills document the staged+dirty rollback |
| P13b | Required fields FAIL if absent; `argument-hint` absence is WARN | PASS | G13 FAILed when `allowed-tools` removed; emitted WARN (rc=0) when `argument-hint` removed; agent `plugin-onboarder.md` got an `argument-hint` |
| P13c | Every skill-script reference resolves; FAILs on a non-existent path | PASS | G14 (10 refs) FAILed on an injected bogus `scripts/does-not-exist.sh`; portable (no `mapfile`, BSD/macOS-safe) |
| P13d | No `.sh` outside `add-plugin/scripts/` re-implements `mk_normalize_repo`/`MK_OWNER`/`MK_MANIFEST` | PASS | Folded into `00-harness-integrity.sh` §6; FAILed on a forked def, did NOT trip on a comment-only mention (false-positive guard) |
| P13e | Block output contains the gate/policy citation token; G6 green | PASS | `marketplace-guard` block cites `G2 / 02-marketplace-shape.sh`; `guard-commit-author` cites the human-authored policy; both exit 2; G6/G0 green |
| P13f | Checklist + `jq` one-liner present; G5 green; no hosted schema file | PASS | Pre-submission checklist + working `jq -e` field-validator in `docs/adding-plugins.md`; no `*.schema.json` created; G5 green |
| P13g | G9 green; empty-state emitted by generator; speculative strings labeled | PASS | Generator emits empty-state prose (G9 green); README illustrative table labeled `[speculative]`; submission onramp + verify step in CONTRIBUTING.md |
| P13h | G9 green; one `sync-readme.sh` extension renders License + Keywords columns | PASS | 5-column table verified in sandbox (License from `.license`, Keywords joined with `—` fallback); empty-state path unchanged → G9 green |
| P15 | Re-running reproduces post-format structural bytes (excl. description/keywords); gates green; merge stays CODEOWNERS | PASS | `.github/scripts/reproducible-diff.sh` (canonical `jq --indent 2`, matches `json-format.sh`) passes at N=0, FAILs on non-canonical bytes / bad owner / forbidden key; wired as a PR-only CI job; NOT in `run-all.sh`; not auto-merge (D7) |

## Phase 2 (not in scope this run)

| ID | Item | Lane | Depends on | Acceptance (gate/check) | Status |
| --- | --- | --- | --- | --- | --- |
| P12a | Actions-pinned gate `15-actions-pinned.sh` | A/C | Phase 0 | Passes SHA-pinned workflows; FAILs `actions/checkout@v6`; allows `./` local reusable | todo |
| P12b | Workflow-permissions gate `16-workflow-permissions.sh` | A/C | Phase 0 | FAILs `write-all` / non-allowlisted `contents: write` | todo |
| P14 | CI commit-author backstop gate `17-commit-author.sh` (atomic with `fetch-depth: 0`) | A/C | Phase 0 | Gate + `fetch-depth` land in one PR (D15); FAILs a Claude-author commit; passes current history | todo |
| P-history-secret-scan | gitleaks (SHA-pinned, active now) | C | Phase 0 | Runs on PR, SHA-pinned, shares P14 checkout; FAILs a planted history secret (D16) | todo |
| D-component-check | constant-cost component probe in vet | B | Phase 0 | Vet blocker when no component dir via `contents/skills` probe (not recursive); rides add-time budget (D12) | todo |

## Phase 3 (PM's go only — not in scope this run)

| ID | Item | Lane | Depends on | Acceptance (gate/check) | Status |
| --- | --- | --- | --- | --- | --- |
| P4 | Consolidated cross-repo audit (scheduled, advisory) | C | PM go | Re-derives repo-exists + plugin.json valid + `source.repo` match + no shipped `marketplace.json`; SKIP on any non-200/network error (D3); default `GITHUB_TOKEN`; opens/updates issue on drift (D17); no-op at N=0 | todo |

## Deferred / Out-of-scope (the Skeptic's cut list — do not silently re-propose)

| Cut item | Reason |
| --- | --- |
| auto-merge (agent-operability-lead-5) | Weakens CODEOWNERS Code-Review signal; thesis is operating, not merge governance (D7). Reproducible-diff *check* kept. |
| `verified`/`passed_at` field (marketplace-consumer-3) | §5.4 violation; stale state source doesn't own (D5). Replaced by scheduled re-vet (P4). |
| Auto-PR-into-candidate (agent-operability-2 / author-advocate-4) | Cross-repo write actor (D7). Minimal `fixes[]` emit-as-data form kept (P7). |
| `install-commands.txt` + gate (marketplace-consumer-4) | Second on-disk index = second source of truth (D6). One-line `jq` suffices. |
| `categories` root field (discoverability-growth-5) | YAGNI at N=0; non-`$schema` field (D6). Re-trigger N≥5, computed from `keywords[]`. |
| `docs/decisions/` ADR tree (registry-architect-5) | New navigational layer; rationale belongs in roadmap / `SOFTWARE-3-0.md` (D9). |
| move-write-perms + gate (platform-expert-6) | Removes no human; gate for a non-problem (D10). |
| schema-URL `curl --head` liveness ping (platform-expert-5 network arm) | Makes a gate network-dependent/flaky (D4). `$schema` jq equality kept (P1). |
| `claude plugin validate` PostToolUse-on-every-edit hook (platform-expert-1) | Unbudgeted binary spawn on the live edit path (D4). |
