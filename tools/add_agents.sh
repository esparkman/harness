#!/usr/bin/env bash
# add_agents.sh — bring a stack's agent bundle into this project's .claude/agents/.
#
# The harness ships NO agents (bring-your-own). This resolves the bundle to pull:
#   1. an explicit REPO argument (owner/name slug, or any git URL), or
#   2. the current project's .claude/harness.json -> .stack.agents_bundle.repo (the stack preset default).
# It clones/updates the bundle in a per-machine cache, then places the bundle's agent files into
# .claude/agents/ either as gitignored symlinks (default; per-developer clone) or as committed real
# files (--copy; whole team gets identical agents).
#
# Usage:
#   tools/add_agents.sh                      # use the stack default bundle, symlink
#   tools/add_agents.sh --copy               # stack default bundle, committed copies
#   tools/add_agents.sh owner/repo           # explicit bundle, symlink
#   tools/add_agents.sh --copy owner/repo    # explicit bundle, committed copies
#
# Flags: --symlink (default) | --copy
set -uo pipefail

MODE="symlink"; REPO_ARG=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --copy) MODE="copy"; shift;;
    --symlink) MODE="symlink"; shift;;
    -h|--help) sed -n '2,20p' "$0"; exit 0;;
    -*) echo "unknown flag: $1" >&2; exit 2;;
    *) REPO_ARG="$1"; shift;;
  esac
done

die() { echo "error: $*" >&2; exit 1; }
command -v git >/dev/null 2>&1 || die "git is required"

# Project root (where .claude/agents/ goes).
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || die "run this inside your project's git repo"
cfg="$repo/.claude/harness.json"

# Resolve the bundle repo + which files to take.
bundle_repo="$REPO_ARG"; globs=()
if [ -z "$bundle_repo" ]; then
  [ -f "$cfg" ] || die "no .claude/harness.json — run /harness:init first, or pass a bundle: add_agents.sh owner/repo"
  bundle_repo="$(jq -r '.stack.agents_bundle.repo // empty' "$cfg" 2>/dev/null)"
  [ -n "$bundle_repo" ] || die "stack '$(jq -r '.stack.name // "?"' "$cfg")' declares no default agent bundle. Pass one: /harness:agents owner/repo"
  while IFS= read -r g; do [ -n "$g" ] && globs+=("$g"); done < <(jq -r '.stack.agents_bundle.glob[]? // empty' "$cfg" 2>/dev/null)
elif [ -f "$cfg" ]; then
  # explicit repo, but reuse the preset globs if this IS the preset's bundle
  local_default="$(jq -r '.stack.agents_bundle.repo // empty' "$cfg" 2>/dev/null)"
  if [ "$local_default" = "$bundle_repo" ]; then
    while IFS= read -r g; do [ -n "$g" ] && globs+=("$g"); done < <(jq -r '.stack.agents_bundle.glob[]? // empty' "$cfg" 2>/dev/null)
  fi
fi
[ "${#globs[@]}" -gt 0 ] || globs=("*.md")   # explicit bundle without a known glob -> take all agents

# slug (owner/name) -> https URL; a full URL is used as-is.
case "$bundle_repo" in
  *://*|*@*:*) url="$bundle_repo";;
  */*)         url="https://github.com/$bundle_repo.git";;
  *)           die "not a repo slug or URL: $bundle_repo (expected owner/name or a git URL)";;
esac
name="$(basename "$bundle_repo" .git)"

cache="${XDG_CACHE_HOME:-$HOME/.cache}/harness/agent-bundles"
mkdir -p "$cache" || die "cannot create cache dir $cache"
clone="$cache/$name"

if [ -d "$clone/.git" ]; then
  echo "  updating bundle: $name"
  git -C "$clone" pull --ff-only >/dev/null 2>&1 || echo "  (warning: could not update $name; using the cached copy)"
else
  echo "  cloning bundle: $url"
  git clone --depth 1 "$url" "$clone" >/dev/null 2>&1 || die "clone failed: $url (check the repo name and your access)"
fi

# Collect matching agent files from the bundle.
files=()
for g in "${globs[@]}"; do
  while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(find "$clone" -maxdepth 1 -type f -name "$g" 2>/dev/null)
done
[ "${#files[@]}" -gt 0 ] || die "no agent files matching (${globs[*]}) in $name"

dest="$repo/.claude/agents"; mkdir -p "$dest" || die "cannot create $dest"

placed=0
if [ "$MODE" = "copy" ]; then
  for f in "${files[@]}"; do cp "$f" "$dest/$(basename "$f")" && placed=$((placed + 1)); done
  echo "  copied $placed agent(s) into .claude/agents/ (committed — the whole team gets them)"
else
  gi="$dest/.gitignore"; touch "$gi"
  for f in "${files[@]}"; do ln -sfn "$f" "$dest/$(basename "$f")" && placed=$((placed + 1)); done
  # keep the machine-local symlinks out of git (they point at your $HOME cache)
  for g in "${globs[@]}"; do grep -qxF "$g" "$gi" 2>/dev/null || printf '%s\n' "$g" >> "$gi"; done
  echo "  symlinked $placed agent(s) into .claude/agents/ (gitignored — per developer; use --copy to commit them)"
fi

echo "  done. agents from $name are wired for $repo"
