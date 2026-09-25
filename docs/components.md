# Components: hooks & skills

The harness ships **hooks** (run by the environment) and **skills** (invoked by the model). Four
hooks are toggled per project in `.claude/harness.json`; the auto-bootstrap hook has no toggle (it
runs before any config exists). Skills come with the plugin.

## Hooks

### Auto-bootstrap (`harness_bootstrap`) — SessionStart hook
Closes the "installed but does nothing" gap: a plugin has no install-time hook, so the first session
in a project with **no** `.claude/harness.json` is where the harness configures itself. It detects the
stack (Rails/Node/Python/Go/generic) and writes a config with all components on and the gates in
**warn** mode, then announces it in the banner. It **never clobbers** an existing config (no-op if the
file is present), only runs inside a git repo, and writes `.claude/harness.json` alone — never
committed `settings.json`. No component toggle (it runs before config exists); opt out with the
`HARNESS_NO_AUTOBOOTSTRAP=1` environment variable. Configure deliberately instead with `/harness:init`.

### SessionStart banner (`session_banner`)
Prints an environment-verified status line at the start of every session — the active config home's
global ruleset, the harness config + stack, and your BYO agent count. Its whole point is to report
*reality* rather than what the model remembers. Shown unless `components.session_banner` is `false`.

### Skill nudge (`skill_nudge`) — SessionStart hook
Skills are **listed, not auto-applied**: at session start Claude Code registers them (availability),
but a skill's instructions only take effect once it's invoked (activation). Without a prompt the
operator has to type `/harness:<name>` before a skill shapes the response. This hook injects a
directive so the model invokes the right skill *on its own* the moment a trigger fires — `guardrails`
(before a first edit / on a failed command / before claiming done), `product-manager` (deciding
what's next / triaging / routing ready work), `story-writer` (writing or refining a story). It changes
model behavior only; a hook cannot call a skill itself.

Fires once per session at `SessionStart` with the **full** directive. (It previously also fired a
terse reminder on every `UserPromptSubmit`; that was dropped — the per-prompt injection added up over
a long session, and the SessionStart directive plus the auto-listed skills carry the reminder.) Shown
unless `components.skill_nudge` is `false`.

### Verification gate (`verification_gate`) — Stop hook
When a turn ends with implementation code changed (per `impl_dirs`), it **runs the project's
`test_command`** and **blocks** (`exit 2`) if it fails — a red test is a fact, not a judgment, so it
is safe to block on. It also **advises** (never blocks) when a UI/impl change (per `ui_dirs`) shipped
without a change under `operator_test_dir` — i.e. no operator-journey test. It short-circuits on
`stop_hook_active` so it can never loop. Inert unless `components.verification_gate` is `true`.

A `test_command` failure **blocks by default**. Rolling out gradually? `touch .claude/.verification-warn`
to downgrade to warn-only (the failure is surfaced but doesn't block). A Stop hook's `exit 2` prevents
the stop and continues so Claude addresses the gap.

> The old `.claude/.last-review` "was it reviewed?" check was removed — it compared a model-written
> marker to HEAD and couldn't tell a real review from a claimed one. A real review gate returns backed
> by a reviewer artifact (roadmap phase 3).

### Pipeline gate (`pipeline_gate`) — PreToolUse hook
Before an `Edit`/`Write` to the implementation surface (`impl_dirs`), it requires either:
- `.claude/.current-story` stamped `DoR: PASSED` (written by the PM pipeline), or
- `.claude/.small-fix` (an explicit, surfaced escape hatch for genuinely independent small work).

Tests, config, docs, and `.claude/` are never gated. **Warn** by default (advises without deciding —
it never auto-approves the edit); `touch .claude/.pipeline-block` to **block**. Inert unless
`components.pipeline_gate` is `true`.

> Both gates read the *stack profile*, so "implementation surface" and "operator test" mean whatever
> your stack says — see [configuration.md](configuration.md).

## Skills

Skills come with the plugin (no per-project toggle) and are stack-agnostic. They are **listed, not
auto-applied** — Claude Code registers each skill's name + description at session start, but a skill's
instructions only take effect when it's invoked (via the `Skill` tool or a `/harness:<name>` command).
The `skill_nudge` hook (above) is what makes the model reach for the matching skill on its own instead
of waiting to be asked.

### `guardrails`
A routing table plus six reference playbooks. Read the one whose trigger just fired; cite a fired
item's ID with one line of evidence.

| Trigger | Playbook |
|---|---|
| first edit of a file this session | CODE |
| dates/times, float money, async, sort, division, regex, mutation, closures | TRAPS |
| a failed command/test, a traceback, output contradicting a prediction | DEBUG |
| about to claim done / commit / open a PR | VERIFY |
| calling a path live, blaming a prod symptom, sizing cost | RUNTIME |
| concluding code is dead/wrong, or planning on external-system behavior | MECHANISM |

### `story-writer`
Turns a PRD / cited source / structured input into a Definition-of-Ready card. Its inviolable rule:
never invent a boundary — ground every value in the source, else existing code, else escalate as an
open question. Strips solutioning. Runs the deterministic DoR lint
(`ruby ${CLAUDE_PLUGIN_ROOT}/tools/dor_lint.rb <story>.yaml`) and quotes the verdict; a card is READY
only when the lint exits 0.

### `product-manager`
Prioritizes from real signals (never invented) and drives the pipeline: prioritize → ready (via
story-writer) → record `.claude/.current-story` (which unlocks the pipeline gate) → route to an
engineer (BYO agent) → track. Coordinates gates; never bypasses them. Acts on the board with operator
authority (triage, move, tag, pin, assign, comment — never delete).

**Tracker:** the harness ships with **Fizzy** as the default board MCP (both skills use
`fizzy_*` read/act tools, with the delete operations withheld by design). It's a default, not a
requirement — point the operations at whatever tracker MCP your project uses, or run the pipeline
against a file-backed backlog (`stories/` + `.claude/.current-story`) with no tracker at all.

### `bookshelf`
Reads your own reference books (EPUBs) in place via `${CLAUDE_PLUGIN_ROOT}/tools/tome.sh`, so a
design/idiom/convention call can be grounded in — and quote — a primary source instead of memory.
Books are **BYO and never shipped** (copyright); point the reader at your shelf with `TOMES_DIR`
(the installer's user step can set it). **Fails gracefully when no shelf exists:** if `TOMES_DIR` is
unset and the fallback shelves are empty, or a book isn't found, the skill says so and falls back to
live docs or an explicit "unverified" label — it never blocks and never invents a book's contents.
Agents can invoke this skill too (see [agents.md](agents.md) → the bookshelf directive).

## How they fit together

```
SessionStart banner ─ reports state
        │
story-writer → DoR lint → product-manager ─ writes .claude/.current-story (DoR: PASSED)
        │                                          │
        │                                    unlocks
        ▼                                          ▼
   guardrails ──── loaded at each risk point ── your BYO agents implement
        │                                          │
        ▼                                          ▼
 pipeline gate (before edits)          verification gate (at Stop) → review + operator test
```
