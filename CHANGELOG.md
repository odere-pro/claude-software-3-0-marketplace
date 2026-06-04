# Changelog

Notable changes to the `odere-pro` marketplace registry. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This registry has no released version of its
own — each listed plugin carries its own `version` in its `plugin.json` — so entries are grouped under
`[Unreleased]` and dated as they land.

## [Unreleased]

### Added

- Agent-driven "add a plugin" workflow: `/add-plugin` + `/vet-plugin` skills, a `plugin-onboarder`
  worker agent, deterministic `vet-candidate` / `add-entry` / `sync-readme` scripts, a
  `09-readme-in-sync` gate (README table generated from the manifest), and `docs/adding-plugins.md`.
- Relaxed `02-marketplace-shape` to allow an entry `name` to differ from the repo basename (owner still
  pinned to `odere-pro`) and to require unique entry names; `marketplace-guard` mirrors the owner rule.

- GitHub best practices and a top-level `.claude/` harness: governance docs (`SECURITY.md`,
  `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `CONTRIBUTING.md`, `CODEOWNERS`), CI + supply-chain workflows
  (`ci.yml`, dormant `scorecard.yml` / `codeql.yml`, Dependabot, SHA-pinned actions), repo hygiene
  configs, a `tests/gates/` validation suite, a `SOFTWARE-3-0.md`, and nested `CLAUDE.md` navigation.
- The registry starts **empty** — plugins are added one at a time (after testing) via `/add-plugin`.
