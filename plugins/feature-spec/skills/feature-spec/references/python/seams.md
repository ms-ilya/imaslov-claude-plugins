# Python layer: test seams

**Loaded only on a Python repo.** Carried into drafting through the design record,
so the spec's verification section says something true about *this* codebase
rather than something generic about testing.

Verification is a coverage category, which means a spec nobody can prove was met
is a failure of this plugin specifically. This file exists so that the
verification section names a seam that already exists.

## Contents

- [Which test, at which level](#which-test-at-which-level) · [Seams](#seams)
- [The patching trap](#the-patching-trap) · [The database case](#the-database-case)
- [What gets faked](#what-gets-faked) · [Async and failure in the verification section](#async-and-failure-in-the-verification-section)
- [What this file must not do](#what-this-file-must-not-do)

## Which test, at which level

> **Procedure: put the test at the lowest level where the behaviour is
> observable.** Not the level where it is easiest to write.

| Level | Owns | Stops owning when |
|---|---|---|
| **Unit** | a decision — a pure function, a validator, a state transition, a policy | the assertion needs a database or a running server |
| **Integration** | two components agreeing — a repository and its schema, a handler and its serialiser | the assertion needs the whole app wired up |
| **Contract / API** | one endpoint's promise — this request produces this status and this body | it duplicates a decision already covered above |
| **End-to-end** | a journey through the real system | anything a lower level already proved |

**An API test asserting a computed value is a unit test wearing a costume** — it
starts a server, opens a connection and waits, to settle something a function
could answer directly. Write it once to prove the wiring connects, never to prove
the arithmetic.

## Seams

> **Prefer the highest existing seam. The ideal number of new seams is one, and
> zero is better.**

Four questions, in order:

1. **Is the logic already a pure function?** Call it. Done — no seam needed.
2. **Does the framework already have an override point?** FastAPI
   `dependency_overrides`, Django's `settings`/`override_settings`, a pytest
   fixture the repo already defines. Use it. Done.
3. **Does the callable already take its dependency as an argument or an
   attribute?** Pass a different one.
4. **Only then:** introduce a seam — and introduce exactly one.

A feature that needs three new injection points to be testable has usually been
designed against a testing style rather than against the code that is there.

## The patching trap

`unittest.mock.patch` will substitute anything, anywhere, which is why it is the
seam most often reached for first and the one that should be reached for last.

**Patch where the name is looked up, not where it is defined** — `patch('mymod.
requests.get')`, not `patch('requests.get')` — because `from x import y` binds a
new name at import time. This is the single most common reason a patch silently
does nothing while the test still passes, and it is worth naming in a spec's
verification section when the feature's coverage depends on one.

More importantly: **a patch is a seam that survives no refactor.** It couples the
test to the module's import structure rather than to its behaviour, so renaming a
module breaks tests that were never about that module. Where the repo has a
fixture, an override point or an argument, use it instead.

**`autospec=True` when a mock stands in for a real callable.** Without it a mock
accepts any signature, so a test keeps passing after the real function's arguments
change — which is a test actively concealing a break.

## The database case

Three honest options, and the spec picks one rather than leaving it implied:

| Option | Right when |
|---|---|
| **Real database, transaction rolled back per test** | The repo already has this fixture. Highest fidelity, and usually the highest existing seam. |
| **Real database, truncated between tests** | Behaviour under test involves commits, or code that opens its own transaction. |
| **In-memory or fake repository** | The behaviour under test is a decision, not persistence — and then the decision probably belongs at unit level anyway. |

SQLite standing in for PostgreSQL is a fourth option and it is the one that fails
quietly: the dialects differ on types, constraints and concurrency, so the test
proves something about a database nobody deploys. Where the repo does this, say so
as a limitation rather than as coverage.

## What gets faked

**Fake what you do not own and cannot make deterministic:** third-party HTTP, the
clock, randomness, the filesystem when the test would race, anything charging
money or sending mail.

**Do not fake what you own.** A faked repository that returns what the test wants
proves the test agrees with itself. Point the real one at a test database instead.

**Never fake the thing under test.** Obvious written down, common in practice —
usually as a partially patched object whose un-patched half is the requirement.

**Freeze the clock rather than sleeping.** A test that sleeps is a test that is
slow and still flaky.

## Async and failure in the verification section

Four specifics worth naming in a spec, because each is a real failure this stack
produces and none is covered by "it is tested":

| Name it when | The criterion |
|---|---|
| The path is async | The test runs on the same loop as the code, and a blocking call in the path is a failure the test can detect |
| The work can be cancelled | `CancelledError` leaves no partial write and no leaked connection — the criterion is what the state *is* afterwards |
| The work can be redelivered | Running it twice produces the same end state — a count, not an assurance |
| Failure is expected | The exception type and the state left behind are both named, because "it raises" is not a criterion |

Each is a success criterion with a number, a type or a count in it. That is why
they belong in the spec rather than in a testing guide.

## What this file must not do

- **No opinions about the project's test runner.** Whatever the repo uses is what
  the spec names — it arrives as a grounding fact, not a preference.
- **No requirement that a seam be added.** If the code has no seam and the feature
  does not need one, the spec says the behaviour is covered at the journey level
  and why.
- **No coverage targets.** A percentage is a number that proves nothing, which is
  exactly what the measurable-criterion rule forbids.
