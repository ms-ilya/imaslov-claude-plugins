#!/usr/bin/env bash
# ABOUTME: Collects an Xcode project's targets, plists, entitlements and sources into a scratch directory outside it.
#
# Usage: collect-context.sh <project-path> [scratch-dir]
#
# The scratch directory defaults to a per-project path under TMPDIR and is
# always outside the audited project. That is not a preference: the audit permits
# itself exactly one created path inside the project, and it is the report.
# A git-ignored temp file is still a file created in a tree the audit promised
# not to touch, so the collector refuses to write there at all.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null 2>&1 || { echo "collect-context: python3 not found" >&2; exit 1; }

PROJECT="${1:-.}"
[ -d "$PROJECT" ] || { echo "collect-context: $PROJECT is not a directory" >&2; exit 2; }
ABS="$(cd "$PROJECT" && pwd)"

MARKER=".appstore-audit-scratch"

if [ $# -ge 2 ]; then
  SCRATCH="$2"
else
  SLUG="$(basename "$ABS" | tr -c 'A-Za-z0-9_-' '_')"
  HASH="$(printf '%s' "$ABS" | cksum | cut -d' ' -f1)"
  TMPROOT="${TMPDIR:-/tmp}"
  TMPROOT="${TMPROOT%/}"
  SCRATCH="${TMPROOT}/appstore-audit/${SLUG}-${HASH}"
fi

# Containment is checked here as well as in the collector, because this script
# creates the directory and the collector cannot refuse a path that has already
# been made. R1 permits exactly one created path inside the audited project, and
# it is the report.
# Normalised without requiring the path to exist: `cd` cannot resolve a
# directory that has not been created, and the whole point is to decide before
# creating it.
SCRATCH_ABS="$(python3 -c 'import os,sys;print(os.path.abspath(sys.argv[1]))' "$SCRATCH")"
case "$SCRATCH_ABS/" in
  "$ABS"/*)
    echo "collect-context: refusing to write context inside the audited project" >&2
    echo "                 the audit creates exactly one path there, and it is the report" >&2
    exit 2
    ;;
esac

# The scratch directory is emptied before each run, so it had better be a
# scratch directory. `collect-context.sh <project> ~/Documents` would otherwise
# delete ~/Documents. The skill never passes a second argument, which makes this
# a hazard only for someone running the script by hand — which is exactly the
# person with no reason to expect it.
if [ -e "$SCRATCH" ]; then
  if [ ! -d "$SCRATCH" ]; then
    echo "collect-context: $SCRATCH exists and is not a directory" >&2
    exit 2
  fi
  if [ -n "$(ls -A "$SCRATCH" 2>/dev/null)" ] && [ ! -f "$SCRATCH/$MARKER" ]; then
    echo "collect-context: refusing to empty $SCRATCH" >&2
    echo "                 it is not empty and carries no $MARKER marker, so it was not" >&2
    echo "                 created by this script. Pass a new or previously used path." >&2
    exit 2
  fi
  rm -rf "$SCRATCH"
fi

mkdir -p "$SCRATCH" || exit 2
printf 'Created by collect-context.sh. Safe to delete.\n' > "$SCRATCH/$MARKER"
python3 "$HERE/lib/collect_context.py" "$ABS" "$SCRATCH" || exit $?
echo "SCRATCH: $SCRATCH"
