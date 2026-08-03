---
id: ARCH-REF-COLLECTION
status: accepted
owner: architecture
scope:
  - flutter
load_when:
  - reference_feature
---

# Reference Feature: Collection

## Purpose

Demonstrates a complex, offline-capable and gamification-connected feature.

## Structure

```text
features/collection/
├── presentation/
│   ├── pages/
│   ├── widgets/
│   ├── notifiers/
│   └── state/
├── application/
│   └── use_cases/
│       ├── collect_fact.dart
│       ├── retry_pending_collections.dart
│       └── observe_collection.dart
├── domain/
│   ├── entities/
│   │   └── collection_entry.dart
│   ├── value_objects/
│   │   └── collection_operation_id.dart
│   ├── repositories/
│   │   └── collection_repository.dart
│   ├── failures/
│   └── policies/
│       └── collection_eligibility_policy.dart
└── data/
    ├── repositories/
    │   └── synced_collection_repository.dart
    ├── datasources/
    │   ├── remote/
    │   └── local/
    ├── dto/
    ├── mappers/
    └── sync/
        └── collection_outbox_processor.dart
```

## Collect flow

```text
User taps Collect
  ↓
CollectionNotifier.collect(factId)
  ↓
CollectFact use case
  ↓
Validate local prerequisites and create operation ID
  ↓
CollectionRepository.collect(command)
  ↓
Persist local pending entry and outbox atomically
  ↓
Attempt remote idempotent command
  ↓
Mark synchronized or retain pending
  ↓
Emit FactCollected outcome/event
  ↓
Progression is updated by server or explicit progression workflow
```

## Invariants

- Duplicate taps do not create duplicate collection entries.
- Operation IDs are stable across retries.
- Server remains authoritative for security-sensitive eligibility and rewards.
- Pending state is visible.
- A rejected collection does not silently disappear.
- Collection does not directly mutate profile XP fields.
- Fact content is referenced by `FactId`, not duplicated.

## Testing

- Eligibility policy unit tests.
- Collect use-case tests with fake repository.
- Repository contract tests for idempotency.
- Outbox retry tests.
- Notifier tests for pending/success/rejection.
- Integration test for offline collect then reconnect.
