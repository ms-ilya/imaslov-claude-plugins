#!/usr/bin/env bash
# ABOUTME: Regenerates plan.md's ## Task graph table from the task files, which are its only source.
# ABOUTME: A status kept in two places is a status that falls behind in one of them.
#
# structured-plan-mode asks for the status in three places at once — the task
# file, the plan, and a native task list. That is three chances to update two.
# Here the task file owns it and the table is derived, exactly as
# bump-protocol.sh owns the record's counters rather than accepting a self-report.
set -uo pipefail

usage() {
  cat <<'USAGE'
usage: make-progress.sh <plan-dir> [--check]

  Rewrites the ## Task graph table in <plan-dir>/plan.md from <plan-dir>/tasks/.
  Every other section is left exactly as it was.

  --check   Report whether the table is current and change nothing.
            Exit 0 current · 1 stale.

Exit 0 written or current · 1 stale under --check · 2 could not run.
USAGE
}

DIR=""; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --check) CHECK=1; shift ;;
    -*) echo "FAIL  unknown option: $1"; usage; exit 2 ;;
    *) [ -z "$DIR" ] || { echo "FAIL  unexpected extra argument: $1"; exit 2; }; DIR="$1"; shift ;;
  esac
done

[ -z "$DIR" ] && { usage; exit 2; }
[ -f "$DIR/plan.md" ] || { echo "FAIL  no plan.md in $DIR"; exit 2; }
[ -d "$DIR/tasks" ] || { echo "FAIL  no tasks/ directory in $DIR"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — make-progress.sh cannot run"; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PYTHONPATH="$HERE/lib" python3 - "$DIR" "$CHECK" <<'PY'
import os, re, sys
from record import Plan, load_tasks, STATUSES

plandir, check = sys.argv[1], sys.argv[2] == '1'
planpath = os.path.join(plandir, 'plan.md')
text = open(planpath).read()
tasks = load_tasks(os.path.join(plandir, 'tasks'))

if not tasks:
    print("FAIL  no task files — nothing to generate the table from")
    sys.exit(2)

rows = ["| Task | Title | Covers | Depends on | Milestone | Status |",
        "|---|---|---|---|---|---|"]
for tid, t in tasks:
    st = t.status()
    if st not in STATUSES:
        print(f"FAIL  tasks/{tid}.md has status '{st}', which is not one of {', '.join(STATUSES)}")
        sys.exit(2)
    rows.append("| {} | {} | {} | {} | {} | {} |".format(
        tid, t.title() or '—',
        ', '.join(t.covers()) or '—',
        ', '.join(t.depends()) or '—',
        t.field('Milestone') or '—', st))
table = "\n".join(rows)

m = re.search(r'^(##\s+Task graph[^\n]*\n)(.*?)(?=^## |\Z)', text, re.M | re.S)
if not m:
    print("FAIL  plan.md has no ## Task graph section to regenerate")
    print("      expected: ## Task graph, followed by the table")
    sys.exit(2)

new = text[:m.start(2)] + "\n" + table + "\n\n" + text[m.end(2):]

if new == text:
    print(f"ok    task graph is current ({len(tasks)} task(s))")
    sys.exit(0)
if check:
    print(f"stale task graph — {len(tasks)} task file(s) disagree with the table in plan.md")
    print("      run: make-progress.sh " + plandir)
    sys.exit(1)

open(planpath, 'w').write(new)
done = sum(1 for _, t in tasks if t.status() == 'Done')
print(f"wrote {planpath}")
print(f"  {len(tasks)} task(s) · {done} done · "
      + " · ".join(f"{tid} {t.status()}" for tid, t in tasks))
PY
