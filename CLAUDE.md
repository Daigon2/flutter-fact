# FACT Repository Instructions

## Mission

Build FACT as a secure, maintainable, multi-city Flutter app for iOS and Android. Repository documents are the source of truth; chat history is not.

## Source priority

1. Current explicit human instruction
2. Accepted product decisions and ADRs
3. Architecture documents
4. Engineering standards
5. Feature documentation and tests
6. Existing implementation patterns
7. Agent assumptions

Report conflicts instead of choosing silently.

## Global invariants

- Use pragmatic feature-first Clean Architecture.
- Riverpod 3 handles shared state and dependency composition.
- `go_router` handles typed navigation.
- Domain code imports no Flutter, Riverpod or Supabase.
- Widgets do not access repositories or vendor clients.
- Business concepts do not move into `core` for convenience.
- Preserve multi-city behavior; Munich is launch content, not a hard-coded architecture assumption.
- The mobile client is untrusted; authorization is server-enforced.

## Task routing

Read `START_HERE.md`, then use `docs/ai/context-routing.md` to load only the documents relevant to the task. Do not read all of `docs/` by default.

Use skills for repeatable workflows and specialist agents only when isolated context adds value.

## Escalation

Follow `docs/ai/escalation.md`. Obtain human approval before new packages, schema/sync semantics, auth/security changes, new sensitive data, cross-feature/public contracts, recurring cost, reward economy changes or accepted-ADR violations.

## Completion

Run applicable checks from `docs/engineering/quality-gates.md`, self-review the final diff, and report:

- behavior changed;
- key files;
- checks actually executed;
- unresolved risk;
- decisions still requiring approval.

Never claim an unexecuted check passed.
