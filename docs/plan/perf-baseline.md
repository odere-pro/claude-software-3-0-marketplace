# Performance baseline — `odere-pro` registry (2026-06-06)

> Author-only; never shipped, never loaded into an end-user session. Roadmap item: "Perf baseline
> doc (push-suite time, PR-job times, one `/add-plugin` token/turn count)" — brainstorm Phase 0,
> Lane D.

This document records measured wall-clock baselines for the push-suite gate runner and documents the
CI job structure so future roadmap items have a concrete numeric reference.

## 1. Local push-suite — `bash tests/gates/run-all.sh`

**Machine:** macOS 25.5.0 (darwin), multi-core (zsh).
**Date:** 2026-06-06. **State:** 18 gates passing, N=0 manifest (0 listed plugins).

### 1.1 Total wall-clock

Three back-to-back runs (cold-cache across runs; shell + `jq` + `shellcheck` already in PATH):

| Run | Wall time |
| --- | --- |
| 1 | 2 389 ms |
| 2 | 2 313 ms |
| 3 | 2 315 ms |
| **median** | **2 315 ms** |

`time` output for the full suite: `1.60s user 1.06s sys 107% cpu 2.480s total`
(user+sys = 2.66 s; real ≈ 2.5 s; parallelism from sub-processes on multi-core).

### 1.2 Per-gate timings (single run, milliseconds)

Each gate was timed individually (`date +%s%N` before/after) on the same run:

| Gate | ms | Note |
| ---- | -- | ---- |
| `00-harness-integrity` | 208 | multi-`grep` + `find` across skills/agents/hooks |
| `01-json-parses` | 48 | `find` + `jq` on every tracked `*.json` |
| `02-marketplace-shape` | 26 | pure `jq` on one manifest |
| `03-no-absolute-paths` | 35 | `grep -r` |
| `04-secret-scan` | 43 | `grep -r` |
| `05-doc-links` | 330 | `find` all `*.md` + per-link `stat` |
| `06-shellcheck` | 480 | `shellcheck -S error` over 6 scripts |
| `07-claude-md-coverage` | 11 | O(documented-layers) `stat` calls |
| `08-markdown-lint` | 404 | `markdownlint-cli2` (advisory) |
| `09-readme-in-sync` | 48 | `sync-readme.sh --check` |
| `10-vet-verdict-schema` | 58 | `jq`-based offline shape check |
| `11-changelog-in-sync` | 18 | `jq` + `grep` on `CHANGELOG.md` |
| `12-skill-failure-handling` | 41 | `grep` over 4 `SKILL.md` files |
| `13-skill-frontmatter` | 86 | YAML front-matter parse × 5 |
| `14-skill-script-paths` | 68 | 10 resolved script-path refs |
| `15-actions-pinned` | 59 | `grep` over 4 workflow YAML files |
| `16-workflow-permissions` | 43 | `grep` over 4 workflow YAML files |
| `17-commit-author` | 439 | `git log --format` over full history |
| **Sum of per-gate** | **2 445 ms** | (serial; actual suite runs ~2 315 ms due to sub-process overlap) |

**Slowest gates (>200 ms):** G17 commit-author (439 ms, history scan), G6 shellcheck (480 ms,
external binary), G8 markdown-lint (404 ms, advisory, Node binary), G5 doc-links (330 ms, `find` +
stat), G0 harness-integrity (208 ms, multi-grep).

**Fastest gates (<50 ms):** G2, G3, G4, G7, G9, G11, G12 — all pure `jq`/`grep` with no binary
invocation.

### 1.3 Scaling notes (N=0 → N=k plugins)

Most gates are O(1) in plugin count because they operate on static files (scripts, docs, workflows).
Gates that walk the manifest are `jq`-only and scale in sub-ms per entry. Exceptions:

- **G11 changelog-in-sync** — `grep` call per listed plugin name (still O(k) `grep` passes, but on
  a single flat file; negligible at k<100).
- **G9 readme-in-sync** — re-runs `sync-readme.sh`; one `jq` pass + one `sed` replace; O(k) but
  dominated by shell startup (~30 ms fixed cost).
- **G17 commit-author** — scales linearly with commit count, not plugin count; history grows slowly.

**Expected total at N=10:** ≈2 400–2 600 ms (effectively flat; no gate grows faster than O(k)).

## 2. CI job structure (`.github/workflows/`)

Four workflow files; each is SHA-pinned (G15) and least-privilege (G16).

### 2.1 `ci.yml` — always-on gate suite

**Trigger:** every push (any branch) + every PR.
**Jobs (run in parallel on `ubuntu-latest`):**

| Job | Triggers | Steps | Typical duration (est.) |
| --- | --- | --- | --- |
| `gates` (validation gates) | push + PR | `checkout` (fetch-depth:0) + `apt install jq shellcheck` + `bash tests/gates/run-all.sh` | ~60–90 s (apt install dominates) |
| `history-secret-scan` (gitleaks CLI) | PR only | `checkout` (fetch-depth:0) + download+verify gitleaks binary (SHA-256) + `./gitleaks git .` | ~30–60 s |
| `reproducible-diff` (manifest provenance) | PR only | `checkout` + `bash .github/scripts/reproducible-diff.sh` | ~15–20 s |

Notes:
- `fetch-depth: 0` on the `gates` job is required by G17 (`17-commit-author.sh`) to scan the full
  history.
- `history-secret-scan` uses the **license-free gitleaks CLI binary** (not `gitleaks/gitleaks-action`,
  which requires a paid `GITLEAKS_LICENSE` on org repos); it downloads, SHA-256-verifies, and runs the
  binary from scratch each time.
- `reproducible-diff` is network-free; `jq` is pre-installed on `ubuntu-latest`.

### 2.2 `audit.yml` — cross-repo provenance (advisory, scheduled)

**Trigger:** weekly cron (`Monday 05:17 UTC`) + `workflow_dispatch`.
**Job:** `audit` — runs `bash .github/scripts/audit-cross-repo.sh` via `GITHUB_TOKEN` (default,
no extra secret). Advisory only (D3): never hard-FAILs; opens/updates one tracking GitHub issue on
detected drift; no-op at N=0. Not in `run-all.sh` (network-dependent).

### 2.3 `codeql.yml` — SAST (scheduled + push/PR to main)

**Trigger:** `push`/`PR` to `main`, weekly cron (`Monday 04:27 UTC`), `workflow_dispatch`.
**Language:** `actions` (CodeQL inspects the workflow YAML). Results upload to code-scanning (SARIF).

### 2.4 `scorecard.yml` — OpenSSF Scorecard (scheduled + push to main)

**Trigger:** `push` to `main`, `branch_protection_rule`, weekly cron (`Monday 04:27 UTC`),
`workflow_dispatch`.
**Output:** SARIF uploaded to code-scanning; results published to the public Scorecard API
(`publish_results: true`) so the badge renders.

## 3. Roadmap numeric targets

The roadmap (`tmp/brainstorm-effectiveness-report-2026-06-06.md` → Phase 0 / `BACKLOG.md` Phase-0
acceptance) states:

> "Keep gates fast and dependency-light (`jq`, `grep`, `find`, `awk`, `python3`)."
> — `tests/gates/CLAUDE.md` conventions section.

Against the measured baseline, the following numeric budgets apply:

| Budget | Value | Basis |
| --- | --- | --- |
| Local `run-all.sh` wall-clock budget | **≤ 5 s** | 2× the measured median (2.3 s); leaves room for up to ~3 new heavy gates (G17-class) before the budget is exceeded. Any single new gate that adds >500 ms must be justified in its PR. |
| Per-gate cap (non-binary gates) | **≤ 100 ms** | All current pure `jq`/`grep` gates land well under this; gates adding `find` walks must stay under it. |
| Per-gate cap (external-binary gates) | **≤ 600 ms** | G6 shellcheck (480 ms) and G8 markdownlint (404 ms) set the empirical ceiling; a new binary-invoking gate must benchmark under 600 ms. |
| Gates in `run-all.sh` | **18 today → ≤ 25** | G0's naming check auto-discovers new gates; the budget is a soft ceiling to keep the suite scannable and the wall-clock under 5 s. |
| Surface budget (agents / skills / hooks) | **10 / 4 / 3 today** | Hard-coded in `tests/gates/00-harness-integrity.sh`; bump in lockstep with any new surface. New surfaces this roadmap: skills 4→5 (list-plugins), site/ (projection); agents + hooks unchanged. |
| CI `gates` job estimated wall-clock | **≤ 3 min** | Current: ~60–90 s (apt + suite); leaves room for a Pages-deploy step and one more install. |

### 3.1 Post-roadmap expected state (after Phase 0+1 items land)

After the current Phase 0+1 batch (blocker-display fix, 5th skill, 3 seeded plugins, G2
strengthening, Pages compound item with gate 18):

| Metric | Expected |
| --- | --- |
| Gates in suite | 19 (current 18 + G18 pages-in-sync) |
| Skills | 5 (add/vet/update/remove/list-plugin) |
| Local `run-all.sh` | ≤ 3 s (G18 is a pure `diff` + static grep; no binary) |
| CI `gates` job | ≤ 90 s (same apt baseline; G18 adds <100 ms) |
| N listed plugins | 3 (seeded) |

## 4. Keyword-derived grouping — implemented (Phase-1 follow-on, 2026-06-06)

The Pages site now carries an offline keyword filter computed purely from existing `keywords[]`
in the generator (`sync-site.sh`). No manifest field was added (D6 preserved).

**What shipped:**
- Each `<article class="card">` emits a `data-keywords="..."` attribute (space-joined, HTML-escaped).
- A `<div class="filter-bar">` toolbar above the grid renders one button per unique sorted keyword.
- A 20-line inline `<script>` (no remote `src`) in the template handles click-to-filter via
  `card.hidden` toggling.
- CSS for `.filter-bar`, `.filter-btn`, `[aria-pressed=true]`, and `.card[hidden]` is injected
  inline before `</style>`.
- N=0 empty-state: all filter surfaces are suppressed (no toolbar, no script).

**Constraints verified:**
- No manifest field — grouping is a pure projection of `keywords[]` (D6).
- Fully offline — inline `<script>` only; G18 group-2 (no-remote-fetch) still passes.
- Every keyword string routed through `html_esc` in jq (G18 group-3 XSS check still passes).
- Byte-deterministic — stable `unique|sort` order, no `date` (G18 group-1 byte-equality passes).
- N=0 and single-keyword entries render cleanly.

**G18 gate update:** The XSS check in group-3 was updated to strip all template-generated `<script>`
blocks (both JSON-LD and the filter script) before checking for manifest-field injection — the
behavioral coverage is preserved and the awk scoping of check 3c is now tighter (stops at the
first `</script>` in the LD block, not at EOF).

**Keep-cut items (unchanged — do not re-propose):**

| Cut item | Reason |
| --- | --- |
| Manifest `categories` root field | Non-negotiable: D6 (no non-`$schema` root field) + VETO discoverability-5. The discoverability need is satisfied by the computed keyword-derived grouping above. Never a manifest field. |
| JSON Feed (gen-feed.sh + feed.json + feed gate) | Non-negotiable: D6 (no second on-disk index) + VETO discoverability-4. Revisit trigger: a concrete external subscriber appears. |
| Live trust badges on the Pages site | Non-negotiable: offline-site rule + VETO supply-chain-2. External `<img>/<script>` forbidden; G18 group-2 already fails by design. Never on the static page. |
| External shadow-name search (platform-5) | Low leverage; collision prevention is already covered by design and by vet + audit-cross-repo.sh. Advisory audit.yml step only if operator requests monitoring. |

## 5. `/add-plugin` token / turn budget (placeholder)

The roadmap notes a token/latency budget for `/add-plugin` runs as a future measurement target. No
live run has been performed against a real candidate in this session (the manifest is N=0). The
following is a **placeholder** to be filled when the first seed run executes:

| Metric | Measured value | Run date |
| --- | --- | --- |
| Total turns (agent + skill) | — | — |
| Approximate token cost (input+output) | — | — |
| Wall-clock (vet → manifest edit → README → gates → PR open) | — | — |
| `vet-candidate.sh` `gh api` calls | ≤ 6 (4 component probes + 1 meta + 1 license) | spec (not measured) |

Update this table after the first successful `/add-plugin <repo>` run or after the seed PR lands.
