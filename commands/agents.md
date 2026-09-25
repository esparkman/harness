---
description: Bring your stack's agent bundle into .claude/agents/ — symlinked per-developer by default, or committed for the whole team with --copy.
---

Bring agents into this project. The harness ships no agents (bring-your-own); this pulls a bundle and
wires it into `.claude/agents/`.

Run this, passing through any arguments the user supplied (`$ARGUMENTS`):

```
bash "${CLAUDE_PLUGIN_ROOT}/tools/add_agents.sh" $ARGUMENTS
```

Argument shapes to expect in `$ARGUMENTS`:

- *(nothing)* — use the stack's default bundle from `.claude/harness.json` (e.g. Rails →
  `octanelabsdev/rails-agents`), symlinked and gitignored (per-developer)
- `--copy` — same bundle, but copied in as committed real files so the whole team gets them
- `owner/repo` (or a git URL) — pull that bundle instead of the stack default
- `--copy owner/repo` — that bundle, committed

If the current stack declares no default bundle and the user gave no repo, the tool says so — relay
that and ask which bundle to use. After it runs, report how many agents were placed and whether they
were symlinked (per-developer) or copied (committed).
