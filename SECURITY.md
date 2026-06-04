# Security policy

`claude-software-3-0-marketplace` is a **registry**, not a plugin. It ships no executable code and no
compiled binaries — its only payload is `.claude-plugin/marketplace.json`, a manifest that points at
plugin repositories owned by `odere-pro`, plus documentation and a small author-only `.claude/` harness
(Bash hooks that run on the maintainer's machine, never for end users).

## Trust model

- **No code is installed from this repo.** Adding the marketplace (`/plugin marketplace add
  odere-pro/claude-software-3-0-marketplace`) only registers an index. Installing a plugin
  (`<plugin>@odere-pro`) pulls that plugin from **its own** repository — so each listed plugin's
  security policy governs the code you actually run.
- **No network on the hot path.** No shipped file fetches a remote payload. The author-only hooks under
  `.claude/hooks/` are local Bash and call no `curl`/`wget`; a CI gate (`tests/gates/06-shellcheck.sh`)
  and the harness rules keep them that way.
- **No secrets, no machine paths.** `tests/gates/04-secret-scan.sh` and `03-no-absolute-paths.sh` fail
  CI on any token-shaped string or leaked home path.
- **Pinned supply chain.** Every GitHub Action is pinned by commit SHA; Dependabot bumps the pins.

## Supported versions

This registry tracks its `main` branch — there is no released, versioned artifact (each listed plugin
carries its own `version`). The current `main` is always the supported state.

## Reporting a vulnerability

Please report privately via **GitHub Security Advisories** —
<https://github.com/odere-pro/claude-software-3-0-marketplace/security/advisories/new> — rather than
opening a public issue. We aim to acknowledge within a few days and to fix or mitigate confirmed issues
before any public disclosure. For a vulnerability in a **listed plugin**, report it to that plugin's
own repository.
