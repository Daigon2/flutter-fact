---
id: ADR-005
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-005: Riverpod as Dependency Injection

Status: **Accepted**  
Date: 2026-07-19

## Context

The project already uses Riverpod for state and requires replaceable repositories/services in tests. A second DI mechanism would create duplicate lifecycle and registration concepts.

## Decision

Use Riverpod as the sole dependency-injection and composition mechanism. Classes still receive dependencies through constructors; providers assemble the graph.

## Alternatives considered

- GetIt
- injectable + GetIt
- manual singleton registry
- constructor wiring only at the app root

## Consequences

- One lifecycle/composition system.
- Easy provider overrides in tests.
- Provider organization and naming require discipline.

## Rules

- Do not add GetIt or injectable.
- Widgets/notifiers do not instantiate repositories or vendor clients.
- Infrastructure and use cases are exposed through providers.
- Classes prefer constructor injection.
- Providers have one clear responsibility.

## Review triggers

- Riverpod is removed as state management.
- Non-Flutter execution contexts require an independent composition root that Riverpod cannot reasonably serve.
- Background isolates reveal a concrete lifecycle limitation.
