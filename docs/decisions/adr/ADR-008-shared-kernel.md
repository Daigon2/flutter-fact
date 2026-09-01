---
id: ADR-008
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
  - implementation
  - review
---

# ADR-008: A Shared Kernel for Value Objects Two Domains Both Need

Status: **Accepted**
Date: 2026-08-31

Answers open question D-18, and closes the duplication cost that ADR-006
recorded as accepted.

Decided by the architect on 2026-08-31, in these words: *"Shared Kernel
einführen, die vorgegebene Architektur scheint hier zu streng zu sein und nicht
zu passen, wenn wir jetzt schon die zweite Ausnahme brauchen. Bitte das
dementsprechend auflockern, aber nur so viel wie nötig. Dann aber auch die
andere Ausnahme genauso darüber auflösen und in den Architekturentscheidungen
festhalten und verbessern."*

Three instructions sit in that sentence, and the third is the one that is easy to
miss: **improve the architecture, do not drill a hole in it.** An exception
granted case by case would have been the worse version of what was already too
strict.

## Context

Gate 6 lets a feature domain import three things: the Dart SDK, its own feature
domain, and vetted pure-Dart packages. The last list, `_domainAllowedPackages`
in `tool/check_architecture.dart`, has been empty since it was written. The rule
is enforced by machine and has never had a hole.

That strictness has been paid for three times, each time measured with a
throwaway probe rather than assumed:

1. **D-9, three coordinate types.** `FactCoordinates`, `MapPosition` and
   `DevicePosition` hold the same two doubles. Answered on 2026-08-31 with
   *keep the local types*, and the measurement supported it: the three are not
   copies. `DevicePosition` carries a third field, and the other two carry
   role-bound behaviour that does not overlap (validation of raw input versus a
   haversine calculation). **This case is not resolved by this ADR, and must not
   be.** A shared coordinate type would have to unite all three roles, which is
   the classic failure of a shared kernel.
2. **Step 27, two verbatim copies.** `puzzles/domain` cannot import
   `facts/domain`, so `PuzzleDifficulty` and `PuzzleOperand` were written a
   second time, byte-for-byte identical in behaviour to
   `FactPuzzleDifficulty` and `FactPuzzleOperand`. Both files reported
   themselves as copies in their own header and named the condition under which
   they would disappear. ADR-006 recorded the duplication as a *known, measured
   cost of the domain boundary*, and its review triggers name exactly this ADR:
   *"Gate 6 gains an allow-list entry that lets domain layers share value
   objects, which would remove the duplication cost recorded above."*
3. **D-18, a third consumer.** The active hunt contract in `challenges/domain`
   (ADR-007) cannot carry the puzzle difficulty, so a restored hunt cannot know
   its own difficulty. Two real consumers exist in the behavioural source: the
   navigation aids are graded by it, and the pause screen shows it.

Case 3 is what forced the decision, and the reason is not the count. A copy of a
coordinate pair diverges visibly. **An enumeration with meaning can diverge
silently:** if `facts` gains a fourth difficulty and a copy does not, no test
fails, and the two halves of the app disagree about what a puzzle is worth.

The three options put to the architect were all workarounds: copy the
enumeration a third time, carry it as a string in the payload, or move the read
model to `application` against ADR-007's wording. None was chosen.

## Decision

**A shared kernel exists at `lib/kernel/`. Every feature domain may import it.
It may import almost nothing.**

That is the whole loosening: **one** additional permitted import path for domain
layers. No hole in rule 11, no per-case exception, no allow-list that someone
has to maintain.

### What it is not

- **Not `core/`.** The root `CLAUDE.md` invariant stands: *business concepts do
  not move into `core` for convenience*, and rule 11 forbids feature concepts
  there. Kernel contents are business concepts by definition, so they need a
  home of their own with a stricter admission rule, not a relaxed `core`.
- **Not a separate package.** `_domainAllowedPackages` was built for vetted
  pure-Dart packages and would have taken a local path dependency without any
  rule change at all. It was rejected for a measured reason: a path-dependency
  package sits outside `dart analyze` of this package and outside
  `dart format lib test tool`, so the kernel would silently leave gates 1 and 2.
  Buying "no rule change" with "no static analysis" is the wrong trade for the
  most widely shared code in the tree.
- **Not a place for entities.** `FactPuzzle` stays in `facts/domain`, and
  `puzzles/domain` still may not see it. The kernel holds value objects, not
  another feature's entities.

### Admission rules

A type may live in the kernel only if all four hold. Each of them exists because
a shared kernel that grows is worse than the duplication it replaced: every
feature domain carries it as a coupling point.

1. **Two or more feature domains need it, demonstrated in code that exists.**
   Not anticipated, not "we will probably need it". The need is named in the
   type's own header, with the domains listed.
2. **Pure Dart.** No Flutter, no Riverpod, no Supabase, no vendor SDK, and no
   import of `core`, `features`, `map`, `services` or `app`. Machine-enforced as
   rule 23.
3. **No role-bound behaviour.** Behaviour on a kernel type must be true for
   every user of it. This is the lesson of D-9 written as a rule: the moment a
   type would have to carry one domain's validation *and* another domain's
   geometry, it does not belong here.
4. **Every entry is named in this ADR.** Adding one is an amendment to this
   document, not a new file. A kernel whose contents can grow without a
   decision is a dumping ground with a nice name.

### Contents, 2026-08-31

| Type | Needed by | Why it qualifies |
|---|---|---|
| `PuzzleDifficulty` | `facts`, `puzzles`, `challenges` | `fromCode` is true for every user: the raw value comes from the same column in all three. |
| `PuzzleOperand` | `facts`, `puzzles` | Two nullable strings and value equality. No behaviour at all, so rule 3 is trivially met. |

Both replace a pair of duplicates. **The kernel starts by removing more code
than it adds**, and that is the shape a kernel entry should have.

### Deliberately not admitted

- **The three coordinate types from D-9.** Rule 3 rejects them, see Context.
- **`FactId`.** `challenges/application` holds whole `Fact` objects today and
  does not need the identity alone. Rule 1 is not met.
- **A default difficulty.** The kernel would be the most convenient place for
  it and therefore the worst: which fallback applies when a puzzle has no
  difficulty is a reward question owned by `puzzles` and `progression`. A
  default here would hide that decision from all three domains at once.

## Alternatives considered

- **Copy the enumeration a third time** (option (a) as put to the architect).
  Cheapest to build. Rejected because an enumeration with meaning diverges
  without a failing test, and because it would have been the third repetition of
  one open question.
- **Carry the difficulty as a string in the hunt payload** (option (b)). Avoids
  the type instead of solving it: the payload would hold the value, and the
  translation back into an enumeration would land in `presentation`.
- **Move the hunt read model to `application`** (option (c)). Contradicts
  ADR-007's wording, which puts the contract in `challenges/domain`.
- **A local package in `_domainAllowedPackages`.** The mechanism the script
  itself provides. Rejected for the gate-coverage reason above.
- **Relax gate 6 for `core/geo` specifically**, the original D-9 proposal.
  Rejected twice over: it solves the case that measurement showed should not be
  solved, and it puts business concepts in `core` against the root invariant.

## Consequences

- **The duplication cost recorded in ADR-006 is gone.** Two files deleted, and
  the two translation functions in `puzzles/application/puzzle_from_fact_puzzle.dart`
  with them: `_difficulty` and `_operand` were a `switch` and a field copy
  between types that are now one type.
- **`facts` gives up two names.** `FactPuzzleDifficulty` and
  `FactPuzzleOperand` are gone; the kernel names are `PuzzleDifficulty` and
  `PuzzleOperand`. Keeping the `Fact` prefix would have kept the duplication
  with extra steps.
- **D-18 is unblocked but not yet built.** The active hunt can now carry its
  difficulty. It is deliberately not added in the same change: the hint field is
  about to change from a count to indices, both changes raise
  `ActiveHunt.payloadVersion`, and two raises in sequence discard a saved hunt
  twice where one discards it once.
- **Rule 23 is machine-enforced in both directions.** Domains may import the
  kernel; the kernel may import almost nothing. The second half is the one that
  matters over time.
- **A fourth cross-domain sharing question will be cheaper and more dangerous.**
  Cheaper because the mechanism exists, more dangerous for the same reason. The
  four admission rules are the answer to that, and rule 4 is the one that will
  be under pressure.

## Rules

- Every feature domain may import `package:fact_app/kernel/`. Nothing else about
  gate 6 changes.
- The kernel may import only `dart:`, itself, and vetted pure-Dart packages from
  `_domainAllowedPackages`.
- A type enters the kernel only when the four admission rules above hold, and
  entering means amending this ADR in the same change.
- The kernel holds value objects. Entities, repositories, services and
  application logic stay in their feature.
- A kernel type carries no behaviour that is true for only one of its users.

## Review triggers

- A type is proposed for the kernel that fails admission rule 1 or 3, which
  means the pressure is on the boundary and not on the type.
- The kernel grows past a handful of types, which means rule 4 stopped working.
- A kernel type needs a default value or a policy, which means a domain decision
  is being hidden in shared code.
- D-9 is reopened, for instance because a fourth coordinate type appears. The
  answer then is still rule 3, and if rule 3 no longer holds, the measurement
  behind D-9 changed and belongs re-measured first.
- `HuntPlan` and `HuntStop` move from `challenges/application` to
  `challenges/domain`. Their own takeback condition is tied to this decision;
  the move is behaviour-neutral and was deliberately left out of this change.
