# Bring-your-own agents

The harness ships **no** agents. It's deliberately agnostic about who does the work — you supply the
specialists in your project's `.claude/agents/`. This is what makes the harness stack-neutral: a
Rust team brings Rust agents, a Rails team brings Rails agents, and the same hooks/guardrails/PM
pipeline wrap around all of them.

## Adding agents

Agents are Markdown files in `.claude/agents/` (Claude Code's native location). Drop yours in — as
committed files, or as symlinks to a shared bundle.

Using an example bundle, e.g. [esparkman/rails-agents](https://github.com/esparkman/rails-agents):
```sh
git clone https://github.com/esparkman/rails-agents ~/rails-agents
cd /path/to/your/project && mkdir -p .claude/agents
for f in ~/rails-agents/rails-*.md ~/rails-agents/dhh-code-reviewer.md; do
  ln -sfn "$f" ".claude/agents/$(basename "$f")"
done
# keep the machine-local symlinks out of git (they point at your $HOME clone):
printf '%s\n' '.claude/agents/rails-*.md' '.claude/agents/dhh-code-reviewer.md' >> .claude/agents/.gitignore
```

Prefer committing real files if you want the whole team to get identical agents without cloning a
bundle. Prefer gitignored symlinks if agents come from a per-developer clone (never commit a
`$HOME` path).

## How agents and the harness interact

- The harness's **hooks and skills fire regardless of which agents are present** — guardrails load
  by task, the gates read the stack profile, the banner counts whatever's in `.claude/agents/`.
- The **PM pipeline** (`product-manager` skill) routes ready work to "the right engineer" — that's
  one of *your* agents. It doesn't care what stack they are.
- If you also install an agent bundle *as a plugin*, note that **project `.claude/agents/` overrides
  same-named plugin agents** — your project's version wins.

## Authoring your own agents

An agent is a Markdown file with YAML front-matter:
```markdown
---
name: my-domain-expert
description: What this agent owns and when to use it.
model: sonnet
tools: Read, Write, Edit, Grep, Glob, Bash
---

# My Domain Expert
Instructions, conventions, and the discipline this agent follows…
```
Guidance:
- **One clear owner per domain.** Route each kind of work to the agent that owns it.
- **Ground the agent in truth, not memory.** If your stack has a way to query the real project
  (a language server, a schema/route introspector, an MCP server), instruct the agent to use it
  before inferring structure from partial reads.
- **A reviewer at the end.** Keep a review agent as the final gate; the verification gate expects a
  review recorded in `.claude/.last-review`.
- **Let the harness carry discipline.** You don't need to bake guardrails or verification rules into
  each agent — the guardrails skill and the gates handle that globally. Keep agents focused on their
  domain.

## The delegation map

Where you enforce "always delegate to an agent," put it in your global ruleset
(`templates/global-CLAUDE.md` has a `TODO` slot for the delegation map). The harness provides the
enforcement scaffolding; your ruleset + agents provide the routing.
