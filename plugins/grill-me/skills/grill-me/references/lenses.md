# ABOUTME: The lenses grill-me uses to find what the user has not thought of — when each pays, how to run it, and what it tends to reveal.

Loaded in step 5 of the default depth. A lens is a way of looking at the task
that produces findings no gap-filling question reaches. Pick the two or three
that fit from the table, then close with the integration check and the readiness
blockers, which are cheap. Running all ten is a checklist, and a checklist is
where question fatigue comes from.

Each finding goes back to the user as a statement with a default they can accept.
It becomes a question only when it passes the three tests in `SKILL.md` step 4.

A lens draws on three kinds of knowledge, and the user has to be able to tell
which one a finding came from:

- **This project.** It carries the `path:line` you opened.
- **This kind of work in general.** Say it as that ("usually", "in most
  projects"), never as a fact about this project.
- **What only the people involved know**: what was tried before, who has to
  agree, what the deadline really is. Ask for it. Do not supply it.

## Choosing lenses

| The task looks like | Start with |
|---|---|
| A solution was requested, the problem was not stated | Premise challenge, goal laddering |
| Rules, validation, permissions, pricing, anything with cases | Example mapping |
| New territory for the user | Blindspot pass, outside view |
| Hard to reverse: migrations, public APIs, data shape, launches | Pre-mortem, riskiest assumption |
| Many answers already collected | Integration check |
| Depends on other people or systems | Readiness blockers, second-order effects |

## Premise challenge

**When it pays:** step 3 already ran the short form. Come back to it when that
check was waved through without a reason, or the answers since have weakened the
case. If the task should not exist, every later question is wasted.

- What happens if this is not done at all?
- What is the smallest version that would still be worth having?
- Is this the problem, or a solution to a problem one step up?

**Reveals:** work that should not be done, a requested solution that does not
serve the real goal, a cheaper route to the same outcome.

## Goal laddering and "why now"

**When it pays:** the goal was given as a feature or a deliverable.

- Ask what finishing this lets someone do that they cannot do today. Repeat on
  the answer, at most three times.
- What prompted this now rather than a month ago?
- What do people do today instead?

**Reveals:** the actual goal, the real deadline driver, the workaround already in
use, which is also the baseline the result has to beat.

## Pre-mortem

**When it pays:** anything hard to undo.

- It is two weeks after this shipped and it was reverted. What is the most likely
  reason?
- What would make a reviewer reject this outright?
- What would you have to do to guarantee this breaks?

**Reveals:** risks the user half-suspects but has not said, fragile dependencies,
missing rollout and rollback steps.

## Riskiest assumption

**When it pays:** the plan rests on something nobody has seen work.

- List what must be true for the approach to work.
- For each: has it been seen, or is it expected?
- Which one, if false, throws the plan away? What is the cheapest check that
  settles it before more planning?

**Reveals:** load-bearing beliefs with no evidence. The output is a spike in the
brief, not a question: the user cannot answer what nobody knows.

## Example mapping

**When it pays:** behaviour depends on rules.

- Give one concrete case where this works, with real values.
- Now one that has to be rejected. What rule separates them?
- Park anything nobody can answer as an open question and keep going.

**Reveals:** missing rules and edge cases. Many rules means several tasks hiding
in one; many parked questions means the task is not ready.

## Blindspot pass

**When it pays:** the territory is new to the user. They said so, or they
answered "don't know" twice. Not for an expert who is merely undecided.

- List the decisions that exist in this territory, the usual choice for each and
  what would make that choice wrong. This part is general knowledge; say so.
- Look for the landmines this project can show you: a convention the code
  follows everywhere, something built and then removed in the history.
- Ask for the ones it cannot show you: what was tried here before, and which
  constraints live in people's heads.
- Say "no significant blindspots" when that is the finding.

**Reveals:** decisions the user did not know they were making.

## Integration check

**When it pays:** before stopping, once several answers are in.

- Put the answers side by side and look for two that cannot both hold.
- Follow each pair to its consequence: "offline-first, and ids assigned by the
  server — what assigns the id offline?"

**Reveals:** conflicts between answers that were each reasonable alone.

## Readiness blockers

**When it pays:** every task, last.

- Is anything stopping a start today that is not in the code: access, an
  environment, a decision that belongs to someone else?
- Who has to say yes to this, and have they?
- What is needed from someone else, and by when?

**Reveals:** the external dependency that turns "ready" into "not ready".

## Outside view

**When it pays:** the plan carries an estimate, or sounds easy.

- What is the most similar thing already done here? How did it go against its
  plan?
- What was the surprise that time?
- Is there something to copy, or is this the first of its kind?

**Reveals:** optimism, recurring traps, prior art the user forgot.

## Second-order effects

**When it pays:** other people or systems consume the result.

- Once this exists, who has to change their code, docs or habits?
- What does it make harder six months from now?
- What will people ask for next because this exists?

**Reveals:** downstream consumers, maintenance cost, follow-on scope that should
shape the design now.
