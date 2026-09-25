#!/usr/bin/env bash
# SessionStart + UserPromptSubmit hook — make the harness skills auto-ENGAGE, not just auto-list.
#
# Skills are invocation-gated: at session start Claude Code only REGISTERS them (availability), it
# does not APPLY them (activation). Without a nudge the operator has to type /harness:<name> before a
# skill shapes the response. This hook injects a directive so the model invokes the right skill on its
# own the moment a trigger fires. It changes model behavior only — it cannot call a skill itself.
#
# Fires on two events for durability (the component's "both" cadence):
#   SessionStart     -> the FULL directive, once per session.
#   UserPromptSubmit -> a TERSE one-line reminder, so the trigger stays fresh in a long session.
#
# Informational/behavioral, so it defaults ON (like session_banner) — set components.skill_nudge
# to false in .claude/harness.json to silence it for a project.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; . "$HERE/_harness_lib.sh"

[ "$(hcfg '.components."skill_nudge"' 'true')" = "false" ] && exit 0

input="$(cat 2>/dev/null || true)"
event="$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)"
[ -n "$event" ] || event="SessionStart"   # SessionStart fires with an empty/absent name in some builds

if [ "$event" = "UserPromptSubmit" ]; then
  read -r -d '' msg <<'EOF' || true
Harness skills — invoke proactively (availability ≠ activation): guardrails (before a first edit, on a failed command/test, before claiming done/committing, on a language trap), product-manager (deciding what's next / triaging / routing ready work), story-writer (writing or refining a story before build). Reach for the matching skill yourself — no /command needed.
EOF
else
  read -r -d '' msg <<'EOF' || true
HARNESS SKILLS — invoke proactively; availability ≠ activation. These plugin skills are listed but do
NOT auto-apply. Invoke the matching one yourself via the Skill tool the moment its trigger fires — do
not wait to be asked and do not require a /command:
  • guardrails      → before your first file edit, on a failed command/test, before claiming
                      done/passing/complete or committing, or when touching a language trap
  • product-manager → when deciding what to work on next, triaging a backlog/board, or routing
                      ready work to an engineer
  • story-writer    → when creating or refining a work item / ticket / story before implementation
EOF
fi

printf '%s\n' "$msg"
esc="$(printf '%s' "$msg" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null)"
[ -n "$esc" ] && printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":%s}}\n' "$event" "$esc"
exit 0
