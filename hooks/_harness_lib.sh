#!/usr/bin/env bash
# Shared helpers for the harness hooks.
#
# The harness is CONFIG-DRIVEN and STACK-AGNOSTIC. Each project carries
# .claude/harness.json (written by the interactive installer) that declares which
# components are active and the stack's conventions:
#
#   { "components": { "session_banner": true, "verification_gate": true, "pipeline_gate": true },
#     "stack": { "name": "rails",
#                "impl_dirs": ["app","lib","db/migrate"],
#                "ui_dirs": ["app/views","app/controllers"],
#                "test_dir": "test", "operator_test_dir": "test/system",
#                "test_command": "bin/rails test" } }
#
# With no config present, the enforcing gates stay INERT (they no-op). Nothing is
# hardcoded to any one stack — the gates read impl_dirs / ui_dirs / operator_test_dir
# / test_command from the profile.

# Repo root of the project the hook is acting on.
harness_repo() {
  git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null \
    || printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# Path to the project's harness config, or empty if none.
harness_cfg() {
  local repo; repo="$(harness_repo)"
  [ -f "$repo/.claude/harness.json" ] && printf '%s' "$repo/.claude/harness.json"
}

# jq read with a default. Usage: hcfg '.stack.test_command' 'bin/rails test'
# Note: we do NOT use jq's `//` operator — it treats a literal `false` as empty, which would make a
# `components.<x>: false` toggle silently fall back to its default. Read the value raw and treat only
# jq's `null` (missing key) and the empty string as "absent → use default"; `false` is preserved.
hcfg() {
  local cfg; cfg="$(harness_cfg)"
  if [ -z "$cfg" ]; then printf '%s' "${2:-}"; return; fi
  local v; v="$(jq -r "${1}" "$cfg" 2>/dev/null)"
  if [ -n "$v" ] && [ "$v" != "null" ]; then printf '%s' "$v"; else printf '%s' "${2:-}"; fi
}

# Component toggle. Enforcing gates default OFF when unconfigured (safe/inert).
# Usage: component_on verification_gate   (pass a default as $2 to override)
component_on() {
  [ "$(hcfg ".components.\"$1\"" "${2:-false}")" = "true" ]
}

# Newline list of dirs for a stack key (impl_dirs, ui_dirs).
stack_dirs() {
  local cfg; cfg="$(harness_cfg)"; [ -n "$cfg" ] || return 0
  jq -r ".stack.$1[]? // empty" "$cfg" 2>/dev/null
}

# Is a repo-relative path under any dir listed for <key>?
path_under() {  # path_under <rel-path> <key>
  local rel="$1" key="$2" d
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    case "$rel" in "$d"/*|"$d") return 0 ;; esac
  done < <(stack_dirs "$key")
  return 1
}
