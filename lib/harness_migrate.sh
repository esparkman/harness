#!/usr/bin/env bash
# harness_migrate.sh — detect and clean a legacy (pre-plugin) harness install in a repo.
#
# Before the harness was a Claude Code plugin, repos wired it in by hand: a committed settings.json
# with a $HOME-referencing `hooks` block, committed hook scripts under .claude/hooks/, machine-local
# symlinked agents, and committed copies of the reference shelf / guardrails. The plugin ships all of
# that now, so those committed artifacts are dead weight (and the $HOME-hook settings.json is a
# supply-chain footgun). This library finds those markers and, on request, removes them safely.
#
# Sourceable: `harness_migrate_scan <repo>` → `harness_migrate_report` → `harness_migrate_apply <repo>`.
# Dry-run by design: scan/report change nothing; only apply mutates, and it backs up first.
# See tools/migrate_legacy.sh (standalone) and `install.sh --migrate`.

# Each finding: "TYPE|absolute-path|human description". Populated by scan, read by report/apply.
HM_FINDINGS=()

_hm_git()  { git -C "$1" "${@:2}"; }
_hm_mode() { _hm_git "$1" ls-tree HEAD -- "$2" 2>/dev/null | awk '{print $1}'; }
_hm_rel()  { printf '%s' "${1#"$2"/}"; }   # absolute path -> repo-relative

# harness_migrate_scan <repo>  — fill HM_FINDINGS; returns 0 whether or not anything was found.
harness_migrate_scan() {
  local repo="$1" cdir="$1/.claude" s sf f mode
  HM_FINDINGS=()
  [ -d "$cdir" ] || return 0

  # 1. A committed settings file that still carries a hooks block, or an old/unpinned marketplace.
  for s in settings.json settings.local.json; do
    sf="$cdir/$s"; [ -f "$sf" ] || continue
    if jq -e '.hooks // empty | length > 0' "$sf" >/dev/null 2>&1; then
      HM_FINDINGS+=("SETTINGS_HOOKS|$sf|committed hooks block — the plugin provides hooks; remove it")
    fi
    if jq -e '[.. | strings | select(test("/harness$"))] | any(test("^(?!octanelabsdev/)"))' \
         "$sf" >/dev/null 2>&1; then
      HM_FINDINGS+=("MKT_OLDREPO|$sf|harness marketplace points at an old owner — re-home to octanelabsdev")
    fi
    if jq -e '.extraKnownMarketplaces.harness.source | objects | (has("ref") | not)' \
         "$sf" >/dev/null 2>&1; then
      HM_FINDINGS+=("MKT_UNPINNED|$sf|harness marketplace has no ref — pin to a release tag")
    fi
  done

  # 2. Committed harness hook scripts (the plugin ships these).
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$(basename "$f")" in
      session_start*|session_banner*|verification_gate*|pipeline_gate*|*harness*|_harness_lib*)
        HM_FINDINGS+=("HOOK_SCRIPT|$repo/$f|committed hook script — the plugin provides it; remove it") ;;
    esac
  done < <(_hm_git "$repo" ls-files '.claude/hooks/*' 2>/dev/null)

  # 3. Tracked symlinked agents — machine-local links that should never be committed.
  #    Verify the git object mode is a symlink (120000) before claiming — a committed *real* agent
  #    file is legitimate and must be left alone. (Learned the hard way; see the RCA.)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    mode="$(_hm_mode "$repo" "$f")"
    [ "$mode" = "120000" ] && \
      HM_FINDINGS+=("AGENT_SYMLINK|$repo/$f|tracked symlink (machine-local) — untrack + gitignore, keep on disk")
  done < <(_hm_git "$repo" ls-files '.claude/agents/*.md' 2>/dev/null)

  # 4. Committed reference-shelf / guardrail copies — the harness owns the reader now.
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    HM_FINDINGS+=("SHELF_COPY|$repo/$f|committed reference-shelf/guardrail copy — the harness owns it; remove it")
  done < <(_hm_git "$repo" ls-files '*tome.sh' 'reference/tomes/*' '.claude/guardrails/*' '.claude/tools/tome.sh' 2>/dev/null | sort -u)
}

# harness_migrate_report  — print the plan. Returns 0 if there is anything to do, 1 if clean.
harness_migrate_report() {
  if [ "${#HM_FINDINGS[@]}" -eq 0 ]; then
    echo "  no legacy harness markers found — nothing to migrate."
    return 1
  fi
  echo "  legacy markers (${#HM_FINDINGS[@]}):"
  local x
  for x in "${HM_FINDINGS[@]}"; do
    printf '    - %-14s %s\n' "${x%%|*}" "$(printf '%s' "$x" | cut -d'|' -f3)"
  done
  return 0
}

# harness_migrate_apply <repo>  — execute the plan. Backs up everything it removes first.
harness_migrate_apply() {
  local repo="$1" cdir="$1/.claude"
  local backup="$cdir/.harness-migrate-backup-$(date +%Y%m%d-%H%M%S)"
  local x type path rel tmp gi
  [ "${#HM_FINDINGS[@]}" -gt 0 ] || { echo "  nothing to apply."; return 0; }
  mkdir -p "$backup"
  for x in "${HM_FINDINGS[@]}"; do
    type="${x%%|*}"; path="$(printf '%s' "$x" | cut -d'|' -f2)"
    case "$type" in
      SETTINGS_HOOKS)
        cp "$path" "$backup/$(basename "$path")"
        tmp="$(mktemp)"; jq 'del(.hooks)' "$path" > "$tmp" && mv "$tmp" "$path"
        echo "    removed .hooks from $(basename "$path") (backed up)" ;;
      HOOK_SCRIPT|SHELF_COPY)
        rel="$(_hm_rel "$path" "$repo")"
        mkdir -p "$backup/$(dirname "$rel")"; cp "$path" "$backup/$rel" 2>/dev/null
        _hm_git "$repo" rm -q -- "$rel" 2>/dev/null && echo "    removed $rel (backed up)"
        rmdir "$repo/$(dirname "$rel")" 2>/dev/null || true ;;
      AGENT_SYMLINK)
        rel="$(_hm_rel "$path" "$repo")"
        _hm_git "$repo" rm --cached -q -- "$rel" 2>/dev/null
        gi="$cdir/agents/.gitignore"
        grep -qxF "$(basename "$rel")" "$gi" 2>/dev/null || printf '%s\n' "$(basename "$rel")" >> "$gi"
        echo "    untracked $rel (kept on disk, gitignored)" ;;
      MKT_OLDREPO|MKT_UNPINNED)
        echo "    marketplace: will be re-homed/pinned by the install step (run install after)" ;;
    esac
  done
  echo "    backup dir: $backup"
  echo "    review, commit the removals, then run the installer to (re)enable the plugin pinned."
}
