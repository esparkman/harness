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

## Migrating off a legacy (pre-plugin) install

Repos wired to the harness *before* it was a plugin carry artifacts the plugin now ships — and one
of them (a committed `settings.json` with a `$HOME`-referencing `hooks` block) is a supply-chain
footgun. The migrator finds and removes them; it is **dry-run by default** and backs up everything it
deletes.

```sh
# report only — changes nothing:
tools/migrate_legacy.sh /path/to/repo
# clean it up (backs up removed files under .claude/.harness-migrate-backup-<ts>/):
tools/migrate_legacy.sh --apply /path/to/repo
# or fold it into an install in one go:
./install.sh --migrate --apply --stack rails /path/to/repo
```

It detects and removes: a committed `hooks` block in `settings.json`/`settings.local.json`, committed
hook scripts under `.claude/hooks/`, committed reference-shelf / guardrail copies, and **tracked
symlinked agents** (untracked + gitignored, kept on disk). It verifies the git object mode before
untracking, so a committed *real* agent file is left alone — only machine-local symlinks are removed.
An old/unpinned marketplace reference is re-homed and pinned by the install step that follows.

## Installing the plugin without the script

The installer is a convenience. You can also do it natively:
```sh
/plugin marketplace add octanelabsdev/harness
/plugin install harness@harness
```
That's enough to start: on the **first session** in a project with no `.claude/harness.json`, the
plugin's `harness_bootstrap` hook detects your stack and writes one for you (see below). To configure
it deliberately instead — force a stack, choose components, enable it team-wide — run `/harness:init`.

## Auto-bootstrap on first session

A plugin has no install-time hook (SessionStart is the earliest point its code runs), so the harness
bootstraps itself the first time you open a session in an unconfigured project:

- **Only when needed** — it no-ops if `.claude/harness.json` already exists (it never clobbers your
  config) and only runs inside a git repo.
- **Stack-detected** — Rails / Node / Python / Go from on-disk markers, else generic.
- **Safe defaults** — all components on, both gates in **warn** mode (nothing blocks yet).
- **Announced** — the SessionStart banner tells you it happened and names the detected stack.
- **`.claude/harness.json` only** — it never touches committed `settings.json`; team enablement stays
  a deliberate act (`/harness:init` or this installer).
- **Opt out** — set `HARNESS_NO_AUTOBOOTSTRAP=1` in your environment.

## Slash commands

Two commands ship with the plugin:

| Command | What it does |
|---|---|
| `/harness:init [flags]` | Runs this installer non-interactively for the current project. No args → auto-detect stack, all components (warn mode), committed enablement. Pass through any installer flag (`--stack`, `--components`, `--local`, `--no-plugin`, …). |
| `/harness:agents [--copy] [owner/repo]` | Brings a stack's agent bundle into `.claude/agents/`. No args → the stack's default bundle (e.g. Rails → `octanelabsdev/rails-agents`), **symlinked** and gitignored (per-developer). `--copy` commits real files (whole team). Pass `owner/repo` (or a git URL) to override the bundle. See [agents.md](agents.md). |

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
