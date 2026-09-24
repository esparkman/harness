#!/usr/bin/env bash
# PreToolUse gate — no feature build without a prioritized, DoR-passing story. Stack-agnostic.
# Gates edits to the implementation surface (the stack profile's impl_dirs) unless a
# `.claude/.current-story` marker stamped `DoR: PASSED` exists, or an explicit `.claude/.small-fix`
# bypass is declared. Tests, config, docs, and .claude/ are never gated. Inert unless
# components.pipeline_gate is true in .claude/harness.json. Per-repo: WARN (default) / BLOCK
# (touch .claude/.pipeline-block).
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
emit() { jq -n --arg d "$1" --arg r "$2" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'; }

# (a) explicit small-fix escape hatch — allowed, but surfaced every time so it can't hide
if [ -f "$cdir/.small-fix" ]; then
  what=$(head -1 "$cdir/.small-fix" 2>/dev/null)
  emit allow "SMALL-FIX BYPASS active${what:+ — $what}. Pipeline gate skipped; remove .claude/.small-fix when done."
  exit 0
fi

# (b) a prioritized, DoR-passing story is present
if [ -f "$cdir/.current-story" ] && grep -qiE "DoR:[[:space:]]*PASSED" "$cdir/.current-story" 2>/dev/null; then
  exit 0
fi

msg="Pipeline gate: no DoR-passing, prioritized story backs this feature edit ($rel). Route it through your story/PM flow, then write .claude/.current-story stamped 'DoR: PASSED'. If this is genuinely independent small work, declare it: printf '%s\\n' '<what + why>' > .claude/.small-fix"
if [ -f "$cdir/.pipeline-block" ]; then
  emit deny "$msg"
else
  emit allow "PIPELINE GATE (warn) — $msg  [warn only; touch .claude/.pipeline-block to enforce]"
fi
exit 0
