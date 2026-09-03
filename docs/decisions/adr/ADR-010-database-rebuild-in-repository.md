---
id: ADR-010
status: proposed
owner: architecture
scope:
  - decision
  - backend
load_when:
  - relevant_decision
  - implementation
  - review
---

# ADR-010: The Database Moves Into This Repository And Is Rebuilt

Status: **Proposed**
Date: 2026-09-03

Requested by the owner on 2026-09-03: *„ja dann verschieb die Datenbank bitte in
das git hier. dann binden wir das Git hier mit Supabase aber eben Dairens git.
Aber bitte auch die Datenbank neu aufbauen, das ist alles sehr schlecht."* And,
on how to read the old one: *„fühl dich nicht an das alte backend / alte
Datenbank gebunden."*

**This is not a new direction.** The direction was settled on 2026-08-31: rebuild,
with the same guard rails as the client. What was missing was the moment at which
it is cheap, and the reason it is cheap now is measured, not hoped for.

## Context

### Why now is the cheap moment, in one number

From the read-only inventory in `docs/operations/backend-inventory.md`: the
running PWA reaches the backend through 17 RPCs and 10 table accesses. **The
Flutter client calls none of the 17.** It touches exactly two things: it reads
`facts`, and it signs in and reads `profiles.username`.

So the coupling between the new client and the old backend is two files. Every
step from 36 to 50 makes that number grow. The inventory said so on 2026-08-31
and it is still true today.

### And a second number, from the owner

*„Alle Fakten aller Städte werden eh gelöscht vorher, bevor wir live."*

That removes the expensive half of any rebuild. There is no fact corpus to
migrate, so there is no schema to preserve for its sake, and the `Rom` versus
`Rome` repair described in E-56 does not need doing. It needs **preventing**,
which is a different and much smaller job.

### What is actually wrong with the old one

Not a list of bugs. A shape. Three properties, each measured:

**There is no migration system.** No `supabase/config.toml`, no CLI project, no
ledger table, no directory that enforces order. Eight SQL files carry the
sentence *"Run manually in Supabase SQL Editor"* in their headers. Two functions
are defined twice (`start_group_session`, `_team_generate_orders`), so which
version runs depends on the order in which somebody pasted files into an editor.
**Nobody can say what the running database contains.** Every finding in the
inventory is qualified with "according to the files".

**Rewards are computed where they can be changed by the person receiving them.**
E-19 (client-side session timing), E-54 (coins farmable through group sessions),
E-69 (repeat taps credit 50 coins each), E-55 (`user_trophies` and
`user_city_scores` writable by their owner). These are not four bugs. They are
one missing property: nothing separates "the client asks" from "the server
grants".

**Three functions take the user id as a parameter and are reachable without a
session** (E-52). That is the same missing property seen from the other side.

Add E-53 (user facts can approve themselves), E-58 (the editorial tool is a
static page holding a `service_role` key in the browser), E-16 (all scores and
trophies world-readable), E-66 (a fact with no assignable city counts as its own
city and hands out two trophies early), and the picture is complete: the old
backend has no consistent notion of who may assert what.

### What must not be baked in

Two things are deliberately unsettled, and the schema has to stay out of their
way.

**The puzzle concept is being rethought.** On 2026-09-03 the owner put it on
hold: *„Lass den teil erstmal ruhen."* E-79 measured why: of 1911 puzzles, 247
can be answered correctly at all, and the 82 counting puzzles compare against
zero. **The new schema therefore stores puzzles as content and implements no
answer checking.** Encoding today's comparison would freeze the very thing that
is under review.

**The city key contract is open as D-22.** This ADR proposes the shape that
answers it, because a rebuilt database is the only place where it can be answered
cheaply. If the architect wants a different shape, this is the section to change.

## Decision drivers

1. **The client must not learn a second wrong contract.** Whatever it binds to
   next, it should bind to once.
2. **A defect class beats a defect fix.** Where a structure can make a whole
   family of holes impossible, prefer the structure.
3. **The state of the database must be readable from the repository.** Today it
   is not, and that alone invalidates every other guarantee.
4. **The live PWA keeps working.** It is the only real user of the old backend
   and it must not be the test subject.
5. **Editorial work must be possible on day two.** The inventory warns that
   without an answer to E-58, any rebuild is back where it started after a day,
   because somebody has to approve facts.

## Considered options

### A. Repair the old project in place

Apply the nine prepared migrations in `docs/operations/supabase-migrations/`,
then keep going.

Rejected. It leaves the structural cause untouched: after the repairs there is
still no migration system, still two definitions of two functions, and still no
way to say what the database contains. The repairs also have to be applied to a
database whose actual state is unknown, which is how the ninth file came to be
named `99-pruefungen.sql`.

### B. Introduce the CLI project on the old database, then refactor forward

Run `supabase db pull` against production, commit the result as migration one,
and evolve from there.

Rejected, but it is the option worth naming, because it is the textbook answer.
It makes migration one a 2000-line snapshot of a schema that nobody designed and
that carries every finding above as committed truth. Every later cleanup then
has to be a reversal, and reversals of RLS policies on live data are the most
expensive kind. The owner's instruction *„fühl dich nicht an das alte backend
gebunden"* rules it out explicitly.

### C. A new, empty project, schema written from what the client needs

Chosen. Justified by the two numbers above: the client uses none of the old RPCs,
and the fact corpus is being discarded anyway.

### D. Two projects in parallel, forever

Not an option, a consequence. C implies a period during which the old project
serves the PWA and the new one serves the app. The decision is about how long,
and it is the owner's, not the architect's.

## Decision

**1. The schema lives in this repository.** A Supabase CLI project at
`supabase/`, with `config.toml` and `migrations/`. This makes ADR-001's fourth
rule true for the first time: *"Schema changes are versioned migrations."* It has
been the rule since 2026-07-19 and has never held.

**2. A new, empty Supabase project, under a Supabase account of its own.**
Nothing is pulled from the old one. The old project stays untouched and keeps
serving the PWA until the owner retires it.

Confirmed by the owner on 2026-09-03: *"ja okay, dann neuer Supabase Accout und
wir verbinden Git damit und meinen ein neues Projekt."* The account matters as
much as the project. The screenshot taken during that conversation showed the
integration list of a Supabase project whose GitHub App is installed on the
`RuleZero` organisation, which is the owner's employer. FACT hanging off work
credentials and work billing is a dependency nobody chose.

**3. The Git connection runs through the repository owner.** The Supabase GitHub
App must be installed by the account that owns `Daigon2/flutter-fact`. Measured
on 2026-09-03: the owner's own GitHub account has `push` but not `admin` on that
repository, and GitHub does not let a collaborator install an App on a repository
owned by another user account. **Maestro Dairen does this step, and nobody else
can.**

**4. Seven structural properties**, each replacing a family of findings rather
than a single one.

| Property | Replaces | How |
|---|---|---|
| Default deny on every table | E-16, E-55 | RLS enabled everywhere, no `USING (true)`, every read and write named by a policy |
| No function takes a user id | E-52 | Every `SECURITY DEFINER` function derives the actor from `auth.uid()`. A caller cannot name somebody else |
| Rewards are an append-only ledger, not counters | E-54, E-69, E-06 | Coins and experience are the sum of ledger rows. A unique constraint on (actor, kind, reference) makes crediting the same thing twice impossible by definition, not by a check somebody has to remember |
| Cities are a table with a stable id | E-11, E-56, E-66, E-75, D-22 | `cities(id, slug, …)`, and `facts.city_id` references it. Nothing derives a city from a display name or a coordinate, anywhere |
| Reward rules are rows, not code | E-49, inventory §5b | Thresholds and amounts live in tables. Changing a trophy threshold is an update, not a migration of a 120-line trigger |
| Server time for anything that pays | E-19 | Durations and deadlines that affect a reward are computed from `now()` inside the granting function. The client displays a countdown, it never reports one |
| Editorial access is a role on a real account | E-58, E-53 | No `service_role` outside the server. Approval is a policy on a role, and a user-created fact cannot set its own approved flag |

**5. What the schema does not contain.** No puzzle answer checking (see above).
No comment or upvote tables until something reads them; the inventory measured
that `comments` is written and never read and `upvotes` is dead on both sides.

**6. Migration content: authentication only, and possibly not even that.** Every
other table is discarded. Whether existing accounts are carried or re-created is
the one open question in this ADR, and it is the owner's: see Risks.

## Consequences

**Good.**

- The database's state becomes readable from the repository, and a CI job can
  assert that it builds from zero.
- Seven findings stop being work items and become impossible.
- D-22 gets an answer as a by-product rather than as a separate project.
- The client binds to one contract instead of two.

**Costs, stated plainly.**

- The nine prepared migrations in `docs/operations/supabase-migrations/` are no
  longer the plan. They keep their value as a **specification of what was wrong**
  and as the test list for the new schema, and they should be re-read in that
  role rather than deleted.
- The 11 pipeline scripts that write with `service_role` have to be re-pointed at
  the new project. They stay server-side, which is where a `service_role` key
  belongs.
- The editorial tool has to be rebuilt against a role instead of a master key.
  This is E-58 and it was already unavoidable.
- There is a period with two projects, and one cut-over moment for the PWA.

## Risks and mitigations

**The account question, and it is the only real one.** Supabase does not support
moving `auth.users` between projects as a supported operation. Carrying accounts
means exporting password hashes and importing them, which is fragile and
officially discouraged. The alternatives are a forced password reset for existing
accounts, or re-creating them.

*This needs the owner and I have not assumed an answer.* The size of the problem
is unknown to me: I do not know how many real accounts exist. If they are the
team and a few testers, re-creating is the cheapest correct answer and the risk
disappears. **If the PWA has real users with collected facts, this becomes the
most expensive part of the whole plan**, and the sequencing below changes.

**The pipeline is the second risk.** 39 scripts, 11 of them with database access.
None of them are in this repository, and I must not modify that repository. They
have to be re-pointed by whoever owns them, and until that happens the new
project has no facts. Mitigation: the cities seed and a small hand-made fact set
are enough for the app to be exercised end to end, so this does not block the
client.

**The third is scope drift into the reward economy.** Making rules into rows
invites redesigning them. It must not. The ledger and the tables are structure;
the numbers in them are copied from what exists until somebody decides otherwise.

## Migration and rollback

**Rollback is the reason this order is safe.** Until step 5, the old project is
untouched and the PWA is unaffected. Abandoning the plan at any earlier point
costs the work done and nothing else.

| Step | What | Who | Touches production? |
|---|---|---|---|
| 0 | `supabase/` as a CLI project in this repository, empty migrations directory, CI job that applies all migrations to a throwaway database from zero | me | no. **Done on 2026-09-03** |
| 1 | New Supabase account, new empty project, Supabase GitHub App installed on `Daigon2/flutter-fact` | **Maestro Dairen** | no |
| 2 | The schema as reviewable migrations, in order: extensions, cities, profiles, facts, collection, ledger, progression, hunts, creator and storage, then policies and functions | me | no, new project only |
| 3 | Cities seed, then facts imported fresh | pipeline owner | new project only |
| 4 | The client's keys point at the new project. Two files | me | no |
| 5 | The PWA is either re-pointed in its single backend file or left on the old project until retired | owner's call | **yes** |

Step 5 is the only irreversible moment, and it is a decision rather than a task.

## Validation

Not "it works". Four things that a machine can assert, added to the existing four
gates in `.github/workflows/gates.yml`.

1. **The schema builds from zero.** All migrations applied to an empty database in
   CI. This is the single check the old backend never had, and its absence is the
   root of everything in the Context section. **Built on 2026-09-03** as Gate 5
   in `.github/workflows/gates.yml`.

   It runs in CI and not on the maintainer's machine, because it needs Docker and
   none is installed there (measured 2026-09-03). That is a real gap and it is
   named rather than papered over: a broken migration is caught on push, not
   before it. `quality-gates.md` therefore still lists four local gates.
2. **No table without RLS, and no policy with `USING (true)`.** A query over
   `pg_tables` and `pg_policies`, run as a test, not as a review habit.
3. **No `SECURITY DEFINER` function with a user id parameter.** A query over
   `pg_proc`. This turns E-52 from a finding into a build failure.
4. **The ledger cannot double-credit.** A test that grants the same reward twice
   and asserts the second attempt is rejected, plus one that asserts the derived
   balance equals the sum of rows.

Additionally, the nine files in `docs/operations/supabase-migrations/` become the
acceptance list: each one describes a hole, and each hole gets a test that proves
the new schema does not have it.

## Related decisions

- **ADR-001** is amended, not replaced. Supabase stays. Its rule about versioned
  migrations becomes enforceable for the first time.
- **ADR-009** stands. Group hunt synchronization over Supabase Realtime is
  unaffected by which project the tables live in, and the transport was chosen as
  replaceable.
- **ADR-007** is being amended separately for D-20 (full hunt restore). That
  amendment is independent of this one.
- **D-22** is answered by property four, subject to the architect's agreement.
- **E-79 and D-19** are explicitly out of scope: no puzzle evaluation in the
  schema.
- **E-57** becomes a table design rather than a repair: the team hunt needs a
  shared first and last station with differing second and second-to-last
  positions, per the owner on 2026-09-03.

## Review triggers

- The account question is answered in a way that requires carrying user data.
- The pipeline cannot be re-pointed, which would make the new project factless
  for longer than the client can tolerate.
- Supabase branching is required and the plan does not allow for it.
- The puzzle concept lands somewhere that needs schema support after all.
