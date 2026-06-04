# Changelog

Notable changes to the `odere-pro` marketplace registry. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This registry has no released version of its
own — each listed plugin carries its own `version` in its `plugin.json` — so entries are grouped under
`[Unreleased]` and dated as they land.

## [Unreleased]

### Added

- GitHub best practices and a top-level `.claude/` harness: governance docs (`SECURITY.md`,
  `CODE_OF_CONDUCT.md`, `SUPPORT.md`, `CONTRIBUTING.md`, `CODEOWNERS`), CI + supply-chain workflows
  (`ci.yml`, dormant `scorecard.yml` / `codeql.yml`, Dependabot, SHA-pinned actions), repo hygiene
  configs, a `tests/gates/` validation suite, a `SOFTWARE-3-0.md`, and nested `CLAUDE.md` navigation.
- Initial registry: `claude-oop-excellence` and `claude-calibration`, each as a `github` source.
