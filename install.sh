#!/usr/bin/env bash
# install.sh — wire the harness into a project. Interactive by default; flag-driven for scripts/CI.
#
# The harness is a Claude Code PLUGIN; this installer sets up the parts a plugin can't:
#   - .claude/harness.json  (which components are active + your stack profile)
#   - plugin enablement in .claude/settings.json (safe: references the versioned plugin, not $HOME scripts)
#   - optionally, a generic global ruleset in your active config home
# It does NOT install agents — agents are Bring-Your-Own (.claude/agents/).
#
# Usage:
#   ./install.sh [TARGET]                                   # interactive
#   ./install.sh --stack rails --yes [TARGET]              # non-interactive, all gates on (warn)
#   ./install.sh --stack node --components session_banner,verification_gate --local --yes .
#
# Flags:
#   --stack NAME        one of: $(ls stacks | sed 's/.json//' | tr '\n' ' ') — or a path to a custom stack JSON
#   --components LIST    comma list of: session_banner,verification_gate,pipeline_gate  (default: all)
#   --local             enablement/config in .claude/settings.local.json (just you) instead of committed settings.json
#   --no-plugin         don't touch settings — only write .claude/harness.json
#   --ref REF           pin the marketplace to this git tag/branch (default: v<plugin.json version>)
#   --no-mcp            don't write .mcp.json even if the stack declares MCP servers
#   --global            also install the generic global-CLAUDE.md into your config home
#   --yes               accept defaults, no prompts
set -euo pipefail

BUNDLE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MKT_NAME="harness"; MKT_REPO="esparkman/harness"   # this repo, self-referencing marketplace
ALL_COMPONENTS=(session_banner verification_gate pipeline_gate)

# --- args ---
TARGET=""; STACK=""; COMPONENTS=""; SCOPE="project"; DO_PLUGIN=1; DO_GLOBAL=""; ASSUME_YES=""; PIN_REF=""; DO_MCP=1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --stack) STACK="$2"; shift 2;;
    --components) COMPONENTS="$2"; shift 2;;
    --local) SCOPE="local"; shift;;
    --no-plugin) DO_PLUGIN=0; shift;;
    --ref) PIN_REF="$2"; shift 2;;
    --no-mcp) DO_MCP=0; shift;;
    --global) DO_GLOBAL=1; shift;;
    --yes|-y) ASSUME_YES=1; shift;;
    -h|--help) sed -n '2,32p' "$0"; exit 0;;
    -*) echo "unknown flag: $1" >&2; exit 2;;
    *) TARGET="$1"; shift;;
  esac
done
TARGET="${TARGET:-$PWD}"
[ -d "$TARGET" ] || { echo "error: target is not a directory: $TARGET" >&2; exit 1; }
TARGET="$(cd "$TARGET" && pwd)"
git -C "$TARGET" rev-parse --show-toplevel >/dev/null 2>&1 || echo "note: $TARGET is not a git repo — the hooks use git and will stay inert until it is." >&2

# Pin the marketplace to an IMMUTABLE release tag (default: v<plugin.json version>) rather than a
# moving branch. Auto-update leaves a tag alone (no new commits on it), so a later compromise or
# force-push of the harness repo can't flow arbitrary hook code to everyone on their next session.
if [ -z "$PIN_REF" ]; then
  _ver="$(jq -r '.version // empty' "$BUNDLE/.claude-plugin/plugin.json" 2>/dev/null)"
  [ -n "$_ver" ] && PIN_REF="v$_ver"
fi

ask() { # ask <prompt> <default>  -> echoes answer
  local a; if [ -n "$ASSUME_YES" ]; then printf '%s' "$2"; return; fi
  read -r -p "$1" a </dev/tty || true; printf '%s' "${a:-$2}"
}
yesno() { local a; a="$(ask "$1 [$2] " "$2")"; case "$a" in [Yy]*) return 0;; *) return 1;; esac; }

echo "── harness installer ──  target: $TARGET"

# --- 1. stack ---
if [ -z "$STACK" ] && [ -z "$ASSUME_YES" ]; then
  echo "Stack presets: $(ls "$BUNDLE"/stacks | sed 's/.json//' | tr '\n' ' ')  (or 'custom')"
  STACK="$(ask "Choose a stack [generic]: " generic)"
fi
STACK="${STACK:-generic}"
if [ "$STACK" = "custom" ]; then
  impl="$(ask 'implementation dirs (comma) [src,lib]: ' 'src,lib')"
  ui="$(ask 'UI dirs (comma, blank ok): ' '')"
  td="$(ask 'test dir [test]: ' 'test')"
  otd="$(ask 'operator/e2e test dir (blank ok): ' '')"
  tc="$(ask 'test command (blank ok): ' '')"
  to_arr() { printf '%s' "$1" | tr ',' '\n' | sed '/^$/d' | jq -R . | jq -s .; }
  STACK_JSON="$(jq -n --arg n custom --argjson impl "$(to_arr "$impl")" --argjson uid "$(to_arr "$ui")" \
    --arg td "$td" --arg otd "$otd" --arg tc "$tc" \
    '{name:$n, impl_dirs:$impl, ui_dirs:$uid, test_dir:$td, operator_test_dir:$otd, test_command:$tc}')"
else
  sfile="$BUNDLE/stacks/$STACK.json"; [ -f "$STACK" ] && sfile="$STACK"
  [ -f "$sfile" ] || { echo "error: no stack preset '$STACK' (have: $(ls "$BUNDLE"/stacks | sed 's/.json//' | tr '\n' ' '))" >&2; exit 1; }
  STACK_JSON="$(cat "$sfile")"
fi
echo "  stack: $(printf '%s' "$STACK_JSON" | jq -r '.name')  impl=$(printf '%s' "$STACK_JSON" | jq -c '.impl_dirs')"

# --- 2. components (the enforceable hooks) ---
declare -A ON
if [ -n "$COMPONENTS" ]; then
  for c in "${ALL_COMPONENTS[@]}"; do ON[$c]=false; done
  IFS=',' read -r -a picked <<< "$COMPONENTS"; for c in "${picked[@]}"; do ON[$c]=true; done
else
  for c in "${ALL_COMPONENTS[@]}"; do
    if yesno "Activate $c?" y; then ON[$c]=true; else ON[$c]=false; fi
  done
fi
COMPS_JSON="$(jq -n --argjson sb "${ON[session_banner]}" --argjson vg "${ON[verification_gate]}" --argjson pg "${ON[pipeline_gate]}" \
  '{session_banner:$sb, verification_gate:$vg, pipeline_gate:$pg}')"

# --- 3. write .claude/harness.json ---
cdir="$TARGET/.claude"; mkdir -p "$cdir"
jq -n --argjson c "$COMPS_JSON" --argjson s "$STACK_JSON" '{components:$c, stack:$s}' > "$cdir/harness.json"
echo "  wrote .claude/harness.json"

# --- 4. enable the plugin (safe committed reference, or --local) ---
if [ "$DO_PLUGIN" = 1 ]; then
  settings="$cdir/settings.json"; [ "$SCOPE" = "local" ] && settings="$cdir/settings.local.json"
  python3 - "$settings" "$MKT_NAME" "$MKT_REPO" "$PIN_REF" <<'PY'
import json, os, sys
p, mkt, repo, ref = (sys.argv + [""])[1:5]
s = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) > 0 else {}
src = {"source": "github", "repo": repo}
if ref:
    src["ref"] = ref
# assign (not setdefault) so re-running re-pins an existing/older/unpinned entry
s.setdefault("extraKnownMarketplaces", {})[mkt] = {"source": src}
s.setdefault("enabledPlugins", {})[f"{mkt}@{mkt}"] = True
with open(p, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print(f"  enabled plugin {mkt}@{mkt} in {os.path.basename(p)} " + (f"(pinned {ref})" if ref else "(UNPINNED — tracks default branch!)"))
PY
else
  echo "  (skipped plugin enablement — run /plugin marketplace add $MKT_REPO && /plugin install $MKT_NAME@$MKT_NAME yourself)"
fi

# --- 4b. per-stack MCP servers (committed .mcp.json), if the stack declares any ---
mcp="$(printf '%s' "$STACK_JSON" | jq -c '.mcp // empty')"
if [ -n "$mcp" ] && [ "$DO_MCP" = 1 ]; then
  python3 - "$TARGET/.mcp.json" "$mcp" <<'PY'
import json, os, sys
p, mcp = sys.argv[1], json.loads(sys.argv[2])
s = json.load(open(p)) if os.path.exists(p) and os.path.getsize(p) > 0 else {}
srv = s.setdefault("mcpServers", {})
for k, v in mcp.items():
    srv[k] = v
with open(p, "w") as f:
    json.dump(s, f, indent=2); f.write("\n")
print("  wrote .mcp.json ground-truth server(s):", ", ".join(mcp.keys()))
PY
  if printf '%s' "$mcp" | grep -q 'rails-mcp-server' && [ -f "$TARGET/Gemfile" ] && ! grep -q 'rails-mcp-server' "$TARGET/Gemfile"; then
    echo "  NOTE: add the gem so 'bundle exec rails-mcp-server' resolves — in your Gemfile:  gem \"rails-mcp-server\", group: :development"
  fi
elif [ -n "$mcp" ]; then
  echo "  (skipped MCP wiring per --no-mcp; stack declares: $(printf '%s' "$mcp" | jq -r 'keys|join(", ")'))"
fi

# --- 5. optional generic global ruleset ---
if [ -z "$DO_GLOBAL" ] && [ -z "$ASSUME_YES" ]; then yesno "Install the generic global-CLAUDE.md into your config home?" n && DO_GLOBAL=1; fi
if [ -n "$DO_GLOBAL" ]; then
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; mkdir -p "$cfg"
  dest="$cfg/CLAUDE.md"
  if [ -f "$dest" ]; then
    echo "  NOTE: $dest already exists — not overwriting. Template is at $BUNDLE/templates/global-CLAUDE.md"
  else
    cp "$BUNDLE/templates/global-CLAUDE.md" "$dest"; echo "  installed global ruleset -> $dest"
  fi
fi

# --- summary ---
active="$(printf '%s' "$COMPS_JSON" | jq -r 'to_entries|map(select(.value))|map(.key)|join(", ")')"
cat <<EOF

✔ harness wired into $TARGET
  stack       : $(printf '%s' "$STACK_JSON" | jq -r '.name')
  gates active: ${active:-none (all off)}
  plugin      : $([ "$DO_PLUGIN" = 1 ] && echo "enabled ($SCOPE scope, marketplace pinned ${PIN_REF:-UNPINNED})" || echo "not enabled")
  mcp         : $( [ -n "$(printf '%s' "$STACK_JSON" | jq -c '.mcp // empty')" ] && { [ "$DO_MCP" = 1 ] && echo ".mcp.json written ($(printf '%s' "$STACK_JSON" | jq -r '.mcp|keys|join(", ")'))" || echo "skipped (--no-mcp)"; } || echo "none for this stack")
  agents      : Bring-Your-Own — put your agents in .claude/agents/ (none shipped)
  skills      : guardrails, story-writer, product-manager come with the plugin

Next: restart Claude Code (or /config) so it picks up the plugin, then open a session —
the SessionStart banner reports the harness state. Gates run in WARN mode; promote with
'touch .claude/.pipeline-block' (pipeline) or edit the verification gate's tail.
EOF
