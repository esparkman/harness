#!/usr/bin/env bash
# Stack detection shared by the installer and the auto-bootstrap hook.
#
# Echoes exactly one stack name that matches a stacks/<name>.json preset:
#   rails | go | python | node | generic
# Detection is by on-disk markers, most specific first. A Rails app also carries a package.json,
# so Rails is checked before node; plain Ruby (no Rails) falls through to generic (no ruby preset).

harness_detect_stack() { # <dir> -> echoes stack name
  local d="${1:-$PWD}"

  if { [ -f "$d/Gemfile" ] && grep -qE "gem ['\"]rails['\"]" "$d/Gemfile" 2>/dev/null; } \
     || [ -f "$d/bin/rails" ] || [ -f "$d/config/application.rb" ]; then
    printf '%s' rails; return
  fi

  [ -f "$d/go.mod" ] && { printf '%s' go; return; }

  if [ -f "$d/pyproject.toml" ] || [ -f "$d/requirements.txt" ] \
     || [ -f "$d/setup.py" ] || [ -f "$d/Pipfile" ]; then
    printf '%s' python; return
  fi

  [ -f "$d/package.json" ] && { printf '%s' node; return; }

  printf '%s' generic
}
