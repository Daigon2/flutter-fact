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

## Review triggers

- A second feature needs write access to a running hunt.
- The group hunt (Phase 6) needs shared state across devices, which is server
  state and not a local store.
- The persistence mechanism is decided differently from the recommendation above.
- A hunt must survive a device change, which makes it server state.
