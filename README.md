# harness

**A stack-agnostic engineering harness for Claude Code.** It turns Claude Code into a disciplined
teammate — enforcement hooks, guardrail playbooks, and a product-management delivery pipeline —
and it works for *any* stack because it's driven by a small per-project config. You **bring your
own agents**; the harness supplies the mechanism.

```sh
git clone https://github.com/octanelabsdev/harness ~/harness
~/harness/install.sh /path/to/your/project      # interactive: pick your stack + components
```

That's it. Restart Claude Code in your project and the harness is live.

---

## Why this exists

Left alone, an AI coding agent forgets the rules it was told, claims "done" without running
anything, edits the wrong file, and drifts from your conventions. A **harness** is the scaffolding
that holds it to a standard:

- a **SessionStart banner** that reports *environment-verified* state (not the model's memory),
- a **verification gate** that won't let a turn end claiming success without evidence,
- a **pipeline gate** that keeps feature work flowing through a Definition-of-Ready story,
- **guardrails** — short checklists the model reads at the exact moment a known mistake is about
  to happen,
- a **PM pipeline** (story-writer → DoR gate → product-manager) so work is ready before it's built.

Most harnesses are welded to one framework. This one isn't: every stack-specific detail lives in a
**stack profile** you pick at install time, so the same hooks work for Rails, Node, Python, Go, or
anything you describe.

## The mental model: mechanism vs. payload

| | Where it lives | You get it by |
|---|---|---|
| **Mechanism** — hooks, guardrails, PM pipeline | this repo (a Claude Code **plugin**) | `install.sh` / `/plugin` |
| **Stack profile** — impl dirs, test dir, test command | `.claude/harness.json` in your project | `install.sh` writes it |
| **Agents** — your specialists | your project's `.claude/agents/` (**BYO**) | you drop them in |

The harness ships **zero agents**. Bring your own — or use an example bundle like
[octanelabsdev/rails-agents](https://github.com/octanelabsdev/rails-agents) for Rails.

## What's inside

- **Hooks** (`hooks/`) — `session_start_banner`, `verification_gate`, `pipeline_gate`. Portable
  (`${CLAUDE_PLUGIN_ROOT}`), config-driven, and **inert until you configure them**.
- **Skills** (`skills/`) — `guardrails` (6 playbooks: CODE, DEBUG, VERIFY, TRAPS, RUNTIME,
  MECHANISM), `story-writer`, `product-manager`. Model-invoked, stack-agnostic.
- **Stacks** (`stacks/`) — presets: `rails`, `node`, `python`, `go`, `generic` (+ custom).
- **Installer** (`install.sh`) — interactive or flag-driven.
- **Template** (`templates/global-CLAUDE.md`) — a generic starter ruleset for your config home.

## 60-second tour of a configured project

After `install.sh`, your project has:

```jsonc
// .claude/harness.json   (committed — your team shares it)
{
  "components": { "session_banner": true, "verification_gate": true, "pipeline_gate": true },
  "stack": {
    "name": "rails",
    "impl_dirs": ["app", "lib", "db/migrate"],
    "ui_dirs": ["app/views", "app/controllers"],
    "test_dir": "test", "operator_test_dir": "test/system",
    "test_command": "bin/rails test"
  }
}
```
```jsonc
// .claude/settings.json   (committed — safe: references the versioned plugin, not a $HOME script)
{ "extraKnownMarketplaces": { "harness": { "source": { "source": "github", "repo": "octanelabsdev/harness" } } },
  "enabledPlugins": { "harness@harness": true } }
```

Open a session and the banner reports it:

```
HARNESS CHECK (SessionStart hook — environment-verified, not model memory):
  global CLAUDE.md : present (72 lines)
  harness          : configured (stack: rails; active: session_banner, verification_gate, pipeline_gate)
  agents (BYO)     : 21 agent(s)
```

## Documentation

- **[docs/concepts.md](docs/concepts.md)** — the architecture, the plugin+config split, the security model.
- **[docs/install.md](docs/install.md)** — install in depth: interactive, flags, scopes, CI, updating, uninstalling.
- **[docs/configuration.md](docs/configuration.md)** — `.claude/harness.json`, components, stack profiles (presets + custom).
- **[docs/components.md](docs/components.md)** — the three hooks and three skills, in detail; warn → block.
- **[docs/agents.md](docs/agents.md)** — bring-your-own agents: adding, overriding, authoring, the rails-agents example.
- **[docs/troubleshooting.md](docs/troubleshooting.md)** — FAQ and fixes.

## Requirements

Claude Code, plus `bash`, `git`, `jq`, and `python3`. (`ruby` if you use the story-writer's DoR lint.)

## License

MIT.
