# `docs/` — human-readable references

Author-only documentation (not shipped; not loaded into end-user sessions).

- [`adding-plugins.md`](adding-plugins.md) — the canonical, agent-driven process for managing the
  registry: the `/vet-plugin`, `/add-plugin`, `/update-plugin` (refresh / `--repo` repoint / `--name`
  rename), and `/remove-plugin` skills, the listability contract, how to clear each blocker, and the
  manual fallback. Start here when growing or maintaining the marketplace.
- [`teams.md`](teams.md) — how the two dev-only agent teams relate: the ideation **brainstorm** team
  and the implementation **`registry-dev`** team, and the roadmap handoff between them.
- [`brainstorm/`](brainstorm/) — the 12-persona, read-only brainstorm team apparatus (charter, roster,
  protocol) that ideates the agentic-engineering level-up.
- [`plan/`](plan/) — phased roadmaps (proposals) produced by the brainstorm team and consumed by
  `registry-dev`.
- [`plugins/`](plugins/) — per-plugin install + quick-start guides for listed plugins (one file per
  plugin; mirrors each plugin's own README quick start so the registry is self-sufficient).

Keep docs link-clean — `tests/gates/05-doc-links.sh` fails CI on a dangling intra-repo `.md` link.
