# Dev teams — how the two agent teams relate

> Author-only apparatus. Neither team ships; nothing here is loaded into an end-user session. Both
> exist to **level up the agentic engineering** of the `odere-pro` marketplace (`SOFTWARE-3-0.md`).

The registry uses two complementary, dev-only agent teams — one that **ideates** and one that
**implements** — with a single handoff between them: a phased roadmap in `docs/plan/`.

## The two teams

| Team | Location | Role | Mode | Output |
| --- | --- | --- | --- | --- |
| **Brainstorm** | [`brainstorm/`](brainstorm/) (12 personas) | Ideate the full-spectrum level-up — internal harness + external product | READ-ONLY / proposal-only | A phased roadmap in [`plan/`](plan/) |
| **`registry-dev`** | [`../.claude/teams/registry-dev/`](../.claude/teams/registry-dev/) (9 roles) | Implement the roadmap behind the gate suite | Edits its lane's paths, one item at a time | Merged-green changes |

## The handoff

```text
docs/brainstorm/  ──(writes)──▶  docs/plan/<roadmap>.md  ──(consumed via BACKLOG.md)──▶  .claude/teams/registry-dev/
   (proposes)                       the proposal                                            (implements)
```

1. **Brainstorm.** Spawn the 12-persona team (kickoff in `docs/brainstorm/README.md`; ready-to-paste
   copy in the git-ignored `tmp/brainstorm-kickoff.md`). `facilitator-pm` runs the three-round
   protocol and writes a phased, assignable roadmap to `docs/plan/` with `registry-architect`'s
   coherence sign-off. The roadmap is a **proposal**.
2. **Implement.** `registry-dev-manager` reads `docs/plan/<roadmap>.md`, copies each item into
   `.claude/teams/registry-dev/BACKLOG.md` (phase → lane → item), and drives delivery through the
   handoff chain (Architect → engineer → QA-functional → QA-adversarial → PM) behind
   `bash tests/gates/run-all.sh` and `claude plugin validate .`.

## When to use which

- Use the **brainstorm team** when the question is *what should we do and in what order* — open-ended
  improvement of the harness or the product.
- Use **`registry-dev`** when there is a roadmap (or a single well-scoped item) to *build* behind the
  gates.

## Prerequisites (both)

Agent Teams enabled: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` (read at
startup — restart Claude Code after enabling).
