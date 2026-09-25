#!/usr/bin/env bash
# migrate_legacy.sh — find (and optionally clean) a legacy, pre-plugin harness install in a repo.
#
# Dry-run by default: it reports what it would change and touches nothing. Pass --apply to execute
# (everything removed is backed up under .claude/.harness-migrate-backup-<ts>/ first). After applying,
# commit the removals and run ./install.sh to (re)enable the plugin, pinned.
#
# Usage:
#   tools/migrate_legacy.sh [TARGET]           # dry-run report (default: current dir)
#   tools/migrate_legacy.sh --apply [TARGET]   # execute the cleanup

set -u
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../lib/harness_migrate.sh"

APPLY=0; TARGET=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1; shift;;
    -h|--help) sed -n '2,13p' "$0"; exit 0;;
    *) TARGET="$1"; shift;;
  esac
done
TARGET="$(cd "${TARGET:-$PWD}" && pwd)" || exit 1

echo "── harness legacy migration ──  target: $TARGET"
git -C "$TARGET" rev-parse --show-toplevel >/dev/null 2>&1 || { echo "  not a git repo — nothing to scan." >&2; exit 0; }

harness_migrate_scan "$TARGET"
harness_migrate_report || exit 0

if [ "$APPLY" = 1 ]; then
  echo "  applying…"
  harness_migrate_apply "$TARGET"
else
  echo "  (dry-run — re-run with --apply to execute)"
fi
