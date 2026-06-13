# Managing odere-pro marketplace plugins

This is the canonical, agent-driven process for **adding, updating, and removing** plugins in the
`odere-pro` registry. It is **author-only** tooling — it edits this repo's `marketplace.json`, README,
CHANGELOG, and the generated Pages `site/`, and opens a PR. It never edits a plugin's own repository.

## TL;DR

```text
/vet-plugin   claude-aws-architect           # read-only: is it ready? what's blocking?
/add-plugin   claude-aws-architect           # add: vet → manifest + README + CHANGELOG → gates → PR
/update-plugin claude-aws-architect          # refresh metadata from the plugin's plugin.json
/update-plugin claude-aws-architect --repo odere-pro/new-repo   # replace / repoint
/update-plugin claude-aws-architect --name aws-architect        # rename the entry
/remove-plugin claude-aws-architect          # drop the entry
```

`<repo>` defaults the owner to `odere-pro`; pass `owner/repo` to be explicit (owner must be
`odere-pro`). `/add-plugin` and `/update-plugin` accept `--name <name>` to set/override the entry name;
`/remove-plugin` and `/update-plugin` take the entry **name** as it appears in the registry.

## The contract (what makes a candidate listable)

A candidate is ready when **all** of these hold (enforced by
`.claude/skills/add-plugin/scripts/vet-candidate.sh`, the `marketplace-guard` hook, and
`tests/gates/02-marketplace-shape.sh`):

- **Owner is `odere-pro`.** The registry is odere-pro-only.
- **It has a valid `.claude-plugin/plugin.json`** with `name`, `description`, and `license`.
- **It ships at least one component directory** — `commands/`, `agents/`, `skills/`, or `hooks/`. A
  plugin with a `plugin.json` but no components is an empty shell. The vet probes these directories
  directly (a constant-cost `contents/<dir>` check, stopping at the first one found — never a
  recursive tree walk), so it stays within the add-time API budget.
- **It ships no `.claude-plugin/marketplace.json` of its own.** A second repo declaring the marketplace
  name `odere-pro` silently shadows this registry — the collision that broke installs before. The
  plugin must be plugin-only.
- **It isn't already listed** here.
- **The listing meets the quality floors** (G2 enforces these on every entry): `description` is
  non-empty, at least 20 characters, and is not just a repeat of the entry `name`; `keywords` lists at
  least one term; and `homepage` (when present) starts with `https://`. These keep each listing
  useful for discovery rather than a bare stub. The generic-keyword denylist
  (e.g. `claude-code`, `plugin`) is **advisory** — `plugin-onboarder` drops generic noise during
  curation, but a generic keyword does not by itself block a listing.

The entry written into `marketplace.json` is always a `github` source with **no `version`** (the
plugin's own `plugin.json` is the version of record) and **no `sha`/`commit`** (installs track the
default branch). The entry `name` may differ from the repo basename — e.g. `plugin-cookbook` lives in
`odere-pro/claude-plugin-cookbook`.

## Listing quality guide

The `plugin-onboarder` agent curates the `description` and `keywords` for every listing. This
section makes those heuristics public so you can write quality metadata before running `/add-plugin`,
and so the curation step is predictable rather than opaque.

### Description

A good listing description is **tight, accurate, and concrete** — one focused paragraph that tells a
developer exactly what the plugin does and when to reach for it. The floors enforced by
`tests/gates/02-marketplace-shape.sh` are a minimum, not a target: ≥ 20 characters and not a repeat of
the entry name. Aim for 60–120 characters: enough to be specific, short enough to scan.

**Voice and tone:**

- State what the plugin *does*, not what it *is* ("Provides structured OOP review workflows" not "A
  plugin for OOP").
- Be concrete about the domain or task ("AWS architecture decisions", "calibration of LLM outputs",
  "wiki-style page generation").
- Omit marketing language: no "powerful", "comprehensive", "amazing", "best-in-class". These are
  noise in a discovery surface.
- Do not repeat the plugin name verbatim in the description — the name is shown alongside it.

**Examples:**

| Description | Verdict |
| ----------- | ------- |
| `"OOP excellence plugin for Claude Code."` | **Weak** — too short (36 chars), vague, repeats the name concept, no concrete task. |
| `"Structured agents and skills for applying object-oriented design principles (SOLID, patterns, refactoring) during code review and generation."` | **Strong** — concrete domain, lists the actual techniques, scannable, no fluff. |
| `"A plugin."` | **Fails G2** — below 20 characters and says nothing. |
| `"Automated calibration workflows that align LLM response quality to a target rubric, using pairwise comparison agents and a feedback loop."` | **Strong** — describes the mechanism and the outcome, specific without being long. |

### Keywords

Keywords feed discovery and the future site's filter surface. The `plugin-onboarder` drops generic
noise automatically, but well-chosen keywords in `plugin.json` reduce the curation step to
pass-through.

**Rules of thumb:**

- Pick 3–6 keywords that are **specific to the plugin's domain**, not to the hosting platform.
- **Always drop** (or never add): `claude-code`, `plugin`, `claude`, `ai`, `llm`, `tool`. These
  describe every entry in the registry equally and add no signal.
- Prefer **noun phrases** that a developer would search for: `code-review`, `oop`, `refactoring`,
  `calibration`, `wiki`, `documentation-generator`.
- Include the primary **technology or methodology** if it is non-obvious from the name:
  `solid-principles`, `pairwise-comparison`, `markdown`.

**Examples:**

| Keywords | Verdict |
| -------- | ------- |
| `["claude-code", "plugin", "ai"]` | **Weak** — all generic; a developer filtering by these gets the entire registry. Onboarder drops all three and falls back to the name. |
| `["oop", "solid-principles", "code-review", "refactoring", "design-patterns"]` | **Strong** — specific to the domain; each term independently narrows the candidate set. |
| `["calibration"]` | **Acceptable** — meets the ≥ 1 term floor; could be strengthened with `["calibration", "llm-alignment", "rubric", "pairwise-comparison"]`. |
| `["wiki", "documentation-generator", "markdown", "page-builder"]` | **Strong** — four distinct, non-overlapping domain terms. |

### Overriding curation at add/update time

If the candidate's `plugin.json` carries suboptimal metadata, you can pass curated values directly
when invoking the skills — the scripts forward them to `add-entry.sh` / `update-entry.sh`:

```bash
/add-plugin claude-oop-excellence \
  --description "Structured agents for applying SOLID and design patterns during code review." \
  --keywords "oop,solid-principles,code-review,refactoring"

/update-plugin claude-oop-excellence \
  --description "Updated description." \
  --keywords "oop,refactoring"
```

This bypasses the `plugin-onboarder` curation step for those fields and uses the supplied values
directly. The quality floors in G2 (`tests/gates/02-marketplace-shape.sh`) still apply.

## Pre-submission checklist (candidate repo)

Before `/add-plugin`, confirm the candidate repo satisfies the contract. The vet runs all of this
automatically, but you can self-check first:

- [ ] The repo is **`odere-pro`-owned** and is a plugin (ships `.claude-plugin/plugin.json`).
- [ ] `plugin.json` has a non-empty **`name`**, **`description`**, and an SPDX **`license`** in the
      allowlist (`MIT Apache-2.0 BSD-2-Clause BSD-3-Clause ISC 0BSD MPL-2.0`).
- [ ] The repo ships **no `.claude-plugin/marketplace.json`** of its own (it would shadow this registry).
- [ ] The repo ships **at least one component directory** (`commands/`, `agents/`, `skills/`, or `hooks/`).
- [ ] `description` is ≥ 20 characters and is not just the `name`; `keywords` lists ≥ 1 term;
      `homepage` (if set) starts with `https://`.

Validate the candidate's `plugin.json` shape locally with one `jq` line (no schema file is hosted
here — the SPDX allowlist and field rules live in `vet-candidate.sh` + `02-marketplace-shape.sh`, so
there is nothing to version-drift):

```bash
gh api repos/<owner>/<repo>/contents/.claude-plugin/plugin.json --jq '.content' | base64 -d \
  | jq -e 'has("name") and has("description") and has("license")
           and (.name|length>0) and (.description|length>=20) and (.license|length>0)' \
  && echo "plugin.json has the required fields" || echo "plugin.json is missing a required field"
```

## How it works (the pieces)

| Piece | Role |
| ----- | ---- |
| `/add-plugin`, `/vet-plugin`, `/update-plugin`, `/remove-plugin` | the skills you invoke (`.claude/skills/`) |
| `plugin-onboarder` | worker agent: fetches + vets the repo, curates description/keywords (`.claude/agents/`) |
| `vet-candidate.sh` | read-only preflight → JSON verdict (`ok` + `blockers[]` + entry fields); `--skip-listed-check` for updates |
| `add-entry.sh` | re-vets, then inserts the entry with `jq` (idempotent, no duplicates) |
| `update-entry.sh` | re-vets, then replaces an existing entry in place (refresh / repoint / rename) |
| `remove-entry.sh` | deletes an entry by name with `jq` |
| `sync-readme.sh` | regenerates the README Plugins table from the manifest |
| `sync-site.sh` | regenerates the Pages `site/` (one card per plugin) from the manifest; `--check` diffs without writing |
| gate `02-marketplace-shape` | CI enforcement of the contract above (allows an empty registry) |
| gate `09-readme-in-sync` | README table can't drift from the manifest |
| gate `18-pages-in-sync` | the Pages `site/` can't drift from the manifest (run `sync-site.sh` after every entry change) |

## Clearing the common blockers

- **"still ships `.claude-plugin/marketplace.json`"** — remove it in the candidate's own repo first
  (plus any CI gate that requires it), the same change made for `claude-oop-excellence` and
  `claude-calibration`: branch off `main`, `git rm .claude-plugin/marketplace.json`, keep `plugin.json`,
  PR. Then re-run `/add-plugin`.
- **"owner is …; lists odere-pro repos only"** — only `odere-pro`-owned repos can be listed.
- **"ships no plugin component directory"** — add at least one of `commands/`, `agents/`, `skills/`,
  or `hooks/` to the candidate repo (a plugin needs at least one component to do anything), then
  re-run the vet.
- **"already listed"** — it's already in the marketplace; nothing to do.

## Updating or replacing a plugin

`/update-plugin <name>` operates on an **already-listed** entry and re-vets the target repo with
`--skip-listed-check` (so "already listed" isn't a blocker), then replaces the entry in place:

- **Refresh** — `/update-plugin <name>` re-pulls `description` / `keywords` / `homepage` / `license`
  from the plugin's current `plugin.json` (use after the plugin changes its manifest).
- **Replace / repoint** — `/update-plugin <name> --repo odere-pro/<new-repo>` points the same entry at a
  different odere-pro repo (the new repo is vetted like any candidate).
- **Rename** — `/update-plugin <name> --name <new-name>` renames the entry (refuses a name that collides
  with another entry).

It only ever changes an existing entry; to add a brand-new one use `/add-plugin`.

## Removing a plugin

`/remove-plugin <name>` deletes the entry by name, regenerates the README (showing the placeholder if it
was the last plugin), updates CHANGELOG, runs the gates, and opens a PR. Removing the last entry leaves
`plugins: []`, which is allowed.

## Empty registry

The marketplace starts with **no plugins**; they're added one at a time (after testing) via
`/add-plugin`. While the `plugins` array is empty, `bash tests/gates/run-all.sh` is green, but
`claude plugin validate --strict` warns "Marketplace has no plugins defined" — that's expected. The
gate suite is the authoritative check; `--strict` validation becomes meaningful once the first plugin
is listed.

## Manual fallback

If you'd rather edit by hand: append one `github`-source block to the `plugins` array in
`.claude-plugin/marketplace.json` (no `version`/`sha`), run
`bash .claude/skills/add-plugin/scripts/sync-readme.sh` **and**
`bash .claude/skills/add-plugin/scripts/sync-site.sh`, add a `CHANGELOG.md` bullet, then
`bash tests/gates/run-all.sh` (and `claude plugin validate .`). Skipping `sync-site.sh` leaves the
Pages `site/` stale and fails gate `18-pages-in-sync`. See [`CONTRIBUTING.md`](../CONTRIBUTING.md).
