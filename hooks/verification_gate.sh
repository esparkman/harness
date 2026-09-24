#!/usr/bin/env bash
# Stop hook — verification gate (WARN mode), stack-agnostic.
# When a turn ends with implementation code changed, it checks (per the project's stack profile)
# that a UI/implementation change ships with an operator-journey test, and that a code review was
# recorded for this tree. Inert unless components.verification_gate is true in .claude/harness.json.
#
# Stop hooks may block via exit 2 (verified: docs "Prevents Claude from stopping, continues the
# conversation"). This ships in WARN mode (exit 0); promote to block at the tail when proven.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/_harness_lib.sh"
INPUT="$(cat)"

# Loop guard — never re-block once continuation was already requested.
[ "$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)" = "true" ] && exit 0

component_on verification_gate || exit 0   # inert unless enabled for this project

repo="$(harness_repo)"; cd "$repo" 2>/dev/null || exit 0
changed="$(git status --porcelain 2>/dev/null || true)"
[ -z "$changed" ] && exit 0

op_test="$(hcfg '.stack.operator_test_dir' '')"
test_cmd="$(hcfg '.stack.test_command' '')"
impl=""; ui=""; op_changed=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  p="${line:3}"                       # strip the 2-char status + space
  p="${p%% -> *}"                     # handle renames
  path_under "$p" impl_dirs && impl=1
  path_under "$p" ui_dirs && ui=1
  if [ -n "$op_test" ]; then case "$p" in "$op_test"/*) op_changed=1 ;; esac; fi
done <<< "$changed"

[ -z "$impl" ] && exit 0   # no implementation change in flight → nothing to gate

warn=()
if [ -n "$ui" ] && [ -n "$op_test" ] && [ -z "$op_changed" ]; then
  warn+=("Operator-task test: implementation UI changed but no $op_test/ change. Add a test that walks the operator's journey (act -> assert the observable outcome), not just an internal-state check.${test_cmd:+ Before 'done', run the FULL suite ($test_cmd) including operator tests.}")
fi

marker="$repo/.claude/.last-review"; head_sha="$(git rev-parse HEAD 2>/dev/null || echo none)"
if [ ! -f "$marker" ] || [ "$(cat "$marker" 2>/dev/null)" != "$head_sha" ]; then
  warn+=("Code review gate: no review recorded for this tree state. Run your reviewer, then record it: echo \"\$(git rev-parse HEAD)\" > .claude/.last-review")
fi

if [ ${#warn[@]} -gt 0 ]; then
  {
    echo "VERIFICATION GATE (warn) — self-review steps not evidenced before stopping:"
    for w in "${warn[@]}"; do echo "  - $w"; done
    echo "(warn only; not blocking. Promote to block once the warn phase is quiet.)"
  } >&2
fi
exit 0

# --- PROMOTE TO BLOCK: replace the final `exit 0` with, when warnings exist:
#   printf '%s\n' "${warn[@]}" >&2
#   exit 2
# (exit 2 on Stop feeds stderr back to Claude and continues so it addresses the gap.)
