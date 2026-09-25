#!/usr/bin/env bash
# PreToolUse gate — no feature build without a prioritized, DoR-passing story. Stack-agnostic.
# Gates edits to the implementation surface (the stack profile's impl_dirs) unless a story at
# `.claude/current-story.yaml` PASSES the DoR lint (tools/dor_lint.rb — the verdict is COMPUTED, not a
# self-written stamp), or an explicit `.claude/.small-fix` bypass is declared. Tests, config, docs, and
# .claude/ are never gated. Inert unless components.pipeline_gate is true in .claude/harness.json.
# Per-repo: WARN (default) / BLOCK (touch .claude/.pipeline-block).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/_harness_lib.sh"

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file_path" ] && exit 0

component_on pipeline_gate || exit 0   # inert unless enabled for this project

dir=$(dirname "$file_path"); [ -d "$dir" ] || dir="$PWD"
repo=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0   # non-repo path -> allow
rel="${file_path#"$repo"/}"

path_under "$rel" impl_dirs || exit 0   # only gate the implementation surface

cdir="$repo/.claude"
emit()   { jq -n --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'; }
# Warn/advisory channel: surface a message WITHOUT deciding. Emitting no permissionDecision and
# exiting 0 leaves the user's normal edit-permission flow intact (verified against the hooks guide:
# "Exit 0 … for a PreToolUse hook this doesn't approve the tool call: the normal permission flow
# still applies") — so warn mode never auto-approves. `additionalContext` is the best-documented way
# to get the text to Claude on PreToolUse (hooks guide: additionalContext is kept and passed to
# Claude); single-hook surfacing isn't spelled out, so treat message visibility as best-effort — the
# no-auto-approve guarantee does NOT depend on it.
advise() { jq -n --arg c "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$c}}'; }

# (a) explicit small-fix escape hatch — allowed, but surfaced every time so it can't hide
if [ -f "$cdir/.small-fix" ]; then
  what=$(head -1 "$cdir/.small-fix" 2>/dev/null)
  advise "SMALL-FIX BYPASS active${what:+ — $what}. Pipeline gate not enforcing; remove .claude/.small-fix when done."
  exit 0
fi

# (b) a DoR-passing story backs this edit — the verdict is COMPUTED by dor_lint, not a self-written
# stamp. The story lives at .claude/current-story.yaml; dor_lint exit 0 = DoR: PASSED.
story="$cdir/current-story.yaml"; lint="$HERE/../tools/dor_lint.rb"
if [ -f "$story" ]; then
  if command -v ruby >/dev/null 2>&1 && [ -f "$lint" ]; then
    if verdict="$(ruby "$lint" "$story" 2>&1)"; then
      exit 0                                   # dor_lint exit 0 = DoR: PASSED -> story backs the edit
    fi
    msg="Pipeline gate: .claude/current-story.yaml did not pass the DoR lint —
$verdict
Fix the story until 'ruby dor_lint.rb' exits 0, or declare independent small work via .claude/.small-fix."
  elif grep -qiE "DoR:[[:space:]]*PASSED" "$story" 2>/dev/null; then
    exit 0                                     # degraded fallback (no ruby): accept an explicit PASSED stamp
  else
    msg="Pipeline gate: .claude/current-story.yaml is present but dor_lint could not run (ruby missing) and the file is not stamped 'DoR: PASSED'. Install ruby for the real gate, or declare small work via .claude/.small-fix."
  fi
else
  msg="Pipeline gate: no DoR-passing story backs this feature edit ($rel). Write a story at .claude/current-story.yaml that passes dor_lint (ruby tools/dor_lint.rb), or declare independent small work: printf '%s\\n' '<what + why>' > .claude/.small-fix"
fi
if [ -f "$cdir/.pipeline-block" ]; then
  emit deny "$msg"
else
  advise "PIPELINE GATE (warn) — $msg  [warn only; does not block or auto-approve — touch .claude/.pipeline-block to enforce]"
fi
exit 0
