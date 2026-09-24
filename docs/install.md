# Installing the harness

## TL;DR

```sh
git clone https://github.com/octanelabsdev/harness ~/harness
~/harness/install.sh /path/to/your/project        # interactive
```

Then restart Claude Code (or run `/config` once) so it picks up the plugin.

## What the installer does

For the target project it:
1. writes **`.claude/harness.json`** — your stack profile + which components are active;
2. enables the harness plugin in **`.claude/settings.json`** (committed, team-wide) — or
   `.claude/settings.local.json` with `--local`;
3. optionally drops the generic **`global-CLAUDE.md`** into your active config home.

It does **not** install agents (those are BYO) and does **not** run in your project's history — the
only files it touches are under `.claude/`.

## Interactive walkthrough

Run with no flags and it prompts for:
- **Stack** — `rails`, `node`, `python`, `go`, `generic`, or `custom` (you'll be asked for impl
  dirs, UI dirs, test dir, operator/e2e test dir, and test command).
- **Components** — activate the session banner / verification gate / pipeline gate (default: all).
- **Global ruleset** — whether to install the generic `global-CLAUDE.md` into your config home
  (skips if one already exists — it never overwrites).

## Flags (scriptable / CI)

```
./install.sh [TARGET]
  --stack NAME          rails | node | python | go | generic | <path-to-custom.json>
  --components LIST      comma list of: session_banner,verification_gate,pipeline_gate  (default: all)
  --local               enablement/config in settings.local.json (just you) instead of committed settings.json
  --no-plugin           only write .claude/harness.json; don't touch settings
  --global              also install the generic global-CLAUDE.md into your config home
  --yes, -y             accept defaults, no prompts
```

Examples:
```sh
# non-interactive, Rails, all gates, committed enablement:
./install.sh --stack rails --yes /path/to/app

# just me, Node, only banner + verification gate:
./install.sh --stack node --components session_banner,verification_gate --local --yes .

# CI seed (no prompts), generic stack:
./install.sh --stack generic --yes "$CI_PROJECT_DIR"
```

## Scopes: project vs. local

| Scope | File | Who gets it | Commit? |
|---|---|---|---|
| **project** (default) | `.claude/settings.json` | the team (on folder-trust) | yes — safe (plugin reference) |
| **local** (`--local`) | `.claude/settings.local.json` | just you, this machine | no (gitignored) |

`.claude/harness.json` is written the same way in both and is meant to be **committed** so everyone
shares the same stack profile and component choices.

## Installing the plugin without the script

The installer is a convenience. You can also do it natively:
```sh
/plugin marketplace add octanelabsdev/harness
/plugin install harness@harness
```
…then create `.claude/harness.json` yourself (copy a preset from `stacks/` under a `"stack"` key and
add a `"components"` block). See [configuration.md](configuration.md).

## Updating

The plugin auto-updates from the marketplace by default. Force a check with
`/plugin marketplace update harness`, or pin behavior with the standard Claude Code env vars
(`DISABLE_AUTOUPDATER`, `FORCE_AUTOUPDATE_PLUGINS`). To change your stack/components later, re-run
`install.sh` (it merges, preserving other settings keys) or edit `.claude/harness.json` directly.

## Uninstalling

```sh
/plugin disable harness@harness        # stop the hooks/skills
/plugin uninstall harness@harness      # remove it
```
Then delete `.claude/harness.json` and the harness keys from `.claude/settings.json` if you want it
fully gone.

## Requirements

`bash`, `git`, `jq`, `python3` on PATH (the installer and hooks use them). `ruby` only if you use
the story-writer's DoR lint.
