# `docs/` — human-readable references

Author-only documentation (not shipped; not loaded into end-user sessions).

- [`adding-plugins.md`](adding-plugins.md) — the canonical, agent-driven process for listing a plugin
  in the registry: the `/vet-plugin` and `/add-plugin` skills, the listability contract, how to clear
  each blocker, and the manual fallback. Start here when growing the marketplace.

Keep docs link-clean — `tests/gates/05-doc-links.sh` fails CI on a dangling intra-repo `.md` link.
