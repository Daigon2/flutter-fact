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
  ADR-007's wording, which puts the contract in `challenges/domain`. Worth being
  precise about the cost, because it was technically the cheapest: gate 6 locks
  only the `domain` layer, so `hunt_plan.dart` already imports `facts/domain`
  from `application` today, measured. Option (c) would therefore have solved D-18
  **without any rule change at all.** It was rejected for two reasons, and only
  the first is about ADR-007: it would have left the two verbatim copies in
  `puzzles/domain` standing, so ADR-006's recorded cost would still be unpaid,
  and the silent-divergence risk that forced the decision would still be open.
  A narrower variant, "only `challenges/domain` may import the kernel", has the
  same defect and would need two further single-case grants to fix it, which is
  exactly the maintained exception list the architect ruled out.
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
- **Rule 23 has one enforceable half, and it is the one that matters.** The
  kernel may import almost nothing, and that is checked. "Any layer may import
  the kernel" is a permission, so there is nothing to check on that side. An
  earlier wording here claimed both directions were enforced; see the amendment
  below.
- **A fourth cross-domain sharing question will be cheaper and more dangerous.**
  Cheaper because the mechanism exists, more dangerous for the same reason. The
  four admission rules are the answer to that, and rule 4 is the one that will
  be under pressure.

## Rules

- Every layer may import `package:fact_app/kernel/`, not only Domain. Nothing
  else about gate 6 changes.
- The kernel may import only `dart:`, itself, and vetted pure-Dart packages from
  `_domainAllowedPackages`.
- A type enters the kernel only when the four admission rules above hold, and
  entering means amending this ADR in the same change.
- The kernel holds value objects. Entities, repositories, services and
  application logic stay in their feature.
- A kernel type carries no behaviour that is true for only one of its users.

## Amendments

### 2026-08-31: the `HuntPlan` takeback condition is not met, and one part of it never will be

Found by an independent architecture review on the day this ADR landed, and it is
the most expensive kind of finding this repository knows: a document that reads as
settled where the code is not.

`hunt_plan.dart:14-21` names **four** foreign types that a move to
`challenges/domain` would need: `FactId`, `FactCoordinates`, the puzzle difficulty
and the puzzle itself. This ADR resolves exactly **one** of them,
`PuzzleDifficulty`.

- **`FactCoordinates` stays out** by admission rule 3. It carries `tryFrom`,
  validation of unchecked raw input, which is role-bound behaviour.
- **`FactPuzzle` stays out permanently.** It is an entity, and the kernel admits
  no entities. That exclusion does not hang on D-9 and is not a "not yet": no
  future answer to D-9 lifts it, because it is this ADR's own rule.
- **`FactId` stays out** by admission rule 1, and that is the weakest of the
  three grounds, see the next amendment.

So the move "without field changes", as `hunt_plan.dart` phrases it, is **not
possible**. Moving those types would require replacing an entity with an identity
or a value object, which is a field change by definition. The takeback condition
is therefore one quarter met, and it was wrong to write it as a pending chore.

**Consequence for the next reader:** do not move `HuntPlan` because this ADR
exists. If the move is wanted, it is a redesign of `HuntStop` first, and that is a
question for `challenges`, not for the kernel.

### 2026-08-31: rule 3 will be tested before rule 4, and at that same spot

This ADR predicted that admission rule 4 would come under pressure first. The
review disagreed with a better argument: **rule 3 will break first, and at the
`HuntStop` migration itself.** `HuntStop.position` builds a `MapPosition` from
`fact.coordinates`, so anyone attempting that move needs `FactCoordinates` in the
kernel, and that is precisely the type rule 3 rejects with the D-9 measurement.
The choice at that moment is: leave the move undone forever, or soften rule 3 for
"just the coordinates, without behaviour". The prediction is recorded here so that
whoever stands there recognises it as the predicted moment rather than a new idea.

### 2026-08-31: why `FactId` is out rests on weaker ground than the rest

Stated plainly, because the ADR's own wording hid it. `FactCoordinates` is
excluded by a **structural** property (role-bound behaviour, measured). `FactId`
is excluded because `challenges/application` happens to hold whole `Fact` objects
today, so admission rule 1 is not met. That is a snapshot of the current data
model, not a property of `FactId`, which has no behaviour beyond value equality
and would satisfy rule 3 as trivially as `PuzzleOperand` does.

**It will flip**, and the direction is already visible: `ActiveHunt` carries
station coordinates and a title rather than a `Fact`, because a read model that
holds an entity cannot be persisted. The moment `HuntStop` follows that pattern,
rule 1 is met and `FactId` becomes a candidate on its own merits. That is not a
reason to admit it now, and it is a reason not to cite the current exclusion as
if it were structural.

### 2026-08-31: the "Needed by" table is the only bookkeeping, and it is unguarded

The named cross-feature edges have a diagram in `domain-map.md` §4 and prose that
justifies each one. The kernel has one hand-maintained table in this document.
The review is right that this is the same discretion whose erosion rule 4 already
names as a risk.

**Half of it is machine-checked since this amendment.**
`test/kernel/kernel_admission_test.dart` reads every top-level type declared under
`lib/kernel/` and fails if one of them is missing from the contents table above.
That does not check *whether* a type belongs in the kernel, which stays a review
question, but it does check that nobody adds one **silently**. Rule 4 is now a
gate rather than a ritual: adding a type without amending this ADR turns the
suite red.

### 2026-08-31: "both directions are machine-enforced" was not true, and the rule is wider than written

An independent code review measured it with throwaway probes. Two corrections,
and the second one changes the rule rather than the wording.

**The enforced half is only the kernel's inside.** Probes confirmed that
`lib/kernel/` is sealed against a relative import out of it, against `export`
instead of `import`, and inside subdirectories. There is nothing to enforce on
the other side: "a layer may import the kernel" is a permission, and a permission
has no violation.

**And the permission is wider than this ADR wrote it.** The text said the kernel
is *"the one place a feature domain may reach outside itself"*, which read as
Domain-only. Measured, Application, Presentation and Data import it too, in five
files. That is not drift, it is **necessary**: `Fact.easiestPuzzleDifficulty`
returns a `PuzzleDifficulty`, so a layer that may call a domain API has to be able
to name the types that API returns. A kernel that only Domain could import would
be unusable by anything that consumes a domain.

So the rule is: the kernel sits below every layer, like `dart:core`.
`dependency-rules.md` now says so in the table and in rule 23.

**What this does cost, named rather than dismissed:** a kernel type can appear in
a widget signature without any gate objecting. Today that is harmless, because
both entries are value objects without behaviour. It stops being harmless the day
admission rule 3 slips, which is the pressure this ADR already predicted twice.

### 2026-08-31: two admission rules got a machine check, two did not, and one of those two never will

The same review found that only rule 2 was enforced. Rule 4 now is, see the
amendment above. On the other two, so that the next reader does not look for a
check that is deliberately absent:

- **Rule 1** (two domains genuinely need it) has a cheap approximation and it is
  deliberately not built: comparing the "Needed by" column against the import
  graph would check *that* two domains import the type, which is not the same
  claim. A type can be imported once per domain out of convenience and still fail
  rule 1, and a genuinely needed type can reach a domain indirectly. A check that
  conflates the two would look like a control and be none, which is worse than an
  open review obligation.
- **Rule 3** (no role-bound behaviour) has no honest approximation at all. The
  review proposed flagging every method beyond constructor, `==`, `hashCode`,
  `toString` and one `fromCode`-style factory. That would have rejected
  `PuzzleDifficulty.fromCode` on a bad day and accepted a badly named role-bound
  method on any day. Not built, and this is the reason.

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
  `challenges/domain`. **Read the amendment below before acting on this**: their
  takeback condition is *not* met by this ADR, and one part of it cannot be met
  by any version of this ADR.
