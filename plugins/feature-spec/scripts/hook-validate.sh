#!/usr/bin/env bash
# ABOUTME: PostToolUse hook — runs check-tree.sh or check-spec.sh whenever the design record or a
# ABOUTME: spec draft is written, so validation is a property of the harness rather than a remembered step.
#
# R1 and R7 are the two rules the skill itself names as the ones that slip first,
# and both are enforced by a step near the end of a loop the model must run under
# exactly the context pressure that makes steps get dropped. A hook registered at
# invocation survives the whole session, which is longer than the allowed-tools
# grant and longer than any single turn.
#
# Runs CLOSED-WORLD checks only: it asserts about what the file says, never about
# what the file has not said yet. A record at the end of Phase 1 has four sections
# and no coverage table; a draft at write three of nine has no acceptance scenarios.
# Both are correct, and an open-world hook calls both broken — which does not teach
# the writer to comply, it teaches the writer to evade: buffer everything into one
# giant Write, or use a filename the hook does not match.
#
# A fabricated citation is wrong at every stage, so that still fires here. The
# open-world checks run at the gate, where completeness is genuinely required.
#
# Reads the PostToolUse payload on stdin. Exit 2 feeds stderr back to Claude as
# feedback; exit 0 is silent success. Anything this hook cannot do, it declines
# to do loudly rather than failing the write.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v python3 >/dev/null 2>&1 || exit 0   # no python3: the checkers cannot run anyway

FILE="$(python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    print(""); sys.exit(0)
ti=d.get("tool_input") or {}
print(ti.get("file_path") or ti.get("path") or "")
' 2>/dev/null)"

[ -n "$FILE" ] || exit 0
[ -f "$FILE" ] || exit 0

base="$(basename "$FILE")"
dir="$(dirname "$FILE")"

case "$base" in
  tree.md)
    # Only a real design record, not any file that happens to be called tree.md.
    grep -q '^## Protocol' "$FILE" 2>/dev/null || exit 0
    out="$(bash "$HERE/check-tree.sh" "$FILE" --closed-world 2>&1)"; rc=$?
    ;;
  spec.draft.md|spec.md)
    [ -f "$dir/tree.md" ] || exit 0
    grep -qE '^##\s+(Requirements|Success criteria)' "$FILE" 2>/dev/null || exit 0
    out="$(bash "$HERE/check-spec.sh" "$FILE" --tree "$dir/tree.md" --closed-world 2>&1)"; rc=$?
    ;;
  plan.md)
    # Only a real implementation plan, not any file that happens to be called plan.md.
    grep -q '^## Task graph' "$FILE" 2>/dev/null || exit 0
    [ -f "$dir/../spec.md" ] || exit 0
    out="$(bash "$HERE/check-plan.sh" "$dir" --spec "$dir/../spec.md" --closed-world 2>&1)"; rc=$?
    ;;
  T[0-9][0-9]*.md)
    # A task file: <specdir>/plan/tasks/T0N.md. The checker takes the plan dir.
    grep -qE '^# T[0-9]+ ' "$FILE" 2>/dev/null || exit 0
    [ "$(basename "$dir")" = "tasks" ] || exit 0
    plandir="$(dirname "$dir")"
    [ -f "$plandir/../spec.md" ] || exit 0
    out="$(bash "$HERE/check-plan.sh" "$plandir" --spec "$plandir/../spec.md" --closed-world 2>&1)"; rc=$?
    ;;
  *) exit 0 ;;
esac

[ "$rc" -eq 0 ] && exit 0

{
  echo "feature-spec: $base contains something that is wrong at any stage."
  echo "This is not about anything you have not written yet — only about what is"
  echo "already there. Fix it and carry on; a finding here is not a critic finding."
  echo
  printf '%s\n' "$out" | grep -E '^(FAIL|      expected:)' | head -40
} >&2
exit 2
