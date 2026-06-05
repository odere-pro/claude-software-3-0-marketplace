# `docs/plan/` — roadmaps (proposals)

Author-only; never shipped, never loaded into an end-user session. This layer holds the **phased
roadmaps** the brainstorm team ([`../brainstorm/`](../brainstorm/)) produces and the `registry-dev`
team implements behind the gate suite.

- A roadmap is a **proposal**: it records decisions and their rejected alternatives but does not, by
  existing, authorize implementation — `registry-dev-manager` and the operator gate that
  ([`../teams.md`](../teams.md)).
- Items are carried into [`../../.claude/teams/registry-dev/BACKLOG.md`](../../.claude/teams/registry-dev/BACKLOG.md)
  (phase → lane → item) and driven one at a time behind `bash tests/gates/run-all.sh`.
- Naming: `NNNN-<slug>.md`. A roadmap the operator keeps out of version control may live in `tmp/`
  instead of here; this folder documents the layer regardless of where a given roadmap file sits.

See [`README.md`](README.md) for the roadmap structure and [`../teams.md`](../teams.md) for the
brainstorm → `registry-dev` handoff.
