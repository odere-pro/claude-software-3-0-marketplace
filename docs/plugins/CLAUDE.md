# `docs/plugins/` — per-plugin install + quick-start guides

Author-only documentation (not shipped; not loaded into end-user sessions).

One file per **listed** plugin: how to install it from the `odere-pro` registry and the canonical
first-run sequence. Each page mirrors the quick start in the plugin's own repo README so the registry
is self-sufficient — a reader can go from "added the marketplace" to "ran the plugin" without leaving
this repo. The plugin's own repo remains the source of truth; if the two drift, refresh the page from
the upstream README.

Generic install steps and the `claude plugin …` lifecycle live in the root
[`README.md`](../../README.md) ("Install plugins" / "Test a plugin"); the pages here add the
plugin-specific quick start on top.

- [`claude-oop-excellence.md`](claude-oop-excellence.md) — OOP-quality audit + gated fix/implement;
  `/onboarding` → `/audit` → `/fix-risks` | `/implement-patterns`.
