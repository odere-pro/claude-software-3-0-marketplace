# Changelog

Notable changes to the `odere-pro` marketplace registry. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This registry has no released version of its
own — each listed plugin carries its own `version` in its `plugin.json` — so entries are grouped under
`[Unreleased]` and dated as they land.

## [Unreleased]

### Added
- List `claude-calibration` (`odere-pro/claude-calibration`).
- List `claude-wiki-pages` (`odere-pro/claude-wiki-pages-plugin`).
- List `claude-oop-excellence` (`odere-pro/claude-oop-excellence`).

- Operability-core gates: `11-changelog-in-sync` (every listed plugin named in the changelog),
  `12-skill-failure-handling` (each `SKILL.md` documents rollback), `13-skill-frontmatter` (required
  skill front-matter), `14-skill-script-paths` (skill script references resolve); deterministic
  CHANGELOG bullets from the add/update/remove scripts; README **License**/**Keywords** columns; a
  PR-scoped `reproducible-diff` CI check for the manifest's structural fields (not auto-merge).
- `/update-plugin` (refresh / `--repo` repoint / `--name` rename) and `/remove-plugin` skills, with
  `update-entry.sh` / `remove-entry.sh` and a `--skip-listed-check` mode on `vet-candidate.sh`.
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
