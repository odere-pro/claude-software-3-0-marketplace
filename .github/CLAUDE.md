# `.github/` — CI, supply chain, governance wiring

Author-only. Continuous integration and the supply-chain hardening for the registry.

## Workflows (`workflows/`)

- **`ci.yml`** — always-on (every push + PR). Installs `jq` + `shellcheck` and runs
  `bash tests/gates/run-all.sh`. This is the gate that must stay green.
- **`scorecard.yml`** — OpenSSF Scorecard. **Dormant**: only `workflow_dispatch` is active; the
  `schedule`/`push` triggers are commented out because the public Scorecard API + code-scanning
  upload need a **public** repo. Uncomment them when the repo goes public.
- **`codeql.yml`** — CodeQL SAST over `languages: actions` (scans the workflow YAML itself; there is
  no compiled language here). Also **dormant** until public, for the same reason.

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
