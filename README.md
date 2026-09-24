# harness

A **stack-agnostic engineering harness for Claude Code**. It ships the *mechanism* —
enforcement hooks, guardrail playbooks, and a PM delivery pipeline — and you **bring your own
agents**. Rails, Rust, Python, Go, anything: the harness reads a small per-project **stack
profile** so nothing is hardcoded to one framework.

> Status: early. Phase 1 = the plugin scaffold + config-driven hooks. Guardrails, PM pipeline,
> and the interactive installer land in later phases. See the spec in the project vault.

## What it is
- **Hooks (plugin):** a SessionStart status banner, a Stop verification gate, and a PreToolUse
  pipeline gate — all portable via `${CLAUDE_PLUGIN_ROOT}` and driven by your stack profile.
- **Config-driven:** each project has `.claude/harness.json` declaring which components are active
  and the stack's conventions (implementation dirs, test dir, operator-test dir, test command).
  With no config, the enforcing gates stay inert.
- **BYO agents:** the harness ships **zero** stack agents. Put your own in `.claude/agents/`.
  (`esparkman/rails-agents` is one example Rails agent bundle.)

## The stack profile (`.claude/harness.json`)
Written by the installer; a preset from `stacks/` merged with your component choices:
```json
{
  "components": { "session_banner": true, "verification_gate": true, "pipeline_gate": false },
  "stack": {
    "name": "rails",
    "impl_dirs": ["app", "lib", "db/migrate"],
    "ui_dirs": ["app/views", "app/controllers"],
    "test_dir": "test",
    "operator_test_dir": "test/system",
    "test_command": "bin/rails test"
  }
}
```
Presets ship in [`stacks/`](stacks/): `rails`, `node`, `generic` (more to come). Pick one or go custom.

## Install (interim — full interactive installer is Phase 3)
```sh
/plugin marketplace add esparkman/harness
/plugin install harness@harness
# then create .claude/harness.json in your project (copy a stacks/ preset under a "stack" key
# and add a "components" block).
```

## Components
| Component | Hook | Does |
|---|---|---|
| `session_banner` | SessionStart | Environment-verified status banner (config home, harness config, BYO agent count). |
| `verification_gate` | Stop | Warns when implementation/UI changed without an operator-journey test or a recorded review. |
| `pipeline_gate` | PreToolUse | Warns/blocks edits to the implementation surface without a DoR-passing story (or a declared small-fix). |

Each is opt-in via `components` in `.claude/harness.json`.
