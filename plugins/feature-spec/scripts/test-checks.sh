#!/usr/bin/env bash
# ABOUTME: Self-test for check-tree.sh and check-spec.sh — asserts the shipped skeletons pass, then
# ABOUTME: mutates one rule at a time and asserts that rule's specific failure fires.
#
# A checker that stops enforcing a rule keeps printing OK, so the rule dies silently.
# This is the only thing standing between a regex tweak and a plugin that validates nothing.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFS="$HERE/../skills/feature-spec/references"
TREE_CHECK="$HERE/check-tree.sh"
SPEC_CHECK="$HERE/check-spec.sh"

command -v python3 >/dev/null 2>&1 || { echo "FAIL  python3 not found — test-checks.sh cannot run"; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/docs/specs" "$WORK/docs/adr"

pass=0; fail=0

# expect <name> <exit-code> <pattern-that-must-appear> -- <command...>
expect() {
  local name="$1" want="$2" pat="$3"; shift 4
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ "$rc" -ne "$want" ]; then
    echo "FAIL  $name"
    echo "      exit $rc, wanted $want"
    printf '%s\n' "$out" | tail -4 | while IFS= read -r l; do echo "      | $l"; done
    fail=$((fail+1)); return
  fi
  if [ -n "$pat" ] && ! printf '%s\n' "$out" | grep -qi -- "$pat"; then
    echo "FAIL  $name"
    echo "      exit code right, but no output matched: $pat"
    printf '%s\n' "$out" | grep -i 'FAIL' | head -3 | while IFS= read -r l; do echo "      | $l"; done
    fail=$((fail+1)); return
  fi
  echo "ok    $name"
  pass=$((pass+1))
}

# ---------------------------------------------------------------- fixtures
# The design record fixture is the skeleton the plugin documents in
# tree-format.md. Testing against the shipped example is what stops the
# format and its checker drifting apart.
python3 - "$REFS/tree-format.md" "$WORK/tree.md" <<'PY'
import re,sys
src=open(sys.argv[1]).read()
m=re.search(r'```skeleton\n(.*?)\n```', src, re.S)
if not m:
    sys.stderr.write("no ```skeleton block in tree-format.md\n"); sys.exit(2)
open(sys.argv[2],'w').write(m.group(1)+"\n")
PY
[ -s "$WORK/tree.md" ] || { echo "FAIL  could not extract the tree skeleton"; exit 2; }

# The files the skeleton's ## Reads names, so the resolution check has something real.
: > "$WORK/docs/specs/GLOSSARY.md"
cat > "$WORK/docs/adr/0004-checkpoint-file-over-database.md" <<'EOF'
# Checkpoint file over a database for retry state

Status: Proposed

## Decision

Retry state lives in the existing JSON checkpoint file, not a new table.
EOF
: > "$WORK/AGENTS.md"

# A spec whose every tag resolves against that record: Q1, Q2, grounding fact 1,
# the chosen strategy and ADR-0004 all exist in the skeleton above.
cat > "$WORK/spec.md" <<'EOF'
# Retry uploads

Batch imports restart from zero after a crash.

## User stories

P1 · Resume an interrupted import

## Requirements

FR-001  The importer resumes from the last checkpoint on restart.
        ← Settled Q1
FR-002  The importer retries a failed row at most 5 times over 24 hours.
        ← Settled Q2
FR-003  Retry state is written to the existing checkpoint file.
        ← Grounding fact 1

## Success criteria

SC-001  An import interrupted at row 10000 resumes within 2 seconds.
        ← Strategy (chosen)
SC-002  A row that has failed 5 times appears in the reject file with its line number.
        ← ADR-0004

## Acceptance scenarios

FR-001  Given a checkpoint exists, when the importer starts, then it resumes from it.
FR-002  Given 5 attempts have been made, when a 6th is due, then the row is rejected.
FR-003  Given a retry is scheduled, when state is written, then it lands in the checkpoint file.

## Out of scope

- Per-source retry overrides.
EOF

mut() { # mut <dest> <sed-expr> [src]
  sed "$2" "${3:-$WORK/tree.md}" > "$WORK/$1"
}

echo "── check-tree.sh ─────────────────────────────────────────────"

expect "shipped skeleton passes" 0 "TREE OK" -- \
  bash "$TREE_CHECK" "$WORK/tree.md" --repo-root "$WORK"

mut ghost.md 's|docs/adr/0004-checkpoint-file-over-database.md|docs/adr/9999-invented.md|'
expect "ghost ## Reads entry is caught" 1 "does not exist" -- \
  bash "$TREE_CHECK" "$WORK/ghost.md" --repo-root "$WORK"

mut state.md 's/| Verification | Missing |/| Verification | Done |/'
expect "illegal coverage state is caught" 1 "illegal state" -- \
  bash "$TREE_CHECK" "$WORK/state.md" --repo-root "$WORK"

mut clearstar.md 's/Clear\* (2 deferred)/Clear*/'
expect "Clear* without a count is caught" 1 "deferral count" -- \
  bash "$TREE_CHECK" "$WORK/clearstar.md" --repo-root "$WORK"

mut na.md 's|N/A — no user-facing surface|N/A|'
expect "N/A without a reason is caught" 1 "no stated reason" -- \
  bash "$TREE_CHECK" "$WORK/na.md" --repo-root "$WORK"

mut rename.md 's/| Problem \& outcome |/| Problem and outcomes |/'
expect "paraphrased category name is caught" 1 "coverage" -- \
  bash "$TREE_CHECK" "$WORK/rename.md" --repo-root "$WORK"

mut noround.md 's/(r1)$//'
expect "settled answer missing its round is caught" 1 "round tag" -- \
  bash "$TREE_CHECK" "$WORK/noround.md" --repo-root "$WORK"

mut nowhy.md 's/^  \*Why:\* one source of truth.*$/  one source of truth./'
expect "settled answer missing its rationale is caught" 1 "rationale" -- \
  bash "$TREE_CHECK" "$WORK/nowhy.md" --repo-root "$WORK"

mut dupq.md 's/\*\*Q2 Attempt ceiling\*\*/**Q1 Attempt ceiling**/'
expect "reused question id is caught" 1 "reused" -- \
  bash "$TREE_CHECK" "$WORK/dupq.md" --repo-root "$WORK"

mut orphan.md 's/deps: Q7/deps: Q12/'
expect "blocked question behind a deferred parent is caught" 1 "transitive" -- \
  bash "$TREE_CHECK" "$WORK/orphan.md" --repo-root "$WORK"

mut round99.md 's/Round: 2 of 3/Round: 99 of 3/'
expect "impossible round number is caught" 1 "protocol counter" -- \
  bash "$TREE_CHECK" "$WORK/round99.md" --repo-root "$WORK"

mut zeroq.md 's/questions 10/questions 0/'
expect "question counter below the ids on the page is caught" 1 "distinct question ids" -- \
  bash "$TREE_CHECK" "$WORK/zeroq.md" --repo-root "$WORK"

mut nophase.md 's/Next phase: 2/Next phase: 12/'
expect "out-of-range next phase is caught" 1 "phases 0 through 7" -- \
  bash "$TREE_CHECK" "$WORK/nophase.md" --repo-root "$WORK"

mut guard.md 's/questions 10 · fact-finders 2 · references 4/questions 30 · fact-finders 6 · references 9/'
expect "guard that should have tripped is caught" 1 "guard says" -- \
  bash "$TREE_CHECK" "$WORK/guard.md" --repo-root "$WORK"

mut noprob.md '/^## Problem$/,/^## Protocol$/{/^## /!d;}'
expect "empty problem statement is caught" 1 "Problem is empty" -- \
  bash "$TREE_CHECK" "$WORK/noprob.md" --repo-root "$WORK"

expect "missing file is not a pass" 2 "no such file" -- \
  bash "$TREE_CHECK" "$WORK/nope.md"

# --- principles files that live outside the repo --------------------------
# This machine keeps its only AGENTS.md in ~. Rejecting the path on shape made
# a real, readable file report as invented.
sed 's|- AGENTS.md   (principles)|- ~/.claude/definitely-not-here-9f3a.md   (principles)|' \
  "$WORK/tree.md" > "$WORK/tree-ext-ghost.md"
expect "an external path that does not exist is still a ghost" 1 "does not exist" -- \
  bash "$TREE_CHECK" "$WORK/tree-ext-ghost.md" --repo-root "$WORK"

sed "s|- AGENTS.md   (principles)|- $WORK/AGENTS.md   (principles)|" \
  "$WORK/tree.md" > "$WORK/tree-ext-ok.md"
expect "an external path that exists resolves" 0 "outside the repo" -- \
  bash "$TREE_CHECK" "$WORK/tree-ext-ok.md" --repo-root "$WORK"

# --- the guard scores pressure, not the mode's own mandate ----------------
# `--deep` mandates 4 fact-finders and loads 10 reference files. Fixed
# thresholds of 3 and 7 put two counters at threshold before the interview
# asked anything, so `--deep` got exactly one round on any repo with a stack.
sed -e 's/Mode: default/Mode: deep/' \
    -e 's/Round: 2 of 3/Round: 2 of 5/' \
    -e 's/fact-finders 2 · references 4/fact-finders 4 · references 10/' \
    "$WORK/tree.md" > "$WORK/tree-deep.md"
expect "deep's own mandate does not trip the guard" 0 "0 at threshold" -- \
  bash "$TREE_CHECK" "$WORK/tree-deep.md" --repo-root "$WORK"

sed -e 's/lines read 340/lines read 4000/' -e 's/questions 10/questions 30/' \
    "$WORK/tree-deep.md" > "$WORK/tree-pressure.md"
expect "real context pressure still trips it" 1 "guard says" -- \
  bash "$TREE_CHECK" "$WORK/tree-pressure.md" --repo-root "$WORK"

echo
echo "── check-spec.sh ─────────────────────────────────────────────"

expect "valid spec passes" 0 "SPEC OK" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md" --tree "$WORK/tree.md"

expect "refuses to run without the design record" 2 "--tree is required" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md"

expect "unreadable design record is not a pass" 2 "not found" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md" --tree "$WORK/nope.md"

smut() { sed "$2" "$WORK/spec.md" > "$WORK/$1"; }

smut fake-q.md 's/← Settled Q1/← Settled Q99/'
expect "fabricated Settled id is caught" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/fake-q.md" --tree "$WORK/tree.md"

smut fake-fact.md 's/← Grounding fact 1/← Grounding fact 42/'
expect "fabricated grounding fact is caught" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/fake-fact.md" --tree "$WORK/tree.md"

smut fake-adr.md 's/← ADR-0004/← ADR-9999/'
expect "fabricated ADR is caught" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/fake-adr.md" --tree "$WORK/tree.md"

smut fake-md.md 's|← Settled Q2|← docs/invented.md|'
expect "citation of a file not in ## Reads is caught" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/fake-md.md" --tree "$WORK/tree.md"

smut untagged.md '/← Settled Q2/d'
expect "missing source tag is caught" 1 "no source tag" -- \
  bash "$SPEC_CHECK" "$WORK/untagged.md" --tree "$WORK/tree.md"

smut adj.md 's/resumes within 2 seconds/resumes quickly/'
expect "unquantified adjective is caught" 1 "unquantified adjective" -- \
  bash "$SPEC_CHECK" "$WORK/adj.md" --tree "$WORK/tree.md"

smut noscen.md '/^FR-002  Given 5 attempts/d'
expect "requirement with no acceptance scenario is caught" 1 "no acceptance scenario" -- \
  bash "$SPEC_CHECK" "$WORK/noscen.md" --tree "$WORK/tree.md"

smut bare.md 's/- Per-source retry overrides./- [NEEDS CLARIFICATION]/'
expect "bare clarification marker is caught" 1 "bare \[NEEDS CLARIFICATION\]" -- \
  bash "$SPEC_CHECK" "$WORK/bare.md" --tree "$WORK/tree.md"

smut dupid.md 's/^FR-003  Retry state/FR-001  Retry state/'
expect "duplicate identifier is caught" 1 "defined 2x" -- \
  bash "$SPEC_CHECK" "$WORK/dupid.md" --tree "$WORK/tree.md"

# --- amendment: identifier stability -------------------------------------
smut reworded.md 's/The importer resumes from the last checkpoint on restart./The importer restarts the whole import from row zero./'
expect "reword under a stable id fails by default" 1 "text changed under existing identifiers" -- \
  bash "$SPEC_CHECK" "$WORK/reworded.md" --tree "$WORK/tree.md" --prev "$WORK/spec.md"

expect "reword is accepted when acknowledged" 0 "allow-reword" -- \
  bash "$SPEC_CHECK" "$WORK/reworded.md" --tree "$WORK/tree.md" --prev "$WORK/spec.md" --allow-reword

smut vanished.md '/^FR-003  Retry state/,+1d'
expect "vanished identifier is caught" 1 "vanished" -- \
  bash "$SPEC_CHECK" "$WORK/vanished.md" --tree "$WORK/tree.md" --prev "$WORK/spec.md"

expect "unreadable --prev is not a pass" 2 "previous spec not found" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md" --tree "$WORK/tree.md" --prev "$WORK/nope.md"

# --- a tag may name several sources, and all of them are citations ---------
# Resolving only the first is the check the second one passes. It let a
# `Deferred Q<n>` — not a source form at all — into a shipped spec behind a
# valid `Settled Q<n>`, and cost a real answer its traceability row.

smut multi-ok.md 's/← Grounding fact 1/← Settled Q1 (r1), Grounding fact 1/'
expect "a tag naming two valid sources passes" 0 "SPEC OK" -- \
  bash "$SPEC_CHECK" "$WORK/multi-ok.md" --tree "$WORK/tree.md"

smut multi-bad.md 's/← Settled Q1$/← Settled Q1 (r1), Deferred Q12 (r2)/'
expect "an invalid second source is caught" 1 "Deferred Q12" -- \
  bash "$SPEC_CHECK" "$WORK/multi-bad.md" --tree "$WORK/tree.md"

smut multi-fake.md 's/← Settled Q1$/← Settled Q1, Settled Q99/'
expect "a fabricated second Settled id is caught" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/multi-fake.md" --tree "$WORK/tree.md"

smut plural.md 's/← Grounding fact 1/← Grounding facts 1, 2/'
expect "the plural Grounding facts form resolves" 0 "SPEC OK" -- \
  bash "$SPEC_CHECK" "$WORK/plural.md" --tree "$WORK/tree.md"

# --- ## Strategy tolerates the decoration a drafter reaches for ------------
# `- **Chosen (structure): C — …**` named no chosen approach to a literal
# `Chosen:` match, and the failure was reported against the spec.
sed 's/^- Chosen: B — sweep.*$/- **Chosen (structure): B — sweep the checkpoint on a timer.**\n- **Chosen (matte): A — composite in the existing pass.**/' \
  "$WORK/tree.md" > "$WORK/tree-decorated.md"
expect "a decorated per-axis Chosen resolves" 0 "SPEC OK" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md" --tree "$WORK/tree-decorated.md"

sed '/^- Chosen:/d' "$WORK/tree.md" > "$WORK/tree-nochosen.md"
expect "a genuinely absent Chosen names the record, not the spec" 1 "design record" -- \
  bash "$SPEC_CHECK" "$WORK/spec.md" --tree "$WORK/tree-nochosen.md"

# --- criteria are written with digits --------------------------------------
smut worded.md 's/An import interrupted at row 10000 resumes within 2 seconds./An import resumes in all three cases./'
expect "a number spelled as a word is flagged" 0 "as a word" -- \
  bash "$SPEC_CHECK" "$WORK/worded.md" --tree "$WORK/tree.md"

echo
echo "── closed-world: incomplete is not wrong ─────────────────────"

# The hook fires on every write, and a document under construction is
# legitimately incomplete. An open-world check calls that broken, which does not
# teach the writer to comply — it teaches the writer to evade, by buffering
# everything into one giant Write or dodging the filename. Closed-world checks
# are true at every stage: a fabricated citation is wrong at write three of nine
# exactly as it is wrong at the end.

# A record as Phase 1 legitimately leaves it: four sections, no coverage table.
cat > "$WORK/phase1.md" <<'EOF'
# Design tree: retry uploads

## Problem
Batch imports restart from zero after a crash.

## Protocol
Slug: 2026-08-24-retry   Mode: default
Round: 0 of 3   Next phase: 2
Counters: questions 0 · fact-finders 2 · references 2 · orchestrator reads 3 · critic passes 0
Guard: not tripped

## Reads
- AGENTS.md   (principles)

## Principles in force
- From AGENTS.md: "smallest reasonable change"

## Grounding facts
1. Ingest state is a JSON checkpoint at `state.go:31` (fact-finder, r0, high)
EOF

expect "a Phase 1 record passes closed-world" 0 "TREE OK (closed-world)" -- \
  bash "$TREE_CHECK" "$WORK/phase1.md" --closed-world --repo-root "$WORK"
expect "the same record still fails the full gate" 1 "missing sections" -- \
  bash "$TREE_CHECK" "$WORK/phase1.md" --repo-root "$WORK"

# A corrupt value is wrong at any stage and must survive closed-world.
sed 's/Round: 0 of 3/Round: 99 of 3/' "$WORK/phase1.md" > "$WORK/phase1-bad.md"
expect "a bad counter still fires in closed-world" 1 "protocol counter" -- \
  bash "$TREE_CHECK" "$WORK/phase1-bad.md" --closed-world --repo-root "$WORK"
sed 's|- AGENTS.md   (principles)|- docs/nope.md|' "$WORK/phase1.md" > "$WORK/phase1-ghost.md"
expect "a ghost read still fires in closed-world" 1 "does not exist" -- \
  bash "$TREE_CHECK" "$WORK/phase1-ghost.md" --closed-world --repo-root "$WORK"

# A draft mid-write: one requirement, no acceptance scenarios yet.
cat > "$WORK/partial.md" <<'EOF'
# Retry uploads

## Requirements

FR-001  The importer resumes from the last checkpoint on restart.
        ← Settled Q1
EOF

expect "a partial draft passes closed-world" 0 "SPEC OK (closed-world)" -- \
  bash "$SPEC_CHECK" "$WORK/partial.md" --tree "$WORK/tree.md" --closed-world
expect "the same draft still fails the full gate" 1 "acceptance scenario" -- \
  bash "$SPEC_CHECK" "$WORK/partial.md" --tree "$WORK/tree.md"

sed 's/← Settled Q1/← Settled Q99/' "$WORK/partial.md" > "$WORK/partial-fake.md"
expect "a fabricated citation still fires in closed-world" 1 "fabricated citation" -- \
  bash "$SPEC_CHECK" "$WORK/partial-fake.md" --tree "$WORK/tree.md" --closed-world
sed 's/on restart\./quickly./' "$WORK/partial.md" > "$WORK/partial-adj.md"
expect "an unquantified adjective still fires in closed-world" 1 "unquantified adjective" -- \
  bash "$SPEC_CHECK" "$WORK/partial-adj.md" --tree "$WORK/tree.md" --closed-world

# An empty stub is the very first write of a draft.
printf '# Retry uploads\n\nBatch imports restart from zero.\n' > "$WORK/stub.md"
expect "an empty stub passes closed-world" 0 "SPEC OK (closed-world)" -- \
  bash "$SPEC_CHECK" "$WORK/stub.md" --tree "$WORK/tree.md" --closed-world

echo
echo "── the hook: silent on incomplete, loud on wrong ─────────────"

HOOK="$HERE/hook-validate.sh"
hookrun() { echo "{\"tool_input\":{\"file_path\":\"$1\"}}" | bash "$HOOK"; }

cp "$WORK/tree.md" "$WORK/docs/specs/tree.md"
expect "hook is silent on a complete record" 0 "" -- hookrun "$WORK/docs/specs/tree.md"
cp "$WORK/phase1.md" "$WORK/docs/specs/tree.md"
expect "hook is silent on a Phase 1 record" 0 "" -- hookrun "$WORK/docs/specs/tree.md"
cp "$WORK/phase1-bad.md" "$WORK/docs/specs/tree.md"
expect "hook fires on a corrupt counter" 2 "protocol counter" -- hookrun "$WORK/docs/specs/tree.md"

cp "$WORK/tree.md" "$WORK/docs/specs/tree.md"
cp "$WORK/partial.md" "$WORK/docs/specs/spec.draft.md"
expect "hook is silent on a partial draft" 0 "" -- hookrun "$WORK/docs/specs/spec.draft.md"
cp "$WORK/partial-fake.md" "$WORK/docs/specs/spec.draft.md"
expect "hook fires on a fabricated citation" 2 "fabricated citation" -- \
  hookrun "$WORK/docs/specs/spec.draft.md"
expect "hook ignores an unrelated file" 0 "" -- hookrun "$WORK/AGENTS.md"

echo
echo "── bump-protocol.sh ──────────────────────────────────────────"

BUMP="$HERE/bump-protocol.sh"
cp "$WORK/tree.md" "$WORK/bump.md"

expect "advances a round and adds questions" 0 "questions 14" -- \
  bash "$BUMP" "$WORK/bump.md" --round --questions 4

expect "the bumped record still validates" 0 "TREE OK" -- \
  bash "$TREE_CHECK" "$WORK/bump.md" --repo-root "$WORK"

expect "corrects a counter below the ids on the page" 0 "questions" -- \
  bash "$BUMP" "$WORK/bump.md" --show

# The guard is arithmetic, and exit 3 is how a caller learns it just tripped.
cp "$WORK/tree.md" "$WORK/trip.md"
expect "trips the guard and says so" 3 "GUARD TRIPPED" -- \
  bash "$BUMP" "$WORK/trip.md" --questions 30 --references 9 --fact-finders 6

expect "a tripped guard survives the checker" 0 "guard state agrees" -- \
  bash "$TREE_CHECK" "$WORK/trip.md" --repo-root "$WORK"

expect "missing record is not a pass" 2 "no such file" -- \
  bash "$BUMP" "$WORK/nope.md" --round

echo
echo "── check-tree.sh --doctor ────────────────────────────────────"

expect "healthy record needs no repair" 0 "Nothing structurally wrong" -- \
  bash "$TREE_CHECK" "$WORK/tree.md" --doctor

sed '/^## Sessions/,$d' "$WORK/tree.md" > "$WORK/nosessions.md"
expect "names the missing section" 1 "required section" -- \
  bash "$TREE_CHECK" "$WORK/nosessions.md" --doctor
expect "prints the repair from the shipped skeleton" 1 "── add ── Sessions" -- \
  bash "$TREE_CHECK" "$WORK/nosessions.md" --doctor
expect "offers the canonical coverage table" 1 "Problem & outcome" -- \
  bash "$TREE_CHECK" "$WORK/rename.md" --doctor

echo
echo "── generators ────────────────────────────────────────────────"

expect "traceability joins requirement to rationale" 0 "one source of truth" -- \
  bash "$HERE/make-traceability.sh" "$WORK/spec.md" --tree "$WORK/tree.md" --out -
expect "traceability lists deferred items" 0 "Deferred, and therefore untraced" -- \
  bash "$HERE/make-traceability.sh" "$WORK/spec.md" --tree "$WORK/tree.md" --out -
expect "traceability reports an unresolvable tag" 1 "Not traceable" -- \
  bash "$HERE/make-traceability.sh" "$WORK/fake-q.md" --tree "$WORK/tree.md" --out -
expect "generators refuse without the record" 2 "--tree is required" -- \
  bash "$HERE/make-traceability.sh" "$WORK/spec.md"

# An answer cited in second position is still cited. Reading only the first
# listed it under "answered but not traced" — a section the operator is told to
# read before reporting, so a false entry there costs attention.
sed -e 's/^FR-002  The importer retries.*$/FR-002  The importer retries a failed row at most 5 times over 24 hours./' \
    -e 's|← Settled Q2$|← Grounding fact 1, Settled Q2 (r1)|' \
    "$WORK/spec.md" > "$WORK/spec-second.md"
expect "a second-position source is traced" 0 "Q2 Attempt ceiling" -- \
  bash "$HERE/make-traceability.sh" "$WORK/spec-second.md" --tree "$WORK/tree.md" --out -
if bash "$HERE/make-traceability.sh" "$WORK/spec-second.md" --tree "$WORK/tree.md" --out - \
   | grep -q "Answered but not traced"; then
  echo "FAIL  a second-position source is still reported as an unused answer"
  fail=$((fail+1))
else
  echo "ok    a second-position source is not reported as unused"
  pass=$((pass+1))
fi

echo
echo "── make-packet.sh ────────────────────────────────────────────"

# A lens declared a blind spot caused by a hand-rolled sed range, not by
# anything in the spec. Phase 6 is the phase most sensitive to input shape and
# was the only one assembling its input by hand.
PACKET="$HERE/make-packet.sh"

expect "packet carries the statements with their tags" 0 "← Settled Q1" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet carries the coverage table with Clear* intact" 0 "Clear\* (2 deferred)" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet carries the deferred list" 0 "Q12 Per-source overrides" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet carries the principles verbatim" 0 "smallest reasonable change" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet carries the scope boundary, not just its heading" 0 "Per-source retry overrides" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet names what a promoted ADR decided" 0 "Decision: Retry state lives" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"
expect "packet inlines the rubric" 0 "anti-rubber-stamp" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md"

# An empty section must say it is empty. A lens cannot tell a section with
# nothing in it from a section the extraction dropped, and it reports the
# second as a blind spot — which is exactly what happened.
sed '/^## Out of scope$/,$d' "$WORK/spec.md" > "$WORK/spec-noscope.md"
expect "an absent section says so rather than arriving blank" 0 "states no scope boundary" -- \
  bash "$PACKET" "$WORK/spec-noscope.md" --tree "$WORK/tree.md"

# Three parallel lenses all numbering findings B1 cannot be reconciled per id.
expect "a lens packet assigns that lens its own id prefix" 0 "\`BP1\`" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md" --lens principles
if bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md" --lens principles \
   | grep -q "Lens 1 — Completeness"; then
  echo "FAIL  a lens packet carries another lens's rubric — duplicated judgement wastes the pass"
  fail=$((fail+1))
else
  echo "ok    a lens packet carries only its own lens"
  pass=$((pass+1))
fi
expect "an unknown lens is refused, not guessed" 2 "unknown lens" -- \
  bash "$PACKET" "$WORK/spec.md" --tree "$WORK/tree.md" --lens vibes
expect "packet refuses without the record" 2 "--tree is required" -- \
  bash "$PACKET" "$WORK/spec.md"

echo
echo "── undo-round.sh ─────────────────────────────────────────────"

UNDO="$HERE/undo-round.sh"
cp "$WORK/tree.md" "$WORK/undo.md"

expect "dry run reports what it would retract" 0 "Retracting round 1" -- \
  bash "$UNDO" "$WORK/undo.md" --round 1 --dry-run
expect "dry run writes nothing" 0 "" -- \
  cmp -s "$WORK/undo.md" "$WORK/tree.md"

expect "retracts and returns the questions" 0 "Returned to ## Frontier" -- \
  bash "$UNDO" "$WORK/undo.md" --round 1
expect "retracted answers are struck through, not deleted" 0 "retracted, r1" -- \
  grep -F "retracted, r1" "$WORK/undo.md"
expect "the original answer text survives" 0 "checkpoint file" -- \
  grep -F "checkpoint file" "$WORK/undo.md"
expect "coverage is marked, never invented" 0 "Re-score required" -- \
  grep -F "Re-score required" "$WORK/undo.md"

# A retracted question returns to the frontier, so its id is legitimately in two
# places. Struck-through text must not count as a live identifier — the same rule
# that lets rule 5 keep a superseded answer in place during an amendment.
expect "the retracted record still passes the checker" 0 "question ids unique" -- \
  bash "$TREE_CHECK" "$WORK/undo.md" --repo-root "$WORK"
expect "the retracted record validates overall" 0 "TREE OK" -- \
  bash "$TREE_CHECK" "$WORK/undo.md" --repo-root "$WORK"

cp "$WORK/tree.md" "$WORK/undo2.md"
expect "refuses a round that has no answers" 2 "no settled answer is tagged" -- \
  bash "$UNDO" "$WORK/undo2.md" --round 9
expect "refuses a record with nothing left to undo" 2 "nothing to undo" -- \
  bash "$UNDO" "$WORK/undo.md" --round 1

echo
echo "── spec-diff.sh ──────────────────────────────────────────────"

DIFF="$HERE/spec-diff.sh"
sed -e 's/at most 5 times over 24 hours/at most 10 times over 48 hours/' \
    -e 's/^FR-001  The importer resumes from the last checkpoint on restart\./FR-001  The importer resumes from the last checkpoint on restart. (withdrawn)/' \
    "$WORK/spec.md" > "$WORK/spec-amended.md"

expect "reports a reword under a stable id" 0 "Reworded under a stable identifier" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-amended.md"
expect "shows the changed words, not the whole line" 0 "\*\*10\*\*" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-amended.md"
expect "counts a marked withdrawal as correct" 0 "Withdrawn, correctly" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-amended.md"

sed '/^SC-002/,+1d' "$WORK/spec.md" > "$WORK/spec-vanished.md"
expect "a vanished identifier fails" 1 "Vanished" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-vanished.md"

expect "identical specs report no change" 0 "Nothing changed" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec.md"

# A requirement that gains a second citation has been retagged. Comparing only
# the first source called that "unchanged".
sed 's|← Settled Q1$|← Settled Q1 (r1), Grounding fact 2|' "$WORK/spec.md" > "$WORK/spec-retag.md"
expect "a second citation counts as a retag" 0 "Same text, different source" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-retag.md"
expect "the retag names both sources" 0 "Settled Q1, Grounding fact 2" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/spec-retag.md"
expect "missing file is not a pass" 2 "no such file" -- \
  bash "$DIFF" "$WORK/spec.md" "$WORK/nope.md"

echo
echo "── check-critique.sh ─────────────────────────────────────────"

cat > "$WORK/c1.txt" <<'EOF'
VERDICT: fix-first
CONFIDENCE: high — every check ran against text in the packet
BLIND SPOT: cannot confirm the file format without reading source

BLOCKING
- B1 [completeness] SC-001 — no number that would prove it
  QUOTE: "resumes within 2 seconds"
  WHY: no settled answer gives that budget
  FIX: cite the settled answer, or mark it [NEEDS CLARIFICATION]
- B2 [consistency] FR-002 — contradicts the chosen strategy
  QUOTE: "at most 5 times over 24 hours"
  WHY: strategy B sweeps on a timer
  FIX: state the interaction with the sweep interval
EOF
cat > "$WORK/c2.txt" <<'EOF'
VERDICT: ship
CONFIDENCE: moderate — one check depended on a summarised section
BLIND SPOT: same as pass 1

RECONCILIATION
- B1 fixed
- B2 not fixed — the sweep interval is still unstated
EOF

expect "a well-formed first pass validates" 0 "CRITIQUE OK" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1.txt" --single
expect "reconciliation accounts for every id" 0 "accounts for all 2" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1.txt" "$WORK/c2.txt"
expect "unresolved findings are reported, not hidden" 0 "ship unresolved" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1.txt" "$WORK/c2.txt"

grep -v 'B2' "$WORK/c2.txt" > "$WORK/c2-dropped.txt"
expect "a dropped finding is caught" 1 "does not account for B2" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1.txt" "$WORK/c2-dropped.txt"

grep -v 'FIX:' "$WORK/c1.txt" > "$WORK/c1-nofix.txt"
expect "a finding with no FIX is caught" 1 "no FIX:" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1-nofix.txt" --single

cat > "$WORK/c-stamp.txt" <<'EOF'
VERDICT: ship
CONFIDENCE: high — everything checked out
BLIND SPOT: none
EOF
expect "a rubber stamp is caught" 1 "CHECKED AND SOUND" -- \
  bash "$HERE/check-critique.sh" "$WORK/c-stamp.txt" --single

# --- severity is the section, not the id prefix ---------------------------
# Three parallel lenses MUST use distinct id prefixes or their ids collide, and
# every scheme that disambiguated them was invisible to a `B\d+` parser: two
# real blocking findings read as zero, and pass 2 then "accounted for all 0".
sed -e 's/- B1 /- BC1 /' -e 's/- B2 /- BC1f /' "$WORK/c1.txt" > "$WORK/c1-lens.txt"
expect "per-lens id prefixes are seen" 0 "2 blocking" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1-lens.txt" --single

sed -e 's/- B1 fixed/- BC1 fixed/' -e 's/- B2 not fixed/- BC1f not fixed/' \
  "$WORK/c2.txt" > "$WORK/c2-lens.txt"
expect "per-lens ids reconcile across passes" 0 "accounts for all 2" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1-lens.txt" "$WORK/c2-lens.txt"
grep -v 'BC1f' "$WORK/c2-lens.txt" > "$WORK/c2-lens-dropped.txt"
expect "a dropped per-lens finding is still caught" 1 "does not account for BC1f" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1-lens.txt" "$WORK/c2-lens-dropped.txt"

# A reconciliation is dispositions, not findings — counting them as
# unclassified would report a problem in every well-formed second pass.
expect "a reconciliation is not read as unclassified findings" 0 "CRITIQUE OK" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1.txt" "$WORK/c2.txt"

# A finding under no severity heading cannot be classified, and one this script
# cannot see ships as resolved.
sed '/^BLOCKING$/d' "$WORK/c1.txt" > "$WORK/c1-nosection.txt"
expect "findings under no severity heading are caught" 1 "no BLOCKING or ADVISORY heading" -- \
  bash "$HERE/check-critique.sh" "$WORK/c1-nosection.txt" --single

echo
echo "── check-plan.sh ─────────────────────────────────────────────"

PLAN_CHECK="$HERE/check-plan.sh"
PROGRESS="$HERE/make-progress.sh"

# The plan fixture is the skeleton the plugin documents in plan-template.md.
# Testing against the shipped example is what stops the format and its checker
# drifting apart — the same stance taken with the design record above.
# A real plan lives in a repository, and the hook has no --repo-root to pass —
# it discovers this the same way check-plan.sh does.
mkdir -p "$WORK/.git" "$WORK/plan/tasks" "$WORK/cmd/ingest"
: > "$WORK/cmd/ingest/state.go"
: > "$WORK/cmd/ingest/replay.go"

python3 - "$REFS/plan-template.md" "$WORK/plan/plan.md" "$WORK/plan/tasks/T01.md" <<'PY'
import re,sys
src=open(sys.argv[1]).read()
for fence,dest in (('plan-skeleton',sys.argv[2]),('task-skeleton',sys.argv[3])):
    m=re.search(rf'```{fence}\n(.*?)\n```', src, re.S)
    if not m:
        sys.stderr.write(f"no ```{fence} block in plan-template.md\n"); sys.exit(2)
    open(dest,'w').write(m.group(1)+"\n")
PY
[ -s "$WORK/plan/plan.md" ] || { echo "FAIL  could not extract the plan skeleton"; exit 2; }
[ -s "$WORK/plan/tasks/T01.md" ] || { echo "FAIL  could not extract the task skeleton"; exit 2; }

# T02-T04 complete the graph the shipped plan skeleton declares. T01 is the
# format under test; these three exist so the backwards coverage check has a
# whole plan to run against.
cat > "$WORK/plan/tasks/T02.md" <<'EOF'
# T02 — Resume from the checkpoint on start

Covers: FR-001, SC-001
Depends on: T01
Milestone: M1
Status: Planned
Touches: cmd/ingest/replay.go

## Goal

An interrupted import continues from the row the checkpoint names.

## Why now

Completes M1: with T01's state on disk, this is the behaviour a user sees.

## Action items

- [ ] Read the checkpoint on startup instead of starting at row 0
- [ ] Skip rows the checkpoint marks as ingested

## Done when

- FR-001  Given a checkpoint exists, when the importer starts, then it resumes from it.
- SC-001  An import interrupted at row 10000 resumes within 2 seconds.

## Notes

## Execution summary
EOF

cat > "$WORK/plan/tasks/T03.md" <<'EOF'
# T03 — Enforce the attempt ceiling

Covers: FR-002
Depends on: T01
Milestone: M2
Status: Planned
Touches: cmd/ingest/state.go

## Goal

A row stops being retried once it has been attempted 5 times.

## Why now

First task of M2, and the reject file in T04 has nothing to write without it.

## Action items

- [ ] Compare the attempt count against the ceiling before scheduling a retry

## Done when

- FR-002  Given 5 attempts have been made, when a 6th is due, then the row is rejected.

## Notes

## Execution summary
EOF

cat > "$WORK/plan/tasks/T04.md" <<'EOF'
# T04 — Write rejected rows to the reject file

Covers: SC-002
Depends on: T03
Milestone: M2
Status: Planned
Touches: cmd/ingest/replay.go

## Goal

A row that exhausted its attempts appears in the reject file with its line number.

## Why now

Completes M2 — the operator-visible half of the ceiling.

## Action items

- [ ] Append the row and its line number to the reject file on exhaustion

## Done when

- SC-002  A row that has failed 5 times appears in the reject file with its line number.

## Notes

## Execution summary
EOF

expect "make-progress.sh generates the task graph" 0 "4 task" -- \
  bash "$PROGRESS" "$WORK/plan"

expect "shipped plan skeleton passes" 0 "PLAN OK" -- \
  bash "$PLAN_CHECK" "$WORK/plan" --spec "$WORK/spec.md" --repo-root "$WORK"

expect "refuses to run without the spec" 2 "--spec is required" -- \
  bash "$PLAN_CHECK" "$WORK/plan"

expect "unreadable spec is not a pass" 2 "not found" -- \
  bash "$PLAN_CHECK" "$WORK/plan" --spec "$WORK/nope.md"

# pmut <name> <sed-expr> <file-within-plan> — one mutation, on its own copy.
pmut() {
  rm -rf "$WORK/p-$1"; cp -R "$WORK/plan" "$WORK/p-$1"
  sed -i.bak "$2" "$WORK/p-$1/$3" && rm -f "$WORK/p-$1/$3.bak"
}
pcheck() { bash "$PLAN_CHECK" "$WORK/p-$1" --spec "${2:-$WORK/spec.md}" --repo-root "$WORK"; }

pmut fake-cov 's/^Covers: FR-003$/Covers: FR-042/' tasks/T01.md
expect "fabricated Covers identifier is caught" 1 "fabricated citation" -- pcheck fake-cov

pmut orphan 's/^Covers: SC-002$/Covers: FR-003/' tasks/T04.md
expect "requirement no task covers is caught" 1 "no task covers" -- pcheck orphan

pmut restated 's/^- FR-002  Given 5 attempts.*$/- FR-002  Attempts are capped correctly./' tasks/T03.md
expect "restated done-condition is caught" 1 "not in the spec" -- pcheck restated

pmut ghostdep 's/^Depends on: T01$/Depends on: T09/' tasks/T02.md
expect "dependency on a task with no file is caught" 1 "has no task file" -- pcheck ghostdep

pmut cycle 's/^Depends on: —$/Depends on: T04/' tasks/T01.md
expect "dependency cycle is caught" 1 "dependency cycle" -- pcheck cycle

pmut ghostpath 's|^Touches: cmd/ingest/state.go:31$|Touches: cmd/ingest/invented.go|' tasks/T01.md
expect "Touches path that does not exist is caught" 1 "does not exist" -- pcheck ghostpath

pmut badstatus 's/^Status: Planned$/Status: Nearly/' tasks/T01.md
expect "illegal task status is caught" 1 "is not one of" -- pcheck badstatus

pmut adjective 's/^- \[ \] Write it whenever a retry is scheduled$/- [ ] Write it quickly whenever a retry is scheduled/' tasks/T01.md
expect "unquantified adjective in an action item is caught" 1 "unquantified adjective" -- pcheck adjective

pmut blockedbare 's/^Status: Planned$/Status: Blocked/' tasks/T03.md
expect "Blocked task with no Blocked by is caught" 1 "Blocked by" -- pcheck blockedbare

pmut nocost 's/ — \*\*Reversing:\*\* a migration of every checkpoint written since M1\./\./' plan.md
expect "plan assumption with no reversal cost is caught" 1 "reversal cost" -- pcheck nocost

pmut untagged 's/^Covers: FR-003$/Covers: —/' tasks/T01.md
expect "task covering nothing and unlabelled is caught" 1 "Enabling work" -- pcheck untagged

pmut noreason 's|^- _nothing — every requirement and criterion is covered by a task_$|- FR-003|' plan.md
expect "not-planned entry with no reason is caught" 1 "no reason" -- pcheck noreason

pmut ghostseam 's|^- cmd/ingest/replay.go |- cmd/ingest/invented.go |' plan.md
expect "seam path that does not exist is caught" 1 "does not exist" -- pcheck ghostseam

pmut ghostms 's/^Milestone: M2$/Milestone: M9/' tasks/T03.md
expect "task in an undeclared milestone is caught" 1 "does not declare" -- pcheck ghostms

# The table is generated. A hand-edited status is a second copy, and a second
# copy is what falls behind — the failure make-progress.sh exists to prevent.
pmut stale 's/^Status: Planned$/Status: Done/' tasks/T02.md
expect "task graph that has fallen behind its task files is caught" 1 "fallen behind" -- pcheck stale
expect "make-progress.sh --check reports the same staleness" 1 "stale task graph" -- \
  bash "$PROGRESS" "$WORK/p-stale" --check
expect "make-progress.sh brings it current" 0 "wrote" -- bash "$PROGRESS" "$WORK/p-stale"
expect "regenerated plan passes" 0 "PLAN OK" -- pcheck stale

# A plan that adds a file names a path that does not exist yet. Making that
# sayable keeps the existence check strict everywhere else, where it catches an
# invented seam.
pmut newfile 's|^Touches: cmd/ingest/state.go:31$|Touches: cmd/ingest/retry.go (new)|' tasks/T01.md
expect "a path marked (new) is not required to exist" 0 "PLAN OK" -- pcheck newfile
pmut newfile-bare 's|^Touches: cmd/ingest/state.go:31$|Touches: cmd/ingest/retry.go|' tasks/T01.md
expect "the same path unmarked is still caught" 1 "does not exist" -- pcheck newfile-bare

# A row for a task file not yet written is an assertion about absence, so it
# belongs at the gate. A hook firing here would punish drafting plan.md first.
rm -rf "$WORK/p-mapfirst"; mkdir -p "$WORK/p-mapfirst/tasks"
cp "$WORK/plan/plan.md" "$WORK/p-mapfirst/plan.md"
cp "$WORK/plan/tasks/T01.md" "$WORK/p-mapfirst/tasks/T01.md"
expect "closed-world allows a map drafted before its tasks" 0 "PLAN OK" -- \
  bash "$PLAN_CHECK" "$WORK/p-mapfirst" --spec "$WORK/spec.md" --repo-root "$WORK" --closed-world
expect "the gate still catches the tasks that were never written" 1 "has no task file" -- \
  bash "$PLAN_CHECK" "$WORK/p-mapfirst" --spec "$WORK/spec.md" --repo-root "$WORK"

# A traceback exits 1, exactly as a finding list does. Without a trailer check
# a parser bug reads as "N problems found" — a checker that never reached a
# verdict reporting one.
sed 's|^spec = Spec.load(specpath)$|spec = Spec.load(specpath); raise RuntimeError("boom")|' \
  "$PLAN_CHECK" > "$WORK/check-plan-crash.sh"
expect "a crashed checker does not read as findings" 2 "did not reach a verdict" -- \
  bash "$WORK/check-plan-crash.sh" "$WORK/plan" --spec "$WORK/spec.md" --repo-root "$WORK"

# R20: a marker the spec carries and the plan drops is a question answered by
# stealth, which is the whole reason deferral is bounded in the interview.
sed 's|^- Per-source retry overrides.$|- [NEEDS CLARIFICATION: per-source retry overrides — decided post-launch]|' \
    "$WORK/spec.md" > "$WORK/spec-marked.md"
expect "open marker the plan drops is caught" 1 "open question the plan does not" -- \
  pcheck stale "$WORK/spec-marked.md"

# Closed-world: a plan mid-write is legitimately incomplete, and a checker that
# calls that broken teaches evasion rather than compliance.
rm -rf "$WORK/p-partial"; mkdir -p "$WORK/p-partial/tasks"
cp "$WORK/plan/tasks/T01.md" "$WORK/p-partial/tasks/T01.md"
expect "closed-world is silent on a plan with no plan.md yet" 0 "PLAN OK" -- \
  bash "$PLAN_CHECK" "$WORK/p-partial" --spec "$WORK/spec.md" --repo-root "$WORK" --closed-world
expect "open-world fails on the same partial plan" 1 "no plan.md" -- \
  bash "$PLAN_CHECK" "$WORK/p-partial" --spec "$WORK/spec.md" --repo-root "$WORK"

sed -i.bak 's/^Covers: FR-003$/Covers: FR-042/' "$WORK/p-partial/tasks/T01.md"
rm -f "$WORK/p-partial/tasks/T01.md.bak"
expect "closed-world still fires on a fabricated Covers tag" 1 "fabricated citation" -- \
  bash "$PLAN_CHECK" "$WORK/p-partial" --spec "$WORK/spec.md" --repo-root "$WORK" --closed-world

# --- the hook, on plan files ----------------------------------------------
mkdir -p "$WORK/docs/specs/plan/tasks"
cp "$WORK/spec.md" "$WORK/docs/specs/spec.md"
cp "$WORK/plan/plan.md" "$WORK/docs/specs/plan/plan.md"
cp "$WORK"/plan/tasks/T0*.md "$WORK/docs/specs/plan/tasks/"
expect "hook is silent on a complete plan" 0 "" -- hookrun "$WORK/docs/specs/plan/plan.md"
expect "hook is silent on a valid task file" 0 "" -- hookrun "$WORK/docs/specs/plan/tasks/T01.md"
sed -i.bak 's/^Covers: FR-003$/Covers: FR-042/' "$WORK/docs/specs/plan/tasks/T01.md"
rm -f "$WORK/docs/specs/plan/tasks/T01.md.bak"
expect "hook fires on a fabricated Covers tag" 2 "fabricated citation" -- \
  hookrun "$WORK/docs/specs/plan/tasks/T01.md"

echo
echo "── make-plan-packet.sh ───────────────────────────────────────"

PPACKET="$HERE/make-plan-packet.sh"
ppacket() { bash "$PPACKET" "${1:-$WORK/plan}" --spec "$WORK/spec.md" --tree "$WORK/tree.md" "${@:2}"; }

expect "packet carries what the spec asked for" 0 "FR-001  The importer resumes" -- ppacket
expect "packet carries the priorities the milestones rest on" 0 "P1 · Resume an interrupted import" -- ppacket
expect "packet carries each task with what it covers" 0 "Covers: FR-003" -- ppacket
expect "packet carries the quoted done-conditions" 0 "Given a retry is scheduled" -- ppacket
expect "packet carries the plan assumptions with their cost" 0 "Reversing" -- ppacket
expect "packet carries the principles verbatim" 0 "smallest reasonable change" -- ppacket
expect "packet carries the chosen strategy the ordering assumes" 0 "sweep the checkpoint" -- ppacket
expect "packet inlines the rubric" 0 "anti-rubber-stamp" -- ppacket

# An empty section must say it is empty, and this one must say *why* an empty
# one is suspicious: the spec names no type or library by design, so a plan with
# no assumptions has invisible ones rather than none.
rm -rf "$WORK/p-noasm"; cp -R "$WORK/plan" "$WORK/p-noasm"
sed -i.bak 's|^- The attempt counter is a field.*$|- _none_|; /^  sidecar file\. \*\*Reversing:\*\*/d' \
  "$WORK/p-noasm/plan.md" && rm -f "$WORK/p-noasm/plan.md.bak"
expect "an empty assumptions section says why that is suspicious" 0 "invisible rather than absent" -- \
  ppacket "$WORK/p-noasm"

# Three parallel lenses all numbering findings B1 cannot be reconciled per id.
expect "a lens packet assigns that lens its own id prefix" 0 "\`BH1\`" -- \
  ppacket "$WORK/plan" --lens honesty
if ppacket "$WORK/plan" --lens honesty | grep -q "Lens 1 — Coverage"; then
  echo "FAIL  a lens packet carries another lens's rubric — duplicated judgement wastes the pass"
  fail=$((fail+1))
else
  echo "ok    a lens packet carries only its own lens"
  pass=$((pass+1))
fi

expect "refuses to build a packet without the spec" 2 "--spec is required" -- \
  bash "$PPACKET" "$WORK/plan" --tree "$WORK/tree.md"
expect "refuses to build a packet without the record" 2 "--tree is required" -- \
  bash "$PPACKET" "$WORK/plan" --spec "$WORK/spec.md"

echo
echo "── shared constants agree ────────────────────────────────────"

# bump-protocol.sh writes the round cap and the guard line; check-tree.sh
# validates both. Two copies of that arithmetic is how the guard came to trip on
# `--deep`'s own mandate in one script while the other called the record fine,
# so the constants live in record.py and nowhere else.
dupes=$(grep -lE "'fast': ?[0-9]+, ?'default': ?[0-9]+, ?'deep': ?[0-9]+|references loaded'," \
        "$HERE/bump-protocol.sh" "$HERE/check-tree.sh" "$HERE/check-spec.sh" 2>/dev/null | wc -l | tr -d ' ')
if [ "$dupes" -eq 0 ] && grep -q "ROUND_CAP = {'fast': 1, 'default': 4, 'deep': 5}" "$HERE/lib/record.py" \
   && grep -q "def thresholds" "$HERE/lib/record.py"; then
  echo "ok    round cap and guard thresholds live only in record.py"
  pass=$((pass+1))
else
  echo "FAIL  round cap or guard thresholds have been copied back out of record.py"
  echo "      expected: ROUND_CAP and thresholds() defined in lib/record.py, and"
  echo "      no second copy in bump-protocol.sh, check-tree.sh or check-spec.sh"
  echo "      (found $dupes script(s) carrying their own copy)"
  fail=$((fail+1))
fi

# Every tool that reads tree.md reads it through record.py. A private tag parser
# is how the same first-match-only bug shipped in two scripts at once.
if grep -q 'from record import' "$HERE/check-spec.sh" \
   && grep -q 'from record import' "$HERE/check-tree.sh" \
   && grep -q 'from record import' "$HERE/make-traceability.sh" \
   && grep -q 'from record import' "$HERE/check-plan.sh" \
   && grep -q 'from record import' "$HERE/make-plan-packet.sh" \
   && grep -q 'from record import' "$HERE/make-progress.sh"; then
  echo "ok    every checker parses the record and the plan through lib/record.py"
  pass=$((pass+1))
else
  echo "FAIL  a checker has grown its own copy of the record parser"
  fail=$((fail+1))
fi

echo
echo "── skill frontmatter ─────────────────────────────────────────"

# Malformed frontmatter loads the skill with EMPTY metadata rather than failing,
# so a broken description is invisible until nobody can find the skill.
if python3 "$HERE/lib/check_frontmatter.py" "$HERE/../skills"; then
  pass=$((pass+1))
else
  fail=$((fail+1))
fi

echo
echo "── scripts a skill names are scripts it may run ──────────────"

# A skill that instructs `bash .../bump-protocol.sh` without granting it stops
# mid-round for a permission prompt — on the step R7 says comes before anything
# else. The grant and the instruction are two lists that must not drift.
grant_drift() {
  python3 - "$HERE/../skills" <<'PY'
import re, sys, os, glob
bad = 0
for path in sorted(glob.glob(os.path.join(sys.argv[1], '*', 'SKILL.md'))):
    name = os.path.basename(os.path.dirname(path))
    text = open(path).read()
    fm = text.split('---', 2)[1] if text.startswith('---') else ''
    granted = set(re.findall(r'Bash\(bash \$\{CLAUDE_PLUGIN_ROOT\}/scripts/([\w.-]+\.sh)', fm))
    body = text.split('---', 2)[2] if text.startswith('---') else text
    used = set(re.findall(r'\$\{CLAUDE_PLUGIN_ROOT\}/scripts/([\w.-]+\.sh)', body))
    missing = sorted(used - granted)
    unused = sorted(granted - used)
    if missing:
        print(f"FAIL  {name}: names {', '.join(missing)} but does not grant it in allowed-tools")
        bad += 1
    if unused:
        print(f"FAIL  {name}: grants {', '.join(unused)} but never names it — "
              f"a permission no instruction can reach")
        print(f"      expected: a row in the skill's Scripts table, or drop the grant")
        bad += 1
    if not missing and not unused:
        print(f"ok    {name}: grants exactly the {len(used)} script(s) it names")
sys.exit(1 if bad else 0)
PY
}
if grant_drift; then pass=$((pass+1)); else fail=$((fail+1)); fi

echo
echo "── rule-table drift ──────────────────────────────────────────"

# All three skills reproduce R1–R17 verbatim on purpose, so one numbering means
# one rule everywhere. Nothing enforced that they stayed identical, which is the
# actual risk in three copies — not the copies themselves.
rule_drift() {
  python3 - "$REFS/rules.md" "$HERE/../skills" <<'PY'
import re,sys,os,glob
canon={}
for m in re.finditer(r'^\| \*\*(R\d+)\*\* \| (.*?) \|\s*$', open(sys.argv[1]).read(), re.M):
    canon[m.group(1)]=m.group(2)
if len(canon)!=21:
    print(f"FAIL  rules.md defines {len(canon)} rules, expected 21"); sys.exit(1)
bad=0
for path in sorted(glob.glob(os.path.join(sys.argv[2],'*','SKILL.md'))):
    name=os.path.basename(os.path.dirname(path))
    got={m.group(1):m.group(2) for m in
         re.finditer(r'^\| \*\*(R\d+)\*\* \| (.*?) \|\s*$', open(path).read(), re.M)}
    if not got:
        print(f"FAIL  {name}: no rule table found"); bad+=1; continue
    for rid,text in sorted(got.items(), key=lambda kv:int(kv[0][1:])):
        if rid not in canon:
            print(f"FAIL  {name}: {rid} is not in rules.md"); bad+=1
        elif text!=canon[rid]:
            print(f"FAIL  {name}: {rid} has drifted from rules.md")
            print(f"      canonical: {canon[rid][:72]}…")
            print(f"      in skill:  {text[:72]}…")
            bad+=1
    missing=[r for r in canon if r not in got]
    if missing:
        print(f"FAIL  {name}: missing {', '.join(sorted(missing, key=lambda r:int(r[1:])))}"); bad+=1
    else:
        print(f"ok    {name}: all 21 rules byte-identical to rules.md")
sys.exit(1 if bad else 0)
PY
}
if rule_drift; then pass=$((pass+1)); else fail=$((fail+1)); fi

echo
echo "─────────────────────────────────────────────────────────────"
if [ "$fail" -eq 0 ]; then
  echo "ALL $pass CHECKS BEHAVE AS DOCUMENTED"
  exit 0
fi
echo "$fail of $((pass+fail)) assertions failed"
exit 1
