#!/usr/bin/env bash
# ABOUTME: Validates each subagent's findings file against the closed finding schema before aggregation.
#
# Usage: validate-findings.sh <findings-*.json ...>
#
# An output that fails here is not merged. Merging a malformed result is how a
# fabricated line number, or a MANUAL item disguised as a finding, reaches a
# report with the same authority as a verified one.
#
# Two gates, and they answer different questions. The schema asks whether the
# document has the right shape. The catalogue check asks whether it is about
# rules that exist, at the numbers and severities those rules actually carry —
# which the schema cannot ask, because the schema has never seen the catalogue.
# Without the second gate a finding naming an invented rule id at a guideline
# number in a section Apple does not have passed cleanly.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(dirname "$HERE")"

command -v python3 >/dev/null 2>&1 || { echo "validate-findings: python3 not found" >&2; exit 1; }
[ $# -ge 1 ] || { echo "usage: validate-findings.sh <findings-*.json ...>" >&2; exit 2; }

bad=0
for f in "$@"; do
  [ -e "$f" ] || { echo "FAIL  $(basename "$f"): file does not exist — the agent may have died before writing"; bad=1; continue; }
  if ! out="$(python3 "$HERE/lib/schema_check.py" "$f" "$PLUGIN/schemas/finding.schema.json" 2>&1)"; then
    echo "FAIL  $(basename "$f"): does not match the finding schema — not merged"
    printf '%s\n' "$out"
    bad=1
    continue
  fi
  if ! out="$(python3 "$HERE/lib/check_findings.py" "$f" "$PLUGIN/rules" 2>&1)"; then
    echo "FAIL  $(basename "$f"): contradicts the catalogue it cites — not merged"
    printf '%s\n' "$out"
    bad=1
    continue
  fi
  counts="$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(f\"{len(d.get('findings',[]))} finding(s), {len(d.get('checklist',[]))} checklist item(s)\")" "$f")"
  echo "ok    $(basename "$f"): $counts"
done
exit $bad
