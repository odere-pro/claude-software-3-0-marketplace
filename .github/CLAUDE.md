# `.github/` — CI, supply chain, governance wiring

Author-only. Continuous integration and the supply-chain hardening for the registry.

## Workflows (`workflows/`)

- **`ci.yml`** — always-on (every push + PR). Installs `jq` + `shellcheck` and runs
  `bash tests/gates/run-all.sh`. This is the gate that must stay green. The checkout uses
  `fetch-depth: 0` (full history) so the commit-author backstop gate `17-commit-author.sh` can scan
  every commit (roadmap P14/D15). It also carries two PR-only jobs:
  - **`history-secret-scan`** — runs the **license-free `gitleaks` CLI binary** (pinned version,
    SHA-256 verified before use) over the full git history to FAIL the PR on any committed secret
    (roadmap P-history-secret-scan; active now, the repo is public, D16). It shares the same
    `fetch-depth: 0` checkout pattern. The CLI is used instead of `gitleaks/gitleaks-action`, which
    requires a paid `GITLEAKS_LICENSE` on **org-owned** repos. It runs only on `pull_request`, so it
    never blocks a push.
  - **`reproducible-diff`** — see below.
- **`scorecard.yml`** — OpenSSF Scorecard. **Active** (the repo is public, D16): weekly `schedule`,
  push to `main`, `branch_protection_rule`, and manual `workflow_dispatch`. Publishes the score to the
  public Scorecard API and uploads SARIF to code-scanning.
- **`codeql.yml`** — CodeQL SAST over `languages: actions` (scans the workflow YAML itself; there is
  no compiled language here). **Active** now the repo is public (D16): push/PR to `main`, a weekly
  schedule, and manual `workflow_dispatch`.
- **`audit.yml`** — the consolidated cross-repo provenance audit (roadmap P4, Phase 3). **Scheduled**
  (weekly cron) + `workflow_dispatch`. It re-derives, live, for every plugin listed in
  `marketplace.json`: the repo exists and its `plugin.json` is fetchable/valid, `source.repo` matches
  `odere-pro/<repo>`, and the listed repo ships no `marketplace.json` of its own (it does **not**
  compare `entry.name` to `plugin.json.name` — the entry name may differ via `--name`, D13). It
  **reuses the `vet-candidate.sh` probes** (DRY — no fork) via `scripts/audit-cross-repo.sh`. It is
  **advisory / notify-only** (D3): it **never hard-FAILs**, **SKIPs** on any non-200/network/`gh`-auth
  error (a connectivity control probe distinguishes a transient outage from real drift). Per-entry
  checks are a **no-op while the registry is empty** (N=0); the About/topics check runs
  unconditionally after the connectivity control probe passes. It is deliberately **not** a
  `tests/gates/` push-suite gate — it makes network calls, which never enter `run-all.sh` (D3/D4).
  Auth is the default `GITHUB_TOKEN` exported as `GH_TOKEN` (reads public plugin repos, no extra
  secret, D17/Q1). Two additional checks extend the per-entry loop and post-loop (Phase 3):
  - **CHECK A — Install-coordinate validity (DRIFT-level):** `MISSING_NAME` is added to the
    per-entry relevance filter in `audit-cross-repo.sh`. A blank `plugin.json.name` breaks
    `<plugin>@odere-pro` install resolution (provenance drift). Source-fetchable is already covered
    by `PLUGIN_JSON_UNREADABLE` — no new probe needed (ADR: MISSING_NAME crosses the D13 line for
    coordinate-validity but stays excluded as an add-time quality floor at vet-time).
  - **CHECK B — About/topics advisory (ADVISORY-level, registry repo only):** checks the
    `odere-pro/claude-software-3-0-marketplace` repo for recommended discovery topics (`claude-code`,
    `marketplace`, `claude-code-plugins`) and a non-empty About description. Findings go to
    `"advisories"` in the report — **never counted as drift**, never escalate the drift issue.
  Two notify channels: on **drift** (or drift + advisories) → opens/updates the provenance-drift
  issue (`"cross-repo audit: provenance drift detected"`, advisories appended in its body). On
  **advisory-only** (drift empty) → opens/updates a **separate** advisory issue
  (`"cross-repo audit: discoverability advisory"`) so advisory notices never co-mingle with the
  provenance-drift issue. The open-or-update idiom is identical across both channels. Permissions are
  least-privilege: `contents: read` to read the checked-out manifest/scripts plus `issues: write` for
  the notify — both narrow scopes G16 permits without an allowlist entry (`issues: write`, like
  `security-events`/`id-token` `write`, is not the high-blast-radius `contents: write`). The single
  `actions/checkout` is SHA-pinned (G15).

The `ci.yml` `reproducible-diff` job (PR-only) runs `scripts/reproducible-diff.sh` (roadmap P15): a
network-free "green ⇒ machine-generated" check that the manifest's **structural** fields
(`source`/`license`/`homepage`, in canonical `jq --indent 2` form — the same formatter
`.claude/hooks/json-format.sh` uses) reproduce the script-emitted shape. It **excludes** the
LLM-curated `description`/`keywords` and is **not** auto-merge — CODEOWNERS still governs merge (D7).
It lives under `scripts/` (not `tests/gates/`) so it never enters the always-on push suite
`run-all.sh`.

The `audit.yml` job runs `scripts/audit-cross-repo.sh` (roadmap P4): the scheduled, advisory
provenance re-derivation described above. Like `reproducible-diff.sh` it lives under `scripts/` (not
`tests/gates/`) so it never enters the push suite — it makes network calls and is notify-only (D3).
It drives `vet-candidate.sh` per listed entry rather than re-implementing the probes (DRY).

## Supply chain

- **All actions are pinned by full commit SHA** with a trailing `# vX.Y.Z` comment — an OpenSSF
  "Pinned-Dependencies" signal.
- **`dependabot.yml`** watches the `github-actions` ecosystem weekly and bumps the SHA pins (it
  updates the pin and the comment together), committing with a `ci:` prefix.

## Governance

- **`CODEOWNERS`** — `* @odere-pro`; enables code-owner review on branch-protected PRs (a Scorecard
  "Code-Review" signal).

> No `release.yml` / tag-release flow: a registry has no versioned artifact of its own (each listed
> plugin owns its `version`). Revisit only if the registry itself ever becomes versioned.
