---
id: ADR-007
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-007: Active Hunt State, Cross-Feature Read Access and Durability

Status: **Accepted**  
Date: 2026-08-31

Answers open question D-16. Delegated to the implementing agent by the architect
on 2026-08-31, with one constraint set by the product owner: **a hunt must
survive an app restart.**

## Context

E-43 decided that the solo hunt runs on the **map**. The map screen belongs to
`discovery`; the state of a running hunt belongs to `challenges`: which station
is current, how far away it is, how many hints were bought.

This is the fifth cross-feature edge. The four existing ones are
`discovery → facts`, `facts → discovery`, `puzzles → facts` and, since step 34,
`challenges → facts`. Rule 10 of the dependency rules requires a public domain
or application contract for such an edge, and the architecture check does not
see rule 10; the script says so itself. It stays a review matter.

The behavioural source keeps `activeHunt` one level above the features, in the
app state (`app.jsx:90`), and writes it to local storage on every change
(`:198`). Three screens read it. Faithful to the source would therefore be an
app-level owner, which contradicts the feature order that gives `challenges` the
session state.

**A measurement that changes the shape of the answer:** this project has **no
device persistence at all**. All four existing stores are in-memory only
(`InMemoryFirstLaunchStore`, `InMemoryTourStore`, `InMemoryAudioModeStore`,
`InMemoryLanguagePreferenceStore`), and `pubspec.yaml` declares no persistence
package. The durability constraint therefore does not create a hunt-specific
problem, it forces the first persistence decision, and four existing stores plus
the cached last GPS position (`map_camera_intents.dart`) are waiting for the same
one.

## Decision

**Ownership.** `Challenges` owns the active hunt, including its session state.
Not the app composition, and not `discovery`.

**Read access.** `discovery` reads the hunt through a public, read-only contract
of `challenges`:

- `challenges/domain` defines the read model and the store contract;
- `challenges/application` exposes it as a provider;
- `discovery/presentation` watches that provider.

`discovery` never calls a `challenges` notifier, never imports its widgets, and
never writes hunt state. Advancing a hunt is a command on the owning feature.

**No adapter in the app composition.** An adapter would introduce a third place
that knows the shape of the hunt for a state that already has one owner.
`dependency-rules.md:180-187` says placement follows the consumer, not taste, and
the consumer needs a read model, not an indirection.

**Durability.** The hunt is persisted locally and restored on start. The store
contract lives in `challenges/domain` with an in-memory default, following the
pattern of the four existing stores; the persistent implementation lives in
`challenges/data`.

**The mechanism is a separate, approval-bound step.** Recommended:
`shared_preferences`. It is **already in `pubspec.lock` as a transitive
dependency** of `supabase_flutter`, so promoting it to a direct dependency adds
no new code to the build. A new package is approval-bound under `CLAUDE.md`, so
this ADR records the recommendation and does not perform it.

**This does not decide OD-002.** `open-decisions.md` lists OD-002, "Local
database technology", for offline collection and sync. A key-value preferences
store and an offline database are different problems: one holds a handful of
small session values that may be discarded on a schema change, the other holds
canonical user content that must migrate. Choosing the first must not be read as
having chosen the second, and the hunt store must not grow into a substitute for
it. If a hunt ever needs queries, migrations or conflict resolution, it belongs
to OD-002 and not here.

## Alternatives considered

- **Hunt state in the app composition**, faithful to the source. Rejected: it
  contradicts the feature order and gives a business state to a layer that owns
  no business.
- **A shared application layer outside both features.** The cleanest on paper and
  the most expensive: it moves state out of the only feature that has a reason to
  own it, for one consumer.
- **`discovery` reading `challenges` state directly through its notifier.**
  Forbidden by `domain-map.md` §5.
- **Keeping the hunt in memory only.** Ruled out by the product constraint. Worth
  recording why it matters: a hunt spans a walk through a city, and the app is
  backgrounded and killed by the operating system during exactly that walk.

## Consequences

- Fifth cross-feature edge, with a contract, and reviewable.
- The first persistent store in the project, and the pattern the other four will
  follow.
- Persisted hunt progress is user data on the device. `security.md` §6 still
  forbids precise coordinates in logs; the stored payload stays on the device and
  is not a new sink for personal data.
- A restored hunt can reference a station whose fact no longer exists. Restoring
  must therefore validate against current data instead of trusting the stored
  payload.

## Rules

- `discovery` imports only `challenges/domain` and `challenges/application`.
- Writes to hunt state happen through `challenges`, never from the map screen.
- The store contract is in `challenges/domain`, the persistent implementation in
  `challenges/data`, and the in-memory default stays the test default.
- Restoring validates; an unparsable or stale payload is discarded, not repaired.

## Amendments

### 2026-08-31: the read model carries neither the distance nor a hint count

Two sentences in **Context** above name fields that the implementation
deliberately does not have. Neither is a rule, so nothing here was violated, but
a document that describes a shape the code does not have is worse than a gap.
Both readings are corrected here rather than in the prose above, so that the
change stays visible.

**"how far away it is" is not a field, and must not become one.** Distance is
not a property of a hunt. It is a function of the hunt and the current GPS
fix, and it changes on every location update while the stored hunt does not.
A persisted distance would be wrong one step after it was written. The consumer
computes it from the station coordinates the read model does carry, with
`MapPosition.distanceInMetersTo`, the same way `hunt_start_options.dart`
already does.

**"how many hints were bought" is the wrong quantity, and the source proves
it.** The behavioural source persists coins, not a count: `app.jsx:931` adds up
`hintCostSpent`, and `app.jsx:908-909` subtracts exactly that amount from the
stop reward (`netPoints = max(0, pointsAwarded - hintCost)`). With
`HINT_COSTS = [0, 20, 30]` (`screen-map.jsx:1031`) the mapping from a count to
a cost is **not invertible**: the sums 20 and 30 both mean one hint. A count is
therefore a lossy derivative of the number the reward calculation needs.

The read model is therefore to carry the **spent cost in coins**. A count is
recoverable from it only by accident today, and would stop being recoverable the
moment a fourth cost value is added; see E-51 in `REBUILD_STATUS.md`.

**Decided, not yet implemented, and the document says so on purpose.** The field
in `active_hunt.dart` is still called `purchasedHintCount` and still holds a
count. Changing it also changes a payload key, which is what `payloadVersion`
exists for, and it is the one open follow-up from this amendment. Until it lands,
ADR and code disagree on this single field, and that disagreement is named here
rather than left for a reader to discover.

**What this does not decide.** *Which* hints are unlocked is separate state, and
the read model does not carry it yet. The source cannot serve as a template
here, because it loses that state on every restart while keeping the debt for it
(E-50). Restoring the unlocked hints belongs to the same step as restoring the
route and the chosen puzzle, and `payloadVersion` exists for exactly that
extension. The **contract** does not change when it happens.

### Still open, and blocking full restoration

The difficulty of a hunt has no way across the domain boundary:
`FactPuzzleDifficulty` belongs to `facts`, and gate 6 locks it out of
`challenges/domain`. Until that is decided, a restored hunt cannot know its own
difficulty. Recorded as D-18 in `REBUILD_STATUS.md`, with the three candidate
ways and why none of them is cheap. This ADR does not decide it: it is the same
family as D-9 and touches the gate, not the hunt.

## Review triggers

- A second feature needs write access to a running hunt.
- The group hunt (Phase 6) needs shared state across devices, which is server
  state and not a local store.
- The persistence mechanism is decided differently from the recommendation above.
- A hunt must survive a device change, which makes it server state.
