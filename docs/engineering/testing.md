---
id: ENG-TESTING
status: accepted
owner: engineering
scope:
  - flutter
  - backend
load_when:
  - implementing_tests
  - reviewing_test_risk
  - bug_fix
---

# Testing Strategy

## 1. Goal

Tests provide confidence proportional to risk. They protect behavior, invariants, contracts and critical user journeys.

## 2. Test portfolio

### Domain unit tests

Use for:

- policies;
- entities and value objects;
- reward/progression rules;
- eligibility;
- conflict resolution;
- pure mapping rules with business meaning.

These tests use no Flutter binding, Riverpod, network or database.

### Application/use-case tests

Use fakes to verify:

- orchestration;
- success and failure paths;
- ordering of meaningful effects;
- idempotency;
- cancellation/retry;
- emitted outcomes.

Avoid verifying every private call.

### Repository and data tests

Verify:

- DTO parsing;
- mapping;
- backend error translation;
- local/remote coordination;
- cache and outbox behavior;
- pagination;
- schema compatibility.

Use contract tests so fake and production repositories share behavioral expectations where valuable.

### Notifier tests

Use Riverpod provider containers and overrides.

Verify:

- initial state;
- commands;
- loading/data/error transitions;
- invalidation;
- cancellation;
- stale/pending states.

### Widget tests

Verify user-observable behavior:

- content;
- interactions;
- accessibility semantics;
- loading/error/empty states;
- navigation intent through test adapters.

Do not assert deep widget-tree implementation details.

### Golden tests

Use selectively for:

- design-system components;
- map overlays that can be rendered deterministically;
- high-value branded screens.

Do not make the entire app dependent on fragile pixel tests.

### Integration tests

Cover critical journeys:

- onboarding/auth;
- city selection;
- discover and open fact;
- collect fact;
- offline collect then reconnect;
- tour progress;
- challenge completion;
- account/profile operations.

Keep the suite small enough to run reliably.

### Backend tests

Supabase migrations, policies, functions and idempotent commands require backend-level tests. Client tests do not prove authorization.

## 3. Risk-based requirements

| Change | Minimum expected coverage |
|---|---|
| Pure UI copy/style | Widget/manual verification as appropriate |
| New widget interaction | Widget test |
| Notifier state flow | Notifier test |
| Domain rule | Unit tests including boundaries |
| Repository query/mapping | Repository/data test |
| Navigation/deep link | Router test |
| Auth/security | Integration + backend policy tests |
| Offline mutation | Unit + repository + integration test |
| Schema migration | Migration/policy tests + rollback consideration |

## 4. Test quality rules

A good test:

- fails for a meaningful regression;
- has clear arrange/act/assert phases;
- controls time, randomness and external dependencies;
- is deterministic;
- avoids real network access unless explicitly integration-level;
- uses domain-relevant fixtures;
- explains scenario through its name.

Avoid:

- testing private methods;
- excessive mocks;
- asserting every implementation call;
- sleep-based waiting;
- shared mutable global fixtures;
- one giant test for an entire feature.

## 5. Fakes and mocks

Prefer fakes for repositories and stateful collaborators.

Use mocks for narrow interaction contracts when the interaction itself is the behavior.

Do not mock value objects, entities or simple DTOs.

## 6. Coverage

Coverage is a diagnostic, not the goal.

No universal percentage is sufficient. High-risk domain and synchronization logic should approach complete behavioral branch coverage. Generated code and trivial getters are excluded from meaningful review.

## 7. Flaky tests

A flaky test is a defect.

- quarantine only with an owner and issue;
- investigate timing, shared state and platform assumptions;
- never rerun indefinitely to obtain green CI.

## Practical test patterns

## Naming

```dart
group('CollectionEligibilityPolicy', () {
  test('rejects collection outside the allowed radius', () {
    // arrange
    // act
    // assert
  });
});
```

## Time

Inject a clock rather than reading `DateTime.now()` inside domain/application logic.

## Randomness

Inject a random source or deterministic seed.

## Async

Use framework-aware waiting and completers. Do not use arbitrary delays.

## Repository fake

A fake should model relevant behavior, including failures and stored state, not simply return canned values for every call.

## Contract suite

Define shared behavioral tests for repository implementations when multiple implementations must honor the same semantics.

## Fixtures

Use builders with sensible defaults:

```dart
final fact = FactBuilder().withCity(munichId).build();
```

Keep fixtures close to their owning feature. Avoid a global fixture warehouse.

## Golden stability

Pin fonts/assets and control dimensions. Review golden changes visually; never blindly regenerate.
