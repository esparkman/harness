---
description: Health-check the harness — verify every needed hook, script, config, and (if review_gate is on) reviewer/skill/schema is present and wired. Exits non-zero on a gap.
---

Run the harness health check for the current project:

```
bash "${CLAUDE_PLUGIN_ROOT}/tools/harness_doctor.sh"
```

It verifies `hooks.json` is valid and every referenced hook script exists; the tool scripts exist and are
executable; `harness.json` is valid and its stack dirs resolve; and, when `review_gate` is on, that a
reviewer plus the `blind-review` skill and findings schema are present. Deterministic (no live
network/process probing). **Exit 0** = healthy (`!` warnings are non-fatal); **exit 2** = a hard gap —
safe to run in CI or a pre-push hook. After it runs, report any `✘` (gaps) or `!` (warnings) and the fix.
