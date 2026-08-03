---
id: ADR-003
status: accepted
owner: architecture
scope:
  - decision
load_when:
  - relevant_decision
---

# ADR-003: Riverpod 3 State Management

Status: **Accepted**  
Date: 2026-07-19

## Context

The application needs testable asynchronous state, clear dependency composition and predictable lifecycle management.

## Decision

Use Riverpod 3. Use Provider for dependencies, Notifier for synchronous feature state and AsyncNotifier for asynchronous workflows. Use local Flutter state for ephemeral widget state.

## Alternatives considered

- Provider/ChangeNotifier
- Bloc/Cubit
- GetX
- Manual inherited widgets

## Consequences

- Shared state is explicit and overrideable in tests.
- Code generation and custom lint become part of the build.
- Teams must avoid turning providers into a global state dumping ground.

## Rules

- Immutable state.
- No legacy ChangeNotifier/StateNotifier for new code.
- No Riverpod types in domain.
- Notifiers coordinate workflows but do not own complex domain rules.
- KeepAlive requires a documented lifecycle reason.

## Review triggers

- Riverpod package direction materially changes.
- Build/code-generation cost becomes unacceptable.
- A concrete feature demonstrates that the model cannot represent required state safely.
