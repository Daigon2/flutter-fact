---
id: ADR-006
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-006: Puzzles as a Shared Bounded Domain

Status: **Accepted**  
Date: 2026-08-31

Answers open question D-15. Delegated to the implementing agent by the architect
on 2026-08-31 with the instruction to decide it with a clean architecture in
mind.

## Context

The puzzle engine (six puzzle types, evaluation policy, hint levels) has two
consumers: `tours` and `challenges`. It was built in step 27 as
`features/puzzles/` and documented in `lib/features/README.md` as a proposal
awaiting confirmation, because three accepted documents did not name it:
`domain-map.md` §2 (ten domains), `architecture-overview.md` §5 and
`project-structure.md`.

Step 27 shipped without touching those documents because the sheet had no entry
point and its only contract consumer lived inside the same feature. The
dependency from `tours` and `challenges` arrives in step 33 and later, so the
question had to be answered before Phase 5.

Two measurements shaped this decision:

- `puzzles/domain` may not import `facts/domain` (dependency allow-list, gate 6).
  Step 27 therefore holds a second difficulty scale and a second operand value
  object, both textually equal to their originals in `facts`. Measured with a
  throwaway probe: the import from `puzzles/domain` fails the architecture check
  with exit code 1, the same import from `puzzles/application` passes.
- Placing the engine inside `tours` or `challenges` would force the other
  feature to import that feature's internals, which is forbidden by rule 8 of
  the dependency rules.

## Decision

`Puzzles` is an eleventh bounded domain.

`Tours` and `Challenges` may depend on `Puzzles` through its **domain and
application contracts only**. `Puzzles` must not reference `Tours` or
`Challenges`, so the graph stays acyclic.

`library` and `creator` are **not** confirmed by this ADR. They remain proposals
in `lib/features/README.md`. Two reasons: neither has content or a consumer
today, so documenting them would be inventory of things that do not exist; and
the scope of `library` overlaps with `Collection` for the same screen (the PWA
"Wallet"). `collection/presentation/pages/collection_page.dart` already holds a
placeholder for it and `shell_tab.dart` assigns the `wallet` tab to Collection.
That overlap is a product question about what the screen **is**, not an
architecture question about where it goes, and it must be settled before
`library` is built.

**Settled on 2026-08-31 by the owner: one screen. `library` is dropped as a
folder proposal.** In his words, everything goes into the Wallet, that is the
bookshelf holding the collected facts. `Collection` therefore owns that screen,
and the placeholder in `collection_page.dart` is the right place for it rather
than a stand-in for a feature that never arrives.

The coins go to **Profile**, not to the shelf. That follows the domain map
anyway (coins belong to `Progression`), and the owner's own reason stands
without it: the coins are a number that does nothing yet. The coin counter in
the map's top chrome stays; it is a live figure during play, not a second home
for the concept.

`creator` remains a proposal, unchanged. It has a real workflow behind it
(submitting a fact, uploading a photo) and no consumer yet.

## Alternatives considered

- Puzzle engine inside `tours`, `challenges` importing it: forbidden by rule 8.
- Duplicating the engine in both features: forbidden by `domain-map.md` §5,
  "Duplicating canonical entities under multiple features", and it would create
  two canonical evaluation policies for the same six puzzle types.
- Puzzle engine in `core`: forbidden by the global invariant that business
  concepts do not move into `core` for convenience.
- Leaving `puzzles` undocumented and building the dependency anyway: that is the
  drift this ADR exists to end. Three accepted documents would have kept
  describing ten domains while the code had eleven.

## Consequences

- One canonical puzzle engine with two consumers.
- The duplicated difficulty scale and operand value object in `puzzles/domain`
  stay, because gate 6 still forbids the import. They are a known, measured cost
  of the domain boundary, not an oversight.
- `domain-map.md`, `architecture-overview.md` and `project-structure.md` name
  `puzzles` from now on.

## Rules

- `tours` and `challenges` import from `puzzles/domain` and
  `puzzles/application`, never from `puzzles/presentation` or `puzzles/data`.
- `puzzles` never imports `tours` or `challenges`.
- A puzzle reward is a specification owned by the consuming feature; applying it
  belongs to Progression, as with `ChallengeReward`.

## Review triggers

- A third consumer appears that is not a tour or a challenge.
- `puzzles` needs to read state owned by `tours` or `challenges`, which would
  make the graph cyclic.
- Gate 6 gains an allow-list entry that lets domain layers share value objects,
  which would remove the duplication cost recorded above.
