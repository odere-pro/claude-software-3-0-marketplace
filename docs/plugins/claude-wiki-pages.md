# claude-wiki-pages — install & quick start

[`odere-pro/claude-wiki-pages-plugin`](https://github.com/odere-pro/claude-wiki-pages-plugin) · Apache-2.0

Turns an Obsidian vault into a maintained, provenance-tracked knowledge base following Andrej
Karpathy's **LLM Wiki** pattern. The human curates sources; the plugin maintains the wiki; hooks
enforce the schema at every tool-call boundary so pages stay typed and citation-backed. A Bun engine
does the deterministic verify/fix/index/search work, and every auto-heal is git-checkpointed — so any
correction the plugin makes is reversible with a plain `git revert`.

## Install

In a Claude Code session:

```text
/plugin marketplace add odere-pro/claude-software-3-0-marketplace
/plugin install claude-wiki-pages@odere-pro
```

Or from the shell:

```bash
claude plugin marketplace add odere-pro/claude-software-3-0-marketplace
claude plugin install claude-wiki-pages@odere-pro
claude plugin list                          # confirm installed/enabled
```

Plugins install per-user (per machine), not per-project — once installed it's available in every repo
you open. A session restart may be needed for its skills, agents, and hooks to load. See the root
[README](../../README.md) for the generic install / `claude plugin …` lifecycle details.

**Prerequisites:** `bash`, `git`, and `jq`. **Bun >= 1.2 is recommended** — it runs the deterministic
engine and the git-checkpointed self-heal; without it the plugin still works, but those engine
commands are disabled. Point it at a **git repo for the vault** so self-heal can checkpoint and
revert. **Obsidian is optional** (graph view, Dataview, Web Clipper). It needs **no MCP server** and
makes no external API calls. macOS/Linux verified.

## Quick start

The plugin has one verb plus a wizard and a health check:

```text
/claude-wiki-pages:wiki          # THE verb — probes vault state, dispatches init / ingest / curator / analyst
/claude-wiki-pages:onboarding    # first-run wizard: scaffold → ingest → first answer
/claude-wiki-pages:doctor        # environment health check — reports green when prereqs are met
```

On a fresh vault, `/claude-wiki-pages:wiki` runs the init wizard and scaffolds a sample, so you see a
real result with no files of your own. Then it's curate-and-maintain: drop new files into `raw/` and
the ingest agent produces typed, citation-backed wiki pages from them.

A typical first session: `/claude-wiki-pages:onboarding` (first time) → `/claude-wiki-pages:wiki` to
init and scaffold → add sources to `raw/` → `/claude-wiki-pages:wiki` to ingest them into the wiki.

## What it ships

| Kind | Items |
| ---- | ----- |
| Skills | **23** — 12 short verbs (`init`, `ingest`, `query`, `lint`, `fix`, `status`, `synthesize`, `index`, `markdown`, `search`, `review`, `draft`) + `onboarding` + 5 agent-teaching skills + Obsidian helpers |
| Agents | **7** — orchestrator + `onboarding` / `ingest` / `curator` / `analyst` / `polish` / `maintenance` worker subagents |
| Commands | **3** — the entry points `/claude-wiki-pages:wiki`, `/claude-wiki-pages:onboarding`, `/claude-wiki-pages:doctor` |
| Hooks | **15** — SessionStart + UserPromptSubmit + 7 PreToolUse + 2 PostToolUse + 2 SubagentStop + Stop + SessionEnd (schema enforcement & session memory) |
| Rules | **4** — path-scoped |

Full mode matrix and arguments live in the plugin's own repo, which is the source of truth:
<https://github.com/odere-pro/claude-wiki-pages-plugin>.
