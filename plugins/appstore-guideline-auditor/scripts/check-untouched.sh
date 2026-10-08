#!/usr/bin/env bash
# ABOUTME: Snapshots the audited project's file list when an audit starts, and at the end lists every file created, changed or deleted since, other than the report.
#
# Usage: check-untouched.sh --snapshot <project-path> <scratch-dir>
#        check-untouched.sh <project-path> <scratch-dir> [--report <report-path>]
#
# The audit promises to leave the project as it found it apart from one file,
# its report. An instruction cannot keep that promise on its own: the audit and
# its subagents hold a Write tool. This script turns the promise into something
# observed. It cannot say WHO changed a file — an editor, a build and the audit
# all look the same from here — so it reports what changed and leaves the
# attribution to the reader.
#
# Exit 0: nothing but the report changed. Exit 1: something else did, listed on
# stdout. Exit 2: the check could not run, which is not a clean result.
set -uo pipefail

usage() {
  echo "usage: check-untouched.sh --snapshot <project-path> <scratch-dir>" >&2
  echo "       check-untouched.sh <project-path> <scratch-dir> [--report <report-path>]" >&2
}

# The marker collect-context.sh writes when it creates the scratch directory.
# Its modification time is the moment the audit started.
MARKER=".appstore-audit-scratch"
BEFORE="project-files.before"

# Paths that tools outside the audit rewrite continuously while a project is
# open: git's own bookkeeping, build output, per-user Xcode state, Finder
# metadata. Listing them would bury a real change under noise on every run.
list_files() {
  # list_files <project> [extra find predicates...]
  local project="$1"; shift
  ( cd "$project" && find . \
      \( -name .git -o -name DerivedData -o -name .build -o -name xcuserdata \) -prune \
      -o -type f ! -name .DS_Store "$@" -print ) | LC_ALL=C sort
}

MODE="check"
if [ "${1:-}" = "--snapshot" ]; then MODE="snapshot"; shift; fi

[ $# -ge 2 ] || { usage; exit 2; }
PROJECT="$1"; SCRATCH="$2"; shift 2
[ -d "$PROJECT" ] || { echo "check-untouched: $PROJECT is not a directory" >&2; exit 2; }
[ -f "$SCRATCH/$MARKER" ] || {
  echo "check-untouched: $SCRATCH is not a scratch directory made by collect-context.sh" >&2
  exit 2
}

if [ "$MODE" = "snapshot" ]; then
  [ $# -eq 0 ] || { usage; exit 2; }
  list_files "$PROJECT" > "$SCRATCH/$BEFORE" || exit 2
  exit 0
fi

REPORT=".appstore-audit/report.md"
while [ $# -gt 0 ]; do
  case "$1" in
    --report) [ $# -ge 2 ] || { echo "check-untouched: --report needs a path" >&2; exit 2; }; REPORT="$2"; shift 2 ;;
    *) echo "check-untouched: unexpected argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ -f "$SCRATCH/$BEFORE" ] || {
  echo "check-untouched: no snapshot in $SCRATCH, so nothing can be compared" >&2
  echo "                 collect-context.sh takes it; this scratch directory predates that" >&2
  exit 2
}
command -v python3 >/dev/null 2>&1 || { echo "check-untouched: python3 not found" >&2; exit 2; }

# The report as find prints it, relative to the project with a leading "./".
# A report written outside the project yields a path starting "./..", which
# matches no listed file, so nothing is excluded for it.
REPORT_REL="$(python3 -c '
import os, sys
project, report = sys.argv[1], sys.argv[2]
if not os.path.isabs(report):
    report = os.path.join(project, report)
print("./" + os.path.relpath(os.path.realpath(report), os.path.realpath(project)))
' "$PROJECT" "$REPORT")" || exit 2

AFTER="$(list_files "$PROJECT")" || exit 2
NEWER="$(list_files "$PROJECT" -newer "$SCRATCH/$MARKER")" || exit 2

drop_report() { grep -vxF -- "$REPORT_REL" || true; }

CREATED="$(comm -13 "$SCRATCH/$BEFORE" <(printf '%s\n' "$AFTER") | drop_report)"
DELETED="$(comm -23 "$SCRATCH/$BEFORE" <(printf '%s\n' "$AFTER"))"
# A file that is both in the snapshot and newer than the marker was rewritten
# in place. One that is only newer is already listed as created.
CHANGED="$(comm -12 "$SCRATCH/$BEFORE" <(printf '%s\n' "$NEWER") | drop_report)"

if [ -z "$CREATED$DELETED$CHANGED" ]; then
  echo "UNTOUCHED: no project file other than the report was created, changed or deleted during the audit"
  exit 0
fi

echo "CHANGED DURING THE AUDIT (other than the report):"
[ -n "$CREATED" ] && printf '%s\n' "$CREATED" | sed 's/^/  created  /'
[ -n "$CHANGED" ] && printf '%s\n' "$CHANGED" | sed 's/^/  changed  /'
[ -n "$DELETED" ] && printf '%s\n' "$DELETED" | sed 's/^/  deleted  /'
echo
echo "This check sees that a file changed, not who changed it. An editor, a build"
echo "or the audit itself would all appear here."
exit 1
