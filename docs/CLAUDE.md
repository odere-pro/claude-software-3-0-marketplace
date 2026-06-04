# `docs/` — human-readable references

Author-only documentation (not shipped; not loaded into end-user sessions).

- [`adding-plugins.md`](adding-plugins.md) — the canonical, agent-driven process for managing the
  registry: the `/vet-plugin`, `/add-plugin`, `/update-plugin` (refresh / `--repo` repoint / `--name`
  rename), and `/remove-plugin` skills, the listability contract, how to clear each blocker, and the
  manual fallback. Start here when growing or maintaining the marketplace.

Keep docs link-clean — `tests/gates/05-doc-links.sh` fails CI on a dangling intra-repo `.md` link.
