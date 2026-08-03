---
id: ENG-API-DOMAIN
status: accepted
owner: engineering
scope:
  - domain
  - api
load_when:
  - domain_modeling
  - repository_change
  - api_change
---

# API and Domain Design Standard

## Public APIs

Keep public APIs small and intentional.

- Prefer required named parameters when several values share a type.
- Do not expose mutable collections.
- Do not expose vendor SDK types outside adapters.
- Do not leak DTOs or database records.
- Make units explicit.
- Document ordering and pagination semantics.
- Return typed expected failures.

## Domain invariants

Create domain types when primitive confusion or invalid values would be costly.

Examples:

- `FactId`
- `CityId`
- `CollectionOperationId`
- `XpAmount`
- `GeoPoint`
- `CollectionTimestamp`

Do not wrap every string automatically. Use value objects where they protect meaning or invariants.

## Use cases

Introduce a use case when the operation:

- coordinates multiple dependencies;
- has business rules;
- is reused by multiple entry points;
- needs transaction/idempotency behavior;
- produces a meaningful domain result.

Simple read-only repository access may be used directly from an AsyncNotifier.

## Repositories

A repository is owned by a domain and exposes business-oriented operations.

Good:

```dart
Future<Result<CollectionEntry, CollectionFailure>> collect(
  CollectFactCommand command,
);
```

Avoid CRUD-shaped interfaces that merely mirror tables:

```dart
insertCollectionRow(Map<String, dynamic> row);
```

## Data sources

Data sources are narrow and technology-specific.

- remote data source speaks Supabase/API language;
- local data source speaks database/cache language;
- repository performs coordination and mapping;
- data source does not contain presentation behavior.

## Backward compatibility

Changes to persisted data, deep links, analytics events and backend contracts require compatibility consideration and migration notes.
