#!/usr/bin/env bash
# ABOUTME: Publishes a checked draft as spec.md — runs the full spec check, renames spec.draft.md and
# ABOUTME: writes traceability.md, so the spec that ships is byte for byte the draft that was checked.
#
# Writing spec.md by hand means retyping the draft, and a retyped spec is a new
# document nobody checked. A rename cannot drift.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: publish-spec.sh <specdir> [--allow-reword | --fresh]

  Runs check-spec.sh on <specdir>/spec.draft.md against <specdir>/tree.md.
  When <specdir>/spec.md already exists this is an amendment: the existing spec
  is checked against as --prev, and what the amendment changes is printed
  before anything is replaced.

  Clean check: spec.draft.md becomes spec.md and traceability.md is written.
  Findings: nothing is touched.

  --allow-reword  On an amendment, accept text changed under an existing
                  identifier. Passed through to check-spec.sh.
  --fresh         Replace an existing spec.md without comparing against it.
                  Only for a restart the user chose: the old spec's identifiers
                  mean nothing to the new one.

Exit 0 when published, 1 when the draft has findings, 2 when a step could not
run.
USAGE
}

DIR=""; ALLOW_REWORD=0; FRESH=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --allow-reword) ALLOW_REWORD=1; shift ;;
    --fresh) FRESH=1; shift ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *)
      [ -z "$DIR" ] || { echo "FAIL  unexpected extra argument: $1"; usage; exit 2; }
      DIR="$1"; shift ;;
  esac
done

[ -z "$DIR" ] && { usage; exit 2; }
[ -d "$DIR" ] || { echo "FAIL  no such directory: $DIR"; exit 2; }
if [ "$ALLOW_REWORD" -eq 1 ] && [ "$FRESH" -eq 1 ]; then
  echo "FAIL  --allow-reword compares against the existing spec and --fresh ignores it — pass one"
  exit 2
fi

DRAFT="$DIR/spec.draft.md"; SPEC="$DIR/spec.md"; TREE="$DIR/tree.md"
if [ ! -f "$DRAFT" ]; then
  echo "FAIL  no draft to publish: $DRAFT"
  [ -f "$SPEC" ] && echo "      spec.md is already there — this run has been published"
  exit 2
fi
[ -f "$TREE" ] || { echo "FAIL  design record not found: $TREE"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

AMEND=0
[ -f "$SPEC" ] && [ "$FRESH" -eq 0 ] && AMEND=1

if [ "$AMEND" -eq 1 ] && [ "$ALLOW_REWORD" -eq 1 ]; then
  out="$(bash "$HERE/check-spec.sh" "$DRAFT" --tree "$TREE" --prev "$SPEC" --allow-reword 2>&1)"; rc=$?
elif [ "$AMEND" -eq 1 ]; then
  out="$(bash "$HERE/check-spec.sh" "$DRAFT" --tree "$TREE" --prev "$SPEC" 2>&1)"; rc=$?
else
  out="$(bash "$HERE/check-spec.sh" "$DRAFT" --tree "$TREE" 2>&1)"; rc=$?
fi

if [ "$rc" -ne 0 ]; then
  printf '%s\n' "$out"
  echo
  if [ "$rc" -eq 1 ]; then
    echo "NOT PUBLISHED — fix the findings above in spec.draft.md and run this again"
    exit 1
  fi
  echo "NOT PUBLISHED — the check could not run"
  exit 2
fi

if [ "$AMEND" -eq 1 ]; then
  # check-spec.sh --prev has passed, so the diff is for the report. Only a diff
  # that could not be rendered stops the publish: once the rename has happened
  # the previous spec is gone and nothing can render it.
  echo "── what this amendment changes ──"
  bash "$HERE/spec-diff.sh" "$SPEC" "$DRAFT" --tree "$TREE"; drc=$?
  if [ "$drc" -gt 1 ]; then
    echo "NOT PUBLISHED — the amendment diff could not be rendered"
    exit 2
  fi
  echo
fi

mv -f "$DRAFT" "$SPEC" || { echo "FAIL  could not rename $DRAFT to $SPEC"; exit 2; }
echo "PUBLISHED  $SPEC"

bash "$HERE/make-traceability.sh" "$SPEC" --tree "$TREE" || {
  echo "FAIL  spec.md is published, but traceability.md could not be written"
  exit 2
}
