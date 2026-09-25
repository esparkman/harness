# Configuration: `.claude/harness.json`

The harness is config-driven. One file per project — `.claude/harness.json` — declares which
components are active and describes your stack. The hooks read it at runtime; with no file, the
enforcing gates stay inert.

## Schema

```jsonc
{
  "components": {
    "session_banner":    true,   // SessionStart status banner (informational; default shown)
    "skill_nudge":       true,   // SessionStart nudge to invoke skills (default on)
    "verification_gate": true,   // Stop gate — operator-test + review checks
    "pipeline_gate":     true    // PreToolUse gate — DoR story required for feature edits
  },
  "stack": {
    "name": "rails",                            // label, shown in the banner
    "impl_dirs":  ["app", "lib", "db/migrate"], // the "implementation surface" the gates care about
    "ui_dirs":    ["app/views", "app/controllers"], // subset whose change should ship an operator test
    "test_dir":   "test",                       // where unit/integration tests live
    "operator_test_dir": "test/system",         // where operator/e2e/journey tests live ("" = none)
    "test_command": "bin/rails test",           // how to run the suite ("" = unknown)
    "agents_bundle": {                          // optional: default agent bundle for /harness:agents
      "repo": "octanelabsdev/rails-agents",     //   owner/name slug or git URL
      "glob": ["rails-*.md", "dhh-code-reviewer.md"] // which files in the bundle are agents
    }
  }
}
```

### Field semantics
- **`impl_dirs`** — a repo-relative path is "implementation" if it's under any of these. Drives
  *both* gates. Everything else (tests, config, docs, `.claude/`) is never gated.
- **`ui_dirs`** — a subset of the implementation surface whose change is expected to come with an
  operator-journey test. Leave `[]` for stacks with no UI layer.
- **`operator_test_dir`** — where journey/e2e tests live. If empty, the verification gate skips the
  operator-test check.
- **`test_command`** — the canonical check the verification gate **runs** on a Stop with impl changes;
  a non-zero exit blocks (see [components.md](components.md)). If empty, the gate only runs its
  advisory operator-test check.
- **`components`** — the toggleable hooks honor these. `session_banner` and `skill_nudge` default to
  **on** unless set to `false`; the two gates (`verification_gate`, `pipeline_gate`) default **off**
  when unconfigured. When on, the pipeline gate runs in **warn** mode, and the verification gate
  **blocks** on a `test_command` failure (opt down with `.claude/.verification-warn`). (The
  `harness_bootstrap` hook has no toggle —
  it only acts when there's no config yet; see [components.md](components.md).)
- **`agents_bundle`** (optional) — the default agent bundle `/harness:agents` pulls when given no
  repo. `repo` is an `owner/name` slug or git URL; `glob` lists which files in the bundle are agents.

Paths are directory prefixes, repo-relative — not globs. `app` matches `app/models/x.rb`.

## Stack presets

Presets live in [`stacks/`](../stacks) and are the `stack` object above:

| Preset | impl_dirs | operator_test_dir | test_command |
|---|---|---|---|
| `rails` | app, lib, db/migrate | test/system | bin/rails test |
| `node` | src, lib, app | e2e | npm test |
| `python` | src, app | tests/e2e | pytest |
| `go` | cmd, internal, pkg | e2e | go test ./... |
| `generic` | src, lib | (none) | (none) |

The installer merges your chosen preset (or custom answers) with your component choices into
`.claude/harness.json`.

## Custom stacks

Pick `custom` in the installer (or `--stack custom`) and answer the prompts, or hand-write the
`stack` object. To make your own reusable preset, drop a JSON file matching the schema's `stack`
object into `stacks/yourstack.json` and pass `--stack stacks/yourstack.json` (or a path anywhere).

Example — a Phoenix/Elixir profile:
```json
{
  "name": "phoenix",
  "impl_dirs": ["lib"],
  "ui_dirs": ["lib/my_app_web/live", "lib/my_app_web/controllers"],
  "test_dir": "test",
  "operator_test_dir": "test/my_app_web/live",
  "test_command": "mix test"
}
```

## Commit it

`.claude/harness.json` is meant to be **committed** so your whole team shares the same stack profile
and component choices. It contains no secrets and no machine paths — only your project's conventions.

## Session-local markers (written as you work)

The gates read/write small marker files under `.claude/` (all gitignored):
- `.claude/.current-story` — a DoR-passing story stamped `DoR: PASSED` (the pipeline gate's key).
- `.claude/.small-fix` — declares independent small work that bypasses the pipeline gate.
- `.claude/.pipeline-block` — promotes the pipeline gate from warn to **block** for this repo.
- `.claude/.verification-warn` — downgrades the verification gate from **block** to warn-only for this repo.
