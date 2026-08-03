---
id: ENG-NAMING
status: accepted
owner: engineering
scope:
  - all
load_when:
  - implementation
  - review
---

# Naming and File Organization

## Files

Use `lower_snake_case.dart`.

One primary public type per file unless tightly coupled small types improve readability.

Names describe responsibility:

```text
fact_details_page.dart
nearby_facts_notifier.dart
collect_fact.dart
supabase_fact_repository.dart
fact_remote_dto.dart
```

Avoid:

```text
helpers.dart
models.dart
services.dart
common.dart
constants.dart
```

## Types

Use `UpperCamelCase`.

Suffixes carry meaning:

| Suffix | Meaning |
|---|---|
| `Page` | routable screen |
| `View` | substantial composed UI surface |
| `Widget` | only when no more precise domain name exists |
| `Notifier` | Riverpod mutable state owner |
| `State` | immutable presentation/application state |
| `Repository` | domain contract |
| `RepositoryImpl` | avoid; use technology/behavior prefix |
| `DataSource` | external/local adapter |
| `Dto` | transport/persistence model |
| `Mapper` | boundary conversion |
| `UseCase` | optional in class name; prefer verb phrase |
| `Policy` | pure business decision |
| `Failure` | expected typed failure |

Prefer:

```text
SupabaseFactRepository
CollectFact
CollectionEligibilityPolicy
```

Avoid:

```text
FactRepositoryImpl
FactServiceManager
GeneralHelper
```

## Variables and methods

Use names that reveal intent and units.

```dart
final distanceMeters = ...
final retryDelay = Duration(seconds: 2);
final collectedAtUtc = ...
```

Methods use verbs:

```text
loadNearbyFacts
collectFact
retryPendingOperations
canCollect
```

Booleans read as assertions:

```text
isCollected
hasPendingSync
canRetry
shouldRequestLocation
```

## Providers

Provider names describe what they expose, not implementation mechanics.

```text
factRepositoryProvider
nearbyFactsProvider
collectionNotifierProvider
currentCityProvider
```

Avoid `get`, `instance`, `serviceLocator` and redundant `riverpod` suffixes.

## Tests

Test files mirror production paths and end in `_test.dart`.

Group names describe the unit and scenario. Test names describe behavior:

```dart
test('returns AlreadyCollected when the fact was collected before', ...)
```

Avoid names such as `test1`, `works`, or method-name-only tests.

## Feature public API

Cross-feature imports use an explicit public entry point when necessary:

```text
features/facts/facts.dart
```

Only stable domain/application contracts are exported. Presentation and data internals are not exported.
