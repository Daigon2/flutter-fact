---
id: ENG-FLUTTER
status: accepted
owner: engineering
scope:
  - flutter
load_when:
  - flutter_implementation
  - flutter_review
---

# Dart and Flutter Coding Standard

## 1. Foundation

Follow Dart formatting and Effective Dart unless this standard is more specific.

Do not manually align code against `dart format`.

## 2. Functions and methods

A function should express one coherent responsibility.

Extract code when:

- distinct business steps are mixed;
- a block needs its own meaningful name;
- error handling obscures the main path;
- the same behavior is duplicated;
- testing a rule otherwise requires exercising unrelated behavior.

Do not extract merely to satisfy an arbitrary line count. Typical functions are short enough to understand without scrolling, but clarity is the rule.

Prefer early returns for invalid or terminal conditions.

```dart
Future<void> collect(FactId factId) async {
  if (state.isLoading) return;

  final result = await _collectFact(factId);
  _apply(result);
}
```

Avoid boolean parameters that obscure meaning.

```dart
// Avoid
loadFacts(true, false);

// Prefer
loadFacts(
  includeCollected: true,
  forceRefresh: false,
);
```

## 3. Classes

A class has one primary reason to change.

Avoid generic classes named:

- `Manager`
- `Helper`
- `Utils`
- `Common`
- `BaseService`

Use domain or technical responsibility in the name.

Prefer composition over inheritance. Inheritance is acceptable for framework contracts and true subtype relationships.

## 4. Widgets

Widgets remain declarative.

A widget may:

- render state;
- own ephemeral UI state;
- invoke notifier commands;
- perform presentation-only navigation;
- map input events to application actions.

A widget must not:

- call Supabase;
- instantiate repositories;
- encode domain eligibility rules;
- perform complex data mapping;
- contain synchronization logic;
- silently swallow failures.

Extract a widget when it:

- has a distinct semantic responsibility;
- is reused;
- has independent interaction/state;
- makes the parent difficult to read.

Do not extract every `Padding`, `Row` or three-line fragment.

## 5. Build methods

Keep `build` focused on structure.

Allowed inside `build`:

- simple view-data selection;
- small local conditions;
- formatting through presentation helpers;
- widget composition.

Move out:

- async work;
- mutation;
- repository access;
- domain decisions;
- expensive collection processing.

## 6. State

All shared state is immutable.

Never mutate collections held by state.

```dart
state = state.copyWith(
  facts: [...state.facts, fact],
);
```

Model independent UI states explicitly rather than stacking unrelated booleans.

Avoid:

```dart
isLoading
hasError
isEmpty
isRefreshing
```

when impossible combinations can occur. Prefer sealed states or a stable state model with explicit invariants.

## 7. Asynchronous code

- Await futures unless intentionally detached.
- Detached work must use an explicit helper and error reporting.
- Preserve stack traces.
- Distinguish cancellation, expected failure and unexpected exception.
- Check widget/context lifetime after async gaps.
- Avoid sequential awaits where operations are independent and safe to run concurrently.
- Never retry indefinitely.

## 8. Nullability

Null represents genuine absence, not an uninitialized shortcut.

Prefer required constructor parameters.

Avoid force unwraps. A `!` requires a nearby invariant that makes it obviously safe.

## 9. Collections

Prefer collection literals, `where`, `map` and comprehensions when readable.

Do not create multiple intermediate collections on hot map-rendering paths without measurement.

Use unmodifiable/immutable views at public boundaries when mutation would violate ownership.

## 10. Errors

Do not catch `Exception` merely to return empty data.

Avoid:

```dart
try {
  return await repository.load();
} catch (_) {
  return [];
}
```

Map known infrastructure failures. Report unexpected errors with stack traces.

## 11. Comments

Comments explain why, constraints or non-obvious trade-offs.

Do not narrate obvious code.

Use `TODO(owner, issue): reason` with a tracked issue or removal condition. Unowned TODOs are forbidden in production paths.

## 12. Documentation comments

Use `///` for public APIs whose contract is not obvious.

Document:

- invariants;
- side effects;
- failure behavior;
- units;
- ordering;
- ownership;
- non-obvious lifecycle.

Do not document private implementation line by line.

## 13. Constants and magic values

Business thresholds belong in named domain policy/configuration.

Visual constants belong near the owning component or design system.

No unexplained durations, distances, retry counts or reward amounts inline.

## 14. Platform code

Native iOS/Android code requires:

- a narrow Flutter-facing adapter;
- platform-specific tests where feasible;
- documented permission and lifecycle behavior;
- no duplicated business rules across platforms.
