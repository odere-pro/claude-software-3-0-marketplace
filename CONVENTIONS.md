# odere-pro plugin conventions

Every plugin listed in this marketplace follows these conventions, so a user gets a consistent
experience across the whole `odere-pro` suite. New plugins match this before they are listed; existing
ones are normalized to it.

## Identity & licensing

- **License: MIT.** A `LICENSE` file, `"license": "MIT"` in `.claude-plugin/plugin.json`, and `MIT` on
  the marketplace entry — all three agree. No `NOTICE` file.
- **Author:** `Oleksandr Derechei` (`odere-pro`) — `.claude-plugin/plugin.json` carries
  `{ "name": "Oleksandr Derechei", "email": "odere.pro@gmail.com", "url": "https://github.com/odere-pro" }`.
- **Description:** clear and concise, present tense, names the core verb.

## Command & skill surface

- **One clear entry verb** — e.g. `wiki`, `audit`, `calibrate`, `write`.
- **An `onboarding` skill** — first-run orientation: what it is, the one command to run first.
- **A `doctor` health check where the environment warrants it** — when the plugin needs a runtime
  (Bun), a vault, or external tools. Pure read-only analyzers (nothing to diagnose) may omit it.
- **Skill frontmatter** declares `name`, `description`, `allowed-tools`; reference skills (teach, don't
  act) add `disable-model-invocation: true`.

## README skeleton (in this order)

`What's inside` · `How it works` · `Prerequisites` · `Install` · `Quickstart` · `Documentation` ·
`Privacy` · `License`

- **Install** shows: `/plugin marketplace add odere-pro/claude-software-3-0-marketplace` then
  `/plugin install <name>`.
- **Privacy** carries a "no telemetry / never phones home" note.

## Repo hygiene

- `CLAUDE.md` (contributor/dev orientation), `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com/)),
  `LICENSE`.
- **CI** at minimum validates the manifest and runs the plugin's own tests; pin third-party actions.
- No telemetry anywhere.
