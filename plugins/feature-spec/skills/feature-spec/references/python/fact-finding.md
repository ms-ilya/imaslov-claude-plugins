# Python layer: what to ground in

**Loaded only when the stack detects as Python.** On any other repo this file is
never read and none of its vocabulary appears anywhere — no questions about
session lifetime in a Swift app, no `asyncio` in a React spec.

This layer shapes **what grounding goes looking for**, so it is loaded before the
fact-finders are dispatched, never after. It adds no rules of its own about how
code should be written; it names the things that, on this stack, are cheaper to
look up than to ask about.

Every answer is a **fact with a citation** — "`get_session` is a FastAPI
dependency yielding a `Session` per request, at `app/deps.py:22`". "It uses
SQLAlchemy" is a summary of a fact, not one, and the interview cannot build on it.

## Contents

- [What to look up first](#what-to-look-up-first) — seven questions, each an interview slot saved
- [Sync or async decides the interview](#sync-or-async-decides-the-interview) · [Boundary facts](#boundary-facts-worth-one-lookup)
- [How to ask for these](#how-to-ask-for-these) · [What this layer must not do](#what-this-layer-must-not-do) · [Dormancy](#dormancy)

## What to look up first

Each collapses a question that would otherwise cost an interview slot.

### 1. What kind of program is this?

**Look for:** a web framework (FastAPI, Django, Flask), a task queue (Celery, RQ,
Dramatiq), a CLI entry point (`console_scripts`, Typer, Click, `argparse`), a
library with no entry point, or a notebook-and-scripts data project.

**Why it earns a slot:** it decides what "the interface" even means, which is a
whole coverage category. On a library the surface is the public API and its
compatibility promise; on a CLI it is flags, stdout versus stderr and exit codes;
on a worker it is the message contract and what happens on redelivery.

### 2. Is the feature's code path sync or async?

**Look for:** `async def` in the neighbours, an ASGI versus WSGI server, `asyncio`
/`anyio`/`trio` imports, or a thread pool.

**Why it earns a slot:** the highest-blast-radius fact on the stack. A blocking
call on an async path stalls the whole event loop, and an async library is
unusable from a sync path without a bridge somebody has to build. Report which
one the **feature's own path** is, not what the project mostly does.

### 3. What owns the unit of work?

**Look for:** a database session or transaction scope, a request context, a
`with` block, a Celery task boundary, or an explicit `commit()`.

**Why it earns a slot:** it decides what "the operation failed" means. A feature
whose writes span two transactions has a partial-failure state that the spec must
describe, and that is a requirement the moment it is known.

### 4. What persists, and where?

**Look for:** an ORM and its migration directory (Alembic, Django migrations), raw
SQL, an object store, a cache, or files on disk.

**Why it earns a slot:** it decides whether the feature needs a migration, whether
that migration is reversible, and what runs during it. A spec that implies a
schema change without saying so is a spec that surprises whoever deploys it.

### 5. How is configuration supplied?

**Look for:** environment variables, Pydantic `Settings`, a `.env`, `django.conf`,
or hard-coded constants.

**Why it earns a slot:** it decides whether "make it configurable" is a line of
code or a deployment change, and it is the single most common thing a spec assumes
without checking.

### 6. What is the validation boundary?

**Look for:** Pydantic models, dataclasses, attrs, marshmallow, TypedDict, or
manual checks at the edges.

**Why it earns a slot:** type hints are not enforced at runtime. Where a repo
already validates untrusted input, the spec cites that boundary; where it does
not, "what happens on a malformed payload" is a real open question and belongs in
Failure & edge cases.

### 7. What does the packaging say?

**Look for:** `pyproject.toml` — the supported Python versions, the dependency
pins, and whether a type checker runs in CI.

**Why it earns a slot:** the version floor decides what syntax is available
(`match`, `|` unions, `ExceptionGroup`), and whether a type checker runs decides
whether "the types enforce it" is a verification answer or wishful thinking.

## Sync or async decides the interview

Fact 2 reorganises the rest, so it is worth stating plainly once grounding
returns it.

| If the path is | Then these collapse | And these become real |
|---|---|---|
| **Sync** | event-loop blocking, cancellation semantics, async context propagation | thread safety if a pool is involved, and whether a long call needs a timeout the framework does not give it |
| **Async** | most thread-safety questions | what blocks the loop, what happens on `CancelledError`, whether the library used is actually async or a sync one in a wrapper |
| **Both, bridged** | nothing | **all of the above, plus who owns the bridge** and what happens when it is saturated |

The third row is the expensive one, and worth identifying early.

## Boundary facts worth one lookup

Three specifics that change what a spec can promise:

| Look for | It decides |
|---|---|
| Existing retry or idempotency handling on the feature's path | Whether "at-least-once" is already survivable or a new requirement |
| How errors currently surface — exception types, a result object, logging | Whether the spec can say "raises `X`" or must define a new failure surface |
| Whether the operation is already idempotent | Whether redelivery is a non-event or a data-corruption path the spec must close |

## How to ask for these

Give the fact-finder the questions above **verbatim and numbered**, plus the
scope path. Ask for the nearest instance to the feature, not a survey — "which
session does `create_order` run inside, and where is it opened" beats "describe
the database layer", which returns an essay nobody can cite.

When the repo is inconsistent, the inconsistency **is** the answer: say the
convention is mixed and cite two examples.

## What this layer must not do

- **No opinions about the framework, the ORM or the packaging tool.** Whatever
  the repo uses is what the spec names.
- **No requirement to adopt type hints, a validator or a migration tool.** If the
  repo does not use one and the feature does not need it, the spec says so. An
  invented migration is out of scope for a spec.
- **No coverage or performance targets** that nobody measures — a number that
  proves nothing is exactly what the measurable-criterion rule forbids.

## Dormancy

On a repo with no `.py` sources, `pyproject.toml` or `requirements.txt` in the
feature's scope, this file is never loaded and the interview proceeds with generic
questions — with no apology for their absence.
