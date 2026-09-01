---
id: ADR-009
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
  - implementation
  - review
---

# ADR-009: Group Hunt Synchronization

Status: **Accepted**
Date: 2026-08-31

Follow-up to ADR-007. Answers the review trigger recorded there: *"The group hunt
(Phase 6) needs shared state across devices, which is server state and not a
local store."* Unblocks step 40. Answers open question E-09.

Decided by the architect on 2026-08-31: *"4a passt neben ADR-007. ADR-007 bekommt
einen Zusatz/Follow-up-ADR für Group Hunt Synchronization. Wenn Realtime später
zu teuer wird, können wir den Transport wechseln."*

**The load-bearing part of that answer is the last sentence, not the first.** The
transport is chosen, and it is chosen as replaceable.

## Context

ADR-007 settled the solo hunt: the state belongs to `challenges`, it lives
locally, and it survives a restart. It also said, in its own review triggers,
that a group hunt is a different problem. It is: two devices, one truth, and
neither device may be the one that holds it.

The backend for this already exists and is not ours to design. From the read-only
inventory in `docs/operations/backend-inventory.md`:

- Three tables, `group_sessions`, `group_participants`, `group_collects`, with
  RLS and a `supabase_realtime` publication that names all three.
- Twelve RPCs across the koop and team modes, from `create_group_session` to
  `tag_endpoint`, all `SECURITY DEFINER`, all doing their own authorization.
- The running PWA subscribes to one channel per session, `group:<id>`, with three
  `postgres_changes` handlers (`02_Frontend/app/api.jsx`).

So the question was never *whether* shared state is server state. It was whether
naming Realtime as the transport breaks the contract ADR-007 established.

**It does not, and the reason is worth stating:** ADR-007 is about *where a
hunt's state lives and who may write it*. A group hunt's state lives on the
server, which ADR-007 already anticipated. The two decisions sit side by side and
answer different questions. Nothing in ADR-007 needs to change.

## Decision

**Supabase Realtime is the transport for group hunt state. The contract does not
know that.**

### The contract names events, not channels

`challenges/domain` gets a synchronization contract expressed in the vocabulary
of the hunt: a participant joined, a station was collected, the session started,
the session ended. It does **not** mention `postgres_changes`, channels,
subscriptions, payload shapes or table names. Those live in
`challenges/data`, behind the contract, exactly like `ActiveHuntStore` and its
`KeyValueStore` adapter.

This is the whole point of the architect's last sentence. A contract that names
`postgres_changes` cannot be switched to polling without breaking the contract,
and keeping that switch available was an explicit condition of the decision.

### The client is a subscriber, never an authority

Every state change goes through an RPC and comes back as an event. The client
never writes group state directly, and it never derives a reward from what it
believes about the session. Two standing rules apply here without exception:

- **The client never determines a credited amount** (product owner, 2026-08-31).
- **The client never computes time a reward depends on** (E-19, architect,
  2026-08-31, *"keine Ausnahme von security.md"*). A group session has a
  duration, so this rule bites here directly: the client may show a countdown,
  and the server decides when the session ended and what it was worth.

### Reconnection is part of the contract, not of the transport

A participant whose connection drops is the new failure class this decision
brings in, and it must be visible in the contract rather than handled in the
adapter. The contract carries a connection state, and rejoining is a re-read of
the session followed by a re-subscribe: **the server state is the truth, the
stream is only how it arrives faster.** An adapter that repairs a gap by
guessing would make the two devices disagree, which is precisely what the server
state exists to prevent.

## Alternatives considered

- **Polling at an interval** (option (b) as put to the architect). Simpler,
  slower, cheaper, and no dropped-connection class. Not chosen, but deliberately
  kept reachable: with the contract above it is an adapter swap, not a rewrite.
  Recorded because "we can switch later" is only true if someone wrote down what
  switching means.
- **Realtime named directly in the contract.** What the PWA does. It is one
  layer less, and it is the version that cannot be switched. Rejected by the
  condition attached to the decision.
- **A local store for group state**, in the shape of ADR-007. Rejected by ADR-007
  itself: shared state across devices is server state. A local copy would be a
  second truth on every device.

## Consequences

- **Recurring cost.** Realtime connections are billed per concurrent connection.
  The cost side was explicitly retained by the architect and is not re-decided
  here.
- **A new failure class**, the participant with a dropped connection. It is named
  in the contract, which means tests can reach it.
- **The local store does not grow.** `ActiveHuntStore` stays the solo hunt's
  store. A group hunt is not persisted locally, and OD-002 is not touched: the
  architect's answer on 2026-08-31 was to avoid choosing a database because a few
  session values need persisting.
- **Step 40 inherits three open backend findings.** They are in
  `REBUILD_STATUS.md` and they are not client bugs, but a client built against
  them will look broken:
  - **E-21:** `start_group_session` is defined twice, in the koop migration and
    again in the team migration. Which version runs depends on the order someone
    pasted the files into the SQL editor.
  - **E-54:** `collect_group_fact` credits 50 coins per session and fact, and the
    client supplies both the fact pool and, in team mode, the meeting point. The
    loop is repeatable from one spot.
  - **E-57:** the team route balancer compares two permutations of the same set,
    so its difference is always zero and its resampling is unreachable. Both
    teams walk the same stations in a different order.
- **The trigger in ADR-007 is answered, not merely fired.** ADR-007 stays
  unchanged; this document is where its group-hunt sentence leads.

## Rules

- `challenges/domain` holds the synchronization contract and names no transport.
- The Realtime adapter lives in `challenges/data` and is the only place that
  knows about channels and `postgres_changes`.
- Group state is written only through server RPCs, never through a table write
  from the client.
- No reward and no session end is computed on the client.
- Reconnecting re-reads the session; the stream never becomes the source of
  truth.

## Review triggers

- Realtime cost outgrows its value, which makes the polling adapter the point of
  this ADR.
- A second feature needs group session state, which would make it a cross-feature
  contract rather than an internal one.
- The group hunt needs to survive an app restart in the same way the solo hunt
  does, which would put a local read-through cache next to server state and
  create the second-truth problem this ADR avoids.
- The backend findings E-21, E-54 or E-57 are fixed or, worse, are not, and step
  40 ships against them anyway.
