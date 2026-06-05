# `.github/` — CI, supply chain, governance wiring

Author-only. Continuous integration and the supply-chain hardening for the registry.

## Workflows (`workflows/`)

- **`ci.yml`** — always-on (every push + PR). Installs `jq` + `shellcheck` and runs
  `bash tests/gates/run-all.sh`. This is the gate that must stay green. The checkout uses
  `fetch-depth: 0` (full history) so the commit-author backstop gate `17-commit-author.sh` can scan
  every commit (roadmap P14/D15). It also carries two PR-only jobs:
  - **`history-secret-scan`** — runs `gitleaks/gitleaks-action` (SHA-pinned) over the full git
    history to FAIL the PR on any committed secret (roadmap P-history-secret-scan; active now, the
    repo is public, D16). It shares the same `fetch-depth: 0` checkout pattern. **Org note:**
    gitleaks-action requires `GITLEAKS_LICENSE` for **org-owned** repos — set it as a repo secret
    (gitleaks.io) or the action errors. It runs only on `pull_request`, so it never blocks a push.
  - **`reproducible-diff`** — see below.
- **`scorecard.yml`** — OpenSSF Scorecard. **Dormant**: only `workflow_dispatch` is active; the
  `schedule`/`push` triggers are commented out because the public Scorecard API + code-scanning
  upload need a **public** repo. Uncomment them when the repo goes public.
- **`codeql.yml`** — CodeQL SAST over `languages: actions` (scans the workflow YAML itself; there is
  no compiled language here). Also **dormant** until public, for the same reason.

The `ci.yml` `reproducible-diff` job (PR-only) runs `scripts/reproducible-diff.sh` (roadmap P15): a
network-free "green ⇒ machine-generated" check that the manifest's **structural** fields
(`source`/`license`/`homepage`, in canonical `jq --indent 2` form — the same formatter
`.claude/hooks/json-format.sh` uses) reproduce the script-emitted shape. It **excludes** the
LLM-curated `description`/`keywords` and is **not** auto-merge — CODEOWNERS still governs merge (D7).
It lives under `scripts/` (not `tests/gates/`) so it never enters the always-on push suite
`run-all.sh`.

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
